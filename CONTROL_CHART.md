# ERLELO Control Cycle - v2.5 Dual-Layer Cascade Control

## Version 2.5 Key Changes

| Change | v2.4 | v2.5 | Impact |
|--------|------|------|--------|
| AH Deadzone (Chamber) | 0.5 g/m³ (5%) | **0.8 g/m³ (8.3%)** | Wider stability zone |
| AH Hysteresis (Chamber) | N/A | **0.3 g/m³** | Directional hysteresis |
| Cooling Threshold | 16.0°C | **16.5°C** | Higher trigger point |
| Temperature Hysteresis | N/A | **0.5°C** | Exit hysteresis |
| Supply Deadzone | N/A | **0.5 g/m³** | Tighter inner loop |
| Supply Hysteresis | N/A | **0.2 g/m³** | Fine supply control |
| State Machine | Simple | **FINE/HUMID/DRY** | Directional transitions |
| Safe Initialization | N/A | **32 seconds** | All relays OFF during startup |

---

## Safe Initialization Period (v2.5)

**NEW in v2.5:** 32-second safe startup prevents equipment damage.

### Why Initialization is Critical

```
PROBLEM: During controller reboot, all variables reset to 0:
  - Temperature reading: 0°C (appears WAY too cold)
  - Humidity reading: 0% (appears WAY too dry)

WITHOUT safe init:
  → System sees "emergency cold + dry"
  → Heating ON + Humidifier ON (if installed)
  → Potential equipment damage!

WITH safe init (v2.5):
  → All relays forced OFF for 32 seconds
  → Sensors fill buffers with real data
  → Control logic runs but doesn't apply
  → Smooth transition to normal operation
```

### Initialization Timeline

```
Time    │ init_complete │ init_countdown │ Relays │ Activity
────────┼───────────────┼────────────────┼────────┼────────────────────
0s      │ false         │ 32             │ ALL OFF│ Start reading sensors
5s      │ false         │ 27             │ ALL OFF│ Buffers filling
15s     │ false         │ 17             │ ALL OFF│ AH/DP calculated
25s     │ false         │ 7              │ ALL OFF│ Mode determined
32s     │ true          │ 0              │ NORMAL │ Control enabled
```

### Signal Structure During Init

```lua
-- During initialization (first 32 seconds):
signals = {
    init_complete = false,
    init_countdown = 15,        -- Seconds remaining
    humidity_mode = MODE_DRY,   -- Control logic runs
    kamra_futes = true,         -- Heating requested...
    relay_warm = false,         -- ...but relay stays OFF
}

-- After initialization:
signals = {
    init_complete = true,
    init_countdown = 0,
    humidity_mode = MODE_DRY,
    kamra_futes = true,
    relay_warm = true,          -- Now relay follows signal
}
```

### Configuration

```lua
-- In constansok variable:
init_duration = 32  -- Seconds (default: 32)

-- Can be adjusted via erlelo_constants_editor.lua
```

---

## Default Configuration Values (v2.5)

| Parameter | Value | Description |
|-----------|-------|-------------|
| ah_deadzone_kamra | 80 | Chamber AH deadzone (0.8 g/m³) |
| ah_hysteresis_kamra | 30 | Chamber AH hysteresis (0.3 g/m³) |
| deltahi_kamra_homerseklet | 15 | Chamber temp high threshold (1.5°C) |
| deltalo_kamra_homerseklet | 10 | Chamber temp low threshold (1.0°C) |
| temp_hysteresis_kamra | 5 | Chamber temp hysteresis (0.5°C) |
| ah_deadzone_befujt | 50 | Supply AH deadzone (0.5 g/m³) |
| ah_hysteresis_befujt | 20 | Supply AH hysteresis (0.2 g/m³) |
| deltahi_befujt_homerseklet | 10 | Supply temp high threshold (1.0°C) |
| deltalo_befujt_homerseklet | 10 | Supply temp low threshold (1.0°C) |
| temp_hysteresis_befujt | 3 | Supply temp hysteresis (0.3°C) |

---

## 1. Dual-Layer Cascade Control Architecture

```
OUTER LOOP (Chamber Control)          INNER LOOP (Supply Control)
============================          ==========================
- WIDER deadzone (0.8 g/m³)           - TIGHTER deadzone (0.5 g/m³)
- LARGER hysteresis (0.3 g/m³)        - SMALLER hysteresis (0.2 g/m³)
- Temperature: 1.5°C threshold        - Temperature: 1.0°C threshold
- Sets the MODE (FINE/HUMID/DRY)      - Fine-tunes supply air

Hierarchy: If supply is within deadzone, chamber MUST also be within deadzone
           (tighter always implies wider)
```

### Cascade Flow

```
       ┌─────────────────────────────────────────────────────────────┐
       │                    OUTER LOOP                               │
       │              (Chamber Control)                              │
       │                                                             │
       │   ┌─────────────────────────────────────────────────────┐   │
       │   │                 INNER LOOP                          │   │
       │   │            (Supply Control)                         │   │
       │   │                                                     │   │
       │   │    Supply Air ──► Heat Exchanger ──► Chamber        │   │
       │   │                                                     │   │
       │   │    Tighter deadzone (0.5 g/m³)                     │   │
       │   │    Faster response                                  │   │
       │   └─────────────────────────────────────────────────────┘   │
       │                                                             │
       │   Wider deadzone (0.8 g/m³)                                │
       │   More stability                                            │
       └─────────────────────────────────────────────────────────────┘
```

---

## 2. Chamber Temperature Control (v2.5)

**Target: 15.0°C (150 raw)**
**Hysteresis: 0.5°C exit threshold**

```
Temperature (°C)
    ↑
20.0│                                              ← COOLING ZONE
    │
19.0│
    │
18.0│
    │
17.0│
    │
16.6│ ════════════════════════════════════════════ ← Cooling ON (>16.5°C)
16.5│ ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
    │                                           │
16.0│      COOLING HYSTERESIS (0.5°C)           │  ← Stays ON if already cooling
    │                                           │
15.5│ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘← Cooling OFF (exit hysteresis)
    │ ┌─────────────────────────────────────────┐
15.0│ │ ─ ─ ─ ─ ─ ─ TARGET ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
    │ │                                         │
14.5│ └─────────────────────────────────────────┘← Heating OFF (exit hysteresis)
    │ ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
    │       HEATING HYSTERESIS (0.5°C)           │  ← Stays ON if already heating
14.0│                                           │
13.9│ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
    │ ════════════════════════════════════════════ ← Heating ON (<14.0°C)
13.0│                                              ← HEATING ZONE
    │
11.0│ ════════════════════════════════════════════ ← "Better Cold Than Dry" min
    │
10.0│
    └──────────────────────────────────────────────→ Time
```

### Temperature State Transitions (v2.5)

| Current Temp | Current State | New State | Action |
|--------------|---------------|-----------|--------|
| > 16.5°C | Any | Cooling ON | Start cooling |
| 15.5 - 16.5°C | Cooling ON | Cooling ON | Continue (hysteresis) |
| < 15.5°C | Cooling ON | Cooling OFF | Exit cooling |
| < 14.0°C | Any | Heating ON | Start heating |
| 14.0 - 14.5°C | Heating ON | Heating ON | Continue (hysteresis) |
| > 14.5°C | Heating ON | Heating OFF | Exit heating |

---

## 3. Humidity State Machine (v2.5)

**Target: 15°C/75%RH → AH = 9.61 g/m³**
**Deadzone: ±0.8 g/m³ (enter), ±0.3 g/m³ (exit hysteresis)**

```
AH (g/m³)
    ↑
11.5│                                              ← HUMID MODE (dehumidify)
    │
11.0│
    │
10.5│ ════════════════════════════════════════════ ← Enter HUMID (>10.41)
10.41│ ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
    │     HUMID HYSTERESIS ZONE                   │
    │     (stays in HUMID until exit)             │
9.91│ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘← Exit DRY (>9.91)
    │ ┌─────────────────────────────────────────┐
9.61│ │ ─ ─ ─ ─ ─ ─ TARGET ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
    │ │         FINE MODE (idle)                │
9.31│ └─────────────────────────────────────────┘← Exit HUMID (<9.31)
    │ ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
    │     DRY HYSTERESIS ZONE                    │
    │     (stays in DRY until exit)              │
8.81│ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘← Enter DRY (<8.81)
    │ ════════════════════════════════════════════
8.0 │                                              ← DRY MODE (humidify)
    │
7.0 │
    └──────────────────────────────────────────────→ Time
```

### State Machine Transitions

```
            ┌─────────────────────────────────────────┐
            │              HUMID MODE                 │
            │         (Dehumidification ON)           │
            │                                         │
            │ Enter: AH > 10.41 (target + 0.8)       │
            │ Exit:  AH < 9.31 (target - 0.3)        │
            └──────────────────┬──────────────────────┘
                               │ AH < 9.31
                               ▼
            ┌─────────────────────────────────────────┐
            │              FINE MODE                  │
            │            (Idle - no action)           │
            │                                         │
            │ AH range: 8.81 to 10.41 g/m³           │
            └────────┬───────────────────────┬────────┘
        AH < 8.81    │                       │ AH > 10.41
                     ▼                       ▼
            ┌─────────────────────────────────────────┐
            │               DRY MODE                  │
            │          (Humidification ON*)           │
            │                                         │
            │ Enter: AH < 8.81 (target - 0.8)        │
            │ Exit:  AH > 9.91 (target + 0.3)        │
            │                                         │
            │ *If humidifier installed               │
            │  Otherwise: "Better cold than dry"     │
            └─────────────────────────────────────────┘
```

### Directional Hysteresis Benefits

```
WITHOUT directional hysteresis:        WITH directional hysteresis (v2.5):
Rapid cycling at boundaries            Stable operation

AH │  ╱╲  ╱╲  ╱╲                       AH │      ────────────────
   │ ╱  ╲╱  ╲╱  ╲                         │     ╱
   │╱             ╲                       │────╱
───┼─────────────────                  ───┼───────────────────────
   │               Threshold              │          Threshold
   │ MODE: FINE HUMID FINE HUMID          │ MODE: FINE  →  HUMID (stable)
```

---

## 4. Combined Control Matrix (v2.5)

**Example: Target T=15°C, RH=75% (AH=9.61 g/m³)**

```
              │ T < 14°C      │ 14-16.5°C    │ T > 16.5°C   │
──────────────┼───────────────┼──────────────┼──────────────┤
AH > 10.41    │ HEAT+DEHUMI   │ DEHUMI       │ COOL+DEHUMI  │
(HUMID mode)  │ (rare)        │              │              │
──────────────┼───────────────┼──────────────┼──────────────┤
8.81-10.41    │ HEAT          │ IDLE         │ COOL         │
(FINE mode)   │ (warm up)     │ (optimal)    │ (cool down)  │
──────────────┼───────────────┼──────────────┼──────────────┤
AH < 8.81     │ HEAT+HUM*     │ HUMID*       │ COOL+HUM*    │
(DRY mode)    │ or blocked    │ or idle      │ (rare)       │
──────────────┴───────────────┴──────────────┴──────────────┘

* Humidification only if humidifier installed
  Otherwise: "Better Cold Than Dry" may block heating
```

---

## 5. AH Calculation Reference

```lua
-- Psychrometric formula (v2.5)
-- Returns AH in g/m³
function calculate_absolute_humidity(temp_c, rh)
    local e_s = 6.112 * math.exp(17.67 * temp_c / (243.5 + temp_c))
    return 216.74 * (rh / 100) * e_s / (273.15 + temp_c)
end

-- Example values at 15°C:
-- 75% RH → AH = 9.61 g/m³ (target)
-- 70% RH → AH = 8.97 g/m³ (humidifier start)
-- 80% RH → AH = 10.25 g/m³
```

### AH Reference Table (at various temperatures)

| Temp | 60% RH | 70% RH | 75% RH | 80% RH | 85% RH |
|------|--------|--------|--------|--------|--------|
| 10°C | 5.64   | 6.58   | 7.05   | 7.51   | 7.98   |
| 13°C | 6.80   | 7.93   | 8.50   | 9.07   | 9.63   |
| 15°C | 7.69   | 8.97   | **9.61** | 10.25  | 10.89  |
| 16°C | 8.17   | 9.53   | 10.21  | 10.89  | 11.58  |
| 17°C | 8.68   | 10.13  | 10.85  | 11.57  | 12.29  |
| 19°C | 9.77   | 11.40  | 12.21  | 13.03  | 13.84  |
| 22°C | 11.64  | 13.58  | 14.55  | 15.52  | 16.49  |

**Key Thresholds (at target 15°C/75%):**
- Target AH: **9.61 g/m³**
- Enter HUMID: **10.41 g/m³** (target + 0.8)
- Enter DRY: **8.81 g/m³** (target - 0.8)
- Exit HUMID: **9.31 g/m³** (target - 0.3)
- Exit DRY: **9.91 g/m³** (target + 0.3)

---

## 6. Supply Air Inner Loop Control

```
Supply Loop (TIGHTER than Chamber):
- Deadzone: 0.5 g/m³ (vs chamber 0.8 g/m³)
- Hysteresis: 0.2 g/m³ (vs chamber 0.3 g/m³)
- Temp threshold: 1.0°C (vs chamber 1.5°C)

Purpose: Fine-tune supply air while chamber stays in FINE mode
```

### Cascade Hierarchy Guarantee

```
IF supply_error ≤ 0.5 g/m³ THEN chamber_error ≤ 0.5 g/m³ < 0.8 g/m³

Example:
  Supply AH error = 0.4 g/m³ → Inside supply deadzone (< 0.5)
  Chamber AH error = 0.4 g/m³ → Inside chamber deadzone (< 0.8)

  Supply AH error = 0.6 g/m³ → Outside supply deadzone (> 0.5)
  Chamber AH error = 0.6 g/m³ → Inside chamber deadzone (< 0.8)
  → Supply loop corrects BEFORE chamber needs action
```

---

## 7. Relay Output Truth Table (v2.5)

| Mode | cool | dehumi | warm | humidi | Relay States |
|------|------|--------|------|--------|--------------|
| FINE (idle) | 0 | 0 | 0 | 0 | All OFF |
| FINE (cool) | 1 | 0 | 0 | 0 | rel_cool, rel_bypass_open |
| FINE (heat) | 0 | 0 | 1 | 0 | rel_warm |
| HUMID | 0 | 1 | 0 | 0 | rel_cool, bypass_closed |
| HUMID+cool | 1 | 1 | 0 | 0 | rel_cool, bypass_closed |
| HUMID+heat | 0 | 1 | 1 | 0 | rel_cool, rel_warm, bypass_closed |
| DRY | 0 | 0 | 0 | 1 | rel_humidifier (if installed) |
| DRY+heat | 0 | 0 | 1* | 1 | rel_warm, rel_humidifier |

*Heating blocked if no humidifier and temp > 11°C ("Better cold than dry")

**Key Relay Formulas (v2.5):**
```lua
relay_cool = (cool or dehumi) and not sleep and use_water_cooling
relay_warm = warm and not sleep and not heating_blocked
relay_bypass_open = humi_save or (cool and not dehumi)
relay_humidifier = (humidity_mode == MODE_DRY) and hw_config.has_humidifier
```

---

## 8. Scenario Examples (v2.5)

### Scenario 1: Hot + Humid (17°C/80%)

| Parameter | Value | AH |
|-----------|-------|-----|
| Chamber | 17°C/80% | 11.57 g/m³ |
| Target | 15°C/75% | 9.61 g/m³ |

**v2.5 Analysis:**
- AH error = 11.57 - 9.61 = **1.96 g/m³** (> 0.8)
- 11.57 > 10.41 → **HUMID mode**
- 17°C > 16.5°C → **Cooling ON**
- Result: **COOL + DEHUMIDIFY** (bypass closed, 0°C water)

### Scenario 2: Cool + Dry (13°C/70%)

| Parameter | Value | AH |
|-----------|-------|-----|
| Chamber | 13°C/70% | 7.93 g/m³ |
| Target | 15°C/75% | 9.61 g/m³ |

**v2.5 Analysis:**
- AH error = 9.61 - 7.93 = **1.68 g/m³** (> 0.8)
- 7.93 < 8.81 → **DRY mode**
- 13°C < 14°C → **Heating needed**
- With humidifier: **HEAT + HUMIDIFY**
- Without humidifier: **Heating BLOCKED** (better cold than dry)

### Scenario 3: At Target (15°C/75%)

| Parameter | Value | AH |
|-----------|-------|-----|
| Chamber | 15°C/75% | 9.61 g/m³ |
| Target | 15°C/75% | 9.61 g/m³ |

**v2.5 Analysis:**
- AH error = 0 g/m³ (< 0.8)
- → **FINE mode**
- Temperature in deadband
- Result: **IDLE** (optimal operation)

### Scenario 4: Slight Variation (16°C/70%)

| Parameter | Value | AH |
|-----------|-------|-----|
| Chamber | 16°C/70% | 9.53 g/m³ |
| Target | 15°C/75% | 9.61 g/m³ |

**v2.5 Analysis:**
- AH error = 0.08 g/m³ (< 0.8) → **FINE mode**
- 16°C < 16.5°C → No cooling needed
- Result: **IDLE** (within deadzone)

---

## 9. Test Suite Coverage (v2.5)

**Total Tests: 2481 (100% pass)**

| Category | Tests | Description |
|----------|-------|-------------|
| v2.5 State Machine | 29 | FINE/HUMID/DRY transitions |
| v2.5 Anti-Cycling | 47 | Hysteresis prevents oscillation |
| v2.5 Temperature | 29 | 16.5°C threshold + hysteresis |
| v2.5 Cross-Signal | 65 | Combined temp+humidity logic |
| v2.5 Invalid States | 35 | No impossible combinations |
| v2.5 Supply Loop | 40 | Cascade hierarchy |
| v2.5 Physical | 29 | Real-world AH constraints |
| v2.5 Scenarios | 32 | Full scenario validation |
| v2.5 Initialization | 23 | Safe startup period |
| Legacy Tests | 2152 | v2.4 compatibility |

---

## 10. Migration from v2.4

| v2.4 Behavior | v2.5 Behavior |
|---------------|---------------|
| Cooling at 16.0°C | Cooling at **16.5°C** |
| 5% AH deadzone | **8.3% (0.8 g/m³)** deadzone |
| Simple ON/OFF | **Directional hysteresis** |
| No supply loop | **Cascade control** |

**Backwards Compatibility:**
- All v2.4 relay logic formulas unchanged
- Sensor handling unchanged
- UI callbacks unchanged
- Statistics recording unchanged

---

*Document Version: 2.5*
*Generated from ERLELO v2.5 control logic*
*Validated by 2481 test cases (100% pass)*
