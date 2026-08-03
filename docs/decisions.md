# Décisions techniques

Format : date, décision, contexte/justification.

## 2026-03-29 — Application monofichier HTML, sans build step

**Décision** : CHARCOT SENTINEL est développé comme une unique page HTML embarquant CSS et JS,
plutôt qu'avec un framework front-end et un pipeline de build.

**Pourquoi** (déduit du contexte projet) : usage embarqué/offline sur tablette et postes
dédiés à bord, sans dépendance à un serveur de build ou à une connexion internet fiable.
Le fichier s'ouvre directement dans un navigateur ou via `sentinel_server.py`.

## 2026-03-29 — Versioning applicatif indépendant de Git (`SAVE_VERSION.ps1`)

**Décision** : la version `CHARCOT SENTINEL vX.Y.Z-charcot` est gérée par script PowerShell,
avec archivage horodaté dans `versions/` et changelog dans `versions/CHANGELOG.txt`,
indépendamment des commits Git.

**Pourquoi** : permet de restaurer rapidement une version antérieure connue-stable avant/après
un exercice ou un incident réel, sans dépendre de l'historique Git. Voir `RESTORE_VERSION.bat`.

## 2026-07-27 — GitHub comme mécanisme de reprise multi-ordinateurs, pas OneDrive

**Décision** : `git push`/`git pull` vers `origin` (`github.com/baltio/LCC-sentinel`) est le
mécanisme de référence pour reprendre le projet sur un autre ordinateur, même si le dossier de
travail est physiquement dans OneDrive.

**Pourquoi** : OneDrive synchronise fichier par fichier sans connaître la sémantique de `.git`
(index, objets, refs) — une synchronisation en plein milieu d'un commit/checkout peut corrompre
le dépôt, surtout avec des gros binaires (plans, PDF > 50 Mo) déjà présents dans ce repo.
OneDrive reste utile comme confort (les fichiers non-Git, ou en attente de commit, apparaissent
aussi sur l'autre poste), mais l'historique de code doit transiter par GitHub.

## 2026-05-12 — Réintroduction du serveur de synchronisation réseau

**Décision** : `sentinel_server.py` (WebSocket + HTTP) remis en service ("serveur is back",
v2.0.24 → v2.0.25).

**Pourquoi** : nécessaire pour la synchronisation multi-postes (Bridge/ECR/OSC/Back
Up/Meeting Point) en temps réel — à documenter plus en détail si des changements y sont
apportés.
