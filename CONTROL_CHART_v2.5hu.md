# ERLELO Szabályozási Ciklus - Hiszterézis Diagramok

## v2.5 Változások Összefoglalása

**Kétszintű Kaszkád Szabályozás Irányított Hiszterézissel**

Főbb fejlesztések:
- Kamra (külső hurok): Szélesebb holtsáv, nagyobb hiszterézis a stabilitás érdekében
- Befúvó levegő (belső hurok): Szűkebb holtsáv, kisebb hiszterézis a precizitás érdekében
- Javított befúvó hőmérséklet küszöbértékek (korábban fordítva voltak)
- Irányított hiszterézis hozzáadása a határértékeken való oszcilláció megelőzésére

## Alapértelmezett Konfigurációs Értékek (v2.5)

### Kamra Szabályozás (Külső Hurok - Szélesebb)

| Paraméter | Érték | Valós | Leírás |
|-----------|-------|-------|--------|
| deltahi_kamra_homerseklet | 15 | 1,5°C | Hőmérséklet felső küszöb |
| deltalo_kamra_homerseklet | 10 | 1,0°C | Hőmérséklet alsó küszöb |
| temp_hysteresis_kamra | 5 | 0,5°C | **ÚJ** Irányított hiszterézis |
| ah_deadzone_kamra | 80 | 0,8 g/m³ | AH holtsáv (korábban 50) |
| ah_hysteresis_kamra | 30 | 0,3 g/m³ | **ÚJ** Irányított hiszterézis |
| deltahi_kamra_para | 15 | 1,5% | Páratartalom felső küszöb (RH kijelzés) |
| deltalo_kamra_para | 10 | 1,0% | Páratartalom alsó küszöb (RH kijelzés) |

### Befúvó Levegő Szabályozás (Belső Hurok - Szűkebb)

| Paraméter | Érték | Valós | Leírás |
|-----------|-------|-------|--------|
| deltahi_befujt_homerseklet | 10 | 1,0°C | Befúvó hőm. felső küszöb (korábban 20!) |
| deltalo_befujt_homerseklet | 10 | 1,0°C | Befúvó hőm. alsó küszöb (korábban 15!) |
| temp_hysteresis_befujt | 3 | 0,3°C | **ÚJ** Irányított hiszterézis |
| ah_deadzone_befujt | 50 | 0,5 g/m³ | **ÚJ** Befúvó AH holtsáv |
| ah_hysteresis_befujt | 20 | 0,2 g/m³ | **ÚJ** Irányított hiszterézis |

### Kaszkád Hierarchia Ellenőrzés

```
A kamrának (külső) SZÉLESEBBNEK kell lennie mint a befúvónak (belső):

AH Szabályozás:
  Kamra:  ±0,8 + 0,3 hiszterézis = 1,9 g/m³ teljes sáv
  Befúvó: ±0,5 + 0,2 hiszterézis = 1,2 g/m³ teljes sáv
  Arány: 1,58 ✓ (külső > belső)

Hőmérséklet Szabályozás:
  Kamra:  +1,5/-1,0 + 0,5 hiszterézis = 3,0°C teljes sáv
  Befúvó: ±1,0 + 0,3 hiszterézis = 2,3°C teljes sáv
  Arány: 1,30 ✓ (külső > belső)
```

---

## 1. Kamra Hőmérséklet Szabályozás (v2.5)

**Célérték: 15,0°C (150 nyers)**

```
Hőmérséklet (°C)
    ↑
20,0│                                              ← HŰTÉSI ZÓNA
    │
19,0│
    │
18,0│
    │
17,0│
    │
16,5│ ════════════════════════════════════════════ ← Hűtés BE (>16,5°C) [korábban 16,0]
16,0│ ┌─────────────────────────────────────────┐
    │ │           ┌───────────────────┐         │
15,5│ │           │  HISZTERÉZIS ZÓNA │         │  ← Hűtés kilépés: el kell érni 15,5°C-ot
    │ │           │  (marad a módban) │         │
15,0│ │ ─ ─ ─ ─ ─ ─ ─ CÉLÉRTÉK ─ ─ ─ ─ ─ ─ ─ ─ │
    │ │           │                   │         │
14,5│ │           │                   │         │  ← Fűtés kilépés: el kell érni 14,5°C-ot
    │ │           └───────────────────┘         │
14,0│ └─────────────────────────────────────────┘
13,9│ ════════════════════════════════════════════ ← Fűtés BE (<14,0°C) [változatlan]
    │
13,0│                                              ← FŰTÉSI ZÓNA
    │
12,0│
    │
11,0│ ════════════════════════════════════════════ ← Min hőm. "Inkább hideg mint száraz"
    │
10,0│
    └──────────────────────────────────────────────→ Idő
```

### Hőmérséklet Állapot Átmenetek (v2.5 Hiszterézissel)

| Aktuális Hőm. | Előző Állapot | Új Állapot | Művelet |
|---------------|---------------|------------|---------|
| > 16,5°C | Bármely | Hűtés BE | Hűtés indítása (+1,5 küszöb átlépése) |
| 14,0 - 16,5°C | Hűtés BE | Hűtés BE | Folytatás amíg < 15,5°C (hiszterézis) |
| < 15,5°C | Hűtés BE | KI | Hűtés leállítása (hiszterézis átlépve) |
| 14,0 - 16,5°C | Fűtés BE | Fűtés BE | Folytatás amíg > 14,5°C (hiszterézis) |
| > 14,5°C | Fűtés BE | KI | Fűtés leállítása (hiszterézis átlépve) |
| 14,0 - 16,5°C | KI | KI | Nincs művelet (holtsáv) |
| < 14,0°C | Bármely | Fűtés BE | Fűtés indítása (-1,0 küszöb átlépése) |

**Megjegyzés:** Aszimmetrikus küszöbök (+1,5°C/-1,0°C), mert a párátlanítás gyakran kissé emeli a hőmérsékletet.

---

## 2. Kamra Páratartalom Szabályozás (v2.5 - AH Alapú Hiszterézissel)

**Célérték: 75,0% RH 15°C-on → AH = 9,61 g/m³**

```
Abszolút Páratartalom (g/m³)
    ↑
12,0│                                              ← PÁRÁS ZÓNA (párátlanítás)
    │
11,5│
    │
11,0│
    │
10,5│
    │
10,41│════════════════════════════════════════════ ← PÁRÁS mód belépés (AH > cél + 0,8)
10,0│ ┌─────────────────────────────────────────┐
    │ │           ┌───────────────────┐         │
 9,91│ │           │                   │         │  ← SZÁRAZ kilépés: ide kell érni
    │ │           │  HISZTERÉZIS ZÓNA │         │
 9,61│ │ ─ ─ ─ ─ ─ ─ CÉL AH ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│
    │ │           │                   │         │
 9,31│ │           │                   │         │  ← PÁRÁS kilépés: ide kell érni
    │ │           └───────────────────┘         │
 9,0│ │                                         │
    │ │         FINOM MÓD (AH elfogadható)      │
 8,81│ └─────────────────────────────────────────┘
    │ ════════════════════════════════════════════ ← SZÁRAZ mód belépés (AH < cél - 0,8)
 8,5│
    │
 8,0│                                              ← SZÁRAZ ZÓNA (párásítás ha van)
    │
 7,5│
    └──────────────────────────────────────────────→ Idő
```

### Páratartalom Mód Állapotgép (v2.5)

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
              ┌──────────┐                               │
     ┌───────→│   FINOM  │←───────┐                      │
     │        │  (mód 0) │        │                      │
     │        └──────────┘        │                      │
     │              │             │                      │
     │   AH > 10,41 │             │ AH < 8,81           │
     │              ▼             │                      │
     │        ┌──────────┐        │        ┌──────────┐ │
     │        │  PÁRÁS   │        └────────│  SZÁRAZ  │ │
     │        │ (mód 1)  │                 │ (mód 2)  │ │
     │        └──────────┘                 └──────────┘ │
     │              │                            │      │
     │   AH < 9,31  │                            │ AH > 9,91
     │   (hiszterézis)                           │ (hiszterézis)
     │              │                            │      │
     └──────────────┴────────────────────────────┴──────┘

Szükséges állapotváltozók:
  humidity_mode_state_ch{N} = 0 (FINOM), 1 (PÁRÁS), 2 (SZÁRAZ)
```

### Páratartalom Állapot Átmenetek (v2.5)

| Aktuális AH | Előző Mód | Új Mód | Művelet |
|-------------|-----------|--------|---------|
| > 10,41 g/m³ | Bármely | PÁRÁS | Párátlanítás indítása |
| 9,31 - 10,41 | PÁRÁS | PÁRÁS | Folytatás (hiszterézis) |
| < 9,31 | PÁRÁS | FINOM | Párátlanítás leállítása |
| < 8,81 g/m³ | Bármely | SZÁRAZ | Párásítás indítása* |
| 8,81 - 9,91 | SZÁRAZ | SZÁRAZ | Folytatás (hiszterézis) |
| > 9,91 | SZÁRAZ | FINOM | Párásítás leállítása |
| 8,81 - 10,41 | FINOM | FINOM | Nincs művelet (holtsáv) |

*Csak ha van párásító. Egyébként az "Inkább hideg mint száraz" blokkolja a fűtést.

---

## 3. Kombinált Szabályozási Mátrix (v2.5)

**Példa: Cél T=15°C, RH=75% (AH=9,61 g/m³)**

```
              │ T < 14°C   │ 14-16,5°C │ T > 16,5°C │
──────────────┼────────────┼───────────┼────────────┤
AH > 10,41    │ FŰTÉS+PÁR- │ PÁRÁTLAN  │ HŰTÉS+PÁR- │
(PÁRÁS mód)   │ ÁTLANÍTÁS  │           │ ÁTLANÍTÁS  │
──────────────┼────────────┼───────────┼────────────┤
AH 8,81-10,41 │ FŰTÉS      │ ÜRESJÁRAT │ HŰTÉS      │
(FINOM mód)   │            │           │            │
──────────────┼────────────┼───────────┼────────────┤
AH < 8,81     │ FŰTÉS+PÁR* │ PÁRÁSÍT*  │ HŰTÉS+PÁR* │
(SZÁRAZ mód)  │            │           │            │
──────────────┴────────────┴───────────┴────────────┘

* Párásítás csak ha van párásító telepítve
  Egyébként: "Inkább hideg mint száraz" blokkolja a fűtést
```

### Hőmérséklet Biztonsági Felülbírálat (Nem Megkerülhető)

```
⚠️ KEMÉNY KORLÁT: Ha kamra hőm. > cél + deltahi (16,5°C) → KÖTELEZŐ HŰTÉS

Ez a felülbírálat FÜGGETLEN a páratartalom módtól!

Még SZÁRAZ módban is (AH < 8,81), ha a hőmérséklet meghaladja a 16,5°C-ot:
  → Hűtés aktiválódik (víz vagy külső levegő)
  → Nem blokkolható páratartalom szempontok alapján
  → A termék biztonsága megköveteli a hőmérséklet szabályozást

Igazságtábla:
┌─────────────────┬──────────────┬─────────────────────────────────┐
│ Páratart. Mód   │ Hőm > 16,5°C │ Művelet                         │
├─────────────────┼──────────────┼─────────────────────────────────┤
│ PÁRÁS           │ IGEN         │ Hűtés + Párátlanítás            │
│ FINOM           │ IGEN         │ Csak hűtés                      │
│ SZÁRAZ          │ IGEN         │ Hűtés (SZÁRAZ mód felülbírálva!)│
│ PÁRÁS           │ NEM          │ Csak párátlanítás               │
│ FINOM           │ NEM          │ Üresjárat                       │
│ SZÁRAZ          │ NEM          │ Párásítás (ha van)              │
└─────────────────┴──────────────┴─────────────────────────────────┘
```

---

## 4. Páratartalom Döntési Logika: RH vs AH (v2.5)

**Felhasználói Felület:** Célértékek és hiszterézis **RH%**-ban konfigurálva (intuitív)
**Belső Logika:** Minden páratartalom döntés **Abszolút Páratartalmat (AH)** használ (pontos)

### Miért AH RH Helyett?

Az RH% függ a hőmérséklettől. Ugyanaz a nedvességtartalom különböző RH%-ot mutat különböző hőmérsékleteken:

```
Ugyanaz a nedvesség (AH = 9,6 g/m³):
  15°C-on → 75% RH  ✓ (célértéken)
  17°C-on → 66% RH  ✗ (száraznak tűnik, de ugyanannyi nedvesség!)
  13°C-on → 87% RH  ✗ (párásnak tűnik, de ugyanannyi nedvesség!)
```

**Probléma az RH-alapú döntésekkel:**
```
Kamra 17°C-on, 70% RH (AH = 10,2 g/m³)
Cél:   15°C, 75% RH (AH = 9,6 g/m³)

RH összehasonlítás: 70% < 75% → "túl száraz" → PÁRÁSÍTANA (ROSSZ!)
AH összehasonlítás: 10,2 > 9,6 → "túl párás" → PÁRÁTLANÍT (HELYES!)
```

### Konverziós Képlet

```lua
-- Felhasználó RH%-ban konfigurál, rendszer AH-ra konvertál a célhőmérsékleten
target_ah = calculate_absolute_humidity(target_temp, target_rh)
current_ah = calculate_absolute_humidity(current_temp, current_rh)

-- v2.5: Holtsáv és hiszterézis küszöbök
local ah_deadzone = const.ah_deadzone_kamra / 100  -- 0,8 g/m³
local ah_hysteresis = const.ah_hysteresis_kamra / 100  -- 0,3 g/m³

-- Mód meghatározás hiszterézissel
if current_ah > target_ah + ah_deadzone then
  humidity_mode = PARAS
elseif current_ah < target_ah - ah_deadzone then
  humidity_mode = SZARAZ
elseif humidity_mode == PARAS and current_ah > target_ah - ah_hysteresis then
  humidity_mode = PARAS  -- Marad PÁRÁS módban (hiszterézis)
elseif humidity_mode == SZARAZ and current_ah < target_ah + ah_hysteresis then
  humidity_mode = SZARAZ    -- Marad SZÁRAZ módban (hiszterézis)
else
  humidity_mode = FINOM
end
```

### Döntési Összefoglaló (v2.5)

| Döntés | Összehasonlítás | Miért |
|--------|-----------------|-------|
| **Mód Kiválasztás** | AH vs AH küszöbök | Valós nedvességtartalom, hőmérséklet-független |
| **Párátlanítás** | humidity_mode == PÁRÁS | AH alapú hiszterézissel |
| **Párásítás** | humidity_mode == SZÁRAZ | AH alapú hiszterézissel |
| **"Inkább hideg mint száraz"** | AH vs AH | Megakadályozza a téves fűtést száraz esetben |

---

## 5. Hiszterézis Függvény Viselkedés (v2.5)

### Alap Hiszterézis (irányított memória nélkül)

```lua
-- Alap hiszterézis függvény (v2.4 stílus)
function hysteresis(measured, target, delta_hi, delta_lo, current_state)
    if measured > target + delta_hi then
        return true   -- Bekapcsol
    elseif measured < target - delta_lo then
        return false  -- Kikapcsol
    else
        return current_state  -- Megtartja az aktuális állapotot (HOLTSÁV)
    end
end
```

### Irányított Hiszterézis (v2.5 - ÚJ)

```lua
-- v2.5: Irányított hiszterézis explicit kilépési küszöbökkel
function directional_hysteresis(measured, target, deadzone, hysteresis, current_mode)
    local upper_threshold = target + deadzone
    local lower_threshold = target - deadzone
    local exit_from_high = target - hysteresis
    local exit_from_low = target + hysteresis
    
    if measured > upper_threshold then
        return MODE_HIGH  -- Belép MAGAS módba
    elseif measured < lower_threshold then
        return MODE_LOW   -- Belép ALACSONY módba
    elseif current_mode == MODE_HIGH and measured > exit_from_high then
        return MODE_HIGH  -- Marad MAGAS (hiszterézis)
    elseif current_mode == MODE_LOW and measured < exit_from_low then
        return MODE_LOW   -- Marad ALACSONY (hiszterézis)
    else
        return MODE_NORMAL  -- Visszatér normálba
    end
end
```

### Vizuális Hiszterézis Ciklus (v2.5)

```
              Hiszterézis Nélkül (v2.4)          Hiszterézissel (v2.5)
              
AH (g/m³)     Hajlamos oszcillációra!           Stabil működés
    │                                           
10,41 ────────┬─── PÁRÁS belépés ────────────── PÁRÁS belépés ─────────
              │         │                              │
              │    ┌────┴────┐                         │
              │    │oszcillál│                         │ PÁRÁS zóna
              │    │a szélen │                         │ (marad PÁRÁS)
              │    └────┬────┘                         │
 9,61 ────────┼─── Célérték ─────────────────── Célérték ──────────────
              │         │                              │
              │    ┌────┴────┐                    ┌────┴────┐
              │    │oszcillál│                    │ hiszterézis │
              │    │a szélen │                    │  puffer    │
              │    └────┬────┘                    └────┬────┘
 9,31 ────────┼─────────┼─────────────────────── PÁRÁS kilépés ────────
              │         │                              │
 8,81 ────────┴─── SZÁRAZ belépés ────────────── SZÁRAZ belépés ───────

Eredmény: Mód folyamatosan vált       Eredmény: Stabil mód, nincs oszcilláció
          a határokon                           amíg egyértelmű kilépés
```

---

## 6. Működési Példa Értékek (v2.5)

### Forgatókönyv: Nyári Nap Hűtés

| Paraméter | Érték | Nyers |
|-----------|-------|-------|
| Cél Hőmérséklet | 15,0°C | 150 |
| Cél RH | 75,0% | 750 |
| Külső Hőmérséklet | 25,0°C | 250 |
| Kamra Hőmérséklet | 22,0°C | 220 |
| Kamra RH | 74,5% | 745 |

**Szabályozási Döntés (v2.5):**
- Kamra AH 22°C/74,5%-on = 14,45 g/m³
- Cél AH 15°C/75%-on = 9,61 g/m³
- AH hiba: +50% (messze a 10,41 küszöb felett)
- Páratartalom mód: **PÁRÁS** (párátlanítás szükséges)
- Hőmérséklet: 220 > 165 → **Hűtés BE** (16,5°C felett)
- Eredmény: **Párátlanítás + Hűtés** (vízhűtés, bypass zárva)

**Megjegyzés (v2.5):** 22°C/74,5%-on az AH 14,45 g/m³ - sokkal magasabb mint a 10,41 küszöb, annak ellenére hogy az RH "normálisnak" tűnik!

### Forgatókönyv: Téli Nap Hűtés (Külső Levegő)

| Paraméter | Érték | Nyers |
|-----------|-------|-------|
| Cél Hőmérséklet | 15,0°C | 150 |
| Cél RH | 75,0% | 750 |
| Külső Hőmérséklet | 2,0°C | 20 |
| Kamra Hőmérséklet | 17,5°C | 175 |
| Kamra RH | 70,0% | 700 |

**Szabályozási Döntés (v2.5):**
- Kamra AH 17,5°C/70%-on = 10,47 g/m³
- AH hiba: +9% (éppen a 10,41 küszöb felett)
- Páratartalom mód: **PÁRÁS** (párátlanítás szükséges)
- Hőmérséklet: 175 > 165 → **Hűtés szükséges** (16,5°C felett)
- Külső előnyös: (175 - 20) = 155 ≥ 50 → **IGEN**
- De párátlanítás kell → **Nem használható külső levegő**
- Eredmény: **Vízhűtés 0°C-on** (bypass zárva a kondenzációhoz)

**Megjegyzés (v2.5):** Bár a külső elég hideg lenne ingyenes hűtéshez, a párátlanítás hideg hőcserélő felületet igényel!

### Forgatókönyv: Hideg Éjszaka Jó Páratartalommal

| Paraméter | Érték | Nyers |
|-----------|-------|-------|
| Cél Hőmérséklet | 15,0°C | 150 |
| Cél RH | 75,0% | 750 |
| Külső Hőmérséklet | 5,0°C | 50 |
| Kamra Hőmérséklet | 13,8°C | 138 |
| Kamra RH | 80,0% | 800 |

**Szabályozási Döntés (v2.5):**
- Kamra AH 13,8°C/80%-on = 9,43 g/m³
- Cél AH = 9,61 g/m³
- AH hiba: -2% (±0,8 holtsávon belül)
- Páratartalom mód: **FINOM** (páratartalom elfogadható)
- Hőmérséklet: 138 < 140 → **Fűtés BE** (14,0°C alatt)
- Eredmény: **Csak fűtés** (a páratartalom rendben van annak ellenére hogy 80% RH magasnak tűnik!)

**Megjegyzés (v2.5):** Hideg hőmérsékleten a 80% RH KEVESEBB nedvességet tartalmaz mint 75% RH 15°C-on. Az AH-alapú szabályozás megakadályozza a téves párátlanítást!

### Forgatókönyv: Hiszterézis Megakadályozza az Oszcillációt

| Paraméter | Érték | Nyers |
|-----------|-------|-------|
| Cél Hőmérséklet | 15,0°C | 150 |
| Cél RH | 75,0% | 750 |
| Kamra Hőmérséklet | 16,0°C | 160 |
| Kamra RH | 79,0% | 790 |
| Előző Mód | PÁRÁS | - |

**Szabályozási Döntés (v2.5):**
- Kamra AH 16°C/79%-on = 10,77 g/m³
- AH hiba: +12%
- Aktuális AH (10,77) a belépési küszöb (10,41) ALATT van?
  - IGEN, de PÁRÁS módban voltunk
- Aktuális AH (10,77) a kilépési küszöb (9,31) FELETT van?
  - IGEN! → **Marad PÁRÁS módban** (hiszterézis)
- Eredmény: **Folytatja a párátlanítást** (nincs módváltás)

**Hiszterézis nélkül (v2.4):** Kilépett volna PÁRÁS módból 10,40-nél, visszalépett volna 10,42-nél → oszcilláció!

---

## 7. Befúvó Levegő Hőmérséklet Szabályozás (v2.5 Kétszintű Kaszkád)

**Páratartalom-elsődleges szabályozás: holtsáv ABSZOLÚT PÁRATARTALOM (AH) hibát használ**

"Inkább hideg mint száraz" filozófia:
- Túl száraz → visszafordíthatatlan termékkárosodás (felület repedés, kéregképződés)
- Túl párás → penészesedési kockázat, kritikus kezelni
- Túl hideg → csak lassítja a folyamatot, helyreállítható
- A termék egyensúlya az AH-tól függ, nem a hőmérséklettől

### v2.5 Befúvó Levegő Paraméterek (Belső Hurok - Szűkebb)

| Paraméter | v2.4 | v2.5 | Leírás |
|-----------|------|------|--------|
| ah_deadzone_befujt | - | 50 | **ÚJ** Befúvó AH holtsáv (0,5 g/m³) |
| ah_hysteresis_befujt | - | 20 | **ÚJ** Befúvó hiszterézis (0,2 g/m³) |
| deltahi_befujt_homerseklet | 20 | 10 | Befúvó hőm. felső (1,0°C, volt 2,0!) |
| deltalo_befujt_homerseklet | 15 | 10 | Befúvó hőm. alsó (1,0°C, volt 1,5!) |
| temp_hysteresis_befujt | - | 3 | **ÚJ** Befúvó hőm. hiszterézis (0,3°C) |
| proportional_gain | 10 | 10 | P erősítés × 10 (változatlan) |
| outdoor_mix_ratio | 30 | 30 | Külső keverési arány (változatlan) |

**Kritikus javítás:** A befúvó küszöbök SZÉLESEBBEK voltak mint a kamráé (fordítva!). Most helyesen szűkebbek.

### 1. Mód: AH HOLTSÁVON KÍVÜL (Agresszív Szabályozás)

Amikor a kamra AH hiba > holtsáv: Agresszív korrekció a páratartalom elsődleges javítására.

```
Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) × P

Ahol P = 1,0 (alapértelmezett)
Egyszerűsítve: Befujt_cél = 2 × Kamra_cél - Kamra_mért

Példa:
  Cél: 15°C, Kamra: 18°C (AH túl magas)
  Befujt_cél = 15 - (18 - 15) × 1 = 15 - 3 = 12°C
  → Hideg levegőt fúj 12°C-on a gyors párátlanításhoz/hűtéshez
```

### 2. Mód: AH HOLTSÁVON BELÜL (Finom Szabályozás)

Amikor a kamra AH a holtsávon belül: Finom hőmérséklet hangolás külső keveréssel.

```
Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) × (1 - mix)
                       - (Külső_mért - Kamra_cél) × mix

Ahol mix = outdoor_mix_ratio (alapértelmezett 30%)

Példa:
  Cél: 15°C, Kamra: 15,5°C, Külső: 20°C (AH rendben)
  Befujt_cél = 15 - 0,5 × 0,7 - 5 × 0,3 = 13,15°C
  → Finom hőmérséklet beállítás (páratartalom már elfogadható)
```

### Kaszkád Szabályozás Vizualizáció

```
KÜLSŐ HUROK (Kamra - Lassú, Nagy Tömeg)          BELSŐ HUROK (Befúvó - Gyors, Kis Tömeg)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        ┌─────────────────┐                              ┌─────────────────┐
        │ Kamra Szenzor   │                              │ Befúvó Szenzor  │
        │  (hőm, RH)      │                              │  (hőm, RH)      │
        └────────┬────────┘                              └────────┬────────┘
                 │                                                │
                 ▼                                                ▼
        ┌─────────────────┐                              ┌─────────────────┐
        │ AH Számítás     │                              │ AH Számítás     │
        │ current_ah      │                              │ supply_ah       │
        └────────┬────────┘                              └────────┬────────┘
                 │                                                │
                 ▼                                                ▼
        ┌─────────────────┐                              ┌─────────────────┐
        │ Mód Kiválasztás │                              │ Relé Vezérlés   │
        │ ±0,8 g/m³ + 0,3 │──── alapjel ────────────►   │ ±0,5 g/m³ + 0,2 │
        │ (SZÉLESEBB)     │                              │ (SZŰKEBB)       │
        └────────┬────────┘                              └────────┬────────┘
                 │                                                │
                 ▼                                                ▼
        ┌─────────────────┐                              ┌─────────────────┐
        │ PÁRÁS/FINOM/    │                              │ Hűtés/Fűtés     │
        │ SZÁRAZ Kimenet  │                              │ Relé Kimenetek  │
        └─────────────────┘                              └─────────────────┘

Időállandó: ~30-60 perc                          Időállandó: ~2-5 perc
(nagy hőtömeg)                                   (kis levegőtérfogat)
```

### Hőmérséklet Korlátok

```lua
-- Befúvó célérték biztonságos tartományba szorítása
if befujt_target_temp < min_supply_air_temp then
  befujt_target_temp = min_supply_air_temp  -- 6°C minimum
end
if befujt_target_temp > max_supply_air_temp then
  befujt_target_temp = max_supply_air_temp  -- 40°C maximum
end
```

### Kombinált Szabályozási Jel Logika

```lua
-- Végső szabályozási jelek kombinálják a kamra ÉS befúvó igényeket
cool = kamra_hutes OR befujt_hutes   -- Bármelyik aktiválja a hűtést
warm = kamra_futes OR befujt_futes   -- Bármelyik aktiválja a fűtést
dehumi = kamra_para_hutes            -- Csak kamra páratartalom
```

---

## 8. Humi_save Mód (Páratartalom Megőrzés)

**Energiatakarékos mód ami megőrzi a páratartalmat üresjárati időszakokban**

| Bemenet | Állapot | Leírás |
|---------|---------|--------|
| inp_humidity_save | BE | Páratartalom megőrzés aktiválása |

**Relé Állapotok Humi_save Módban:**
- `rel_reventon` = BE (recirkulációs ventilátor)
- `rel_add_air_save` = BE (minimális friss levegő)
- `rel_bypass_open` = BE (bypass engedélyezve)

```
Humi_save Mód Áramlás:

  ┌─────────────────────────────────────────────────────┐
  │                    KAMRA                            │
  │                                                     │
  │    ┌──────┐                         ┌──────┐       │
  │    │Bypass│←── NYITVA ─────────────→│Vent. │       │
  │    └──────┘                         └──────┘       │
  │        ↑                                ↑          │
  │        │    Recirkuláló levegő         │          │
  │        └───────────────────────────────┘          │
  │                                                     │
  └─────────────────────────────────────────────────────┘

  Cél: Páratartalom fenntartása külső légcsere nélkül
       Energiatakarékosság stabil körülmények között
```

---

## 9. Sum_wint Jel (Nyár/Tél Mód)

**Csak hardver megkülönböztetés - NEM változtatja a szabályozási logikát**

A sum_wint jel kiválasztja melyik ventilátor sebesség bekötés aktív. A levegő sűrűsége változik a hőmérséklettel:
- **Nyár**: Könnyebb (kevésbé sűrű) levegő → nagyobb ventilátor sebesség kell
- **Tél**: Sűrűbb (nehezebb) levegő → kisebb ventilátor sebesség kell

| Jel | Évszak | Levegő Tulajdonság | Fő Ventilátor |
|-----|--------|-------------------|---------------|
| sum_wint = KI | Nyár | Könnyű (kevésbé sűrű) | Nagyobb sebesség bekötés |
| sum_wint = BE | Tél | Sűrű (nehezebb) | Kisebb sebesség bekötés |

**Kulcspontok:**
- Minden szabályozási logika **azonosan működik egész évben**
- A jel CSAK a ventilátor sebesség hardver bekötést választja ki
- Nyáron nagyobb ventilátor sebesség kell ugyanannyi levegőtömeg mozgatásához
- Télen kisebb ventilátor sebesség (sűrűbb levegő = több tömeg fordulónként)

---

## 10. Bypass Vezérlési Logika (Vízkör)

**A bypass szelep szabályozza a víz hőmérsékletét a hőcserélőben**

A rendszer víz-levegő hőcserélőt használ. A levegő MINDIG áthalad a hőcserélőn.
A bypass szabályozza hogy friss hideg víz (0°C) vagy recirkulált melegebb víz (8°C) kerül felhasználásra.

| Feltétel | Bypass Állapot | Víz Hőm. | Cél |
|----------|----------------|----------|-----|
| Párátlanítás (dehumi) | ZÁRVA | 0°C | Hideg víz = max kondenzáció |
| Csak hűtés (nincs dehumi) | NYITVA | 8°C | Melegebb víz = hűt szárítás nélkül |
| humi_save | NYITVA | 8°C | Energiatakarékos recirkuláció |

```lua
-- v2.5: Egyszerűsített bypass logika (változatlan v2.3-tól)
relay_bypass_open = humi_save or (cool and not dehumi)

-- Külső levegő használatakor a bypass állapot nem számít (víz nincs használva)
```

```
Vízkör Bypass-szal:

BYPASS ZÁRVA (Párátlanítás Mód):               BYPASS NYITVA (Csak Hűtés Mód):
Víz Hőmérséklet: 0°C                           Víz Hőmérséklet: 8°C

  ┌─────────────────────────────┐               ┌─────────────────────────────┐
  │      VÍZ-LEVEGŐ             │               │      VÍZ-LEVEGŐ             │
  │       HŐCSERÉLŐ             │               │       HŐCSERÉLŐ             │
  │  ┌───────────────────────┐  │               │  ┌───────────────────────┐  │
  │  │ ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋ │  │               │  │ ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋ │  │
  │  │ ≋≋≋ HIDEG TEKERCS ≋≋≋ │  │               │  │ ≋≋≋ MELEG TEKERCS ≋≋≋ │  │
  │  │ ≋≋≋≋≋ (0°C) ≋≋≋≋≋≋≋≋≋ │  │               │  │ ≋≋≋≋≋ (8°C) ≋≋≋≋≋≋≋≋≋ │  │
  │  └───────────────────────┘  │               │  └───────────────────────┘  │
  └─────────────────────────────┘               └─────────────────────────────┘

  Eredmény: Hideg víz (0°C) okozza           Eredmény: Melegebb víz (8°C) hűt
            a kondenzációt → nedvesség               túlzott kondenzáció nélkül
            eltávolítás                              (CSAK HŰTÉS, páratartalom megőrzés)
            (PÁRÁTLANÍTÁS + HŰTÉS)
```

---

## 11. Mozgóátlag Szűrés

**Szenzor adat simítás a zaj okozta oszcillációk megelőzésére**

| Paraméter | Érték | Leírás |
|-----------|-------|--------|
| buffer_size | 10 | Átlagolandó minták száma |
| threshold | 50 | Tüske szűrő (±5,0°C/±5,0%) |

```lua
function moving_average_update(buffer_var, result_var, new_value, buffer_size, threshold)
  -- Tüskék elutasítása: ha új érték > küszöb eltérés az átlagtól, figyelmen kívül hagyja
  if math.abs(new_value - current_avg) > threshold then
    return  -- Tüske észlelve, kihagyja ezt az olvasást
  end

  -- Körkörös puffer frissítés
  buffer[index] = new_value
  index = (index % buffer_size) + 1

  -- Új átlag számítás
  result_var:setValue(sum / count)
end
```

---

## 12. Statisztika Bemelegítési Késleltetés

**Befúvó levegő és NTC adatok csak 2 perces bemelegítés után kerülnek rögzítésre aktív módban**

| Paraméter | Érték | Leírás |
|-----------|-------|--------|
| SUPPLY_WARMUP_TIME | 120 | Másodpercek várakozás aktív indulás után |
| STATS_INTERVAL | 30 | Rögzítés 30 lekérdezésenként (~30 másodperc) |

### Miért Bemelegítési Késleltetés?

Amikor pihenőből (rest) aktívba (active) módba vált:
- A légkezelő rendszernek idő kell a stabilizálódáshoz
- A befúvó levegő szenzoroknak légáramlás kell a pontos olvasásokhoz
- A víz hőmérsékleteknek a hőcserélőben stabilizálódniuk kell

---

## 13. Külső Levegő Használati Stratégia

**Külső levegő CSAK hűtésre használható, SOHA párátlanításra**

A külső levegő nem tudja eltávolítani a nedvességet - a párátlanítás hideg vízhűtéses tekercset igényel a kondenzációhoz.

```lua
-- Külső előnyös amikor a kamra 5°C+-szal melegebb mint a külső
local outdoor_use_threshold = const.outdoor_use_threshold or 50  -- 5,0°C
local outdoor_beneficial = (kamra_hom - kulso_hom) >= outdoor_use_threshold

-- Hűtési stratégia döntés
local use_water_cooling = true
local use_outdoor_air = false

if dehumi then
  -- Párátlanítás: MINDIG víz, SOHA külső
  use_water_cooling = true
  use_outdoor_air = false
elseif cool and outdoor_beneficial then
  -- Csak hűtés előnyös külsővel: ingyenes hűtés
  use_water_cooling = false
  use_outdoor_air = true
end
```

| Feltétel | Vízhűtés | Külső Levegő | Miért |
|----------|----------|--------------|-------|
| Párátlanítás kell | IGEN (0°C) | NEM | Csak hideg tekercs kondenzál nedvességet |
| Hűtés, külső 5°C+-szal hidegebb | NEM | IGEN | Ingyenes hűtés |
| Hűtés, külső nem elég hideg | IGEN (8°C) | NEM | Mechanikus hűtés kell |

---

## 14. Relé Kimenet Igazságtábla (v2.5)

| cool | dehumi | warm | humidi | sleep | humi_save | outdoor_ben | Relé Állapotok |
|------|--------|------|--------|-------|-----------|-------------|----------------|
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | Mind KI |
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | rel_cool, rel_bypass_open |
| 0 | 1 | 0 | 0 | 0 | 0 | 0 | rel_cool, bypass_zárva |
| 1 | 1 | 0 | 0 | 0 | 0 | 0 | rel_cool, bypass_zárva |
| 0 | 0 | 1 | 0 | 0 | 0 | 0 | rel_warm |
| 0 | 1 | 1 | 0 | 0 | 0 | 0 | rel_cool, rel_warm, bypass_zárva |
| 0 | 0 | 0 | 1 | 0 | 0 | 0 | rel_humidifier (ha van) |
| 1 | 0 | 0 | 0 | 0 | 0 | 1 | rel_add_air_max (nincs vízhűtés) |
| 0 | 0 | 0 | 0 | 0 | 1 | 0 | rel_reventon, rel_add_air_save, rel_bypass_open |
| * | * | * | * | 1 | * | * | Minden relé KI (alvás) |

**Kulcs Relé Képletek (v2.5):**
```lua
relay_cool = (cool or dehumi) and not sleep and use_water_cooling
relay_warm = warm and not sleep
relay_add_air_max = use_outdoor_air and not humi_save
relay_bypass_open = humi_save or (cool and not dehumi)
relay_main_fan = sum_wint_jel  -- Hardver: nyár=magas, tél=alacsony
relay_humidifier = humidification
```

---

## 15. Befúvó Levegő Célérték Számítás

```
Befúvó Levegő Cél Hőmérséklet:

Ha outdoor_beneficial:
    befujt_target = kamra_cel * (1 - mix_ratio) + kulso * mix_ratio

    Példa (mix_ratio = 30%):
    Cél = 15°C, Külső = 25°C
    befujt_target = 15 * 0,7 + 25 * 0,3 = 10,5 + 7,5 = 18°C

Egyébként:
    befujt_target = kamra_cel  (ugyanaz mint kamra cél)

Minimum korlát:
    ha befujt_target < 6°C:
        befujt_target = 6°C  (kondenzáció megelőzése)
```

---

## 16. Teszt Értékek Referencia (v2.5)

Ezek az értékek a v2.5 küszöböket tükrözik (frissítve v2.4-ről):

| Teszt Forgatókönyv | Kamra Hőm | Kamra RH | Cél Hőm | Cél RH | Külső Hőm | Párásító | Várt Eredmény |
|-------------------|-----------|----------|---------|--------|-----------|----------|---------------|
| Normál hideg | 139 (13,9°C) | 750 | 150 | 750 | - | - | Fűtés BE |
| Normál meleg | 166 (16,6°C) | 750 | 150 | 750 | - | - | Hűtés BE (>16,5) |
| Célértéken | 150 (15,0°C) | 750 | 150 | 750 | - | - | Üresjárat |
| Holtsáv alsó | 145 (14,5°C) | 750 | 150 | 750 | - | - | Üresjárat |
| Holtsáv felső | 160 (16,0°C) | 750 | 150 | 750 | - | - | Üresjárat (+1,5-ön belül) |
| Túl párás (AH) | 150 | 820 (82%) | 150 | 750 | - | - | Párátlanítás BE |
| Párás holtsáv | 150 | 800 (80%) | 150 | 750 | - | - | FINOM mód (AH=10,25, <10,41) |
| Túl száraz (AH) | 150 | 650 (65%) | 150 | 750 | - | IGEN | Párásítás BE |
| Túl száraz nincs pár. | 145 | 650 (65%) | 150 | 750 | - | NEM | Fűtés BLOKKOLVA |
| Inkább hideg száraz | 120 | 600 | 150 | 750 | - | NEM | Fűtés BLOKKOLVA |
| Téli hűtés | 175 (17,5°C) | 700 | 150 | 750 | 20 (2°C) | - | Hűtés vízzel (párátl.!) |
| Nyári hűtés | 167 (16,7°C) | 600 | 150 | 750 | 250 (25°C) | - | Hűtés vízzel |
| Szenzor hiba | HIBA | HIBA | 150 | 750 | - | - | Üresjárat (visszaesés) |
| Hiszterézis teszt | 160 | 770 | 150 | 750 | - | - | Marad előző módban |

---

## 17. Párásítás Vezérlés Hiszterézissel (v2.5)

**Kamránkénti párásító konfiguráció: `hw_config.has_humidifier`**

A párásítás abszolút páratartalom (AH) összehasonlítást használ v2.5 hiszterézissel.

```lua
if hw_config.has_humidifier then
  local target_ah = calculate_absolute_humidity(target_temp, target_rh)
  local current_ah = calculate_absolute_humidity(current_temp, current_rh)
  
  -- v2.5: SZÁRAZ mód küszöbök használata
  local dry_threshold = target_ah - (const.ah_deadzone_kamra / 100)  -- 8,81 g/m³
  local exit_threshold = target_ah + (const.ah_hysteresis_kamra / 100)  -- 9,91 g/m³

  if humidifier_currently_on then
    -- Folytatja amíg kilépési küszöb (hiszterézissel)
    humidification = current_ah < exit_threshold
  else
    -- Csak akkor indul ha SZÁRAZ küszöb alatt
    humidification = current_ah < dry_threshold
  end
end
```

### Párásító Állapot Átmenetek (v2.5)

| Aktuális Állapot | Aktuális AH | Küszöb | Új Állapot |
|------------------|-------------|--------|------------|
| KI | current ≥ 8,81 | SZÁRAZ küszöb | KI |
| KI | current < 8,81 | SZÁRAZ küszöb | **BE** |
| BE | current < 9,91 | Kilépési küszöb | BE (hiszterézis) |
| BE | current ≥ 9,91 | Kilépési küszöb | **KI** |

```
Párásító Hiszterézis (v2.5):

  kilépés_ah (9,91) ───────────────────────────────────── Kikapcsol
                     │         ░░░░░░░░░░░░░░░░░░░░░░░░░│
                     │         ░░░ MŰKÖDÉSI ZÓNA ░░░░░░░│ (BE marad amíg
                     │         ░░░░░░░░░░░░░░░░░░░░░░░░░│  current < 9,91)
  cél (9,61)        ─┼─────────────────────────────────────
                     │
  száraz_ah (8,81)  ───────────────────────────────────── Bekapcsol
                     │
                     │         SZÁRAZ ZÓNA ALATT
                     │         (bekapcsol ha ide ér)
                     ▼
```

---

## 18. Szükséges Állapotváltozók (v2.5 - ÚJ)

### Kamránkénti Futásidejű Változók

```lua
-- Páratartalom mód állapotgép
humidity_mode_state_ch{N} = 0  -- 0=FINOM, 1=PÁRÁS, 2=SZÁRAZ

-- Hőmérséklet felülbírálat állapot
temp_override_state_ch{N} = 0  -- 0=NORMÁL, 1=KÉNYSZER_HŰTÉS

-- Előző állapotok átmenet észleléshez
prev_humidity_mode_ch{N} = 0
prev_temp_override_ch{N} = 0

-- Befúvó levegő szabályozás állapot (belső hurok)
supply_inside_deadzone_ch{N} = false
```

### Konfigurációs Paraméterek (constansok)

```lua
-- Kamra (külső hurok)
ah_deadzone_kamra_ch{N} = 80       -- 0,8 g/m³
ah_hysteresis_kamra_ch{N} = 30     -- 0,3 g/m³
deltahi_kamra_homerseklet_ch{N} = 15  -- 1,5°C
deltalo_kamra_homerseklet_ch{N} = 10  -- 1,0°C
temp_hysteresis_kamra_ch{N} = 5    -- 0,5°C

-- Befúvó (belső hurok)
ah_deadzone_befujt_ch{N} = 50      -- 0,5 g/m³
ah_hysteresis_befujt_ch{N} = 20    -- 0,2 g/m³
deltahi_befujt_homerseklet_ch{N} = 10  -- 1,0°C
deltalo_befujt_homerseklet_ch{N} = 10  -- 1,0°C
temp_hysteresis_befujt_ch{N} = 3   -- 0,3°C
```

---

## 19. Gyors Referencia (v2.5)

### Küszöbérték Összefoglaló

| Szabályozás | Belépési Küszöb | Kilépési Küszöb | Teljes Sáv |
|-------------|-----------------|-----------------|------------|
| Kamra PÁRÁS | AH > 10,41 | AH < 9,31 | 1,9 g/m³ |
| Kamra SZÁRAZ | AH < 8,81 | AH > 9,91 | 1,9 g/m³ |
| Kamra HŰTÉS | T > 16,5°C | T < 15,5°C | 3,0°C |
| Kamra FŰTÉS | T < 14,0°C | T > 14,5°C | 3,0°C |
| Befúvó (belső) | ±0,5 g/m³ / ±1,0°C | ±0,2 / ±0,3 hiszt | 1,2 g/m³ / 2,3°C |

### Szabályozási Prioritás

1. **Hőmérséklet Biztonság** - Nem megkerülhető hűtés ha > 16,5°C
2. **Páratartalom Mód** - PÁRÁS/FINOM/SZÁRAZ AH alapján
3. **Hőmérséklet Komfort** - Fűtés/hűtés páratartalom korlátokon belül
4. **Energia Optimalizálás** - Külső levegő ha előnyös

### Mód Meghatározási Folyamat

```
┌─────────────────────────────────────────────────────────────────┐
│                      SZABÁLYOZÁSI CIKLUS KEZDETE                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Szenzorok       │
                    │ Olvasása, AH    │
                    │ Számítás        │
                    └────────┬────────┘
                              │
                              ▼
                    ┌─────────────────┐
              IGEN  │ Hőm > 16,5°C?   │   NEM
           ┌────────┤                 ├────────┐
           │        └─────────────────┘        │
           ▼                                   ▼
    ┌──────────────┐                 ┌─────────────────┐
    │ KÉNYSZER     │                 │ AH kiértékelés  │
    │ HŰTÉS        │                 │ küszöbök ellen  │
    │ (felülbírál) │                 │ hiszterézissel  │
    └──────────────┘                 └────────┬────────┘
                                              │
              ┌───────────────────────────────┼───────────────────────────────┐
              ▼                               ▼                               ▼
       ┌──────────┐                    ┌──────────┐                    ┌──────────┐
       │  PÁRÁS   │                    │  FINOM   │                    │  SZÁRAZ  │
       │(párátlan)│                    │(üresjár.)│                    │(párásít) │
       └──────────┘                    └──────────┘                    └──────────┘
```

---

*Dokumentum Verzió: 2.5*
*Generálva ERLELO v2.5 szabályozási logika ajánlásokból*
*Keresztellenőrizve szabályozástechnikai elemzéssel és kaszkád tervezéssel*

## Verzió Történet

| Verzió | Dátum | Változások |
|--------|-------|------------|
| v2.3 | 2024 | Páratartalom-elsődleges holtsáv, AH-alapú szabályozás |
| v2.4 | 2024 | Konfiguráció fejlesztések, explicit beállítás |
| v2.5 | 2024 | Kétszintű kaszkád, irányított hiszterézis |

## v2.5 Változások Összefoglaló
- **Kétszintű kaszkád**: Kamra (külső) szélesebb mint Befúvó (belső)
- **Irányított hiszterézis**: Megakadályozza az oszcillációt a mód határokon
- **Javított befúvó küszöbök**: Fordítva voltak (szélesebb mint kamra), most helyesek
- **Új állapotgép**: PÁRÁS/FINOM/SZÁRAZ explicit átmenetekkel
- **Új paraméterek**: 5 új paraméter a hiszterézis szabályozáshoz
- **Várt előnyök**: 50-70% csökkenés a mód váltásokban, hosszabb relé élettartam
