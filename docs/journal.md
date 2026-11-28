# Journal de développement

Historique des sessions et des changements réalisés. Le détail des bumps de version
applicative reste dans `versions/CHANGELOG.txt` (source exhaustive) — ce journal résume le
contexte et les décisions de chaque session, ce que le changelog ne capture pas.

## 2026-11-28 — v2.0.44

- Réorganisation de la page CONFIG (SYSTEM SETTINGS) : les sous-sections de l'ancien « ONGLET 2 »
  deviennent des onglets à part entière ; LISTES, LOG, RAPPORT, OSC et B.BOX sortent de la barre latérale
  et deviennent des onglets de CONFIG (les pages elles-mêmes sont inchangées, une barre d'onglets
  unique est déplacée en tête de la page affichée).
- RESET AFTER DRILL + RESET CRUISE fusionnés en un seul bouton RESET qui remet tout à zéro, listes
  CREW / PAX comprises, puis propose de recharger les listes au redémarrage.
- Page LISTES simplifiée : l'Overview n'affiche plus que CREW / PAX on board et deux boutons
  IMPORT CREW LIST / IMPORT PAX LIST ; après un import, la vue « processed data » de cette liste
  s'ouvre (une vue séparée pour CREW et pour PAX). Nouveaux sous-onglets « Manual backup count »
  (saisie + SAVE AND ACTIVATE) et « Files & distribution » (source active, archives, sauvegarde
  serveur, répartition PAX LB01/LB03, allocation des embarcations — anciens blocs de l'Overview).
- Import XLS (manifestes CREW / PAX du bord) : lecture des colonnes par position. L'ancienne lecture
  « compactée » décalait les colonnes dès qu'un champ était vide (nationalité, cabine crew fausses)
  et comptait les lignes de total « Passenger [acc. SOLAS…] » / « Persons total… » comme 2 PAX en trop.
  Ces lignes (et « Total Crew: ») sont ignorées. Vérifié sur tous les fichiers de
  X:\3-SAFETY\16 - Logiciel Questionnaires\Listes CREW&PAX (PAX251126 : 155 PAX).
- Assembly PAX : liste des cabines A mise à jour (`PAX_ASSEMBLY_A_CABINS`, 739 et 754-757 ajoutées),
  toute autre cabine valide → B, préfixe « S » traité comme le numéro. Plus d'affectation A/B
  « au hasard » (fallback une ligne sur deux) pour une cabine inconnue. L'app Mustering répartit
  désormais les PAX selon l'assembly calculée par Sentinel 4.
- PROCESSED DATA : changer une cabine recalcule enfin l'assembly et le lifeboat (avant, l'assembly
  calculée était figée comme « manuelle ») ; seul un muster choisi à la main prime sur la cabine.
- FIRE > SITUATION > FIRE LOCATION : le local saisi (ou choisi avec 📍) s'affiche sur la carte
  PONT DU FEU avec un overlay rouge « 🔥 FIRE » (affichage seul, l'état de zone de PLANS n'est pas
  modifié). Le mode AUTO du mini-plan ne fonctionnait pas (`window.FireDeckMiniMap` n'existe pas,
  le module est un `const`) et un changement de pont pendant le chargement de l'image était perdu.
- Icônes de plan OSC ⇄ Sentinel 4 : les deux apps n'utilisaient pas le même repère (OSC : x/y =
  pixels de l'écran de la tablette + sx/sy = plan ; Sentinel : x/y = plan). Une icône posée sur une
  app apparaissait hors du plan / au mauvais endroit sur l'autre. Format commun : x/y = coordonnées
  du plan (Sentinel convertit les anciens marqueurs sx/sy). L'OSC traite désormais
  PLAN_TACTICAL_UPDATE (avant : icône vue seulement au prochain état complet, et risque d'effacement
  par le STATE_SYNC de la tablette).
- Page MUSTER : retour de ADA TEAM (132 306 307 629 630 920 921 922) et ADMIN TEAM (303 310),
  avec COMPLETE / MISSING / présence par personne, synchronisées et reliées aux listes teamADA /
  teamAdmin de l'app Mustering. Elles n'apparaissent ni sur la page FIRE ni au Meeting Point de l'OSC.
- PIN : le poste BRIDGE a toujours le PIN 100001 (`FIXED_PINS` dans sentinel_server.py), réimposé
  au démarrage même si pins.json en contient un autre, non renouvelable depuis la console (« PIN
  fixe »). Les autres postes gardent leur PIN aléatoire ; un poste qui avait 100001 en reçoit un nouveau.

## 2026-07-27

- Mise en place de la structure de documentation (`.ai/MASTER_WORKFLOW.md`, `docs/`,
  `SESSION.md`) pour permettre une reprise de session sans perte de contexte.
- Travail en cours (non commité) : correctif d'une erreur au début de l'embarquement, en vue
  du bump v2.0.26 → v2.0.27 (voir `versions/CHANGELOG.txt` ligne 27 et `SESSION.md`).

## Historique antérieur (résumé depuis `versions/CHANGELOG.txt`)

- v2.0.0 → v2.0.20 (2026-03-29 → 2026-04-16) : mise en place initiale, adaptation tablette OSC
  11 pouces, démo bridge, corrections Abandon/Lifeboat/rapport, ajout des plans, premiers
  drills, correction du nombre de lifeboats.
- v2.0.20 → v2.0.24 (2026-04-29 → 2026-04-30) : cycle de drills généraux d'équipage et
  corrections associées, préparation GCD AFFMAR.
- v2.0.24 → v2.0.25 (2026-05-12) : remise en service du serveur local (`sentinel_server.py`).
- v2.0.25 → v2.0.26 (2026-05-19) : mise à jour du 19/05/2026.
- v2.0.26 → v2.0.27 (2026-07-27) : correctif erreur début embarquement (en cours).
