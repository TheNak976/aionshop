# Institutional Sniper Entry v2.0 - Presets de Configuration

## 🎯 Presets Prêts à l'Emploi

### 1️⃣ SCALPING AGRESSIF (M5-M15)
**Objectif:** Maximum de signaux, trades rapides

```
=== Institutional Settings ===
InpSwingLength = 3
InpDisplacementATR = 1.0
InpATRPeriod = 10
InpFilterByHTF = false
InpHTF = PERIOD_H1

=== Order Blocks ===
InpDrawOB = true
InpColorBullishOB = clrDarkGreen
InpColorBearishOB = clrDarkRed
InpRemoveMitigated = true

=== Liquidity & Entry ===
InpShowSweeps = true
InpShowSwingPoints = true
InpMinCandleSize = 0.2
InpRequireEngulfing = false

=== Performance ===
InpMaxBarsBack = 300
```

**Avantages:**
- ✅ Beaucoup de signaux
- ✅ Réaction rapide
- ✅ Bon pour sessions volatiles

**Inconvénients:**
- ⚠️ Plus de faux signaux
- ⚠️ Nécessite surveillance constante

---

### 2️⃣ SWING TRADING CONSERVATEUR (H1-H4)
**Objectif:** Signaux de haute qualité, moins de bruit

```
=== Institutional Settings ===
InpSwingLength = 7
InpDisplacementATR = 1.5
InpATRPeriod = 14
InpFilterByHTF = true
InpHTF = PERIOD_D1

=== Order Blocks ===
InpDrawOB = true
InpColorBullishOB = clrGreen
InpColorBearishOB = clrCrimson
InpRemoveMitigated = false

=== Liquidity & Entry ===
InpShowSweeps = true
InpShowSwingPoints = true
InpMinCandleSize = 0.5
InpRequireEngulfing = true

=== Performance ===
InpMaxBarsBack = 500
```

**Avantages:**
- ✅ Signaux de haute qualité
- ✅ Moins de faux signaux
- ✅ Bon pour trading à temps partiel

**Inconvénients:**
- ⚠️ Moins de signaux
- ⚠️ Nécessite patience

---

### 3️⃣ INTRADAY ÉQUILIBRÉ (M15-H1)
**Objectif:** Balance entre fréquence et qualité

```
=== Institutional Settings ===
InpSwingLength = 5
InpDisplacementATR = 1.2
InpATRPeriod = 14
InpFilterByHTF = false
InpHTF = PERIOD_H4

=== Order Blocks ===
InpDrawOB = true
InpColorBullishOB = clrDarkGreen
InpColorBearishOB = clrDarkRed
InpRemoveMitigated = false

=== Liquidity & Entry ===
InpShowSweeps = true
InpShowSwingPoints = true
InpMinCandleSize = 0.3
InpRequireEngulfing = false

=== Performance ===
InpMaxBarsBack = 500
```

**Avantages:**
- ✅ Bon compromis qualité/quantité
- ✅ Adapté à la plupart des marchés
- ✅ Configuration par défaut recommandée

**Inconvénients:**
- ⚠️ Peut nécessiter ajustements selon la paire

---

### 4️⃣ GOLD/XAU SPÉCIAL (M15-H1)
**Objectif:** Optimisé pour la volatilité de l'or

```
=== Institutional Settings ===
InpSwingLength = 4
InpDisplacementATR = 1.3
InpATRPeriod = 12
InpFilterByHTF = false
InpHTF = PERIOD_H4

=== Order Blocks ===
InpDrawOB = true
InpColorBullishOB = clrGold
InpColorBearishOB = clrMaroon
InpRemoveMitigated = true

=== Liquidity & Entry ===
InpShowSweeps = true
InpShowSwingPoints = true
InpMinCandleSize = 0.25
InpRequireEngulfing = false

=== Performance ===
InpMaxBarsBack = 400
```

**Avantages:**
- ✅ Adapté aux mouvements rapides de l'or
- ✅ Capture les sweeps de liquidité fréquents
- ✅ Bon pour sessions Londres/NY

---

### 5️⃣ CRYPTO VOLATIL (M15-H1)
**Objectif:** Pour Bitcoin, Ethereum, etc.

```
=== Institutional Settings ===
InpSwingLength = 4
InpDisplacementATR = 1.1
InpATRPeriod = 10
InpFilterByHTF = false
InpHTF = PERIOD_H4

=== Order Blocks ===
InpDrawOB = true
InpColorBullishOB = clrLime
InpColorBearishOB = clrOrangeRed
InpRemoveMitigated = true

=== Liquidity & Entry ===
InpShowSweeps = true
InpShowSwingPoints = true
InpMinCandleSize = 0.2
InpRequireEngulfing = false

=== Performance ===
InpMaxBarsBack = 300
```

**Avantages:**
- ✅ Réactif aux mouvements crypto
- ✅ Capture les pumps/dumps
- ✅ 24/7 trading

---

### 6️⃣ INDICES (US30, NAS100, S&P500)
**Objectif:** Trading d'indices avec structure claire

```
=== Institutional Settings ===
InpSwingLength = 6
InpDisplacementATR = 1.4
InpATRPeriod = 14
InpFilterByHTF = true
InpHTF = PERIOD_H4

=== Order Blocks ===
InpDrawOB = true
InpColorBullishOB = clrDodgerBlue
InpColorBearishOB = clrCrimson
InpRemoveMitigated = false

=== Liquidity & Entry ===
InpShowSweeps = true
InpShowSwingPoints = true
InpMinCandleSize = 0.4
InpRequireEngulfing = false

=== Performance ===
InpMaxBarsBack = 500
```

**Avantages:**
- ✅ Respecte la structure des indices
- ✅ Filtre HTF pour tendance claire
- ✅ Bon pour sessions US

---

## 🔧 Comment Appliquer un Preset

### Méthode 1: Modification Manuelle
1. Ouvrez l'indicateur sur le graphique
2. Clic droit → "Propriétés de l'indicateur"
3. Onglet "Paramètres"
4. Copiez les valeurs du preset choisi
5. Cliquez "OK"

### Méthode 2: Fichier de Configuration (Avancé)
1. Créez un fichier `.set` dans `MQL5/Presets/`
2. Nommez-le: `Institutional_Sniper_Entry_v2_SCALPING.set`
3. Chargez-le via "Charger" dans les paramètres

---

## 📊 Tableau Comparatif

| Preset | Timeframe | Signaux/Jour | Qualité | Difficulté |
|--------|-----------|--------------|---------|------------|
| Scalping Agressif | M5-M15 | 15-30 | ⭐⭐⭐ | 🔴 Élevée |
| Swing Conservateur | H1-H4 | 2-5 | ⭐⭐⭐⭐⭐ | 🟢 Facile |
| Intraday Équilibré | M15-H1 | 5-10 | ⭐⭐⭐⭐ | 🟡 Moyenne |
| Gold Spécial | M15-H1 | 8-15 | ⭐⭐⭐⭐ | 🟡 Moyenne |
| Crypto Volatil | M15-H1 | 10-20 | ⭐⭐⭐ | 🔴 Élevée |
| Indices | M30-H1 | 5-8 | ⭐⭐⭐⭐ | 🟡 Moyenne |

---

## 🎓 Conseils d'Optimisation

### 1. **Testez sur Démo d'Abord**
- Appliquez le preset
- Observez pendant 1 semaine
- Notez les performances

### 2. **Ajustements Fins**
Si trop de signaux:
- ↑ Augmentez `InpSwingLength` (+1 ou +2)
- ↑ Augmentez `InpMinCandleSize` (+0.1)
- ✅ Activez `InpRequireEngulfing`

Si pas assez de signaux:
- ↓ Réduisez `InpSwingLength` (-1 ou -2)
- ↓ Réduisez `InpMinCandleSize` (-0.1)
- ❌ Désactivez `InpFilterByHTF`

### 3. **Adaptation par Paire**
Chaque paire a sa personnalité:
- **EUR/USD:** Preset Intraday Équilibré
- **GBP/USD:** Preset Scalping (très volatile)
- **USD/JPY:** Preset Swing (mouvements lents)
- **XAU/USD:** Preset Gold Spécial
- **BTC/USD:** Preset Crypto Volatil

### 4. **Sessions de Trading**
- **Asie (00:00-09:00 GMT):** Moins de signaux, augmentez sensibilité
- **Londres (08:00-17:00 GMT):** Preset standard
- **New York (13:00-22:00 GMT):** Preset standard ou agressif
- **Overlap Londres-NY (13:00-17:00 GMT):** Meilleure période

---

## 📝 Template de Journalisation

```
Date: ___________
Paire: ___________
Timeframe: ___________
Preset Utilisé: ___________

Paramètres:
- SwingLength: ___
- DisplacementATR: ___
- MinCandleSize: ___
- RequireEngulfing: ___
- FilterByHTF: ___

Résultats:
- Signaux générés: ___
- Trades pris: ___
- Win Rate: ____%
- Notes: _________________
```

---

## 🚀 Preset Personnalisé

Créez votre propre configuration:

```
=== MES PARAMÈTRES ===
InpSwingLength = ___
InpDisplacementATR = ___
InpATRPeriod = ___
InpFilterByHTF = ___
InpHTF = ___

InpDrawOB = ___
InpColorBullishOB = ___
InpColorBearishOB = ___
InpRemoveMitigated = ___

InpShowSweeps = ___
InpShowSwingPoints = ___
InpMinCandleSize = ___
InpRequireEngulfing = ___

InpMaxBarsBack = ___

Notes: _________________
```

---

**Rappel:** Aucun preset n'est parfait. Testez, ajustez, et trouvez ce qui fonctionne pour VOTRE style de trading!
