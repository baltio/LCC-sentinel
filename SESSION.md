# SESSION

_État exact du projet à relire en début de session._

## Date

2026-07-27

## Branche Git

`master`, tracke `origin/master` → `https://github.com/baltio/LCC-sentinel.git`. Un seul
commit existant pour l'instant : `48649db Initial commit - CHARCOT SENTINEL v2.0.24 Emergency
Management System` (déjà présent côté GitHub, rien à pousser sur ce commit).

## Modifications en cours (non commitées)

- `LCC sentinel 3.html` — modifié et partiellement stagé (MM) : correctif "erreur début
  embarquement", bump de version v2.0.26 → v2.0.27.
- `Source/index.html` — même correctif, à synchroniser.
- `manifest.json` — modifié et stagé (M).
- `versions/CHANGELOG.txt` — nouvelle entrée v2.0.26 → v2.0.27 ajoutée.
- Nouveaux fichiers non trackés :
  - `versions/LCC_sentinel_v2.0.26_2026-07-27_1452_maj-2707-post-modif-correctif-.html`
    (archive générée par `SAVE_VERSION.ps1`)
  - `versions/source_index_v2.0.26_2026-07-27_1452.html` (idem)
  - `.ai/MASTER_WORKFLOW.md`, `docs/` (documentation ajoutée cette session)

## Ce qui fonctionne

- Application principale opérationnelle en v2.0.26 (dernière version commitée/stable connue).
- Serveur de synchronisation réseau (`sentinel_server.py`) opérationnel depuis v2.0.25.

## Ce qui reste à faire

- Vérifier/valider le correctif "début embarquement" en cours dans `LCC sentinel 3.html` /
  `Source/index.html`.
- Commiter ce correctif atomiquement (probable message : "Correction du bug de début
  d'embarquement").
- Décider si les archives `versions/*v2.0.26*` (générées par `SAVE_VERSION.ps1`) doivent être
  commitées ou ignorées — vérifier `.gitignore` actuel.

## Bugs connus

Voir `docs/backlog.md`.

## Prochaine étape

1. Relire le diff du correctif embarquement avec l'utilisateur.
2. Commiter.
3. Mettre à jour `docs/journal.md` et `docs/roadmap.md` en conséquence.

## Fichiers importants modifiés cette session

- `.ai/MASTER_WORKFLOW.md` (nouveau)
- `docs/architecture.md`, `docs/roadmap.md`, `docs/backlog.md`, `docs/decisions.md`,
  `docs/journal.md` (nouveaux)
- `SESSION.md` (nouveau, ce fichier)
