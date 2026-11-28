# Guide — Rendre un logiciel « installable » + mises à jour par clé USB

Destiné à une session Claude Code / Visual Studio travaillant sur **un autre logiciel** (ex. NAVILOG,
dossier `C:\Users\safety\OneDrive\Visual Studio Project\Logiciel historique`). Il décrit ce qui a été
fait sur **LCC Sentinel 4**, pourquoi, les pièges vérifiés, puis un plan à adapter.

> **Pour la session qui lit ce guide** : l'implémentation de référence est sur ce PC, lisible
> directement (chemins absolus ci-dessous). Lis-la avant d'écrire du code, ne la recopie pas à
> l'aveugle : adapte-la au projet cible après l'avoir inspecté (étape 0 du plan).

---

## 1. Ce que l'utilisateur obtient (le résultat visé)

| Moment | Action de l'utilisateur | Ce qui se passe |
|---|---|---|
| Préparation (PC avec internet) | Double-clic `PREPARER_INSTALLATION.bat` | Crée sur le Bureau un dossier propre : uniquement les fichiers utiles + installateur Python + modules Python téléchargés à l'avance |
| Installation (PC cible, **sans internet**) | Copier le dossier dans `C:\NOM_APP`, double-clic `INSTALLER_….bat` | Python + modules installés hors-ligne, pare-feu ouvert (1 demande admin), icône Bureau, serveur démarré à chaque ouverture de session Windows |
| Usage quotidien | Icône du Bureau | Démarre le serveur s'il ne tourne pas, attend qu'il réponde, ouvre l'appli (fenêtre Chrome/Edge `--app`) déjà connectée |
| Crash / redémarrage du PC | Rien (ou l'icône) | Une surveillance relance le serveur automatiquement ; démarrage auto à la connexion Windows |
| Mise à jour | Clé USB avec le nouveau dossier, double-clic `METTRE_A_JOUR.bat` **sur la clé** | Arrêt serveur, sauvegarde de l'ancienne version, copie de la nouvelle **sans toucher aux données / certificat**, relance |

---

## 2. Implémentation de référence (à lire)

Racine : `C:\Users\safety\OneDrive\Visual Studio Project\Logiciel LCC 2.0\LCC sentinel 2\`

| Fichier | Rôle |
|---|---|
| `lanceur\lcc.ps1` | **Tout le mécanisme** dans un seul script PowerShell à « actions » : `Lancer`, `Serveur` (surveillance), `Arreter`, `Installer`, `Preparer`, `MettreAJour`. Encodé **UTF-8 avec BOM**. |
| `INSTALLER_LCC_SENTINEL.bat`, `LANCER_LCC_SENTINEL.bat`, `ARRETER_SERVEUR.bat`, `PREPARER_INSTALLATION.bat`, `METTRE_A_JOUR.bat` | Enveloppes d'une ligne : `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lanceur\lcc.ps1" -Action X` |
| `sentinel_server.py` | Serveur Python. Options ajoutées : `--local-http-port` / `--local-port` (accès local en clair lié à `127.0.0.1`), `--no-pause`, filtre des fichiers sensibles dans `do_GET`, `/api/server-info` |
| `LISEZ-MOI_INSTALLATION.txt` | Notice courte copiée dans le dossier d'installation (installation, usage, tablettes, mise à jour, dépannage) |
| `SAVE_VERSION.ps1` | Incrémente la version **et le `CACHE_NAME` de chaque service worker** (sinon les PWA installées ne se mettent jamais à jour) |
| `docs\architecture.md` | Sections « Lanceur du PC serveur », « IP du serveur du bord », « RESET (nouvelle croisière) » |

---

## 3. Architecture

```
PC SERVEUR (C:\NOM_APP, hors OneDrive)
├─ lanceur\app.ps1 -Action Serveur   ← lancé à l'ouverture de session (raccourci dossier Démarrage)
│    boucle : lance python serveur.py --no-pause ; s'il s'arrête → relance (ralentit si crash en boucle)
│    journaux : %LOCALAPPDATA%\NOM_APP\logs   (PAS dans le dossier du logiciel / OneDrive)
├─ serveur.py
│    ports RÉSEAU (0.0.0.0)      : pour les tablettes (HTTPS auto-signé si besoin)
│    ports LOCAUX (127.0.0.1)    : http://localhost:XXXX en clair, pour ce PC uniquement
└─ icône Bureau → app.ps1 -Action Lancer
     serveur prêt ? sinon démarre la surveillance, attend /api/... (45 s max)
     pare-feu OK ? sinon propose de l'ouvrir (UAC)
     ouvre chrome/msedge --app=http://localhost:XXXX/app.html?params-de-connexion
```

---

## 4. Leçons vérifiées (ne pas les réapprendre)

Chacune a été constatée en test réel sur LCC, pas supposée.

**Navigateur / PWA**
1. **HTTPS auto-signé = pas d'installation PWA ni de mode hors-ligne.** Même après avoir cliqué
   « Continuer », Chrome refuse le service worker (« An unknown error occurred when fetching the
   script ») et l'installabilité (`not-from-secure-origin`). **`http://localhost` est une origine
   sûre** : d'où les ports locaux en clair liés à `127.0.0.1` (injoignables depuis le réseau).
2. **Site public (GitHub Pages) → IP du réseau local : bloqué** (`ERR_BLOCKED_BY_LOCAL_NETWORK_ACCESS_CHECKS`,
   Chrome 154). Il faut l'autorisation « Accès au réseau local » côté tablette.
3. **Polices / scripts sur CDN** (Google Fonts, jsdelivr…) : à embarquer en local (`assets/fonts/fonts.css`
   + `.woff2`), sinon affichage dégradé / démarrage ralenti sans internet.
4. **Service worker** : à chaque version, les octets de `sw.js` doivent changer (bump `CACHE_NAME`),
   sinon les appareils installés gardent l'ancienne appli **indéfiniment**. Vérifier que le script de
   version bump **tous** les `sw*.js`.
5. **Fichier ouvert par double-clic (`file://`)** : ne devine pas le bon schéma ws/wss ; prévoir un repli.

**Python / Windows**
6. **`.venv` dans OneDrive = cassé sur un autre PC** (chemin absolu de l'autre utilisateur). Ne jamais
   en dépendre : utiliser le Python du système (trouvé par `py -3`, puis `python` hors `WindowsApps`,
   puis chemins standards) — le `python.exe` de `WindowsApps` est un faux (Microsoft Store).
7. **Installation hors-ligne** : télécharger à l'avance l'installateur officiel (`python-3.12.x-amd64.exe`,
   installé avec `/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1`) et les modules :
   `pip download --only-binary=:all: --platform win_amd64 --python-version 3.10..3.14 -d wheels <modules>`,
   puis sur la cible `pip install --no-index --find-links wheels <modules>`.
8. **`input()` / `pause` dans un serveur lancé automatiquement** = blocage. Ajouter `--no-pause`.
9. Chemins trop longs (MAX_PATH) : créer les venv de test dans un chemin court (`%TEMP%\x`).

**PowerShell 5.1 (celui de Windows 10)**
10. Script avec accents → **UTF-8 avec BOM** obligatoire.
11. `$ErrorActionPreference = 'Continue'` (avec `Stop`, le moindre avertissement de pip/python sur
    stderr devient fatal) ; tester `$LASTEXITCODE` explicitement.
12. `Start-Process -PassThru` : lire `$proc.Handle` **avant** `WaitForExit()`, sinon `ExitCode` est vide.
13. Mutex « une seule surveillance » : attraper `AbandonedMutexException` (surveillance précédente tuée).
14. `[System.IO.DriveInfo]::new()` plante sur un chemin réseau `\\serveur\…` → `try/catch`.
15. `robocopy` : code de sortie < 8 = succès (1 = fichiers copiés).
16. Lancement invisible : raccourci vers `powershell.exe -WindowStyle Hidden -File …` ; messages à
    l'utilisateur via `System.Windows.Forms.MessageBox`.

**Réseau / sécurité**
17. **Pare-feu** : règles créées une fois (UAC) à l'installation ; à chaque lancement, vérifier sans
    droits admin (`Get-NetFirewallRule`) et proposer de corriger. Sans règle, les tablettes Wi-Fi sont
    bloquées sans message clair.
18. **Serveur web qui sert le dossier du logiciel** : bloquer clé privée (`*.pem`), fichier d'état,
    `*.py`, `*.bat`, `*.ps1`, journaux, dossiers internes — en normalisant le chemin (`unquote` +
    `posixpath.normpath`) sinon `%2E` ou `./` contournent le filtre.
19. Certificat auto-signé : ne pas le synchroniser entre PC (il contient l'IP) ; ne pas le régénérer
    sur une adresse temporaire (`127.x`, `169.254.x`) — chaque régénération oblige les tablettes à le
    ré-accepter.
20. IP du serveur du bord : **fixe** sur le PC, et pré-remplie par défaut dans les applis.

**Mise à jour**
21. **Ne jamais écraser** l'état en cours, le certificat, les données utilisateur : le dossier préparé
    ne les contient pas, la copie les exclut en plus (`robocopy /E /XF … /XD …`), **pas de `/MIR`**.
22. Arrêter le serveur avant de copier ; sauvegarder l'ancienne version (retour arrière) ; refuser si
    source = cible ; retrouver l'installation via le `WorkingDirectory` du raccourci Bureau.
23. Garder le comportement **par défaut d'un serveur sur port non standard** à l'esprit pendant les
    tests (LCC utilise alors un autre fichier d'état → faux « état perdu »).

**Publication GitHub Pages** (si utilisée)
24. Branche `gh-pages` mise à jour à la main ; **la pousser seule** (`git push origin gh-pages`) : poussée
    en même temps que `master`, GitHub n'a pas lancé la publication (2 fois).

---

## 5. Spécificités observées sur NAVILOG (à confirmer par la session)

Dossier : `C:\Users\safety\OneDrive\Visual Studio Project\Logiciel historique`

- Appli principale : `NAVILOG (1).html` (espace + parenthèses dans le nom → encoder `%20`, `%28`, `%29`
  dans les URL ; envisager un nom sans espace avec une page de redirection pour l'ancien nom).
- **Plusieurs serveurs**, chacun avec son `.bat` et sa fenêtre :
  `py -m http.server 8000` (appli), `cors_proxy_tar1090.py` (3215), `gps_tcp_bridge.py`
  (3210, **IP GPS en dur `10.117.19.170:2000`** dans le `.bat`), `tile_server\navilog_tile_server.py`
  (**port 8080**), `https_server_icewatch.py` (HTTPS pour le GPS des tablettes).
  → la surveillance doit gérer **N processus** (une boucle par serveur, ou un serveur Python unique).
  → **conflit de port : LCC Sentinel utilise 8080 (et 8081, 8764, 8765).** Si les deux logiciels
    tournent sur le même PC, changer le port des tuiles de NAVILOG.
  → mettre l'IP/port du GPS dans un fichier de configuration, pas dans un `.bat`.
- Dossier de **11 Go** : `versions\` (6,9 Go), `NAVILOG_PARTAGE\` (2 Go, ancien export portable),
  `Raster\` (911 Mo), `NAVILOG_DATA\` (712 Mo, tuiles). Le dossier préparé doit être une **liste
  blanche** ; décider quelles données (tuiles, rasters) sont dans le paquet, et si elles sont mises à
  jour séparément (gros volumes).
- Très nombreux `tmp_*.py`, `.kra`, `.docx`, `.xlsx` de travail → exclus du paquet.
- `BUILD_NAVILOG_PORTABLE.ps1` existe déjà (liste de fichiers → `NAVILOG_PARTAGE\app`) : bon point de
  départ pour l'action `Preparer` ; il fait `Remove-Item` du dossier de sortie — garder ce genre
  d'effacement limité au dossier de sortie.
- `.venv` présent dans OneDrive → même piège que LCC (leçon 6).
- `SAVE_VERSION.ps1` existe : vérifier qu'il bump le `CACHE_NAME` du `sw.js` NAVILOG.

---

## 6. Plan à suivre (session NAVILOG)

**Étape 0 — Inventaire (ne rien modifier)**
- Lister ce qu'il faut pour faire tourner l'appli : fichiers HTML/JS/CSS, données réellement
  chargées (chercher `fetch(`, `src=`, `href=`, URLs de tuiles), serveurs Python et leurs dépendances
  (`import` non standard → modules à embarquer), ports, URLs externes (CDN, polices, API internet).
- Identifier les **données utilisateur à ne jamais écraser** (routes, journaux, réglages, fichiers
  produits par les serveurs).
- Poser à l'utilisateur les questions de décision : quels serveurs sont indispensables ; PC cible
  (IP fixe ?) ; tablettes ou PC seul ; tuiles/rasters dans le paquet ou à part.

**Étape 1 — Serveurs prêts pour un lancement automatique**
- `--no-pause` (aucun `input()`), sortie en UTF-8, ports configurables, codes de sortie ≠ 0 en erreur.
- Endpoint léger de santé (ex. `/api/status`) pour que le lanceur sache quand le serveur est prêt.

**Étape 2 — `lanceur\navilog.ps1` à actions** (copier la structure de `lcc.ps1`)
- `Serveur` : surveillance de **chaque** serveur (redémarrage, ralentissement si crash en boucle,
  mutex, fichier d'arrêt, journaux dans `%LOCALAPPDATA%`).
- `Lancer`, `Arreter`, `Installer`, `Preparer` (liste blanche + `installation\python-*.exe` +
  `installation\wheels`), `MettreAJour` (exclusions des données utilisateur).
- Enveloppes `.bat` d'une ligne + `LISEZ-MOI`.

**Étape 3 — Appli**
- Polices/scripts externes en local ; IP/ports par défaut ; si PWA : bump du service worker à chaque
  version.

**Étape 4 — Tests (obligatoires avant de livrer)**
- Ports de test différents, état/données dans un dossier temporaire, Python de test dans un venv court
  (`LCC_PYTHON`-like variable d'environnement pour forcer l'exécutable).
- `Preparer` → dossier temp ; installation des modules **sans internet** depuis `wheels` ; démarrage
  du serveur depuis la copie ; serveur tué → relance automatique vérifiée ; `Arreter`.
- `MettreAJour` sur une installation simulée (ancienne version + fausses données utilisateur) :
  vérifier que les données sont intactes, la version changée, la sauvegarde présente.
- Navigateur : Chrome headless + protocole DevTools (`--remote-debugging-port`, profil temporaire)
  pour vérifier service worker, installabilité (`Page.getInstallabilityErrors`), hors-ligne
  (`Network.emulateNetworkConditions`). Ne jamais tuer le Chrome de l'utilisateur ; n'ouvrir aucune
  fenêtre visible sans prévenir.
- Nettoyer tout ce qui a été créé pour les tests.

---

## 7. Message à coller dans la session NAVILOG

```
Lis le guide C:\Users\safety\OneDrive\Visual Studio Project\Logiciel LCC 2.0\LCC sentinel 2\docs\GUIDE_INSTALLEUR_ET_MISES_A_JOUR.md
puis l'implémentation de référence qu'il cite (lanceur\lcc.ps1 en priorité).
Objectif : faire la même chose pour NAVILOG — dossier préparé pour installation hors-ligne,
installateur, icône Bureau qui démarre les serveurs et ouvre l'appli, relance automatique en cas de crash,
et METTRE_A_JOUR.bat pour pousser les nouvelles versions par clé USB sans écraser les données.
Commence par l'étape 0 (inventaire) et pose-moi les questions de décision avant de modifier quoi que ce soit.
Teste chaque étape comme décrit en section 6 avant de me dire que c'est terminé.
```
