# 🚨 GUIDE RAPIDE - Popup Sélection des Locaux - Page Fire

## Pour Commencer

### En 30 secondes
1. **Ouvrir** : Page Fire du logiciel LCC Sentinel
2. **Cliquer** : Bouton "SELECT ZONES" (section Evacuation)
3. **Voir** : Grille des ponts × MVZ avec locaux réels
4. **Interagir** : Cliquer zones pour marquer évacuation

---

## Layout du Popup

```
┌─────────────────────────────────────────────────────────────┐
│ EVACUATION ZONES — Select Deck/MVZ Zones with Locals    [×] │
├─────────────────────────────────────────────────────────────┤
│ Note: MVZ1 is at the bow (forward), MVZ5 is at the stern │
│       (aft). Select zones in evacuation order.              │
├─────────────────────────────────────────────────────────────┤
│                 MVZ 1    MVZ 2    MVZ 3    MVZ 4            │
│ ─────────────────────────────────────────────────────────── │
│ DECK 10  │ [Button] [Button] [Button] [Button]             │
│          │  Locals  Locals   Locals   Locals               │
│          │  ...     ...      ...      ...                  │
│ ─────────────────────────────────────────────────────────── │
│ DECK 09  │ [Button] [Button] [Button] [Button]             │
│          │  Locals  Locals   Locals   Locals               │
│ ...                                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## États des Zones

### Cycle de Sélection
```
┌──────────────────────────────────────────┐
│ Cliquer zone = Change état:              │
│                                          │
│ [None]                                   │
│   ↓ (Clic 1)                             │
│ [In Progress] (couleur + liste locaux)  │
│   ↓ (Clic 2)                             │
│ [Evacuated] (couleur différente)         │
│   ↓ (Clic 3)                             │
│ [None] (couleur neutre)                  │
│   ↓ ...                                   │
└──────────────────────────────────────────┘
```

### Couleurs & Signification
| État | Visuel | Signification |
|------|--------|---------------|
| **None** | Gris neutre | Zone sans status |
| **In Progress** | Bleu/Orange | Évacuation en cours |
| **Evacuated** | Vert | Évacuation complétée |

---

## Comprendre les Axes

### Ponts (Vertical Axis)
```
DK09 ┌─ Superstructure (mâts, équipement)
DK08 ├─ Bridge Deck (pont navigation)
DK07 ├─ VIP Suite Deck
DK06 ├─ Suite Passenger Deck
DK05 ├─ Upper Passenger Deck
DK04 ├─ Main Passenger Deck
DK03 ├─ Crew Deck
DK02 ├─ Service Deck
DK01 ├─ Engine Room
DKDB └─ Double Bottom (ballast/réservoirs)

↑ HAUT DU NAVIRE
```

### MVZ - Zones Longitudinales (Horizontal Axis)
```
Bow (Avant) ←─────────────────────→ Stern (Arrière)

MVZ 1     MVZ 2    MVZ 3    MVZ 4     MVZ 5
┌─────────────────────────────────────┐
│ Avant  │ Av-Cent │ CENTRE │ Ar-Cent │ Arrière │
│ (Promenade, │ │ │ │ (Hélisurface, │
│ Chaîne)     │ │ │ │  Technique)    │
└─────────────────────────────────────┘
```

---

## Exemples d'Utilisation

### Scénario 1 : Feu Moteurs (DK01)
```
1. Cliquer DECK 1, MVZ 3 → [In Progress]
   (Engine Room — Main Machinery Space)
2. Cliquer DECK 1, MVZ 4 → [In Progress]
   (Generator Rooms)
3. Attendre évacuation complète
4. Cliquer mêmes zones → [Evacuated]
```

### Scénario 2 : Feu Zones Avant
```
1. Cliquer DECK 4, MVZ 5 → [In Progress]
   (Forward Expedition Prep Area)
2. Cliquer DECK 5, MVZ 5 → [In Progress]
3. Cliquer DECK 6, MVZ 5 → [In Progress]
4. Progresser vers arrière (MVZ 4, 3, 2, 1)
```

---

## Locaux Clés par Pont

### DK01 - Engine Room
```
MVZ 1: Aft Engine Room, Stern Tubes
MVZ 2: Main Engine Central, Fuel Oil Service
MVZ 3: Main Switchboard, Workshop
MVZ 4: Generators, Purifier Room
MVZ 5: CO2 Room, Forward Bow Thruster
```

### DK03 - Crew Accommodation
```
MVZ 1: Aft Crew Cabins
MVZ 2: Crew Mess, Medical Centre, IT Room
MVZ 3: Main Galley (4 sections), Laundry
MVZ 4: Officers Cabins, Hotel Store
MVZ 5: Electrical, Forepeak, Stairways
```

### DK04 - Passenger Decks
```
MVZ 1: Aft Technical, Tenders Garage, Minor Suites
MVZ 2: Restaurants (Fwd), Libraries, Shops
MVZ 3: Grand Salon, Restaurants (Aft)
MVZ 4: Pantries, Wellness
MVZ 5: Forward Expedition, Theatre
```

---

## Prochaines Étapes

### À Faire Après Sélection
1. ✅ **Enregistrer zones** : Les zones restent sélectionnées
2. ✅ **Synchroniser** : Connecté aux autres postes via réseau
3. ✅ **Documenter** : Timestamps enregistrés automatiquement
4. ✅ **Escalader** : Avertir gestionnaires si nécessaire

---

## Données Disponibles

### CSV Complet
Fichier: `LOCAUX_NAVIRE_COMPLET.csv`
- 700+ locaux catalogués
- Colonnes: Deck, MVZ, Room_Name, Zone_Code, Type, Danger_Level
- Usage: Import tableurs, analyses, rapports

### Documentation Complète
Fichier: `STRUCTURE_LOCAUX_NAVIRE.md`
- Vue d'ensemble ponts/MVZ
- Organisation locaux
- Méthodologie sélection

---

## 🎓 Astuces

### 1️⃣ MVZ = Avant/Arrière, PAS Port/Stbd
```
❌ FAUX: "MVZ = tribord"
✅ CORRECT: "MVZ = zones longitudinales (avant à arrière)"
```

### 2️⃣ Prioriser du Foyer
```
Feu Avant (MVZ 5)?
  → Évacuer d'abord MVZ 5,4,3 (approche vers arrière)
  
Feu Arrière (MVZ 1)?
  → Évacuer d'abord MVZ 1,2,3 (approche vers avant)
```

### 3️⃣ Zones Critiques à Évacuer En PREMIER
```
🔴 Priorité Haute:
   - Engine Rooms (DK01)
   - Main Switchboards (DK02, DK03)
   - Bridge (DK08)
   - Fire Suppression (DK03)

🟠 Priorité Moyenne:
   - Galley (DK03)
   - Électricité (tous decks)
   - Storage Hazardous (divers)

🟡 Priorité Basse:
   - Passenger Cabins
   - Public Spaces
   - Crew Accommodation
```

---

## 📞 Support & Questions

### Données à disposition
- ✅ JSON complet : `window.OE_SPACES` (in browser console)
- ✅ CSV export : Fichier fourni
- ✅ Documentation : 3 fichiers MD/CSV

### Contact Technique
Logiciel: LCC Sentinel v2.0+
Build: 2026-03-29
Analyse réalisée par: Assistant IA

---

**Dernier update**: 2026-03-29
**Statut**: ✅ Déployé et opérationnel
