# ERLELO Control Cycle - Hysteresis Charts

## Default Configuration Values

| Parameter | Value | Description |
|-----------|-------|-------------|
| deltahi_kamra_homerseklet | 10 | Temperature high threshold (1.0°C) |
| deltalo_kamra_homerseklet | 10 | Temperature low threshold (1.0°C) |
| deltahi_kamra_para | 15 | Humidity high threshold (1.5%) |
| deltalo_kamra_para | 10 | Humidity low threshold (1.0%) |
| deltahi_befujt_homerseklet | 20 | Supply temp high threshold (2.0°C) |
| deltalo_befujt_homerseklet | 15 | Supply temp low threshold (1.5°C) |

---

## 1. Chamber Temperature Control

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
16.1│ ════════════════════════════════════════════ ← Cooling ON (>16.0°C)
16.0│ ┌─────────────────────────────────────────┐
    │ │                                         │
15.5│ │         DEADBAND (No Action)            │  ← Maintains current state
    │ │                                         │
15.0│ │ ─ ─ ─ ─ ─ ─ TARGET ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
    │ │                                         │
14.5│ │                                         │
    │ │                                         │
14.0│ └─────────────────────────────────────────┘
13.9│ ════════════════════════════════════════════ ← Heating ON (<14.0°C)
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

### Temperature State Transitions

| Current Temp | Current State | New State | Action |
|--------------|---------------|-----------|--------|
| > 16.0°C | Any | Cooling ON | Start cooling |
| 14.0 - 16.0°C | Cooling ON | Cooling ON | Continue cooling |
| 14.0 - 16.0°C | Heating ON | Heating ON | Continue heating |
| 14.0 - 16.0°C | OFF | OFF | No action |
| < 14.0°C | Any | Heating ON | Start heating |

---

## 2. Chamber Humidity Control

**Target: 75.0% (750 raw)**

```
Humidity (%)
    ↑
90.0│                                              ← DEHUMIDIFICATION ZONE
    │
85.0│
    │
80.0│
    │
76.6│ ════════════════════════════════════════════ ← Dehumidify ON (>76.5%)
76.5│ ┌─────────────────────────────────────────┐
    │ │                                         │
76.0│ │      UPPER DEADBAND (No Action)         │
    │ │                                         │
75.0│ │ ─ ─ ─ ─ ─ ─ TARGET ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
    │ │                                         │
74.0│ └─────────────────────────────────────────┘
73.9│ ════════════════════════════════════════════ ← Dehumidify OFF (<74.0%)
    │
72.0│ ┌─────────────────────────────────────────┐
    │ │      LOWER DEADBAND (No Action)         │
70.0│ └─────────────────────────────────────────┘
69.9│ ════════════════════════════════════════════ ← Humidify ON (<70.0%)*
    │
65.0│                                              ← HUMIDIFICATION ZONE
    │                                                (*if humidifier installed)
60.0│
    └──────────────────────────────────────────────→ Time
```

### Humidity State Transitions

| Current RH | Current State | New State | Action |
|------------|---------------|-----------|--------|
| > 76.5% | Any | Dehumi ON | Start dehumidification |
| 74.0 - 76.5% | Dehumi ON | Dehumi ON | Continue dehumidifying |
| 74.0 - 76.5% | OFF | OFF | No action (deadband) |
| 70.0 - 74.0% | Humidi ON | Humidi ON | Continue humidifying* |
| 70.0 - 74.0% | OFF | OFF | No action (deadband) |
| < 70.0% | Any | Humidi ON | Start humidification* |

*Only if humidifier installed. Otherwise "Better Cold Than Dry" may block heating.

**Humidification Threshold:** Target RH - 5% = 75% - 5% = **70%**

---

## 3. Combined Control Matrix

**Example: Target T=15°C, RH=75%**

```
          │ T < 14°C  │ 14-16°C  │ T > 16°C │
──────────┼───────────┼──────────┼──────────┤
RH > 76.5%│ HEAT+DEH  │ DEHUMI   │ COOL+DEH │
──────────┼───────────┼──────────┼──────────┤
74-76.5%  │ HEAT      │ IDLE     │ COOL     │
──────────┼───────────┼──────────┼──────────┤
RH < 74%  │ HEAT+HUM* │ HUMID*   │ COOL+HUM*│
──────────┴───────────┴──────────┴──────────┘

* Humidification only if humidifier installed
  Otherwise: "Better Cold Than Dry" may block heating
```

---

## 4. Humidity Decision Logic: RH vs AH (v2.3)

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

-- All comparisons done in AH
if current_ah > target_ah * (1 + delta_hi/100) then
  dehumi = true   -- Dehumidify
elseif current_ah < target_ah * (1 - delta_lo/100) then
  humidi = true   -- Humidify (if installed)
end
```

### Decision Summary (v2.3)

| Decision | Compares | Why |
|----------|----------|-----|
| **Dehumidification** | AH vs AH | Actual moisture content, temp-independent |
| **Humidification** | AH vs AH | Actual moisture content, temp-independent |
| **"Better Cold Than Dry"** | AH vs AH | Prevents false heating when dry |

---

## 5. Hysteresis Function Behavior

```lua
-- Hysteresis function logic
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

### Visual Hysteresis Cycle

```
State
  ON ────────────────────┐         ┌──────────────────────
                         │         │
                         │         │     Deadband
                         │    ═════│═════
                         │         │
OFF ─────────────────────┴─────────┴──────────────────────

     ▲                   ▲         ▲                    ▲
     │                   │         │                    │
  Turn ON            Turn OFF   Turn ON             Turn OFF
  (>target+hi)       (<target-lo)
```

---

## 6. Working Example Values

### Scenario: Summer Day Cooling (v2.3)

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Outdoor Temp | 25.0°C | 250 |
| Chamber Temp | 22.0°C | 220 |
| Chamber RH | 74.5% | 745 |

**Control Decision:**
- Temperature: 220 > 160 → **Cooling ON**
- Humidity: 745 < 765 but > 740 → **Deadband (maintain current)**
- Outdoor beneficial: (220 - 250) = -30 < 50 → **NO** (outdoor is hotter!)
- Result: Use water cooling (outdoor air not beneficial)

**Note (v2.3):** Outdoor air is only beneficial when chamber is 5°C+ warmer than outdoor.
Formula: `(kamra_hom - kulso_hom) >= 50` (chamber minus outdoor, threshold 5.0°C)

### Scenario: Winter Day Cooling (External Air) (v2.3)

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Outdoor Temp | 2.0°C | 20 |
| Chamber Temp | 17.5°C | 175 |
| Chamber RH | 76.0% | 760 |

**Control Decision:**
- Temperature: 175 > 160 → **Cooling needed**
- Outdoor beneficial: (175 - 20) = 155 ≥ 50 → **YES** (chamber 15.5°C warmer than outdoor)
- Result: **Use cold external air for free cooling**

**Relay States:**
- `rel_add_air_max` = ON (use outdoor air)
- `rel_cool` = OFF (water cooling not needed)
- `use_outdoor_air` = true (new v2.3 signal)
- Energy saved by using cold winter air instead of compressor

```
Winter Cooling Flow:

  ┌─────────┐     Cold Air     ┌─────────────┐
  │ Outside │ ═══════════════> │   Chamber   │
  │  2°C    │    (2°C fresh)   │   17.5°C    │
  └─────────┘                  └─────────────┘
                                     │
                                     ▼
                               Target: 15°C

  Energy: FREE (no compressor)
```

### Scenario: Cold Night Heating

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Outdoor Temp | 5.0°C | 50 |
| Chamber Temp | 13.8°C | 138 |
| Chamber RH | 72.0% | 720 |

**Control Decision:**
- Temperature: 138 < 140 → **Heating needed**
- Humidity: 720 < 740 → **Too dry**
- No humidifier + dry → Check "Better Cold Than Dry":
  - Target AH at 15°C/75% ≈ 9.6 g/m³
  - Current AH at 13.8°C/72% ≈ 8.6 g/m³
  - Current AH < Target AH AND Temp > 11°C
  - → **Heating BLOCKED** (prevent further drying)

### Scenario: Normal Operation

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Chamber Temp | 15.2°C | 152 |
| Chamber RH | 75.3% | 753 |

**Control Decision:**
- Temperature: 140 ≤ 152 ≤ 160 → **Deadband**
- Humidity: 740 ≤ 753 ≤ 765 → **Deadband**
- Result: **IDLE** - No action needed

### Scenario: Too Dry (Humidification Needed)

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Chamber Temp | 15.0°C | 150 |
| Chamber RH | 68.0% | 680 |
| Humidifier | Installed | - |

**Control Decision:**
- Temperature: 150 = target → **Deadband**
- Humidity: 680 < 740 → **Too dry, below deadband**
- Humidifier installed: **YES**
- Result: **Start humidification**

**Relay States:**
- `rel_humidifier` = ON (add moisture)
- Temperature relays unchanged

```
Humidity Control Flow (Too Dry):

     Target: 75%
         │
  76.5% ─┼─────── Dehumidify ON threshold
         │  ░░░░░ DEADBAND
  74.0% ─┼─────── Humidify ON threshold
         │
  68.0% ─┼─────── Current (TOO DRY) ← Humidifier ON
         │
         ▼
```

### Scenario: Too Dry Without Humidifier

| Parameter | Value | Raw |
|-----------|-------|-----|
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |
| Chamber Temp | 14.5°C | 145 |
| Chamber RH | 65.0% | 650 |
| Humidifier | NOT installed | - |

**Control Decision:**
- Temperature: 145 in deadband, but needs heating to reach target
- Humidity: 650 < 740 → **Too dry**
- Humidifier installed: **NO**
- "Better Cold Than Dry" check:
  - Current AH at 14.5°C/65% ≈ 8.0 g/m³
  - Target AH at 15°C/75% ≈ 9.6 g/m³
  - Current AH < Target AH → **Heating would make it drier**
- Result: **Heating BLOCKED** (wait for natural humidity recovery)

```
"Better Cold Than Dry" Logic:

  Without humidifier, heating dry air makes it even drier!

  Before heating:  14.5°C, 65% RH → AH = 8.0 g/m³
  After heating:   15.0°C, ~62% RH → AH = 8.0 g/m³ (same moisture, lower RH%)

  Solution: Block heating until AH rises naturally
```

### Scenario: Sensor Error State Fallback

| Parameter | Value | Raw |
|-----------|-------|-----|
| Chamber Sensor | ERROR | hibaszam ≤ 0 |
| Target Temp | 15.0°C | 150 |
| Target RH | 75.0% | 750 |

**Control Decision:**
- Sensor error detected: `kamra_hibaszam ≤ 0`
- Fallback: **Use target values as measured values**
- Result: System assumes target is reached → **IDLE (safe operation)**

```
Error State Fallback Logic:

  if kamra_hibaflag then
    kamra_hom = kamra_cel_hom    -- Use target temp
    kamra_para = kamra_cel_para  -- Use target humidity
  end

  Purpose: Prevent wild control oscillations during sensor failure
           System enters safe "holding" state
```

---

## 7. Supply Air Temperature Control (v2.3 Humidity-Primary Deadzone)

**Humidity-primary control: deadzone uses ABSOLUTE HUMIDITY (AH) error**

"Better cold than dry" philosophy:
- Too dry → irreversible product damage (surface cracking, case hardening)
- Too humid → mold risk, critical to address
- Too cold → just slows process, recoverable
- Product equilibrium depends on AH, not temperature

| Parameter | Default | Description |
|-----------|---------|-------------|
| ah_deadzone | 50 | AH deadzone as % of target (5.0%) |
| proportional_gain | 10 | P gain × 10 (10 = 1.0) |
| outdoor_mix_ratio | 30 | Outdoor mixing ratio (30%) |
| min_supply_air_temp | 60 | Minimum supply temp (6°C) |
| max_supply_air_temp | 400 | Maximum supply temp (40°C) |

### Mode 1: OUTSIDE AH DEADZONE (Aggressive Control)

When AH error > deadzone: Aggressive correction to fix humidity first.

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

When AH within deadzone: Fine-tune temperature with outdoor mixing.

```
Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) × (1 - mix)
                       - (Külső_mért - Kamra_cél) × mix

Where mix = outdoor_mix_ratio (default 30%)

Example:
  Target: 15°C, Chamber: 15.5°C, Outdoor: 20°C (AH is OK)
  Befujt_cél = 15 - 0.5 × 0.7 - 5 × 0.3 = 13.15°C
  → Gentle temperature adjustment (humidity already acceptable)
```

### Deadzone Detection (Humidity-Primary)

```lua
-- v2.3: AH determines deadzone state
local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)

-- AH deadzone as percentage of target (default 5%)
local ah_deadzone_percent = (const.ah_deadzone or 50) / 10  -- 5.0%
local ah_deadzone = target_ah * (ah_deadzone_percent / 100)

local ah_error = math.abs(current_ah - target_ah)
local inside_ah_deadzone = ah_error <= ah_deadzone
```

**Why Humidity-Primary?**
- Product quality depends on AH, not just temperature
- Dehumidification is time-critical (mold prevention)
- Drying too fast causes irreversible damage
- Temperature is easier to recover from

```
Deadzone Visualization (AH-Based):

  Example: Target 15°C/75%RH → target_ah = 9.61 g/m³
  Deadzone = 5% of target = 0.48 g/m³

          │ Outside Deadzone │ Inside Deadzone │ Outside Deadzone │
          │  (Aggressive)    │   (Fine)        │  (Aggressive)    │
          │                  │                 │                  │
   ───────┼──────────────────┼─────────────────┼──────────────────┼───────→ AH (g/m³)
        9.13               9.61             10.09             10.57
                            ↑                 ↑
                       Target AH          +5% threshold

  NOTE: Temperature error is NOT considered for deadzone detection
        Temperature limits are still enforced as safety limits
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

## 9. Sum_wint Signal (Summer/Winter Mode) (v2.3)

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

**Control Logic:**

```lua
-- Main fan speed selection (hardware wiring)
relay_main_fan = sum_wint_jel  -- ON=winter speed, OFF=summer speed

-- NOTE: Control decisions (cooling, heating, dehumidify) are IDENTICAL
-- regardless of summer/winter signal
```

```
Summer vs Winter Operation (Same Logic, Different Fan Speed):

SUMMER (sum_wint = OFF):                  WINTER (sum_wint = ON):
  Fan: HIGH speed wiring                    Fan: LOW speed wiring
  ┌────────┐                               ┌────────┐
  │ Outside│    Same control               │ Outside│    Same control
  │  25°C  │    decisions!                 │  -5°C  │    decisions!
  └────────┘                               └────────┘
       │                                        │
       ▼ Fan moves lighter air faster          ▼ Fan moves denser air slower
  ═════════════                           ═════════════
   Same mass                                Same mass
   flow rate                                flow rate
```

---

## 10. Bypass Control Logic (Water Circuit) (v2.3)

**Bypass valve controls water temperature in the heat exchanger**

The system uses a water-air heat exchanger. Air ALWAYS passes through the heat exchanger.
The bypass controls whether fresh cold water (0°C) or recirculated warmer water (8°C) is used.

| Condition | Bypass State | Water Temp | Purpose |
|-----------|--------------|------------|---------|
| Dehumidification (dehumi) | CLOSED | 0°C | Cold water = max condensation |
| Cooling only (no dehumi) | OPEN | 8°C | Warmer water = cool without drying |
| humi_save | OPEN | 8°C | Energy saving recirculation |

```lua
-- v2.3: Simplified bypass logic
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
  │           │  │              │               │           │  │              │
  └───────────│──│──────────────┘               └───────────│──│──────────────┘
              │  │                                          │  │
         IN ──┘  └── OUT                               IN ──┘  └── OUT
              │  │                                          │  │
              │  │     ┌────────┐                           │  └──────┐
              │  └────→│ BYPASS │← CLOSED                   │         │
              │        │ VALVE  │                           │    ┌────┴────┐
              │        └────────┘                           │    │ BYPASS  │← OPEN
              │             │                               │    │ VALVE   │
              ▼             ▼                               │    └────┬────┘
         ┌─────────┐   (blocked)                           │         │
         │ CHILLER │                                       └─────────┘
         │  (0°C)  │                                       (recirculate)
         └─────────┘

  Result: Cold water (0°C) causes              Result: Warmer water (8°C) cools
          condensation → removes moisture              without excessive condensation
          (DEHUMIDIFICATION + COOLING)                 (COOLING ONLY, preserve humidity)
```

**Why 0°C vs 8°C matters:**

| Water Temp | Coil Surface | Air Effect | Use Case |
|------------|--------------|------------|----------|
| 0°C | Below dew point | Air cools + condenses moisture | Dehumidification needed |
| 8°C | Above dew point | Air cools, minimal condensation | Cooling only, keep humidity |

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

```
Moving Average Example (Temperature):

Raw sensor:  15.2, 15.3, 15.1, 25.0*, 15.2, 15.4, 15.3, 15.2
                              ↑ spike rejected (>threshold)

Filtered:    15.2, 15.25, 15.2, 15.2, 15.2, 15.25, 15.27, 15.26

Result: Smooth control signal, no false triggers from sensor noise
```

---

## 12. Statistics Warmup Delay (v2.2)

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

### Statistics Recording Logic

```lua
-- Track active phase transitions
if last_active_state ~= is_aktiv then
  if is_aktiv then
    active_start_time = os.time()  -- Start warmup timer
  else
    active_start_time = nil        -- Clear timer on rest
  end
end

-- Check if warmup complete (2 min after active starts)
local supply_data_ready = is_aktiv and active_start_time and
                          (os.time() - active_start_time) >= SUPPLY_WARMUP_TIME
```

### Statistics Series (v2.2)

| Series | When Recorded | Description |
|--------|---------------|-------------|
| mode_ch{N} | Always | 1=aktív, 0=pihenő |
| chamber_temp_ch{N} | Always | Chamber temperature |
| chamber_humidity_ch{N} | Always | Chamber humidity |
| target_temp_ch{N} | Always | Target temperature |
| target_humidity_ch{N} | Always | Target humidity |
| supply_temp_ch{N} | After warmup | Supply air temperature |
| supply_humidity_ch{N} | After warmup | Supply air humidity |
| supply_dewpoint_ch{N} | After warmup | Supply dew point |
| ntc1_ch{N} | After warmup | NTC water temp 1 |
| ntc2_ch{N} | After warmup | NTC water temp 2 |
| ntc3_ch{N} | After warmup | NTC water temp 3 |
| ntc4_ch{N} | After warmup | NTC water temp 4 |

```
Timeline: Rest → Active Transition

  ──────┬────────────────┬─────────────────────────────────→ Time
        │                │
  REST  │  WARMUP (2min) │  ACTIVE (normal operation)
        │                │
        │ Supply/NTC     │ Supply/NTC data
        │ data SKIPPED   │ now recorded
        │                │
        ↑                ↑
  Active starts    Warmup complete
```

---

## 13. Outdoor Air Usage Strategy (v2.3)

**Outdoor air is used ONLY for cooling, NEVER for dehumidification**

Outdoor air cannot remove moisture - dehumidification requires cold water coils for condensation.

```lua
-- v2.3: Outdoor beneficial when chamber is 5°C+ warmer than outdoor
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

## 14. Relay Output Truth Table (v2.3)

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

**Key Relay Formulas (v2.3):**
```lua
relay_cool = (cool or dehumi) and not sleep and use_water_cooling
relay_warm = warm and not sleep
relay_add_air_max = use_outdoor_air and not humi_save
relay_bypass_open = humi_save or (cool and not dehumi)
relay_main_fan = sum_wint_jel  -- Hardware: summer=high, winter=low
relay_humidifier = humidification
```

---

## 14. Supply Air Target Calculation

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

## 15. Test Values Reference

These values are verified by the test suite (2065 tests, 100% pass):

| Test Scenario | Chamber Temp | Chamber RH | Target Temp | Target RH | Outdoor Temp | Humidifier | Expected Result |
|---------------|--------------|------------|-------------|-----------|--------------|------------|-----------------|
| Normal cold | 139 (13.9°C) | 750 | 150 | 750 | - | - | Heating ON |
| Normal hot | 161 (16.1°C) | 750 | 150 | 750 | - | - | Cooling ON |
| At target | 150 (15.0°C) | 750 | 150 | 750 | - | - | Idle |
| Deadband low | 145 (14.5°C) | 750 | 150 | 750 | - | - | Idle |
| Deadband high | 155 (15.5°C) | 750 | 150 | 750 | - | - | Idle |
| Too humid | 150 | 800 (80%) | 150 | 750 | - | - | Dehumidify ON |
| Humid deadband | 150 | 760 (76%) | 150 | 750 | - | - | Idle |
| Too dry | 150 | 680 (68%) | 150 | 750 | - | YES | Humidify ON |
| Too dry no hum | 145 | 650 (65%) | 150 | 750 | - | NO | Heat BLOCKED |
| Better cold dry | 120 | 600 | 150 | 750 | - | NO | Heating BLOCKED |
| Winter cooling | 175 (17.5°C) | 760 | 150 | 750 | 20 (2°C) | - | Cool w/ ext air |
| Summer cooling | 162 (16.2°C) | 745 | 150 | 750 | 250 (25°C) | - | Cool w/ ext air |
| Sensor error | ERROR | ERROR | 150 | 750 | - | - | Idle (fallback) |
| Humi_save mode | 150 | 750 | 150 | 750 | - | - | Recirculate |
| Sum_wint ON | 150 | 750 | 150 | 750 | -50 (-5°C) | - | Main fan ON |
| Outside deadzone | 180 (18°C) | 750 | 150 | 750 | 200 (20°C) | - | Aggressive supply=12°C |
| Inside deadzone | 151 (15.1°C) | 755 | 150 | 750 | 200 (20°C) | - | Fine control supply |

---

## 16. Humidification Control with Hysteresis (v2.3)

**Per-chamber humidifier config: `hw_config.has_humidifier`**

Humidification uses absolute humidity (AH) comparison with proper hysteresis.

```lua
if hw_config.has_humidifier then
  local target_ah = calculate_absolute_humidity(target_temp, target_rh)
  local current_ah = calculate_absolute_humidity(current_temp, current_rh)

  -- Start threshold: target RH - 5% (configurable via humidifier_start_delta)
  local start_delta_rh = const.humidifier_start_delta or 50  -- 5.0% RH
  local start_rh = (kamra_cel_para - start_delta_rh) / 10
  local start_ah = calculate_absolute_humidity(target_temp, start_rh)

  if humidifier_currently_on then
    -- Keep running until target AH reached
    humidification = current_ah < target_ah
  else
    -- Start only when significantly below target (5% RH threshold)
    humidification = current_ah < start_ah
  end
end
```

### Humidifier State Transitions

| Current State | Current AH | Target AH | Start AH | New State |
|---------------|------------|-----------|----------|-----------|
| OFF | current ≥ start | - | - | OFF |
| OFF | current < start | - | - | **ON** |
| ON | current < target | - | - | ON |
| ON | current ≥ target | - | - | **OFF** |

```
Humidifier Hysteresis:

  target_ah ──────────────────────────────────────── Turn OFF
             │         ░░░░░░░░░░░░░░░░░░░░░░░░░│
             │         ░░░ RUNNING ZONE ░░░░░░░│ (stays ON while
             │         ░░░░░░░░░░░░░░░░░░░░░░░░░│  current < target)
  start_ah  ──────────────────────────────────────── Turn ON
             │
             │         BELOW START ZONE
             │         (turn ON when reached)
             ▼
```

---

*Document Version: 2.3*
*Generated from ERLELO v4 control logic*
*Cross-checked against Erlelo_System_Documentation_v2.2.docx and SYSTEM_ARCHITECTURE.md*
