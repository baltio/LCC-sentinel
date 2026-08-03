# Architecture — CHARCOT SENTINEL

## Vue d'ensemble

CHARCOT SENTINEL est une application web monofichier (HTML + CSS + JS embarqués) pour la
coordination des urgences à bord du COMMANDANT CHARCOT (PONANT). Pas de build step, pas de
framework — le fichier HTML est directement servi/ouvert.

Voir `description Logiciel.txt` pour le tutoriel fonctionnel complet (pages Fire, Flood,
Pollution, Medical, Muster, Abandon, OSC, Plans, Lists, Messages, Log, Report, Settings).

## Fichiers principaux

- `LCC sentinel 3.html` — application principale, ouverte en usage réel/exercice. Contient la
  chaîne de version `CHARCOT SENTINEL vX.Y.Z-charcot`.
- `Source/index.html` — copie source équivalente, tenue synchronisée avec le fichier principal
  par `SAVE_VERSION.ps1` (les deux sont mis à jour ensemble à chaque bump de version).
- `manifest.json` — manifeste PWA (icônes, nom, `start_url` pointant vers `LCC sentinel 3.html`).
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
`SAVE_VERSION.ps1` détecte `CHARCOT SENTINEL vX.Y.Z-charcot` dans `LCC sentinel 3.html`,
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

## Points d'attention pour toute modification

- Le fichier HTML principal est volumineux (~2,4 Mo) — toujours localiser précisément la
  section à modifier (grep sur un id/label plutôt que relecture complète) avant d'éditer.
- Toute modification fonctionnelle doit être répercutée dans les deux copies
  (`LCC sentinel 3.html` et `Source/index.html`) si elles doivent rester synchronisées, sauf
  si l'utilisateur indique explicitement qu'elles divergent intentionnellement.
- Ce logiciel est utilisé en conditions réelles et en exercice à bord — ne jamais casser une
  fonctionnalité opérationnelle existante sans validation explicite.
