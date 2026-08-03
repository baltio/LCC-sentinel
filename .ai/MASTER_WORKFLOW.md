# MASTER WORKFLOW — CHARCOT SENTINEL

Tu es l'assistant de développement de ce projet (CHARCOT SENTINEL — LE COMMANDANT CHARCOT).

Ton objectif n'est pas uniquement d'écrire du code. Tu dois maintenir le projet organisé,
documenté et facilement reprenable, y compris après une longue coupure ou sur un autre poste.

Ces règles sont obligatoires pour toute session de travail sur ce dépôt.

## SOURCE DE VÉRITÉ

Le dépôt GitHub `baltio/LCC-sentinel` (remote `origin`, branche `master`) est la source de
vérité du code — c'est ce qui permet de reprendre le projet sur un autre ordinateur. Toute
modification importante doit être **commitée et poussée (`git push`)** avant la fin d'une
session, pas seulement laissée en fichiers modifiés locaux. Ce dossier projet est aussi situé
dans OneDrive : OneDrive synchronise les fichiers de travail entre ordinateurs, mais ce n'est
**pas** un substitut fiable à `git push`/`git pull` pour l'historique de code (risque de
conflit/corruption du dossier `.git` si OneDrive synchronise pendant une opération Git — voir
`docs/decisions.md`).

## DOCUMENTATION

Le dossier `docs/` contient toujours :

- `architecture.md` — comment le projet est construit (fichier unique, versioning, serveur de sync)
- `roadmap.md` — fonctionnalités prévues / en cours
- `backlog.md` — bugs connus et idées non planifiées
- `decisions.md` — décisions techniques importantes et leur justification
- `journal.md` — historique des sessions de développement réalisées

Ils doivent rester cohérents entre eux :
- Modification de l'architecture → mettre `architecture.md` à jour.
- Décision technique importante → l'ajouter dans `decisions.md`.
- Fonctionnalité terminée → mettre `roadmap.md` à jour.
- Bug ou idée → `backlog.md`.
- Travail réalisé → `journal.md`.

## SESSION.md

`SESSION.md` (à la racine) représente l'état exact du projet à l'instant présent. Avant la fin
d'une session, il doit contenir :

- date
- branche Git et état des modifications en cours
- ce qui fonctionne
- ce qui reste à faire
- bugs connus
- prochaine étape
- fichiers importants modifiés (ex : `LCC sentinel 3.html`, `Source/index.html`)

## GIT

- Commits atomiques uniquement : ne jamais mélanger plusieurs fonctionnalités dans un commit.
- Ne jamais utiliser `git add -A` / `git add .` sans relire `git status` d'abord (le dépôt
  contient des gros binaires — plans, photos, PDF — à ne pas commiter par accident).
- Messages explicites, à l'impératif, décrivant le *pourquoi* :
  - `Ajout du suivi des portes coupe-feu sur la page Fire`
  - `Correction du bug de comptage à l'embarquement`
  - `Refactoring du panneau OSC`
- Ne jamais forcer un push, ni amender un commit déjà partagé, sans confirmation explicite.

## VERSIONING APPLICATIF (CHARCOT SENTINEL vX.Y.Z-charcot)

Ce projet a son propre système de version intégré au HTML, distinct des commits Git :

- La version vit dans `LCC sentinel 3.html` et `Source/index.html` sous la forme
  `CHARCOT SENTINEL vX.Y.Z-charcot`.
- `SAVE_VERSION.ps1` (ou `SAVE_VERSION.bat`) archive une copie horodatée dans `versions/`,
  incrémente la version et journalise l'entrée dans `versions/CHANGELOG.txt`.
- Ne jamais éditer manuellement le numéro de version ni les fichiers dans `versions/` —
  ce sont des archives générées.
- Un bump de version (patch/minor/major) n'est pas un substitut à un commit Git : les deux
  mécanismes sont complémentaires et doivent rester synchronisés (bump avant ou juste après
  un commit atomique correspondant).

## CODE

Toujours respecter :

- l'architecture existante (application monofichier HTML/CSS/JS, pas de build step)
- DRY / éviter la duplication de code dans le fichier HTML (souvent volumineux — vérifier
  qu'une fonction similaire n'existe pas déjà avant d'en écrire une nouvelle)
- des noms explicites (variables, fonctions, id/data-attributes du DOM)
- pas de commentaires superflus — uniquement pour expliquer un *pourquoi* non évident

## REFACTORING

Si une amélioration structurelle importante est détectée (ex : sortir le CSS/JS du monofichier,
changer le mécanisme de synchronisation réseau) :

1. Ne pas modifier directement.
2. Proposer le changement : pourquoi, avantages, inconvénients.
3. Attendre validation avant d'implémenter.

## DÉBUT DE SESSION

1. Vérifier `SESSION.md`.
2. Vérifier `docs/roadmap.md`.
3. Vérifier `docs/backlog.md`.
4. Proposer les priorités du jour.

## FIN DE SESSION

Avant de terminer, mettre à jour :

- `SESSION.md`
- `docs/journal.md`
- `docs/backlog.md`
- `docs/roadmap.md`

Puis proposer un message de commit (sans committer sans confirmation explicite si ce n'est
pas déjà la pratique validée avec l'utilisateur).

## IA

Avant toute génération importante sur `LCC sentinel 3.html` :

- relire `docs/architecture.md` pour respecter les conventions existantes,
- ne jamais casser une fonctionnalité opérationnelle existante (ce logiciel est utilisé en
  conditions réelles/exercices à bord — voir `docs/architecture.md`),
- privilégier des modifications localisées plutôt que des réécritures larges.

## OBJECTIF

Le projet doit pouvoir être repris instantanément, par n'importe qui, sans perte d'information,
en lisant uniquement `SESSION.md` puis `docs/`.
