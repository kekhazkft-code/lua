# ERLELO v2.5 Rendszer Architektúra

## Áttekintés

Az ERLELO egy páratartalom-elsődleges klímaszabályozó rendszer mezőgazdasági tárolókamrákhoz, SINUM vezérlőkön fut. A rendszer az abszolút páratartalmat (AH) használja elsődleges szabályozási változóként, a hőmérséklet másodlagos.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ERLELO v2.5 RENDSZER ARCHITEKTÚRA                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        SINUM VEZÉRLŐ                                 │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │erlelo_kamra1 │  │erlelo_kamra2 │  │erlelo_kamra3 │  Kamra       │   │
│  │  │    .lua      │  │    .lua      │  │    .lua      │  Vezérlők    │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │   │
│  │         │                 │                 │                       │   │
│  │         └────────────┬────┴────────────────┘                       │   │
│  │                      │                                              │   │
│  │  ┌──────────────┐    │    ┌──────────────┐                         │   │
│  │  │erlelo_kulso  │────┴────│ constansok   │  Megosztott             │   │
│  │  │    .lua      │         │  változók    │  Erőforrások            │   │
│  │  └──────────────┘         └──────────────┘                         │   │
│  │   Külső Érzékelő           Konfiguráció                             │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   Modbus    │  │    SBUS     │  │  Változók   │  │  HTTP API   │       │
│  │  Érzékelők  │  │    Relék    │  │   Tárolás   │  │   Hozzáfér. │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Komponens Architektúra

### 1. Kamra Vezérlő (erlelo_kamra.lua)

A fő szabályozási logika minden kamrához. Kamránként függetlenül fut.

```
┌─────────────────────────────────────────────────────────────────┐
│                    KAMRA VEZÉRLŐ                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   INICIALIZÁLÁS                          │   │
│  │                                                          │   │
│  │  újraindítás ──▶ init_start_time = most                 │   │
│  │                │                                         │   │
│  │                ▼                                         │   │
│  │  ┌─────────────────────────────────────┐                │   │
│  │  │   INIT MÓD (32 másodperc)           │                │   │
│  │  │   • Érzékelők olvasása              │                │   │
│  │  │   • Pufferek feltöltése             │                │   │
│  │  │   • Logika fut                      │                │   │
│  │  │   • MINDEN RELÉ KI                  │                │   │
│  │  └─────────────────────────────────────┘                │   │
│  │                │                                         │   │
│  │                ▼ 32mp eltelt                             │   │
│  │  ┌─────────────────────────────────────┐                │   │
│  │  │   NORMÁL ÜZEMMÓD                    │                │   │
│  │  │   init_complete = igaz              │                │   │
│  │  └─────────────────────────────────────┘                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   LEKÉRDEZÉSI CIKLUS (1 másodperc)       │   │
│  │                                                          │   │
│  │  1. Érzékelők Olvasása (Modbus)                         │   │
│  │     ├── Kamra T/RH                                      │   │
│  │     └── Befújt T/RH                                     │   │
│  │                                                          │   │
│  │  2. Adatfeldolgozás                                     │   │
│  │     ├── Tüske szűrő                                     │   │
│  │     ├── Mozgó átlag (puffer=5)                          │   │
│  │     └── AH, HP számítás                                 │   │
│  │                                                          │   │
│  │  3. Szabályozási Logika                                 │   │
│  │     ├── Páratartalom mód meghatározása (FINOM/PÁRÁS/SZÁRAZ) │
│  │     ├── Kamra hurok (külső, szélesebb küszöbök)         │   │
│  │     └── Befújt hurok (belső, szűkebb küszöbök)          │   │
│  │                                                          │   │
│  │  4. Kimenet                                             │   │
│  │     ├── Jelek változó frissítése (JSON)                 │   │
│  │     └── Relé állapotok beállítása (ha init kész && !alv)│   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Külső Érzékelő Vezérlő (erlelo_kulso.lua)

Külső hőmérséklet és páratartalom olvasása, minden kamra számára megosztva.

```
┌─────────────────────────────────────────────────────────────────┐
│                   KÜLSŐ ÉRZÉKELŐ VEZÉRLŐ                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Lekérdezési Ciklus (1 másodperc):                             │
│  1. Modbus érzékelő olvasása                                   │
│  2. Tüske szűrő alkalmazása                                    │
│  3. Mozgó átlag frissítése                                     │
│  4. Külső AH, HP számítása                                     │
│  5. Globális változókba mentés (*_glbl)                        │
│                                                                 │
│  Írt Változók:                                                 │
│  • kulso_homerseklet_glbl                                      │
│  • kulso_para_glbl                                             │
│  • kulso_ah_dp_glbl (JSON ah, hp értékekkel)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Konstans Szerkesztő (erlelo_constants_editor.lua)

UI eszköz futásidejű paraméter beállításhoz.

```
┌─────────────────────────────────────────────────────────────────┐
│                    KONSTANS SZERKESZTŐ                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Felhasználói Felület:                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Kamra: [1]  [Frissítés]  [Mentés]                      │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  Kamra Hőm. Felső:   [15]  Jelenlegi: 1.5°C            │   │
│  │  Kamra Hőm. Alsó:    [10]  Jelenlegi: 1.0°C            │   │
│  │  Init Időtartam:     [32]  Jelenlegi: 32s              │   │
│  │  ...                                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Műveletek:                                                    │
│  • Frissítés: GET /api/v1/variables/{id} → JSON elemzés       │
│  • Mentés: PUT /api/v1/variables/{id} → érték + alapért. friss.│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Adatfolyam Architektúra

### Változó Elnevezési Konvenció

```
Kamra-specifikus:  {név}_ch{1,2,3}     Példa: kamra_homerseklet_ch1
Globális:          {név}_glbl          Példa: kulso_homerseklet_glbl
```

### Változó Feloldás (V függvény)

```lua
V('kamra_homerseklet')  
  → próbálja: kamra_homerseklet_ch1 (1-es kamránál)
  → ha nincs: kamra_homerseklet_glbl
```

### Adatfolyam Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            ADATFOLYAM                                    │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ÉRZÉKELŐK                  FELDOLGOZÁS                 KIMENETEK        │
│                                                                          │
│  ┌────────────┐            ┌────────────┐            ┌────────────┐     │
│  │ Modbus     │            │ Kamra      │            │ signals    │     │
│  │ Kamra      │───────────▶│ Vezérlő    │───────────▶│ _chX       │     │
│  │ Érzékelő   │            │            │            │ (JSON)     │     │
│  └────────────┘            │  ┌──────┐  │            └─────┬──────┘     │
│                            │  │ Mód  │  │                  │            │
│  ┌────────────┐            │  │Állap.│  │            ┌─────▼──────┐     │
│  │ Modbus     │───────────▶│  │      │  │            │ SBUS       │     │
│  │ Befújt     │            │  └──────┘  │            │ Relék      │     │
│  │ Érzékelő   │            │            │            └────────────┘     │
│  └────────────┘            └─────▲──────┘                               │
│                                  │                                       │
│  ┌────────────┐            ┌─────┴──────┐                               │
│  │ Modbus     │            │ constansok │                               │
│  │ Külső      │───────────▶│ _chX       │◀──── Konstans Szerkesztő     │
│  │ Érzékelő   │            │ (JSON)     │                               │
│  └────────────┘            └────────────┘                               │
│        │                                                                 │
│        ▼                                                                 │
│  ┌────────────┐                                                         │
│  │ kulso_*    │                                                         │
│  │ _glbl      │                                                         │
│  └────────────┘                                                         │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Szabályozási Architektúra

### Kettős-Rétegű Kaszkád

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      KETTŐS-RÉTEGŰ KASZKÁD SZABÁLYOZÁS                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  KAMRA HUROK (Külső)               BEFÚJT HUROK (Belső)                │
│  ─────────────────────             ─────────────────────               │
│                                                                         │
│  ┌─────────────────────┐          ┌─────────────────────┐             │
│  │ Páratartalom Mód    │          │ Csak Hőmérséklet    │             │
│  │ + Hőmérséklet       │          │                     │             │
│  │                     │          │                     │             │
│  │ Küszöbök:           │          │ Küszöbök:           │             │
│  │ • Hőm: ±1.5/1.0°C   │──────────│ • Hőm: ±1.0°C      │             │
│  │ • AH: ±0.8 g/m³     │          │                     │             │
│  │ • Hiszt.: 0.5°C     │          │ • Hiszt.: 0.3°C    │             │
│  └─────────────────────┘          └─────────────────────┘             │
│           │                                │                           │
│           │    Mód beállítás, hűtés/       │    Gyors korrekciók       │
│           │    fűtés kérés                 │    a befújt levegőhöz     │
│           ▼                                ▼                           │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                      RELÉ KIMENETI LOGIKA                        │  │
│  │                                                                  │  │
│  │  relay_cool = (kamra_hutes VAGY befujt_hutes) ÉS NEM alvas      │  │
│  │               ÉS init_complete                                   │  │
│  │  relay_warm = (kamra_futes VAGY befujt_futes) ÉS NEM alvas      │  │
│  │               ÉS NEM heating_blocked ÉS init_complete            │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Páratartalom Állapotgép

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PÁRATARTALOM ÁLLAPOTGÉP                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                    ┌──────────────────────┐                            │
│                    │      MÓD_FINOM       │                            │
│                    │   (AH ±0.8-on belül) │                            │
│                    └──────────┬───────────┘                            │
│                               │                                         │
│         ┌─────────────────────┼─────────────────────┐                  │
│         │                     │                     │                  │
│         │ AH > cél+0.8        │                     │ AH < cél-0.8     │
│         ▼                     │                     ▼                  │
│  ┌──────────────┐             │             ┌──────────────┐           │
│  │  MÓD_PÁRÁS   │             │             │  MÓD_SZÁRAZ  │           │
│  │              │             │             │              │           │
│  │ Párátlanítás │             │             │ Fűtés tiltás │           │
│  │ Hűtés        │             │             │ Párásítás*   │           │
│  └──────┬───────┘             │             └──────┬───────┘           │
│         │                     │                    │                   │
│         │ AH < cél-0.3        │    AH > cél+0.3    │                   │
│         └─────────────────────┴────────────────────┘                   │
│                                                                         │
│  * Csak ha humidifier_installed = igaz                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Inicializálási Architektúra

### Indítási Sorrend

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      INICIALIZÁLÁSI SORREND                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  IDŐ      ÁLLAPOT            ÉRZÉKELŐK     LOGIKA       RELÉK          │
│  ────     ──────             ─────────     ──────       ─────          │
│                                                                         │
│  0s       INIT KEZDÉS        Olvasás       Fut          MIND KI        │
│           init_complete=H    (érvénytelen) (kimenetek                   │
│           countdown=32                      figyelmen                   │
│                                             kívül)                      │
│                                                                         │
│  5s       INIT               Értékek       Fut          MIND KI        │
│           countdown=27       stabilizálód.                              │
│                                                                         │
│  15s      INIT               Érvényes      Mód          MIND KI        │
│           countdown=17       adat a        meghatározva                 │
│                              pufferekben                                │
│                                                                         │
│  32s      NORMÁL             Érvényes      Fut          VEZÉRELVE      │
│           init_complete=I                                               │
│           countdown=0                                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Miért Szükséges az Inicializálás

```
INICIALIZÁLÁS NÉLKÜL:
─────────────────────
Újraind. → Változók = 0 → T=0°C, RH=0% → "Vészhelyzet!" → Fűtés+Párásítás BE
                                                          ↓
                                                BERENDEZÉS KÁROSODÁS KOCKÁZAT

INICIALIZÁLÁSSAL:
─────────────────
Újraind. → Változók = 0 → INIT MÓD → Relék KI → Érzékelők stabilizálódnak
                              ↓
                         32 másodperc
                              ↓
                         NORMÁL MÓD → Biztonságos vezérlés valós adatok alapján
```

---

## Fájl Architektúra

### Telepítési Fájlok

| Fájl | Típus | Cél | Fut |
|------|-------|-----|-----|
| `erlelo_kamra1.lua` | Vezérlő | 1. kamra vezérlés | SINUM eszköz |
| `erlelo_kamra2.lua` | Vezérlő | 2. kamra vezérlés | SINUM eszköz |
| `erlelo_kamra3.lua` | Vezérlő | 3. kamra vezérlés | SINUM eszköz |
| `erlelo_kulso.lua` | Vezérlő | Külső érzékelő | SINUM eszköz |
| `erlelo_constants_editor.lua` | UI | Paraméter hangolás | SINUM eszköz |

### Telepítési Segédprogramok

| Fájl | Típus | Cél | Futtatás |
|------|-------|-----|----------|
| `erlelo_create.lua` | Segédpr. | Változók létrehozása | Egyszer telepítéskor |
| `erlelo_store.lua` | Segédpr. | ID leképezés építése | Egyszer telepítéskor |
| `erlelo_delete.lua` | Segédpr. | Változók törlése | Csak tisztításnál |

### Konfigurációs Fájlok

| Fájl | Cél |
|------|-----|
| `erlelo_config_1ch.json` | 1-kamrás konfiguráció |
| `erlelo_config_2ch.json` | 2-kamrás konfiguráció |
| `erlelo_config_3ch.json` | 3-kamrás konfiguráció |

---

## Paraméter Architektúra

### 27 Konfigurálható Paraméter

| Kategória | Darab | Paraméterek |
|-----------|-------|-------------|
| Kamra Hurok | 5 | deltahi/lo_kamra, temp_hyst, ah_dz/hyst_kamra |
| Befújt Hurok | 5 | deltahi/lo_befujt, temp_hyst, ah_dz/hyst_befujt |
| Globális Vezérlés | 6 | outdoor_mix, threshold, gain, min/max_supply, min_no_humi |
| Érzékelő Feldolg. | 5 | buffer, spike, max_error, temp/humi_change |
| Párásító | 2 | installed, start_delta |
| Alvás Ciklus | 3 | enabled, on_minutes, off_minutes |
| Inicializálás | 1 | init_duration |

### Paraméter Tárolás

```
constansok_ch1 (JSON változó):
{
  "deltahi_kamra_homerseklet": 15,
  "deltalo_kamra_homerseklet": 10,
  ...
  "init_duration": 32
}
```

---

## Jel Kimeneti Architektúra

### signals_chX Változó (JSON)

```json
{
  "kamra_hutes": true,
  "kamra_futes": false,
  "kamra_para_hutes": true,
  "befujt_hutes": true,
  "befujt_futes": false,
  "relay_cool": true,
  "relay_warm": false,
  "relay_add_air_max": false,
  "relay_humidifier": false,
  "humidity_mode": 1,
  "heating_blocked": false,
  "sleep": false,
  "init_complete": true,
  "init_countdown": 0
}
```

---

## Kommunikációs Architektúra

### Modbus (Érzékelők)

```
SINUM ←──Modbus RTU──→ Hőmérséklet/Páratartalom Érzékelők
        Regiszter 0: Hőmérséklet (×10)
        Regiszter 1: Páratartalom (×10)
```

### SBUS (Relék)

```
SINUM ←──SBUS──→ Relé Modulok
        setState("on"/"off")
```

### HTTP API (Konfiguráció)

```
Konstans Szerkesztő ←──HTTP──→ SINUM API
        GET  /api/v1/variables/{id}
        PUT  /api/v1/variables/{id}
        POST /api/v1/variables
```

---

## Verzió Történet

| Verzió | Dátum | Változások |
|--------|-------|------------|
| v2.5 | 2024 Nov | Kettős-rétegű kaszkád, irányított hiszterézis, állapotgép, 27 konfigurálható paraméter, biztonságos inicializálás (32mp) |
| v2.4 | 2024 Nov | Páratartalom-elsődleges vezérlés, HTTP minták |
| v2.3 | 2024 Nov | Változó elnevezés szabványosítás |
| v2.0 | 2024 Okt | Kezdeti páratartalom-tudatos tervezés |
