# ERLELO v2.5 System Architecture

## Overview

ERLELO is a humidity-primary climate control system for agricultural storage chambers, running on SINUM controllers. The system uses absolute humidity (AH) as the primary control variable with temperature as secondary.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ERLELO v2.5 SYSTEM ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        SINUM CONTROLLER                              │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │erlelo_kamra1 │  │erlelo_kamra2 │  │erlelo_kamra3 │  Chamber     │   │
│  │  │    .lua      │  │    .lua      │  │    .lua      │  Controllers │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │   │
│  │         │                 │                 │                       │   │
│  │         └────────────┬────┴────────────────┘                       │   │
│  │                      │                                              │   │
│  │  ┌──────────────┐    │    ┌──────────────┐                         │   │
│  │  │erlelo_kulso  │────┴────│ constansok   │  Shared                 │   │
│  │  │    .lua      │         │  variables   │  Resources              │   │
│  │  └──────────────┘         └──────────────┘                         │   │
│  │   Outdoor Sensor           Configuration                            │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   Modbus    │  │    SBUS     │  │  Variables  │  │  HTTP API   │       │
│  │   Sensors   │  │   Relays    │  │   Storage   │  │   Access    │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. Chamber Controller (erlelo_kamra.lua)

The main control logic for each chamber. Runs independently per chamber.

```
┌─────────────────────────────────────────────────────────────────┐
│                    CHAMBER CONTROLLER                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   INITIALIZATION                         │   │
│  │                                                          │   │
│  │  on reboot ──▶ init_start_time = now                    │   │
│  │              │                                           │   │
│  │              ▼                                           │   │
│  │  ┌─────────────────────────────────────┐                │   │
│  │  │   INIT MODE (32 seconds)            │                │   │
│  │  │   • Sensors read                    │                │   │
│  │  │   • Buffers fill                    │                │   │
│  │  │   • Logic runs                      │                │   │
│  │  │   • ALL RELAYS OFF                  │                │   │
│  │  └─────────────────────────────────────┘                │   │
│  │              │                                           │   │
│  │              ▼ 32s elapsed                               │   │
│  │  ┌─────────────────────────────────────┐                │   │
│  │  │   NORMAL OPERATION                  │                │   │
│  │  │   init_complete = true              │                │   │
│  │  └─────────────────────────────────────┘                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   POLL CYCLE (1 second)                  │   │
│  │                                                          │   │
│  │  1. Read Sensors (Modbus)                               │   │
│  │     ├── Chamber T/RH                                    │   │
│  │     └── Supply T/RH                                     │   │
│  │                                                          │   │
│  │  2. Process Data                                        │   │
│  │     ├── Spike filter                                    │   │
│  │     ├── Moving average (buffer=5)                       │   │
│  │     └── Calculate AH, DP                                │   │
│  │                                                          │   │
│  │  3. Control Logic                                       │   │
│  │     ├── Determine humidity mode (FINE/HUMID/DRY)        │   │
│  │     ├── Chamber loop (outer, wider thresholds)          │   │
│  │     └── Supply loop (inner, tighter thresholds)         │   │
│  │                                                          │   │
│  │  4. Output                                              │   │
│  │     ├── Update signals variable (JSON)                  │   │
│  │     └── Set relay states (if init_complete && !sleep)   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Outdoor Sensor Controller (erlelo_kulso.lua)

Reads outdoor temperature and humidity, shared across all chambers.

```
┌─────────────────────────────────────────────────────────────────┐
│                   OUTDOOR SENSOR CONTROLLER                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Poll Cycle (1 second):                                        │
│  1. Read Modbus sensor                                         │
│  2. Apply spike filter                                         │
│  3. Update moving average                                      │
│  4. Calculate outdoor AH, DP                                   │
│  5. Store to global variables (*_glbl)                         │
│                                                                 │
│  Variables Written:                                            │
│  • kulso_homerseklet_glbl                                      │
│  • kulso_para_glbl                                             │
│  • kulso_ah_dp_glbl (JSON with ah, dp)                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Constants Editor (erlelo_constants_editor.lua)

UI device for runtime parameter adjustment.

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONSTANTS EDITOR                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User Interface:                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Chamber: [1]  [Refresh]  [Save]                        │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  Chamber Temp Hi:    [15]  Current: 1.5°C              │   │
│  │  Chamber Temp Lo:    [10]  Current: 1.0°C              │   │
│  │  Init Duration:      [32]  Current: 32s                │   │
│  │  ...                                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Operations:                                                   │
│  • Refresh: GET /api/v1/variables/{id} → parse JSON           │
│  • Save: PUT /api/v1/variables/{id} → update value + default  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Architecture

### Variable Naming Convention

```
Chamber-specific:  {name}_ch{1,2,3}     Example: kamra_homerseklet_ch1
Global:            {name}_glbl          Example: kulso_homerseklet_glbl
```

### Variable Resolution (V function)

```lua
V('kamra_homerseklet')  
  → tries: kamra_homerseklet_ch1 (for chamber 1)
  → if not found: kamra_homerseklet_glbl
```

### Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            DATA FLOW                                     │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SENSORS                    PROCESSING                  OUTPUTS          │
│                                                                          │
│  ┌────────────┐            ┌────────────┐            ┌────────────┐     │
│  │ Modbus     │            │ Chamber    │            │ signals    │     │
│  │ Chamber    │───────────▶│ Controller │───────────▶│ _chX       │     │
│  │ Sensor     │            │            │            │ (JSON)     │     │
│  └────────────┘            │  ┌──────┐  │            └─────┬──────┘     │
│                            │  │ Mode │  │                  │            │
│  ┌────────────┐            │  │State │  │            ┌─────▼──────┐     │
│  │ Modbus     │───────────▶│  │      │  │            │ SBUS       │     │
│  │ Supply     │            │  └──────┘  │            │ Relays     │     │
│  │ Sensor     │            │            │            └────────────┘     │
│  └────────────┘            └─────▲──────┘                               │
│                                  │                                       │
│  ┌────────────┐            ┌─────┴──────┐                               │
│  │ Modbus     │            │ constansok │                               │
│  │ Outdoor    │───────────▶│ _chX       │◀──── Constants Editor        │
│  │ Sensor     │            │ (JSON)     │                               │
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

## Control Architecture

### Dual-Layer Cascade

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      DUAL-LAYER CASCADE CONTROL                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  CHAMBER LOOP (Outer)              SUPPLY LOOP (Inner)                 │
│  ─────────────────────             ─────────────────────               │
│                                                                         │
│  ┌─────────────────────┐          ┌─────────────────────┐             │
│  │ Humidity Mode       │          │ Temperature Only    │             │
│  │ + Temperature       │          │                     │             │
│  │                     │          │                     │             │
│  │ Thresholds:         │          │ Thresholds:         │             │
│  │ • Temp: ±1.5/1.0°C  │──────────│ • Temp: ±1.0°C     │             │
│  │ • AH: ±0.8 g/m³     │          │                     │             │
│  │ • Hysteresis: 0.5°C │          │ • Hysteresis: 0.3°C │             │
│  └─────────────────────┘          └─────────────────────┘             │
│           │                                │                           │
│           │    Sets mode, requests         │    Fast corrections       │
│           │    cooling/heating             │    to supply air          │
│           ▼                                ▼                           │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                      RELAY OUTPUT LOGIC                          │  │
│  │                                                                  │  │
│  │  relay_cool = (kamra_hutes OR befujt_hutes) AND NOT sleep       │  │
│  │               AND init_complete                                  │  │
│  │  relay_warm = (kamra_futes OR befujt_futes) AND NOT sleep       │  │
│  │               AND NOT heating_blocked AND init_complete          │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Humidity State Machine

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      HUMIDITY STATE MACHINE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                    ┌──────────────────────┐                            │
│                    │      MODE_FINE       │                            │
│                    │   (AH within ±0.8)   │                            │
│                    └──────────┬───────────┘                            │
│                               │                                         │
│         ┌─────────────────────┼─────────────────────┐                  │
│         │                     │                     │                  │
│         │ AH > target+0.8     │                     │ AH < target-0.8  │
│         ▼                     │                     ▼                  │
│  ┌──────────────┐             │             ┌──────────────┐           │
│  │  MODE_HUMID  │             │             │  MODE_DRY    │           │
│  │              │             │             │              │           │
│  │ Dehumidify   │             │             │ Block heat   │           │
│  │ Cool         │             │             │ Humidify*    │           │
│  └──────┬───────┘             │             └──────┬───────┘           │
│         │                     │                    │                   │
│         │ AH < target-0.3     │    AH > target+0.3 │                   │
│         └─────────────────────┴────────────────────┘                   │
│                                                                         │
│  * Only if humidifier_installed = true                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Initialization Architecture

### Startup Sequence

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      INITIALIZATION SEQUENCE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  TIME     STATE              SENSORS       LOGIC        RELAYS         │
│  ────     ─────              ───────       ─────        ──────         │
│                                                                         │
│  0s       INIT START         Reading       Running      ALL OFF        │
│           init_complete=F    (invalid)     (outputs     (safe)         │
│           countdown=32                      ignored)                    │
│                                                                         │
│  5s       INIT               Values        Running      ALL OFF        │
│           countdown=27       stabilizing                                │
│                                                                         │
│  15s      INIT               Valid data    Mode         ALL OFF        │
│           countdown=17       in buffers    determined                   │
│                                                                         │
│  32s      NORMAL             Valid         Running      CONTROLLED     │
│           init_complete=T                                               │
│           countdown=0                                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why Initialization Is Required

```
WITHOUT INITIALIZATION:
───────────────────────
Reboot → Variables = 0 → T=0°C, RH=0% → "Emergency!" → Heat+Humidify ON
                                                        ↓
                                              EQUIPMENT DAMAGE RISK

WITH INITIALIZATION:
────────────────────
Reboot → Variables = 0 → INIT MODE → Relays OFF → Sensors stabilize
                              ↓
                         32 seconds
                              ↓
                         NORMAL MODE → Safe control based on real data
```

---

## File Architecture

### Deployment Files

| File | Type | Purpose | Runs On |
|------|------|---------|---------|
| `erlelo_kamra1.lua` | Controller | Chamber 1 control | SINUM device |
| `erlelo_kamra2.lua` | Controller | Chamber 2 control | SINUM device |
| `erlelo_kamra3.lua` | Controller | Chamber 3 control | SINUM device |
| `erlelo_kulso.lua` | Controller | Outdoor sensor | SINUM device |
| `erlelo_constants_editor.lua` | UI | Parameter tuning | SINUM device |

### Setup Utilities

| File | Type | Purpose | Runs |
|------|------|---------|------|
| `erlelo_create.lua` | Utility | Create variables | Once per setup |
| `erlelo_store.lua` | Utility | Build ID mapping | Once per setup |
| `erlelo_delete.lua` | Utility | Remove variables | Cleanup only |

### Configuration Files

| File | Purpose |
|------|---------|
| `erlelo_config_1ch.json` | 1-chamber configuration |
| `erlelo_config_2ch.json` | 2-chamber configuration |
| `erlelo_config_3ch.json` | 3-chamber configuration |

---

## Parameter Architecture

### 27 Configurable Parameters

| Category | Count | Parameters |
|----------|-------|------------|
| Chamber Loop | 5 | deltahi/lo_kamra, temp_hyst, ah_dz/hyst_kamra |
| Supply Loop | 5 | deltahi/lo_befujt, temp_hyst, ah_dz/hyst_befujt |
| Global Control | 6 | outdoor_mix, threshold, gain, min/max_supply, min_no_humi |
| Sensor Processing | 5 | buffer, spike, max_error, temp/humi_change |
| Humidifier | 2 | installed, start_delta |
| Sleep Cycle | 3 | enabled, on_minutes, off_minutes |
| Initialization | 1 | init_duration |

### Parameter Storage

```
constansok_ch1 (JSON variable):
{
  "deltahi_kamra_homerseklet": 15,
  "deltalo_kamra_homerseklet": 10,
  ...
  "init_duration": 32
}
```

---

## Signal Output Architecture

### signals_chX Variable (JSON)

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

## Communication Architecture

### Modbus (Sensors)

```
SINUM ←──Modbus RTU──→ Temperature/Humidity Sensors
        Register 0: Temperature (×10)
        Register 1: Humidity (×10)
```

### SBUS (Relays)

```
SINUM ←──SBUS──→ Relay Modules
        setState("on"/"off")
```

### HTTP API (Configuration)

```
Constants Editor ←──HTTP──→ SINUM API
        GET  /api/v1/variables/{id}
        PUT  /api/v1/variables/{id}
        POST /api/v1/variables
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v2.5 | Nov 2024 | Dual-layer cascade, directional hysteresis, state machine, 27 configurable parameters, safe initialization (32s) |
| v2.4 | Nov 2024 | Humidity-primary control, HTTP patterns |
| v2.3 | Nov 2024 | Variable naming standardization |
| v2.0 | Oct 2024 | Initial humidity-aware design |
