# Structure des Locaux du Navire COMMANDANT CHARCOT

## Vue d'ensemble

Le navire est organisé selon **deux axes principaux** :

### 1. **Ponts (Decks)**
Les ponts horizontaux du navire, de bas en haut :
- **DKDB** : Double Design Bottom (compartiments de ballast, réservoirs de fuel)
- **DK01** : Engine Room (salle des machines)
- **DK02** : Machinery/Service Deck (services auxiliaires et équipements)
- **DK03** : Service/Accommodation (crew cabins, offices)
- **DK04** : Passenger Deck (cabines passagers, restaurants)
- **DK05** : Upper Passenger Deck (spas, restaurants)
- **DK06** : Suite Deck (suites passagers)
- **DK07** : VIP Suite Deck (suites de luxe)
- **DK08** : Bridge/Captain Deck (pont de navigation, cabine capitaine)
- **DK09** : Superstructure/Mast Deck (mâts, équipement)

### 2. **MVZ - Master Vertical Zones (Zones Maîtres Verticales)**
Les zones longitudinales du navire, d'avant en arrière :
- **MVZ 1** : Zone d'avant (Bow/Forward) - inclut promenade avant, chaîne
- **MVZ 2** : Zone avant-centrale
- **MVZ 3** : Zone centrale (approximativement au milieu du navire)
- **MVZ 4** : Zone arrière-centrale
- **MVZ 5** : Zone d'arrière (Aft/Stern) - inclut équipement technique, hélisurface

## Organization des Locaux

Chaque local du navire est catalogué avec :
- **name** : Nom du compartiment (ex: "Engine Room — Main Machinery Space")
- **deck** : Pont auquel appartient le local (ex: "DK03")
- **mvz** : Zone maître verticale (1-5)
- **type** : Type de local (machinery, accommodation, galley, storage, technical, etc.)
- **danger** : Niveau de risque (low, medium, high)
- **zone** : Identifiant unique du zone

## Utilisation dans Fire Page

### Popup "SELECT ZONES" (Sélectionner Locaux)

Le popup affiche une grille :
- **Lignes** : Ponts (DECK 1 à DECK 10)
- **Colonnes** : MVZ (MVZ 1 à MVZ 5)

Chaque bouton affiche :
1. Le numéro de MVZ
2. L'état de l'évacuation (None/In progress/Evacuated)
3. **Liste des locaux** pour cette combinaison deck/mvz

### Méthodologie de Sélection

**Important** : MVZ1 = Zone d'avant (Bow), MVZ5 = Zone d'arrière (Aft)

Lors d'une évacuation incendie, l'ordre typique serait :
1. Sélectionner les zones contaminées d'abord
2. Progresser vers les zones saines
3. Évacuer par MVZ vers l'avant ou l'arrière selon la situation

## Data Structure (OE_SPACES)

```javascript
window.OE_SPACES = [
  {
    "id": "",
    "name": "Engine Room — Main Machinery Space",
    "deck": "DK01",
    "mvz": 4,
    "type": "machinery",
    "danger": "high",
    "zone": "DK01-M-001"
  },
  // ... environ 700+ locaux ...
]
```

## Exemple de Construction (Deck DK03/MVZ 3)

Locaux du pont DK03 en MVZ 3 :
- Main Galley — Preparation Room
- Main Galley — Hot Kitchen
- Main Galley — Cold Kitchen / Pastry
- Main Galley — Dishwasher Room
- Freshwater Generator Room
- Laundry / Linen Store
- Laundry Room
- Sewage Treatment Plant
- Pool Technical Room
- Midship Stairway / Lift Trunk — DK03

## Améliorations apportées

✅ **Popup enrichi** : Affichage des locaux réels au lieu de simples grilles vides
✅ **Meilleure navigation** : Prévisualisation des locaux pour chaque zone deck/mvz
✅ **Documentation MVZ** : Indications claires sur les zones avant/arrière
✅ **Organisé par pont** : Structure logique facilitant la navigation

## Implementation Technique

### Function `buildLocalsByDeckAndMVZ()`
Organise automatiquement tous les locaux de `window.OE_SPACES` par combinaison deck+mvz.

### Method `getLocalsForDeckMvz(deck, mvz)`
Récupère la liste des locaux pour une combinaison spécifique.

### Enhanced Modal UI
Affiche jusqu'à 2 premiers locaux de chaque zone avec indication "+N more" si plus de locaux.

---

**Last Updated**: 2026-03-29
**Version**: LCC Sentinel v2.0+
