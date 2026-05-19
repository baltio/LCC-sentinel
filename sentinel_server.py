#!/usr/bin/env python3
"""
=================================================================
  CHARCOT SENTINEL — Serveur WebSocket
  LE COMMANDANT CHARCOT — PONANT
  Synchronisation multi-postes en temps reel

  Lancer   : python sentinel_server.py
  Prereqis : pip install websockets   (ou double-cliquer INSTALL.bat)
=================================================================
"""

import asyncio
import json
import logging
import socket
import ssl
import threading
from datetime import datetime, timezone
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

try:
    import websockets
except ImportError:
    print("\n[ERREUR] Le module 'websockets' n'est pas installe.")
    print("  Executez : pip install websockets")
    print("  Ou double-cliquez sur INSTALL.bat\n")
    input("Appuyez sur Entree pour quitter...")
    raise SystemExit(1)

# ── Configuration ─────────────────────────────────────────────────────────────
HOST = '0.0.0.0'   # Ecouter sur toutes les interfaces reseau
PORT = 8765
HTTP_PORT = 8080    # Serveur HTTP pour l'application PWA
STATE_FILE = Path(__file__).with_name('sentinel_state.json')
CERT_FILE  = Path(__file__).with_name('ssl_cert.pem')
KEY_FILE   = Path(__file__).with_name('ssl_key.pem')
AUTOSAVE_INTERVAL = 5

# Profils autorises  →  code PIN (4 chiffres) : informations du poste
PROFILES = {
    '1001': {'id': 'bridge',    'name': 'Bridge Officer',   'role': 'Bridge',        'initials': 'BR'},
    '2002': {'id': 'ecr',       'name': 'Engine Control',   'role': 'ECR',           'initials': 'EC'},
    '3003': {'id': 'osc',       'name': 'On-Scene Cmdr',    'role': 'OSC',           'initials': 'OS'},
    '4004': {'id': 'backup',    'name': 'Back Up Station',  'role': 'Back Up',       'initials': 'BU'},
    '5005': {'id': 'meetpoint', 'name': 'Meeting Point',    'role': 'Meeting Point', 'initials': 'MP'},
}

# ── Etat serveur ───────────────────────────────────────────────────────────────
clients      = {}   # websocket → {authenticated, clientId, name, role, ip, ...}
alarms       = {}   # type → startTime | None
log_buffer   = []   # derniers logs synchronises (max MAX_LOG)
MAX_LOG      = 500
shared_snapshot = {}
shared_snapshot_meta = {'updatedBy': None, 'updatedAt': None}
state_dirty = False
client_counter = 0
log = logging.getLogger('sentinel')

# ── Utilitaires ───────────────────────────────────────────────────────────────
def get_local_ip():
    """Retourne l'adresse IP locale la plus probable (hors loopback)."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        pass
    try:
        all_ips = [i[4][0] for i in socket.getaddrinfo(socket.gethostname(), None)
                   if i[0] == socket.AF_INET and not i[4][0].startswith('127.')]
        if all_ips:
            return all_ips[0]
    except Exception:
        pass
    return '127.0.0.1'

def now_iso():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

def mark_state_dirty():
    global state_dirty
    state_dirty = True

def build_full_state_payload():
    return {
        'alarms': {k: {'active': v is not None, 'startTime': v} for k, v in alarms.items()},
        'logBuffer': log_buffer[-50:],
        'snapshot': shared_snapshot,
        'snapshotMeta': shared_snapshot_meta,
    }

def load_persistent_state():
    global shared_snapshot, shared_snapshot_meta

    if not STATE_FILE.exists():
        return False

    try:
        data = json.loads(STATE_FILE.read_text(encoding='utf-8'))
    except Exception as exc:
        log.warning(f'[STATE] Chargement impossible: {exc}')
        return False

    if isinstance(data.get('alarms'), dict):
        alarms.clear()
        for alarm_type, alarm in data['alarms'].items():
            if isinstance(alarm, dict) and alarm.get('active'):
                alarms[alarm_type] = alarm.get('startTime') or now_iso()
            else:
                alarms[alarm_type] = None

    if isinstance(data.get('logBuffer'), list):
        log_buffer.clear()
        log_buffer.extend(data['logBuffer'][-MAX_LOG:])

    if isinstance(data.get('snapshot'), dict):
        shared_snapshot = data['snapshot']

    if isinstance(data.get('snapshotMeta'), dict):
        shared_snapshot_meta = data['snapshotMeta']

    return True

def save_persistent_state(force=False):
    global state_dirty

    if not force and not state_dirty:
        return False

    payload = build_full_state_payload()
    try:
        STATE_FILE.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    except Exception as exc:
        log.warning(f'[STATE] Sauvegarde impossible: {exc}')
        return False

    state_dirty = False
    return True

async def autosave_loop():
    while True:
        await asyncio.sleep(AUTOSAVE_INTERVAL)
        save_persistent_state()

def get_client_list():
    return [
        {
            'clientId': info['clientId'],
            'name':     info.get('name', 'Unknown'),
            'role':     info.get('role', ''),
            'initials': info.get('initials', '?'),
            'ip':       info.get('ip', ''),
            'profileId':info.get('profileId', ''),
        }
        for ws, info in list(clients.items())
        if info.get('authenticated')
    ]

async def send_to(ws, message: dict):
    try:
        await ws.send(json.dumps(message, ensure_ascii=False))
    except Exception:
        pass

async def broadcast(message: dict, exclude=None):
    """Diffuser un message a tous les clients authentifies."""
    targets = [ws for ws, info in list(clients.items())
               if info.get('authenticated') and ws is not exclude]
    if not targets:
        return
    data = json.dumps(message, ensure_ascii=False)
    await asyncio.gather(
        *(ws.send(data) for ws in targets),
        return_exceptions=True
    )

# ── Gestionnaire de connexion ──────────────────────────────────────────────────
async def handler(ws, path='/'):
    global client_counter
    client_counter += 1
    cid = f'C{client_counter:03d}'
    peer = getattr(ws, 'remote_address', None)
    ip   = peer[0] if peer else 'unknown'

    clients[ws] = {'authenticated': False, 'clientId': cid, 'ip': ip}
    log.info(f'[+] Connexion {cid} depuis {ip}')

    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            mtype = msg.get('type', '')
            info  = clients.get(ws, {})

            # ── Authentification ─────────────────────────────────────────────
            if mtype == 'AUTH':
                token        = (msg.get('payload') or {}).get('token', '').strip()
                profile_data = (msg.get('payload') or {}).get('profile', {}) or {}

                if token in PROFILES:
                    prof = PROFILES[token]
                    display_name = profile_data.get('name') or prof['name']
                    role         = profile_data.get('role') or prof['role']
                    initials     = profile_data.get('initials') or prof['initials']

                    clients[ws] = {
                        'authenticated': True,
                        'clientId':  cid,
                        'ip':        ip,
                        'name':      display_name,
                        'role':      role,
                        'initials':  initials,
                        'profileId': prof['id'],
                    }

                    client_list = get_client_list()
                    # Notifier tous les autres de la mise a jour de la liste
                    await broadcast({'type': 'CLIENT_LIST', 'payload': client_list, 'ts': now_iso()})
                    # Repondre AUTH_OK au nouveau client
                    await send_to(ws, {
                        'type': 'AUTH_OK',
                        'payload': {'clientId': cid, 'clients': client_list},
                        'ts': now_iso(),
                    })
                    log.info(f'[OK] AUTH: {display_name} / {role} ({cid}) - {ip}')

                else:
                    await send_to(ws, {
                        'type': 'AUTH_FAIL',
                        'payload': {'reason': 'Token invalide — verifier le profil ou le mot de passe'},
                        'ts': now_iso(),
                    })
                    log.warning(f'[KO] AUTH FAIL: {cid} token={repr(token[:30])}')
                    await ws.close()
                    return

            elif not info.get('authenticated'):
                await send_to(ws, {'type': 'ERROR', 'payload': {'reason': 'Non authentifie'}})

            # ── Messages authentifies ─────────────────────────────────────────
            elif mtype == 'REQUEST_SYNC':
                await send_to(ws, {
                    'type': 'FULL_STATE',
                    'payload': build_full_state_payload(),
                    'ts': now_iso(),
                })
                log.debug(f'[SYNC] -> {cid}')

            elif mtype == 'STATE_SYNC':
                payload = (msg.get('payload') or {})
                snapshot = payload.get('snapshot')
                if isinstance(snapshot, dict):
                    global shared_snapshot, shared_snapshot_meta
                    shared_snapshot = snapshot
                    shared_snapshot_meta = {'updatedBy': cid, 'updatedAt': now_iso()}
                    mark_state_dirty()
                    save_persistent_state()
                    await broadcast({
                        'type': 'FULL_STATE',
                        'payload': build_full_state_payload(),
                        'ts': now_iso(),
                    }, exclude=ws)

            elif mtype == 'HEARTBEAT':
                await send_to(ws, {'type': 'HEARTBEAT_ACK', 'ts': now_iso()})

            elif mtype == 'ALARM_ACTIVATE':
                alarm_type = (msg.get('payload') or {}).get('alarmType')
                start_time = (msg.get('payload') or {}).get('startTime') or now_iso()
                if alarm_type:
                    alarms[alarm_type] = start_time
                    mark_state_dirty()
                    msg.setdefault('ts', now_iso())
                    await broadcast(msg, exclude=ws)
                    log.info(f'[ALARM] {alarm_type.upper()} ACTIVE — {info.get("name")}')

            elif mtype == 'ALARM_DEACTIVATE':
                alarm_type = (msg.get('payload') or {}).get('alarmType')
                if alarm_type:
                    alarms[alarm_type] = None
                    mark_state_dirty()
                    msg.setdefault('ts', now_iso())
                    await broadcast(msg, exclude=ws)
                    log.info(f'[ALARM] {alarm_type.upper()} END   — {info.get("name")}')

            elif mtype == 'LOG_ENTRY':
                entry = msg.get('payload')
                if entry:
                    log_buffer.append(entry)
                    if len(log_buffer) > MAX_LOG:
                        log_buffer.pop(0)
                    mark_state_dirty()
                await broadcast(msg, exclude=ws)

            elif mtype in ('MUSTER_UPDATE', 'ABANDON_UPDATE', 'OSC_TEAM_UPDATE',
                           'OSC_MESSAGE', 'FIRE_TEAM_UPDATE', 'CHAT_MESSAGE'):
                await broadcast(msg, exclude=ws)
                if mtype == 'CHAT_MESSAGE':
                    text = (msg.get('payload') or {}).get('text', '')
                    log.info(f'[CHAT] {info.get("name")}: {text[:80]}')

            else:
                # Transfert generique pour messages futurs
                await broadcast(msg, exclude=ws)

    except websockets.exceptions.ConnectionClosedOK:
        pass
    except websockets.exceptions.ConnectionClosedError:
        pass
    except Exception as e:
        log.error(f'[ERR] {cid}: {e}')
    finally:
        clients.pop(ws, None)
        client_list = get_client_list()
        await broadcast({'type': 'CLIENT_LIST', 'payload': client_list, 'ts': now_iso()})
        log.info(f'[-] Deconnexion {cid}')

# ── Certificat SSL auto-signé ────────────────────────────────────────────────

def generate_self_signed_cert(local_ip):
    """Génère un certificat SSL auto-signé pour HTTPS local. Retourne True si OK."""
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        import datetime as dt
        import ipaddress

        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, local_ip),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, 'PONANT LCC'),
        ])
        san_list = [x509.DNSName('localhost'),
                    x509.IPAddress(ipaddress.IPv4Address('127.0.0.1'))]
        try:
            san_list.append(x509.IPAddress(ipaddress.IPv4Address(local_ip)))
        except Exception:
            pass
        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(dt.datetime.utcnow())
            .not_valid_after(dt.datetime.utcnow() + dt.timedelta(days=3650))
            .add_extension(x509.SubjectAlternativeName(san_list), critical=False)
            .sign(key, hashes.SHA256())
        )
        CERT_FILE.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
        KEY_FILE.write_bytes(key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        ))
        log.info('[HTTPS] Certificat SSL généré : %s', CERT_FILE.name)
        return True
    except ImportError:
        log.warning('[HTTPS] Module "cryptography" absent — serveur en HTTP (pip install cryptography)')
        return False
    except Exception as exc:
        log.warning('[HTTPS] Erreur génération certificat : %s', exc)
        return False


# ── Serveur HTTP statique ─────────────────────────────────────────────────────

LISTS_FOLDER = Path(__file__).parent / 'lists_data'

def start_http_server(use_https=False):
    """Sert les fichiers statiques (HTML, assets) sur HTTP_PORT dans un thread."""
    www_root = Path(__file__).parent

    class SilentHandler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(www_root), **kwargs)

        def log_message(self, fmt, *args):
            pass  # Supprimer les logs HTTP verbeux

        def end_headers(self):
            # Headers pour autoriser le service worker PWA
            self.send_header('Service-Worker-Allowed', '/')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Access-Control-Allow-Origin', '*')
            super().end_headers()

        def do_OPTIONS(self):
            self.send_response(204)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.end_headers()

        def do_GET(self):
            # Liste les fichiers JSON disponibles
            if self.path == '/api/lists-files':
                LISTS_FOLDER.mkdir(exist_ok=True)
                files = sorted(
                    [f.name for f in LISTS_FOLDER.glob('*.json')],
                    reverse=True
                )
                body = json.dumps({'files': files}).encode('utf-8')
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            # Charge un fichier JSON spécifique
            if self.path.startswith('/api/load-lists/'):
                filename = self.path[len('/api/load-lists/'):]
                # Sécurité : interdire les chemins relatifs
                if '..' in filename or '/' in filename or '\\' in filename:
                    self.send_response(400)
                    self.end_headers()
                    return
                target = LISTS_FOLDER / filename
                if not target.exists() or target.suffix != '.json':
                    self.send_response(404)
                    self.end_headers()
                    return
                body = target.read_bytes()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            super().do_GET()

        def do_POST(self):
            if self.path == '/api/save-lists':
                try:
                    length = int(self.headers.get('Content-Length', 0))
                    body = self.rfile.read(length)
                    data = json.loads(body.decode('utf-8'))
                    LISTS_FOLDER.mkdir(exist_ok=True)
                    # Nom de fichier basé sur la date
                    from datetime import datetime as dt
                    date_str = dt.now().strftime('%Y-%m-%d_%H%M')
                    filename = f'LCC_lists_{date_str}.json'
                    target = LISTS_FOLDER / filename
                    target.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
                    resp = json.dumps({'ok': True, 'file': filename}).encode('utf-8')
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(resp)))
                    self.end_headers()
                    self.wfile.write(resp)
                    log.info(f'[LISTS] Sauvegarde: {filename}')
                except Exception as exc:
                    log.warning(f'[LISTS] Erreur sauvegarde: {exc}')
                    self.send_response(500)
                    self.end_headers()
                return
            self.send_response(404)
            self.end_headers()

    server = HTTPServer((HOST, HTTP_PORT), SilentHandler)
    if use_https:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
        server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


# ── Main ───────────────────────────────────────────────────────────────────────
async def main():
    local_ip = get_local_ip()

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s  %(message)s',
        datefmt='%H:%M:%S',
    )

    restored = load_persistent_state()

    # ── HTTPS : génère le cert si absent, sinon réutilise ──
    if not CERT_FILE.exists() or not KEY_FILE.exists():
        use_https = generate_self_signed_cert(local_ip)
    else:
        use_https = True
        log.info('[HTTPS] Certificat existant utilisé : %s', CERT_FILE.name)

    http_scheme = 'https' if use_https else 'http'
    ws_scheme   = 'wss'   if use_https else 'ws'

    http_server = start_http_server(use_https=use_https)

    sep = '=' * 62
    print(f'\n{sep}')
    print(f'  CHARCOT SENTINEL - Serveur WebSocket + {http_scheme.upper()}')
    print(f'  LE COMMANDANT CHARCOT - PONANT')
    print(sep)
    print(f'  IP du serveur  : {local_ip}')
    print(f'  WebSocket      : {ws_scheme}://{local_ip}:{PORT}')
    print(f'  Application    : {http_scheme}://{local_ip}:{HTTP_PORT}/LCC%20sentinel%203.html')
    if use_https:
        print(f'  [HTTPS] Certificat auto-signé — accepter l\'avertissement Chrome une seule fois')
    print(sep)
    print(f'  PROFILS ET TOKENS D\'ACCES :')
    print(f'  {"-" * 55}')
    for token, p in PROFILES.items():
        print(f'  [{p["role"]:<15}]  Code PIN : {token}')
    print(f'  {"-" * 55}')
    print()
    print(f'  Dans les Settings de l\'application :')
    print(f'    IP du serveur  : {local_ip}')
    print(f'    Port WS        : {PORT}')
    print(f'    Token          : (copier le token du profil souhaite)')
    print(f'    Etat persistant: {STATE_FILE.name} ({"restaure" if restored else "nouveau"})')
    print()
    print(f'  OUVRIR L\'APP DANS CHROME :')
    print(f'    {http_scheme}://{local_ip}:{HTTP_PORT}/LCC%20sentinel%203.html')
    if use_https:
        print(f'    → Accepter l\'avertissement "Non sécurisé" puis installer la PWA')
    print(f'    (ou {http_scheme}://localhost:{HTTP_PORT}/LCC%20sentinel%203.html en local)')
    print()
    print(f'  CTRL+C pour arreter le serveur')
    print(sep)

    ws_ssl = None
    if use_https:
        ws_ssl = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ws_ssl.load_cert_chain(str(CERT_FILE), str(KEY_FILE))

    async with websockets.serve(handler, HOST, PORT, ssl=ws_ssl):
        autosave_task = asyncio.create_task(autosave_loop())
        print(f'\n  Serveur actif - en attente de connexions...\n')
        try:
            await asyncio.Future()   # boucle infinie
        finally:
            autosave_task.cancel()
            save_persistent_state(force=True)
            http_server.shutdown()

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print('\n  Serveur arrete proprement.\n')
    except OSError as e:
        print(f'\n[ERREUR] Impossible de demarrer : {e}')
        print(f'  Le port {PORT} est peut-etre deja utilise.')
        input('Appuyez sur Entree pour quitter...')
