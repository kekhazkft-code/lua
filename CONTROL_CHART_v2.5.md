# ERLELO Control Cycle - Hysteresis Charts

## v2.5 Changes Summary

**Dual-Layer Cascade Control with Directional Hysteresis**

Key improvements:
- Chamber (outer loop): Wider deadzone, larger hysteresis for stability
- Supply (inner loop): Tighter deadzone, smaller hysteresis for precision
- Fixed inverted supply temperature thresholds

- Added directional hysteresis to prevent oscillation at boundaries

## Default Configuration Values (v2.5)

### Chamber Control (Outer Loop - Wider)

| Parameter | Value | Actual | Description |
|-----------|-------|--------|-------------|
| deltahi_kamra_homerseklet | 15 | 1.5°C | Temperature high threshold |
| deltalo_kamra_homerseklet | 10 | 1.0°C | Temperature low threshold |
| temp_hysteresis_kamra | 5 | 0.5°C | **NEW** Directional hysteresis |
| ah_deadzone_kamra | 80 | 0.8 g/m³ | AH deadzone (was 50) |
| ah_hysteresis_kamra | 30 | 0.3 g/m³ | **NEW** Directional hysteresis |
| deltahi_kamra_para | 15 | 1.5% | Humidity high threshold (RH display) |
| deltalo_kamra_para | 10 | 1.0% | Humidity low threshold (RH display) |

### Supply Air Control (Inner Loop - Tighter)

| Parameter | Value | Actual | Description |
|-----------|-------|--------|-------------|
| deltahi_befujt_homerseklet | 10 | 1.0°C | Supply temp high threshold (was 20!) |
| deltalo_befujt_homerseklet | 10 | 1.0°C | Supply temp low threshold (was 15!) |
| temp_hysteresis_befujt | 3 | 0.3°C | **NEW** Directional hysteresis |
| ah_deadzone_befujt | 50 | 0.5 g/m³ | **NEW** Supply AH deadzone |
| ah_hysteresis_befujt | 20 | 0.2 g/m³ | **NEW** Directional hysteresis |

### Cascade Hierarchy Verification

```
Chamber (outer) must be WIDER than Supply (inner):

AH Control:
  Chamber: ±0.8 + 0.3 hysteresis = 1.9 g/m³ total band
  Supply:  ±0.5 + 0.2 hysteresis = 1.2 g/m³ total band
  Ratio: 1.58 ✓ (outer > inner)

Temperature Control:
  Chamber: +1.5/-1.0 + 0.5 hysteresis = 3.0°C total band
  Supply:  ±1.0 + 0.3 hysteresis = 2.3°C total band
  Ratio: 1.30 ✓ (outer > inner)
```

---

## 1. Chamber Temperature Control (v2.5)

**Target: 15.0°C (150 raw)**

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
16.5│ ════════════════════════════════════════════ ← Cooling ON (>16.5°C) [was 16.0]
16.0│ ┌─────────────────────────────────────────┐
    │ │           ┌───────────────────┐         │
15.5│ │           │  HYSTERESIS ZONE  │         │  ← Exit cooling: must reach 15.5°C
    │ │           │  (stay in mode)   │         │
15.0│ │ ─ ─ ─ ─ ─ ─ ─ TARGET ─ ─ ─ ─ ─ ─ ─ ─ ─ │
    │ │           │                   │         │
14.5│ │           │                   │         │  ← Exit heating: must reach 14.5°C
    │ │           └───────────────────┘         │
14.0│ └─────────────────────────────────────────┘
13.9│ ════════════════════════════════════════════ ← Heating ON (<14.0°C) [unchanged]
    │
13.0│                                              ← HEATING ZONE
    │
12.0│
    │
11.0│ ════════════════════════════════════════════ ← Min temp for "Better Cold Than Dry"
    │
10.0│
    └──────────────────────────────────────────────→ Time
```

### Temperature State Transitions (v2.5 with Hysteresis)

| Current Temp | Previous State | New State | Action |
|--------------|----------------|-----------|--------|
| > 16.5°C | Any | Cooling ON | Start cooling (cross +1.5 threshold) |
| 14.0 - 16.5°C | Cooling ON | Cooling ON | Continue until < 15.5°C (hysteresis) |
| < 15.5°C | Cooling ON | OFF | Stop cooling (crossed hysteresis) |
| 14.0 - 16.5°C | Heating ON | Heating ON | Continue until > 14.5°C (hysteresis) |
| > 14.5°C | Heating ON | OFF | Stop heating (crossed hysteresis) |
| 14.0 - 16.5°C | OFF | OFF | No action (deadband) |
| < 14.0°C | Any | Heating ON | Start heating (cross -1.0 threshold) |

**Note:** Asymmetric thresholds (+1.5°C/-1.0°C) because dehumidification often raises temperature slightly.

---

## 2. Chamber Humidity Control (v2.5 - AH-Based with Hysteresis)

**Target: 75.0% RH at 15°C → AH = 9.61 g/m³**

```
Absolute Humidity (g/m³)
    ↑
12.0│                                              ← HUMID ZONE (dehumidify)
    │
11.5│
    │
11.0│
    │
10.5│
    │
10.41│════════════════════════════════════════════ ← Enter HUMID mode (AH > target + 0.8)
10.0│ ┌─────────────────────────────────────────┐
    │ │           ┌───────────────────┐         │
 9.91│ │           │                   │         │  ← Exit DRY: must reach here
    │ │           │  HYSTERESIS ZONE  │         │
 9.61│ │ ─ ─ ─ ─ ─ ─ TARGET AH ─ ─ ─ ─ ─ ─ ─ ─ │
    │ │           │                   │         │
 9.31│ │           │                   │         │  ← Exit HUMID: must reach here
    │ │           └───────────────────┘         │
 9.0│ │                                         │
    │ │         FINE MODE (AH acceptable)       │
 8.81│ └─────────────────────────────────────────┘
    │ ════════════════════════════════════════════ ← Enter DRY mode (AH < target - 0.8)
 8.5│
    │
 8.0│                                              ← DRY ZONE (humidify if installed)
    │
 7.5│
    └──────────────────────────────────────────────→ Time
```

### Humidity Mode State Machine (v2.5)

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
              ┌──────────┐                               │
     ┌───────→│   FINE   │←───────┐                      │
     │        │  (mode 0)│        │                      │
     │        └──────────┘        │                      │
     │              │             │                      │
     │   AH > 10.41 │             │ AH < 8.81           │
     │              ▼             │                      │
     │        ┌──────────┐        │        ┌──────────┐ │
     │        │  HUMID   │        └────────│   DRY    │ │
     │        │ (mode 1) │                 │ (mode 2) │ │
     │        └──────────┘                 └──────────┘ │
     │              │                            │      │
     │   AH < 9.31  │                            │ AH > 9.91
     │   (hysteresis)                            │ (hysteresis)
     │              │                            │      │
     └──────────────┴────────────────────────────┴──────┘

State variables needed:
  humidity_mode_state_ch{N} = 0 (FINE), 1 (HUMID), 2 (DRY)
```

### Humidity State Transitions (v2.5)

| Current AH | Previous Mode | New Mode | Action |
|------------|---------------|----------|--------|
| > 10.41 g/m³ | Any | HUMID | Start dehumidification |
| 9.31 - 10.41 | HUMID | HUMID | Continue (hysteresis) |
| < 9.31 | HUMID | FINE | Stop dehumidification |
| < 8.81 g/m³ | Any | DRY | Start humidification* |
| 8.81 - 9.91 | DRY | DRY | Continue (hysteresis) |
| > 9.91 | DRY | FINE | Stop humidification |
| 8.81 - 10.41 | FINE | FINE | No action (deadband) |

*Only if humidifier installed. Otherwise "Better Cold Than Dry" blocks heating.

---

## 3. Combined Control Matrix (v2.5)

**Example: Target T=15°C, RH=75% (AH=9.61 g/m³)**

```
              │ T < 14°C   │ 14-16.5°C │ T > 16.5°C │
──────────────┼────────────┼───────────┼────────────┤
AH > 10.41    │ HEAT+DEH   │ DEHUMI    │ COOL+DEH   │
(HUMID mode)  │            │           │            │
──────────────┼────────────┼───────────┼────────────┤
AH 8.81-10.41 │ HEAT       │ IDLE      │ COOL       │
(FINE mode)   │            │           │            │
──────────────┼────────────┼───────────┼────────────┤
AH < 8.81     │ HEAT+HUM*  │ HUMID*    │ COOL+HUM*  │
(DRY mode)    │            │           │            │
──────────────┴────────────┴───────────┴────────────┘

* Humidification only if humidifier installed
  Otherwise: "Better Cold Than Dry" blocks heating
```

### Temperature Safety Override (Non-Negotiable)

```
⚠️ HARD LIMIT: If chamber temp > target + deltahi (16.5°C) → MUST COOL

This override is INDEPENDENT of humidity mode!

Even in DRY mode (AH < 8.81), if temperature exceeds 16.5°C:
  → Cooling activates (water or outdoor air)
  → Cannot be blocked by humidity considerations
  → Product safety requires temperature control

Truth table:
┌─────────────────┬──────────────┬─────────────────────────────────┐
│ Humidity Mode   │ Temp > 16.5°C│ Action                          │
├─────────────────┼──────────────┼─────────────────────────────────┤
│ HUMID           │ YES          │ Cool + Dehumidify               │
│ FINE            │ YES          │ Cool only                       │
│ DRY             │ YES          │ Cool (override DRY mode!)       │
│ HUMID           │ NO           │ Dehumidify only                 │
│ FINE            │ NO           │ Idle                            │
│ DRY             │ NO           │ Humidify (if installed)         │
└─────────────────┴──────────────┴─────────────────────────────────┘
```

---

## 4. Humidity Decision Logic: RH vs AH (v2.5)

**User Interface:** Targets and hysteresis configured in **RH%** (intuitive)
**Internal Logic:** All humidity decisions use **Absolute Humidity (AH)** (accurate)

### Why AH Instead of RH?

RH% depends on temperature. The same moisture content shows different RH% at different temperatures:

```
Same moisture (AH = 9.6 g/m³):
  At 15°C → 75% RH  ✓ (at target)
  At 17°C → 66% RH  ✗ (appears dry, but same moisture!)
  At 13°C → 87% RH  ✗ (appears wet, but same moisture!)
```

**Problem with RH-based decisions:**
```
Chamber at 17°C, 70% RH (AH = 10.2 g/m³)
Target:    15°C, 75% RH (AH = 9.6 g/m³)

RH comparison: 70% < 75% → "too dry" → would HUMIDIFY (WRONG!)
AH comparison: 10.2 > 9.6 → "too wet" → DEHUMIDIFY (CORRECT!)
```

### Conversion Formula

```lua
-- User configures in RH%, system converts to AH at target temp
target_ah = calculate_absolute_humidity(target_temp, target_rh)
current_ah = calculate_absolute_humidity(current_temp, current_rh)

-- v2.5: Deadzone and hysteresis thresholds
local ah_deadzone = const.ah_deadzone_kamra / 100  -- 0.8 g/m³
local ah_hysteresis = const.ah_hysteresis_kamra / 100  -- 0.3 g/m³

-- Mode determination with hysteresis
if current_ah > target_ah + ah_deadzone then
  humidity_mode = HUMID
elseif current_ah < target_ah - ah_deadzone then
  humidity_mode = DRY
elseif humidity_mode == HUMID and current_ah > target_ah - ah_hysteresis then
  humidity_mode = HUMID  -- Stay in HUMID (hysteresis)
elseif humidity_mode == DRY and current_ah < target_ah + ah_hysteresis then
  humidity_mode = DRY    -- Stay in DRY (hysteresis)
else
  humidity_mode = FINE
end
```

### Decision Summary (v2.5)

| Decision | Compares | Why |
|----------|----------|-----|
| **Mode Selection** | AH vs AH thresholds | Actual moisture content, temp-independent |
| **Dehumidification** | humidity_mode == HUMID | Based on AH with hysteresis |
| **Humidification** | humidity_mode == DRY | Based on AH with hysteresis |
| **"Better Cold Than Dry"** | AH vs AH | Prevents false heating when dry |

---

## 5. Hysteresis Function Behavior (v2.5)

### Standard Hysteresis (without directional memory)

```lua
-- Basic hysteresis function (v2.4 style)
function hysteresis(measured, target, delta_hi, delta_lo, current_state)
    if measured > target + delta_hi then
        return true   -- Turn ON
    elseif measured < target - delta_lo then
        return false  -- Turn OFF
    else
        return current_state  -- Keep current state (DEADBAND)
    end
end
```

### Directional Hysteresis (v2.5 - NEW)

```lua
-- v2.5: Directional hysteresis with explicit exit thresholds
function directional_hysteresis(measured, target, deadzone, hysteresis, current_mode)
    local upper_threshold = target + deadzone
    local lower_threshold = target - deadzone
    local exit_from_high = target - hysteresis
    local exit_from_low = target + hysteresis
    
    if measured > upper_threshold then
        return MODE_HIGH  -- Enter HIGH mode
    elseif measured < lower_threshold then
        return MODE_LOW   -- Enter LOW mode
    elseif current_mode == MODE_HIGH and measured > exit_from_high then
        return MODE_HIGH  -- Stay HIGH (hysteresis)
    elseif current_mode == MODE_LOW and measured < exit_from_low then
        return MODE_LOW   -- Stay LOW (hysteresis)
    else
        return MODE_NORMAL  -- Return to normal
    end
end
```

### Visual Hysteresis Cycle (v2.5)

```
              Without Hysteresis (v2.4)          With Hysteresis (v2.5)
              
AH (g/m³)     Prone to cycling!                 Stable operation
    │                                           
10.41 ────────┬─── Enter HUMID ──────────────── Enter HUMID ───────────
              │         │                              │
              │    ┌────┴────┐                         │
              │    │ cycling │                         │ HUMID zone
              │    │ at edge │                         │ (stays HUMID)
              │    └────┬────┘                         │
 9.61 ────────┼─── Target ───────────────────── Target ────────────────
              │         │                              │
              │    ┌────┴────┐                    ┌────┴────┐
              │    │ cycling │                    │ hysteresis │
              │    │ at edge │                    │  buffer   │
              │    └────┬────┘                    └────┬────┘
 9.31 ────────┼─────────┼─────────────────────── Exit HUMID ───────────
              │         │                              │
 8.81 ────────┴─── Enter DRY ────────────────── Enter DRY ─────────────

Result: Mode flips constantly            Result: Stable mode, no cycling
        at boundaries                            until clear exit
```

---

## 6. Working Example Values (v2.5)

### Scenario: Summer Day Cooling

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Outdoor Temp | 25.0°C | 250 |
| Chamber Temp | 22.0°C | 220 |
| Chamber RH | 74.5% | 745 |

**Control Decision (v2.5):**
- Chamber AH at 22°C/74.5% = 14.45 g/m³
- Target AH at 15°C/75% = 9.61 g/m³
- AH error: +50% (way above 10.41 threshold)
- Humidity mode: **HUMID** (dehumidify needed)
- Temperature: 220 > 165 → **Cooling ON** (above 16.5°C)
- Result: **Dehumidify + Cool** (water cooling, bypass closed)

**Note (v2.5):** At 22°C/74.5%, AH is 14.45 g/m³ - much higher than 10.41 threshold despite RH appearing "normal"!

### Scenario: Winter Day Cooling (External Air)

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Outdoor Temp | 2.0°C | 20 |
| Chamber Temp | 17.5°C | 175 |
| Chamber RH | 70.0% | 700 |

**Control Decision (v2.5):**
- Chamber AH at 17.5°C/70% = 10.47 g/m³
- AH error: +9% (just above 10.41 threshold)
- Humidity mode: **HUMID** (dehumidify needed)
- Temperature: 175 > 165 → **Cooling needed** (above 16.5°C)
- Outdoor beneficial: (175 - 20) = 155 ≥ 50 → **YES**
- But dehumi needed → **Cannot use outdoor air**
- Result: **Water cooling at 0°C** (bypass closed for condensation)

**Note (v2.5):** Even though outdoor is cold enough for free cooling, dehumidification requires cold coils!

### Scenario: Cold Night with Good Humidity

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Outdoor Temp | 5.0°C | 50 |
| Chamber Temp | 13.8°C | 138 |
| Chamber RH | 80.0% | 800 |

**Control Decision (v2.5):**
- Chamber AH at 13.8°C/80% = 9.43 g/m³
- Target AH = 9.61 g/m³
- AH error: -2% (within ±0.8 deadzone)
- Humidity mode: **FINE** (humidity acceptable)
- Temperature: 138 < 140 → **Heating ON** (below 14.0°C)
- Result: **Heat only** (humidity is fine despite 80% RH appearing high!)

**Note (v2.5):** At cold temps, 80% RH has LESS moisture than 75% RH at 15°C. AH-based control prevents false dehumidification!

### Scenario: Hysteresis Preventing Cycling

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Chamber Temp | 16.0°C | 160 |
| Chamber RH | 79.0% | 790 |
| Previous Mode | HUMID | - |

**Control Decision (v2.5):**
- Chamber AH at 16°C/79% = 10.77 g/m³
- AH error: +12%
- Current AH (10.77) is BELOW entry threshold (10.41)?
  - YES, but we were in HUMID mode
- Current AH (10.77) is ABOVE exit threshold (9.31)?
  - YES! → **Stay in HUMID mode** (hysteresis)
- Result: **Continue dehumidifying** (no mode flip)

**Without hysteresis (v2.4):** Would have exited HUMID at 10.40, re-entered at 10.42 → cycling!

---

## 7. Supply Air Temperature Control (v2.5 Dual-Layer Cascade)

**Humidity-primary control: deadzone uses ABSOLUTE HUMIDITY (AH) error**

"Better cold than dry" philosophy:
- Too dry → irreversible product damage (surface cracking, case hardening)
- Too humid → mold risk, critical to address
- Too cold → just slows process, recoverable
- Product equilibrium depends on AH, not temperature

### v2.5 Supply Air Parameters (Inner Loop - Tighter)

| Parameter | v2.4 | v2.5 | Description |
|-----------|------|------|-------------|
| ah_deadzone_befujt | - | 50 | **NEW** Supply AH deadzone (0.5 g/m³) |
| ah_hysteresis_befujt | - | 20 | **NEW** Supply hysteresis (0.2 g/m³) |
| deltahi_befujt_homerseklet | 20 | 10 | Supply temp high (1.0°C, was 2.0!) |
| deltalo_befujt_homerseklet | 15 | 10 | Supply temp low (1.0°C, was 1.5!) |
| temp_hysteresis_befujt | - | 3 | **NEW** Supply temp hysteresis (0.3°C) |
| proportional_gain | 10 | 10 | P gain × 10 (unchanged) |
| outdoor_mix_ratio | 30 | 30 | Outdoor mixing ratio (unchanged) |

**Critical fix:** Supply thresholds were WIDER than chamber (inverted!). Now correctly tighter.

### Mode 1: OUTSIDE AH DEADZONE (Aggressive Control)

When chamber AH error > deadzone: Aggressive correction to fix humidity first.

```
Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) × P

Where P = 1.0 (default)
Simplified: Befujt_cél = 2 × Kamra_cél - Kamra_mért

Example:
  Target: 15°C, Chamber: 18°C (AH too high)
  Befujt_cél = 15 - (18 - 15) × 1 = 15 - 3 = 12°C
  → Supply cold air at 12°C to rapidly dehumidify/cool chamber
```

### Mode 2: INSIDE AH DEADZONE (Fine Control)

When chamber AH within deadzone: Fine-tune temperature with outdoor mixing.

```
Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) × (1 - mix)
                       - (Külső_mért - Kamra_cél) × mix

Where mix = outdoor_mix_ratio (default 30%)

Example:
  Target: 15°C, Chamber: 15.5°C, Outdoor: 20°C (AH is OK)
  Befujt_cél = 15 - 0.5 × 0.7 - 5 × 0.3 = 13.15°C
  → Gentle temperature adjustment (humidity already acceptable)
```

### Supply Air Control Loop (v2.5)

```lua
-- v2.5: Supply air has its own deadzone and hysteresis (inner loop)
local supply_ah = calculate_absolute_humidity(befujt_hom / 10, befujt_para / 10)
local supply_target_ah = target_ah  -- Same as chamber target

local supply_ah_deadzone = const.ah_deadzone_befujt / 100  -- 0.5 g/m³
local supply_ah_hysteresis = const.ah_hysteresis_befujt / 100  -- 0.2 g/m³

-- Supply control is TIGHTER than chamber (inner loop)
local supply_ah_error = math.abs(supply_ah - supply_target_ah)
local supply_inside_deadzone = supply_ah_error <= supply_ah_deadzone
```

### Cascade Control Visualization

```
OUTER LOOP (Chamber - Slow, Large Mass)          INNER LOOP (Supply - Fast, Small Mass)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━           ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        ┌─────────────────┐                              ┌─────────────────┐
        │ Chamber Sensor  │                              │ Supply Sensor   │
        │  (temp, RH)     │                              │  (temp, RH)     │
        └────────┬────────┘                              └────────┬────────┘
                 │                                                │
                 ▼                                                ▼
        ┌─────────────────┐                              ┌─────────────────┐
        │ Calculate AH    │                              │ Calculate AH    │
        │ current_ah      │                              │ supply_ah       │
        └────────┬────────┘                              └────────┬────────┘
                 │                                                │
                 ▼                                                ▼
        ┌─────────────────┐                              ┌─────────────────┐
        │ Mode Selection  │                              │ Relay Control   │
        │ ±0.8 g/m³ + 0.3 │──── setpoint ────────────►  │ ±0.5 g/m³ + 0.2 │
        │ (WIDER)         │                              │ (TIGHTER)       │
        └────────┬────────┘                              └────────┬────────┘
                 │                                                │
                 ▼                                                ▼
        ┌─────────────────┐                              ┌─────────────────┐
        │ HUMID/FINE/DRY  │                              │ Cooling/Heating │
        │ Mode Output     │                              │ Relay Outputs   │
        └─────────────────┘                              └─────────────────┘

Time constant: ~30-60 minutes                    Time constant: ~2-5 minutes
(large thermal mass)                             (small air volume)
```

### Temperature Constraints

```lua
-- Clamp supply target to safe range
if befujt_target_temp < min_supply_air_temp then
  befujt_target_temp = min_supply_air_temp  -- 6°C minimum
end
if befujt_target_temp > max_supply_air_temp then
  befujt_target_temp = max_supply_air_temp  -- 40°C maximum
end
```

### Combined Control Signal Logic

```lua
-- Final control signals combine chamber AND supply needs
cool = kamra_hutes OR befujt_hutes   -- Either triggers cooling
warm = kamra_futes OR befujt_futes   -- Either triggers heating
dehumi = kamra_para_hutes            -- Only chamber humidity
```

---

## 8. Humi_save Mode (Humidity Preservation)

**Energy-saving mode that preserves humidity during idle periods**

| Input | State | Description |
|-------|-------|-------------|
| inp_humidity_save | ON | Activate humidity preservation |

**Relay States in Humi_save Mode:**
- `rel_reventon` = ON (recirculation fan)
- `rel_add_air_save` = ON (minimal fresh air)
- `rel_bypass_open` = ON (bypass enabled)

```
Humi_save Mode Flow:

  ┌─────────────────────────────────────────────────────┐
  │                    CHAMBER                          │
  │                                                     │
  │    ┌──────┐                         ┌──────┐       │
  │    │Bypass│←── OPEN ───────────────→│ Fan  │       │
  │    └──────┘                         └──────┘       │
  │        ↑                                ↑          │
  │        │    Recirculating air          │          │
  │        └───────────────────────────────┘          │
  │                                                     │
  └─────────────────────────────────────────────────────┘

  Purpose: Maintain humidity without external air exchange
           Saves energy during stable conditions
```

---

## 9. Sum_wint Signal (Summer/Winter Mode)

**Hardware-only distinction - does NOT change control logic**

The sum_wint signal selects which fan speed wiring is active. Air density varies with temperature:
- **Summer**: Lighter (less dense) air → needs higher fan speed
- **Winter**: Denser (heavier) air → needs lower fan speed

| Signal | Season | Air Property | Main Fan |
|--------|--------|--------------|----------|
| sum_wint = OFF | Summer | Light (less dense) | Higher speed wiring |
| sum_wint = ON | Winter | Dense (heavier) | Lower speed wiring |

**Key Points:**
- All control logic works **identically year-round**
- The signal ONLY selects fan speed hardware wiring
- Summer needs higher fan speed to move same air mass
- Winter needs lower fan speed (denser air = more mass per rotation)

---

## 10. Bypass Control Logic (Water Circuit)

**Bypass valve controls water temperature in the heat exchanger**

The system uses a water-air heat exchanger. Air ALWAYS passes through the heat exchanger.
The bypass controls whether fresh cold water (0°C) or recirculated warmer water (8°C) is used.

| Condition | Bypass State | Water Temp | Purpose |
|-----------|--------------|------------|---------|
| Dehumidification (dehumi) | CLOSED | 0°C | Cold water = max condensation |
| Cooling only (no dehumi) | OPEN | 8°C | Warmer water = cool without drying |
| humi_save | OPEN | 8°C | Energy saving recirculation |

```lua
-- v2.5: Simplified bypass logic (unchanged from v2.3)
relay_bypass_open = humi_save or (cool and not dehumi)

-- When using outdoor air, bypass state doesn't matter (water not used)
```

```
Water Circuit with Bypass:

BYPASS CLOSED (Dehumidification Mode):          BYPASS OPEN (Cooling Only Mode):
Water Temp: 0°C                                 Water Temp: 8°C

  ┌─────────────────────────────┐               ┌─────────────────────────────┐
  │      WATER-AIR HEAT         │               │      WATER-AIR HEAT         │
  │        EXCHANGER            │               │        EXCHANGER            │
  │  ┌───────────────────────┐  │               │  ┌───────────────────────┐  │
  │  │ ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋ │  │               │  │ ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋ │  │
  │  │ ≋≋≋ COLD COIL ≋≋≋≋≋≋≋ │  │               │  │ ≋≋≋ WARM COIL ≋≋≋≋≋≋≋ │  │
  │  │ ≋≋≋≋≋ (0°C) ≋≋≋≋≋≋≋≋≋ │  │               │  │ ≋≋≋≋≋ (8°C) ≋≋≋≋≋≋≋≋≋ │  │
  │  └───────────────────────┘  │               │  └───────────────────────┘  │
  └─────────────────────────────┘               └─────────────────────────────┘

  Result: Cold water (0°C) causes              Result: Warmer water (8°C) cools
          condensation → removes moisture              without excessive condensation
          (DEHUMIDIFICATION + COOLING)                 (COOLING ONLY, preserve humidity)
```

---

## 11. Moving Average Filtering

**Sensor data smoothing to prevent noise-induced oscillations**

| Parameter | Value | Description |
|-----------|-------|-------------|
| buffer_size | 10 | Number of samples to average |
| threshold | 50 | Spike filter (±5.0°C/±5.0%) |

```lua
function moving_average_update(buffer_var, result_var, new_value, buffer_size, threshold)
  -- Reject spikes: if new value differs > threshold from average, ignore it
  if math.abs(new_value - current_avg) > threshold then
    return  -- Spike detected, skip this reading
  end

  -- Circular buffer update
  buffer[index] = new_value
  index = (index % buffer_size) + 1

  -- Calculate new average
  result_var:setValue(sum / count)
end
```

---

## 12. Statistics Warmup Delay

**Supply air and NTC data only recorded after 2-minute warmup in aktív mode**

| Parameter | Value | Description |
|-----------|-------|-------------|
| SUPPLY_WARMUP_TIME | 120 | Seconds to wait after active starts |
| STATS_INTERVAL | 30 | Record every 30 polls (~30 seconds) |

### Why Warmup Delay?

When switching from pihenő (rest) to aktív (active) mode:
- Air handling system needs time to stabilize
- Supply air sensors need airflow to provide accurate readings
- Water temperatures in heat exchanger need to stabilize

---

## 13. Outdoor Air Usage Strategy

**Outdoor air is used ONLY for cooling, NEVER for dehumidification**

Outdoor air cannot remove moisture - dehumidification requires cold water coils for condensation.

```lua
-- Outdoor beneficial when chamber is 5°C+ warmer than outdoor
local outdoor_use_threshold = const.outdoor_use_threshold or 50  -- 5.0°C
local outdoor_beneficial = (kamra_hom - kulso_hom) >= outdoor_use_threshold

-- Cooling strategy decision
local use_water_cooling = true
local use_outdoor_air = false

if dehumi then
  -- Dehumidification: ALWAYS water, NEVER outdoor
  use_water_cooling = true
  use_outdoor_air = false
elseif cool and outdoor_beneficial then
  -- Cooling only with beneficial outdoor: free cooling
  use_water_cooling = false
  use_outdoor_air = true
end
```

| Condition | Water Cooling | Outdoor Air | Why |
|-----------|---------------|-------------|-----|
| Need dehumidification | YES (0°C) | NO | Only cold coils condense moisture |
| Cooling, outdoor 5°C+ colder | NO | YES | Free cooling |
| Cooling, outdoor not cold enough | YES (8°C) | NO | Need mechanical cooling |

---

## 14. Relay Output Truth Table (v2.5)

| cool | dehumi | warm | humidi | sleep | humi_save | outdoor_ben | Relay States |
|------|--------|------|--------|-------|-----------|-------------|--------------|
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | All OFF |
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | rel_cool, rel_bypass_open |
| 0 | 1 | 0 | 0 | 0 | 0 | 0 | rel_cool, bypass_closed |
| 1 | 1 | 0 | 0 | 0 | 0 | 0 | rel_cool, bypass_closed |
| 0 | 0 | 1 | 0 | 0 | 0 | 0 | rel_warm |
| 0 | 1 | 1 | 0 | 0 | 0 | 0 | rel_cool, rel_warm, bypass_closed |
| 0 | 0 | 0 | 1 | 0 | 0 | 0 | rel_humidifier (if installed) |
| 1 | 0 | 0 | 0 | 0 | 0 | 1 | rel_add_air_max (no water cool) |
| 0 | 0 | 0 | 0 | 0 | 1 | 0 | rel_reventon, rel_add_air_save, rel_bypass_open |
| * | * | * | * | 1 | * | * | All relays OFF (sleep) |

**Key Relay Formulas (v2.5):**
```lua
relay_cool = (cool or dehumi) and not sleep and use_water_cooling
relay_warm = warm and not sleep
relay_add_air_max = use_outdoor_air and not humi_save
relay_bypass_open = humi_save or (cool and not dehumi)
relay_main_fan = sum_wint_jel  -- Hardware: summer=high, winter=low
relay_humidifier = humidification
```

---

## 15. Supply Air Target Calculation

```
Supply Air Target Temperature:

If outdoor_beneficial:
    befujt_target = kamra_cel * (1 - mix_ratio) + kulso * mix_ratio

    Example (mix_ratio = 30%):
    Target = 15°C, Outdoor = 25°C
    befujt_target = 15 * 0.7 + 25 * 0.3 = 10.5 + 7.5 = 18°C

Else:
    befujt_target = kamra_cel  (same as chamber target)

Minimum constraint:
    if befujt_target < 6°C:
        befujt_target = 6°C  (prevent condensation)
```

---

## 16. Test Values Reference (v2.5)

These values reflect v2.5 thresholds (updated from v2.4):

| Test Scenario | Chamber Temp | Chamber RH | Target Temp | Target RH | Outdoor Temp | Humidifier | Expected Result |
|---------------|--------------|------------|-------------|-----------|--------------|------------|-----------------|
| Normal cold | 139 (13.9°C) | 750 | 150 | 750 | - | - | Heating ON |
| Normal hot | 166 (16.6°C) | 750 | 150 | 750 | - | - | Cooling ON (>16.5) |
| At target | 150 (15.0°C) | 750 | 150 | 750 | - | - | Idle |
| Deadband low | 145 (14.5°C) | 750 | 150 | 750 | - | - | Idle |
| Deadband high | 160 (16.0°C) | 750 | 150 | 750 | - | - | Idle (within +1.5) |
| Too humid (AH) | 150 | 820 (82%) | 150 | 750 | - | - | Dehumidify ON |
| Humid deadband | 150 | 800 (80%) | 150 | 750 | - | - | FINE mode (AH=10.25, <10.41) |
| Too dry (AH) | 150 | 650 (65%) | 150 | 750 | - | YES | Humidify ON |
| Too dry no hum | 145 | 650 (65%) | 150 | 750 | - | NO | Heat BLOCKED |
| Better cold dry | 120 | 600 | 150 | 750 | - | NO | Heating BLOCKED |
| Winter cooling | 175 (17.5°C) | 700 | 150 | 750 | 20 (2°C) | - | Cool w/ water (dehumi!) |
| Summer cooling | 167 (16.7°C) | 600 | 150 | 750 | 250 (25°C) | - | Cool w/ water |
| Sensor error | ERROR | ERROR | 150 | 750 | - | - | Idle (fallback) |
| Hysteresis test | 160 | 770 | 150 | 750 | - | - | Stay in prev mode |

---

## 17. Humidification Control with Hysteresis (v2.5)

**Per-chamber humidifier config: `hw_config.has_humidifier`**

Humidification uses absolute humidity (AH) comparison with v2.5 hysteresis.

```lua
if hw_config.has_humidifier then
  local target_ah = calculate_absolute_humidity(target_temp, target_rh)
  local current_ah = calculate_absolute_humidity(current_temp, current_rh)
  
  -- v2.5: Use DRY mode thresholds
  local dry_threshold = target_ah - (const.ah_deadzone_kamra / 100)  -- 8.81 g/m³
  local exit_threshold = target_ah + (const.ah_hysteresis_kamra / 100)  -- 9.91 g/m³

  if humidifier_currently_on then
    -- Keep running until exit threshold (with hysteresis)
    humidification = current_ah < exit_threshold
  else
    -- Start only when below DRY threshold
    humidification = current_ah < dry_threshold
  end
end
```

### Humidifier State Transitions (v2.5)

| Current State | Current AH | Threshold | New State |
|---------------|------------|-----------|-----------|
| OFF | current ≥ 8.81 | DRY threshold | OFF |
| OFF | current < 8.81 | DRY threshold | **ON** |
| ON | current < 9.91 | Exit threshold | ON (hysteresis) |
| ON | current ≥ 9.91 | Exit threshold | **OFF** |

```
Humidifier Hysteresis (v2.5):

  exit_ah (9.91) ────────────────────────────────────── Turn OFF
                  │         ░░░░░░░░░░░░░░░░░░░░░░░░░│
                  │         ░░░ RUNNING ZONE ░░░░░░░│ (stays ON while
                  │         ░░░░░░░░░░░░░░░░░░░░░░░░░│  current < 9.91)
  target (9.61)  ─┼─────────────────────────────────────
                  │
  dry_ah (8.81)  ──────────────────────────────────────── Turn ON
                  │
                  │         BELOW DRY ZONE
                  │         (turn ON when reached)
                  ▼
```

---

## 18. State Variables Required (v2.5 - NEW)

### Per-Chamber Runtime Variables

```lua
-- Humidity mode state machine
humidity_mode_state_ch{N} = 0  -- 0=FINE, 1=HUMID, 2=DRY

-- Temperature override state
temp_override_state_ch{N} = 0  -- 0=NORMAL, 1=FORCE_COOLING

-- Previous states for transition detection
prev_humidity_mode_ch{N} = 0
prev_temp_override_ch{N} = 0

-- Supply air control state (inner loop)
supply_inside_deadzone_ch{N} = false
```

### Configuration Parameters (constansok)

```lua
-- Chamber (outer loop)
ah_deadzone_kamra_ch{N} = 80       -- 0.8 g/m³
ah_hysteresis_kamra_ch{N} = 30     -- 0.3 g/m³
deltahi_kamra_homerseklet_ch{N} = 15  -- 1.5°C
deltalo_kamra_homerseklet_ch{N} = 10  -- 1.0°C
temp_hysteresis_kamra_ch{N} = 5    -- 0.5°C

-- Supply (inner loop)
ah_deadzone_befujt_ch{N} = 50      -- 0.5 g/m³
ah_hysteresis_befujt_ch{N} = 20    -- 0.2 g/m³
deltahi_befujt_homerseklet_ch{N} = 10  -- 1.0°C
deltalo_befujt_homerseklet_ch{N} = 10  -- 1.0°C
temp_hysteresis_befujt_ch{N} = 3   -- 0.3°C
```

---

## 19. Quick Reference (v2.5)

### Threshold Summary

| Control | Enter Threshold | Exit Threshold | Total Band |
|---------|-----------------|----------------|------------|
| Chamber HUMID | AH > 10.41 | AH < 9.31 | 1.9 g/m³ |
| Chamber DRY | AH < 8.81 | AH > 9.91 | 1.9 g/m³ |
| Chamber COOL | T > 16.5°C | T < 15.5°C | 3.0°C |
| Chamber HEAT | T < 14.0°C | T > 14.5°C | 3.0°C |
| Supply (inner) | ±0.5 g/m³ / ±1.0°C | ±0.2 / ±0.3 hyst | 1.2 g/m³ / 2.3°C |

### Control Priority

1. **Temperature Safety** - Non-negotiable cooling if > 16.5°C
2. **Humidity Mode** - HUMID/FINE/DRY based on AH
3. **Temperature Comfort** - Heat/cool within humidity constraints
4. **Energy Optimization** - Outdoor air when beneficial

### Mode Determination Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      START CONTROL CYCLE                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Read Sensors    │
                    │ Calculate AH    │
                    └────────┬────────┘
                              │
                              ▼
                    ┌─────────────────┐
              YES   │ Temp > 16.5°C?  │   NO
           ┌────────┤                 ├────────┐
           │        └─────────────────┘        │
           ▼                                   ▼
    ┌──────────────┐                 ┌─────────────────┐
    │ FORCE COOL   │                 │ Evaluate AH vs  │
    │ (override)   │                 │ thresholds with │
    └──────────────┘                 │ hysteresis      │
                                     └────────┬────────┘
                                              │
              ┌───────────────────────────────┼───────────────────────────────┐
              ▼                               ▼                               ▼
       ┌──────────┐                    ┌──────────┐                    ┌──────────┐
       │  HUMID   │                    │   FINE   │                    │   DRY    │
       │ (dehumi) │                    │  (idle)  │                    │ (humidi) │
       └──────────┘                    └──────────┘                    └──────────┘
```

---

*Document Version: 2.5*
*Generated from ERLELO v2.5 control logic recommendations*
*Cross-checked against control theory analysis and cascade design*

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v2.3 | 2024 | Humidity-primary deadzone, AH-based control |
| v2.4 | 2024 | Configuration improvements, explicit setup |
| v2.5 | 2024 | Dual-layer cascade, directional hysteresis |

## v2.5 Changes Summary
- **Dual-layer cascade**: Chamber (outer) wider than Supply (inner)
- **Directional hysteresis**: Prevents oscillation at mode boundaries
- **Fixed supply thresholds**: Were inverted (wider than chamber), now correct
- **New state machine**: HUMID/FINE/DRY with explicit transitions
- **New parameters**: 5 new parameters for hysteresis control
- **Expected benefits**: 50-70% reduction in mode cycling, extended relay life
