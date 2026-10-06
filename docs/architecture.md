# Architecture — CHARCOT SENTINEL

## Vue d'ensemble

CHARCOT SENTINEL est une application web monofichier (HTML + CSS + JS embarqués) pour la
coordination des urgences à bord du COMMANDANT CHARCOT (PONANT). Pas de build step, pas de
framework — le fichier HTML est directement servi/ouvert.

Voir `description Logiciel.txt` pour le tutoriel fonctionnel complet (pages Fire, Flood,
Pollution, Medical, Muster, Abandon, OSC, Plans, Lists, Messages, Log, Report, Settings).

## Fichiers principaux

- `LCC sentinel 4.html` — application principale, ouverte en usage réel/exercice. Contient la
  chaîne de version `CHARCOT SENTINEL vX.Y.Z-charcot`.
- `Source/index.html` — copie source équivalente, tenue synchronisée avec le fichier principal
  par `SAVE_VERSION.ps1` (les deux sont mis à jour ensemble à chaque bump de version).
- `manifest.json` — manifeste PWA (icônes, nom, `start_url` pointant vers `LCC sentinel 4.html`).
- `sw.js` — service worker PWA.
- `sentinel_server.py` — serveur Python (WebSocket + HTTP) pour la synchronisation
  multi-postes en temps réel (Bridge, ECR, OSC, Back Up, Meeting Point), avec profils par PIN
  4 chiffres, autosave périodique de l'état partagé (`sentinel_state.json`), TLS optionnel
  (`ssl_cert.pem` / `ssl_key.pem`).
- `INSTALL.bat` / `START_SERVER.bat` — installation des dépendances Python (`websockets`) et
  démarrage du serveur local.

## Données de référence

- `assets/` — données de zones/espaces du navire (`OE_SPACES_annotated_*.json`,
  `zones_*.json`, `_compact_spaces.json`), listes d'assemblée (`assembly stations.xlsx`).
- `Source/` (hors HTML) — plans, photos, PDF de référence (plan général d'urgence, plans
  d'incendie, logos, images d'embarcations) utilisés comme assets visuels de l'application.
- `LOCAUX_NAVIRE_COMPLET.csv`, `STRUCTURE_LOCAUX_NAVIRE.md` — référentiel des locaux du navire.

## Versioning applicatif

Voir la section "VERSIONING APPLICATIF" de `.ai/MASTER_WORKFLOW.md`. En résumé :
`SAVE_VERSION.ps1` détecte `CHARCOT SENTINEL vX.Y.Z-charcot` dans `LCC sentinel 4.html`,
archive une copie horodatée de ce fichier et de `Source/index.html` dans `versions/`,
incrémente la version dans les deux fichiers, et journalise dans `versions/CHANGELOG.txt`.

Ce mécanisme est indépendant de Git : un même commit peut couvrir zéro, un ou plusieurs bumps
de version applicative.

## Synchronisation réseau

`sentinel_server.py` fait tourner en parallèle :
- un serveur HTTP (port 8080) qui sert la PWA,
- un serveur WebSocket (port 8765) qui synchronise l'état entre postes connectés
  (alarmes, logs, snapshot partagé), avec sauvegarde automatique toutes les
  `AUTOSAVE_INTERVAL` secondes.

### IP du serveur du bord

`10.115.19.23` — `SHIP_SERVER_IP` dans `sentinel_server.py` (IP annoncée en priorité dans les
liens/QR, et toujours incluse dans le certificat HTTPS), et IP par défaut des appareils jamais
configurés dans `LCC sentinel 4.html` (`NetworkModule.config`), `LCC OSC.html` (`NetOSC.init`) et
`LCC Sentinel Mustering.html` (`serverConfig`). À changer aux 4 endroits si le serveur change de PC.
Au démarrage, le serveur régénère `ssl_cert.pem` si le certificat ne couvre pas l'IP du PC courant
(en conservant les IP qu'il couvrait déjà).

### RESET CRUISE (nouvelle croisière)

Settings > RESET CRUISE (`ResetCruise` dans `LCC sentinel 4.html`) : remet tout à zéro sauf les listes
(`oe_sentinel_lists_state`, `oe_sentinel_lists_pax_backup`) et les réglages (`ResetCruise.PRESERVE_KEYS`).
Connecté, il envoie `RESET_CRUISE` : le serveur vide état / alarmes / journal, adopte un **n° de
croisière** (horodatage ISO, persisté dans `sentinel_state.json`) et relaie l'ordre aux postes et au
serveur pair. Chaque appli garde ce n° (`oe_cruise_id`, `lcc_osc_cruise_id`, `lcc_mustering_cruise_id`) :
un poste absent pendant le reset voit un n° plus récent à l'`AUTH_OK` et se remet à zéro avant tout
envoi (OSC / Mustering : seulement si leurs données locales datent d'avant le reset). Le serveur refuse
les `STATE_SYNC` portant un n° plus ancien que le sien et adopte un n° plus récent.

### Lanceur du PC serveur

`lanceur/lcc.ps1` (appelé par `INSTALLER_LCC_SENTINEL.bat`, `LANCER_LCC_SENTINEL.bat`,
`ARRETER_SERVEUR.bat` et les raccourcis qu'il crée) :
- installation unique : Python + modules, pare-feu, raccourci Bureau « LCC SENTINEL »,
  démarrage auto du serveur à l'ouverture de session (dossier Démarrage) ;
- surveillance : relance `sentinel_server.py --no-pause` s'il s'arrête (journaux dans
  `%LOCALAPPDATA%\LCC_Sentinel\logs`, hors OneDrive) ;
- ouverture de l'appli en fenêtre Chrome/Edge sur `http://localhost:8081` + WebSocket local
  `8764` — ports en clair liés à `127.0.0.1` uniquement (`--local-http-port` / `--local-port`).
  Sur localhost, Chrome accepte service worker et installation PWA, ce qu'il refuse sur l'origine
  HTTPS auto-signée (vérifié). `/api/server-info` permet à cette instance locale de générer des
  QR/liens tablettes avec l'IP réseau et les ports HTTPS.

## Points d'attention pour toute modification

- Le fichier HTML principal est volumineux (~2,4 Mo) — toujours localiser précisément la
  section à modifier (grep sur un id/label plutôt que relecture complète) avant d'éditer.
- Toute modification fonctionnelle doit être répercutée dans les deux copies
  (`LCC sentinel 4.html` et `Source/index.html`) si elles doivent rester synchronisées, sauf
  si l'utilisateur indique explicitement qu'elles divergent intentionnellement.
- Ce logiciel est utilisé en conditions réelles et en exercice à bord — ne jamais casser une
  fonctionnalité opérationnelle existante sans validation explicite.
