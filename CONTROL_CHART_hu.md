# ERLELO v2.5 Szabályozási Diagram

## Rendszer Áttekintés

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ERLELO v2.5 SZABÁLYOZÁSI FOLYAMAT                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ÉRZÉKELŐK          FELDOLGOZÁS          ÁLLAPOTGÉP          KIMENETEK    │
│  ──────────         ───────────          ──────────          ─────────    │
│                                                                             │
│  ┌─────────┐         ┌───────────┐        ┌───────────┐       ┌─────────┐ │
│  │ Kamra   │──────▶  │  Mozgó    │──────▶ │ PÁRATART. │──────▶│ Relék   │ │
│  │  T/RH   │         │  Átlag    │        │   MÓD     │       │ Hűtés   │ │
│  └─────────┘         │ (buffer=5)│        │ (kamra)   │       │ Fűtés   │ │
│                      │  + tüske  │        │           │       │ Vent.   │ │
│  ┌─────────┐         │  szűrő    │        │ FINOM     │       │ Bypass  │ │
│  │ Befújt  │──────▶  └───────────┘        │ PÁRÁS     │       │ Párás.  │ │
│  │  T/RH   │              │               │ SZÁRAZ    │       └─────────┘ │
│  └─────────┘              │               └─────┬─────┘                   │
│                           ▼                     │                         │
│  ┌─────────┐         ┌───────────┐              ▼                         │
│  │ Külső   │──────▶  │ Pszichro- │        ┌───────────┐                   │
│  │  T/RH   │         │ metria    │        │KETTŐS-RÉT.│                   │
│  └─────────┘         │ AH, HP    │        │ KASZKÁD   │                   │
│                      └───────────┘        │           │                   │
│                           │               │ Kamra:    │                   │
│  ┌─────────┐              │               │  AH mód   │                   │
│  │constans-│◀─────────────┘               │  + hőm.   │                   │
│  │  ok     │  Mind a 21 param             │           │                   │
│  │ változó │  változóból                  │ Befújt:   │                   │
│  └─────────┘                              │  csak hőm.│                   │
│                                           └───────────┘                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Páratartalom Mód Állapotgép

```
                              ┌─────────────────────────────────────┐
                              │         AH ÖSSZEHASONLÍTÁS          │
                              │   kamra_ah vs cél_ah                │
                              └──────────────┬──────────────────────┘
                                             │
              ┌──────────────────────────────┼──────────────────────────────┐
              │                              │                              │
              ▼                              ▼                              ▼
    ┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
    │   MÓD_SZÁRAZ    │          │   MÓD_FINOM     │          │   MÓD_PÁRÁS     │
    │                 │          │                 │          │                 │
    │  AH < cél       │          │  AH a holtsávon │          │  AH > cél       │
    │    - 0.8 g/m³   │          │  belül (±0.8)   │          │    + 0.8 g/m³   │
    └────────┬────────┘          └────────┬────────┘          └────────┬────────┘
             │                            │                            │
    ┌────────┴────────┐          ┌────────┴────────┐          ┌────────┴────────┐
    │ Műveletek:      │          │ Műveletek:      │          │ Műveletek:      │
    │ • Fűtés tiltás  │          │ • Finom hőm.    │          │ • Agresszív     │
    │   ha > 11°C     │          │   szabályozás   │          │   hűtés         │
    │ • Párásítás ha  │          │ • Külső levegő  │          │ • Párátlanítás  │
    │   elérhető      │          │   keverés (30%) │          │                 │
    └─────────────────┘          └─────────────────┘          └─────────────────┘

    KILÉPÉSI FELTÉTELEK (Irányított Hiszterézis):
    ─────────────────────────────────────────────
    SZÁRAZ → FINOM:  AH > cél + 0.3 g/m³
    PÁRÁS → FINOM:   AH < cél - 0.3 g/m³
```

---

## Mind a 21 Konfigurálható Paraméter

### Kamra Hurok (Külső)
| # | Paraméter | Alapért. | Valós | Egység |
|---|-----------|----------|-------|--------|
| 1 | `deltahi_kamra_homerseklet` | 15 | 1.5 | °C |
| 2 | `deltalo_kamra_homerseklet` | 10 | 1.0 | °C |
| 3 | `temp_hysteresis_kamra` | 5 | 0.5 | °C |
| 4 | `ah_deadzone_kamra` | 80 | 0.8 | g/m³ |
| 5 | `ah_hysteresis_kamra` | 30 | 0.3 | g/m³ |

### Befújt Hurok (Belső)
| # | Paraméter | Alapért. | Valós | Egység |
|---|-----------|----------|-------|--------|
| 6 | `deltahi_befujt_homerseklet` | 10 | 1.0 | °C |
| 7 | `deltalo_befujt_homerseklet` | 10 | 1.0 | °C |
| 8 | `temp_hysteresis_befujt` | 3 | 0.3 | °C |

### Globális Szabályozás
| # | Paraméter | Alapért. | Valós | Egység |
|---|-----------|----------|-------|--------|
| 9 | `outdoor_mix_ratio` | 30 | 30 | % |
| 10 | `outdoor_use_threshold` | 50 | 5.0 | °C |
| 11 | `proportional_gain` | 10 | 1.0 | - |
| 12 | `min_supply_air_temp` | 60 | 6.0 | °C |
| 13 | `max_supply_air_temp` | 400 | 40.0 | °C |
| 14 | `min_temp_no_humidifier` | 110 | 11.0 | °C |

### Érzékelő Feldolgozás
| # | Paraméter | Alapért. | Valós | Egység |
|---|-----------|----------|-------|--------|
| 15 | `buffer_size` | 5 | 5 | minta |
| 16 | `spike_threshold` | 50 | 5.0 | egység |
| 17 | `max_error_count` | 10 | 10 | hiba |
| 18 | `temp_change_threshold` | 2 | 0.2 | °C |
| 19 | `humidity_change_threshold` | 5 | 0.5 | % |

### Inicializálás
| # | Paraméter | Alapért. | Valós | Egység |
|---|-----------|----------|-------|--------|
| 20 | `init_duration` | 32 | 32 | másodperc |

---

## "Inkább Hideg Mint Száraz" Logika

```
  HA:
    • humidifier_installed = hamis
    • humidity_mode = SZÁRAZ
    • warm = igaz (fűtés kérve)
    • kamra_hom > 11.0°C

  AKKOR:
    • heating_blocked = igaz
    • relay_warm = KI

  MIÉRT:
    Párásító nélkül a fűtés tovább szárítaná a levegőt.
    A száradás okozta termékkár VISSZAFORDÍTHATATLAN.
    A hideg okozta termékkár VISSZAFORDÍTHATÓ.
    → "Inkább Hideg Mint Száraz"
```

---

## Biztonságos Inicializálás

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INDÍTÁSI SORREND                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ÚJRAINDÍTÁS                                                               │
│    │                                                                        │
│    ▼                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    INICIALIZÁLÁSI MÓD                                │   │
│  │                                                                      │   │
│  │  Időtartam: 32 másodperc (init_duration-nal állítható)              │   │
│  │                                                                      │   │
│  │  AKTÍV:                            TILTOTT:                         │   │
│  │  ✓ Érzékelő olvasás                ✗ Minden relé (KI-n tartva)      │   │
│  │  ✓ Buffer feltöltés                                                  │   │
│  │  ✓ Pszichrometriai számítások                                       │   │
│  │  ✓ Szabályozási logika fut                                          │   │
│  │  ✓ Mód meghatározás                                                 │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│    │                                                                        │
│    │ 32 másodperc eltelt                                                    │
│    ▼                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    NORMÁL ÜZEMMÓD                                    │   │
│  │                                                                      │   │
│  │  init_complete = igaz                                               │   │
│  │  Relé vezérlés engedélyezve                                         │   │
│  │  Alvás ciklus aktív (ha engedélyezve)                               │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

MIÉRT KELL AZ INICIALIZÁLÁS:
────────────────────────────
Újraindításkor minden változó alapértelmezettre áll (0).
Inicializálás nélkül:
  • A szabályozó T=0°C, RH=0%-ot lát
  • Vészhelyzetnek értelmezi
  • Fűtést + párásítást kapcsol
  • Berendezés károsodhat!

Inicializálással:
  • Relék 32 másodpercig KI maradnak
  • Érzékelők valós értékeket adnak
  • Bufferek érvényes adatokkal töltődnek
  • Biztonságos átmenet normál üzemmódba
```

---

## Jel Kimenetek (signals JSON)

| Jel | Típus | Leírás |
|-----|-------|--------|
| `kamra_hutes` | bool | Kamra hűtés kérés |
| `kamra_futes` | bool | Kamra fűtés kérés |
| `kamra_para_hutes` | bool | Párátlanítás (MÓD_PÁRÁS) |
| `befujt_hutes` | bool | Befújt hűtés kérés |
| `befujt_futes` | bool | Befújt fűtés kérés |
| `relay_cool` | bool | Hűtés relé kimenet |
| `relay_warm` | bool | Fűtés relé kimenet |
| `humidity_mode` | int | Aktuális mód (0/1/2) |
| `heating_blocked` | bool | Fűtés tiltva SZÁRAZ módban |
| `init_complete` | bool | Inicializálás kész |
| `init_countdown` | int | Hátralévő másodpercek |
