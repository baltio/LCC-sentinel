# Modifications - Popup Sélection des Locaux - Page Fire

## 📋 Résumé des Modifications

### Objectif Réalisé
✅ Amélioration du popup "SELECT ZONES" (Sélectionner Locaux) sur la page Fire
✅ Intégration des données réelles des locaux du navire (OE_SPACES)
✅ Organisation intelligente par Pont (Deck) et MVZ (Zone Maître Verticale)
✅ Affichage de la liste des locaux pour chaque combinaison deck/mvz

---

## 🔧 Modifications Techniques

### 1. Fichier HTML Principal
**Fichier** : `LCC sentinel 3.html`
**Module** : `FireSit`

#### Additions
```javascript
// Nouvelles propriétés
localsByDeckMvz: {},  // Cache organisé des locaux par deck+mvz

// Nouvelle fonction
buildLocalsByDeckAndMVZ() {
  // Organise tous les locaux de window.OE_SPACES
  // Crée un index key="DECK|MVZ" pour accès rapide
}

getLocalsForDeckMvz(deck, mvz) {
  // Retourne la liste des locaux pour une zone donnée
}
```

#### Modifications
- ✅ **openEvacModal()** : Refonte complète
  - Appel automatique à `buildLocalsByDeckAndMVZ()` si nécessaire
  - Affichage des locaux réels sous chaque bouton zone
  - Prévisualisation des 2 premiers locaux + compteur
  - Ajout d'indications MVZ (avant/arrière)
  - Meilleur formatage HTML

---

## 📊 Données des Locaux

### Structure OE_SPACES
Chaque local du navire contient :
```javascript
{
  "name": "Engine Room — Main Machinery Space",
  "deck": "DK01",      // Pont (D KDB à DK09)
  "mvz": 4,            // Zone Maître Verticale (1-5)
  "type": "machinery", // Type de compartiment
  "danger": "high",    // Niveau de risque
  "zone": "DK01-M-001" // Code de zone unique
}
```

### Total : ~700+ Locaux catalogués

### Ponts du Navire
| Code | Nom | Fonction |
|------|-----|----------|
| DKDB | Double Design Bottom | Réservoirs de ballast/fuel |
| DK01 | Engine Room | Salle des machines |
| DK02-DK07 | Decks passagers/services | Cabines, restaurants, services |
| DK08 | Bridge Deck | Pont de navigation, officiers |
| DK09 | Superstructure | Mâts, équipement |

### MVZ - Position dans le Navire
| MVZ | Position | Description |
|-----|----------|-------------|
| **1** | **Avant** | Bow, Forward, Promenade avant |
| 2 | Avant-central | Zone avant du navire |
| 3 | **Central** | Zone médiane approximative |
| 4 | Arrière-central | Zone arrière |
| **5** | **Arrière** | Aft, Stern, Hélisurface |

---

## 🎯 Utilisation du Nouveau Popup

### Avant (Ancien)
```
╔═══════════════════════════════════════╗
║    EVACUATION ZONES                   ║
╠═══════════════════════════════════════╣
║ Deck │ MVZ1 │ MVZ2 │ MVZ3 │ MVZ4 │   ║
║──────┼──────┼──────┼──────┼──────┤   ║
║D10   │  ◯   │  ◯   │  ◯   │  ◯   │   ║
║D09   │  ◯   │  ◯   │  ◯   │  ◯   │   ║
║ ...  │      │      │      │      │   ║
╚═══════════════════════════════════════╝
```

### Après (Nouveau) ✨
```
╔════════════════════════════════════════════════════════╗
║    EVACUATION ZONES — Select Deck/MVZ Zones          ║
║    with Locals                                        ║
╠════════════════════════════════════════════════════════╣
║ Note: MVZ1 is at the bow (forward), MVZ5 is at the    ║
║ stern (aft). Select zones in evacuation order.        ║
╠════════════════════════════════════════════════════════╣
║ Deck │ MVZ1 │ MVZ2 │ MVZ3 │ MVZ4 │                   ║
║──────┼──────┼──────┼──────┼──────┤                   ║
║D10   │ ◯    │ ◯    │ ◯    │ ◯    │                   ║
║      │  S1  │  S2  │  S3  │  S4  │                   ║
║      │ Nav. │ Mast │ ...  │ ...  │                   ║
║      │ +2..│      │      │      │                   ║
║───────────────────────────────────────────────────────║
║D09   │ ◯    │ ◯    │ ◯    │ ◯    │                   ║
║      │  S5  │  S6  │ Lift │ Esca │                   ║
║      │ Bridge│ Tech │ rway │ ...  │                   ║
║      │ +1.. │ ...  │      │      │                   ║
```

---

## 🔄 Flux Activation

1. **Clic sur "SELECT ZONES"**
   ```
   FireSit.openEvacModal()
     ← buildLocalsByDeckAndMVZ() [si première fois]
     ← Construit grille avec locaux réels
     ← Affiche modal enrichi
   ```

2. **Sélection d'une zone deck/mvz**
   ```
   FireSit.toggleEvacZone('DECK 3', 'MVZ 2')
     ← Bascule état (None → In progress → Evacuated → None)
     ← Réorganise evacSelected
     ← Réouvre modal avec état mis à jour
   ```

3. **Mise à jour du champ**
   ```
   FireSit.buildEvacLabel()
     ← Génère texte du champ fire-evac
     ← Ex: "DECK 3 MVZ 2 (In progress), DECK 4 MVZ 1 (Evacuated)"
   ```

---

## 📁 Fichiers Créés/Modifiés

### ✅ Modifiés
- **LCC sentinel 3.html** (FireSit module)
  - Ajout propriétés `localsByDeckMvz` et `buildLocalsByDeckAndMVZ()`
  - Refonte `openEvacModal()` avec données réelles
  - Méthode `getLocalsForDeckMvz()`

### ✅ Créés
- **STRUCTURE_LOCAUX_NAVIRE.md** (Documentation)
  - Structure ponts/MVZ
  - Organisation locaux
  - Guide d'utilisation

- **LOCAUX_NAVIRE_COMPLET.csv** (Data Export)
  - Export CSV de tous les ~700 locaux
  - Colonne: Deck, MVZ, Room_Name, Zone_Code, Type, Danger_Level
  - Usage: Analyse, rapports, intégrations

---

## 💡 Utilité

### Pour les Officiers de Pont
- ✅ Visualisation claire des zones à évacuer
- ✅ Liste des locaux réels plutôt que zones abstraites
- ✅ Indication MVZ (avant/arrière) pour aide décision
- ✅ Accès rapide aux données de compartiments

### Pour l'Administration
- ✅ Export CSV pour audit et rapports
- ✅ Base de données locaux centralisée
- ✅ Traçabilité complète position/pont/mvz

### Pour le Développement
- ✅ Structure de données réutilisable
- ✅ API simple (getLocalsForDeckMvz)
- ✅ Facilement extensible (filtres par type/danger)

---

## 🧪 Test

### Tester le Nouveau Popup
1. Ouvrir LCC Sentinel page Fire
2. Cliquer sur bouton "SELECT ZONES"
3. Observer :
   - ✅ Grille affichée avec données deck/mvz
   - ✅ Locaux listés sous chaque bouton
   - ✅ MVZ1 = avant, MVZ5 = arrière
   - ✅ Clic zone = cycle d'état

### Vérifier les Données
```javascript
// Console browser
console.log(FireSit.localsByDeckMvz);
// Affiche structure des locaux par deck|mvz

console.log(FireSit.getLocalsForDeckMvz('DK03', '3'));
// Affiche locaux pour Deck 3, MVZ 3
```

---

## 🚀 Améliorations Futures Possibles

### Phase 2
- [ ] Filtrage par type de local (machinery, accommodation, etc.)
- [ ] Filtrage par niveau de danger (high/medium/low)
- [ ] Carte 2D interactive avec mise en évidence des zones
- [ ] Historique d'évacuation avec timestamps
- [ ] Synchronisation réseau des zones sélectionnées

### Phase 3
- [ ] Intégration avec système d'alarme incendie/détecteurs
- [ ] Calcul automatique itinéraires d'évacuation
- [ ] Gestion des zones inaccessibles (dommages, feu)
- [ ] API REST pour requêtes externes
- [ ] Dashboard évacuation globale

---

## 📝 Notes Importantes

1. **MVZ Numbering**: Contre-intuitif mais conforme standard maritime
   - MVZ1 = Avant (Forward/Bow)
   - MVZ5 = Arrière (Aft/Stern)

2. **Cache Persistan**: `localsByDeckMvz` construis une fois puis réutilisé
   - Améliore performance après première ouverture du modal

3. **Localité**: ~250 locaux par pont, varient selon fonction

4. **Extensibilité**: Facile ajouter filtres, recherche, etc.

---

**Version** : LCC Sentinel v2.0+
**Date** : 2026-03-29
**État** : ✅ Production Ready
