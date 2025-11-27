# Erlelo System Architecture

## Version 2.2 - With Statistics & UI Refresh

Multi-Chamber Climate Control System for Sinum Home Automation Platform

---

## 1. System Overview

### 1.1 Purpose

The Erlelo system (Hungarian: "érlelő" - curing/aging chamber) is an automated climate control system designed for agricultural drying and curing applications. The system manages temperature and humidity within enclosed chambers to achieve optimal conditions for product curing.

### 1.2 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SINUM PLATFORM                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  INSTALLATION (run once):                                               │
│  ┌──────────────┐     ┌──────────────┐                                  │
│  │erlelo_create │────►│erlelo_store  │  Creates variables from GitHub   │
│  │ NUM_CHAMBERS │     │ MAPPING_ID   │  Builds name→ID mapping          │
│  └──────────────┘     └──────────────┘                                  │
│                              │                                           │
│                              ▼                                           │
│  RUNTIME:                                                               │
│  ┌──────────────┐     ┌─────────────────────────────────────┐           │
│  │erlelo_kulso  │────►│ Global Variables (*_glbl)           │           │
│  │ (T+100ms)    │     │ kulso_homerseklet, kulso_para, etc. │           │
│  │ Stats + UI   │     └─────────────────────────────────────┘           │
│  └──────────────┘                  │                                     │
│         │                          │                                     │
│         │    ┌─────────────────────┼──────────────────────────┐         │
│         │    ▼                     ▼                          ▼         │
│         │ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│         │ │erlelo_kamra1 │  │erlelo_kamra2 │  │erlelo_kamra3 │         │
│         │ │ (T+500ms)    │  │ (T+1000ms)   │  │ (T+1500ms)   │         │
│         │ │ CHAMBER_ID=1 │  │ CHAMBER_ID=2 │  │ CHAMBER_ID=3 │         │
│         │ │ Stats + UI   │  │ Stats + UI   │  │ Stats + UI   │         │
│         │ └──────────────┘  └──────────────┘  └──────────────┘         │
│         │        │                 │                 │                   │
│         │        ▼                 ▼                 ▼                   │
│         │ ┌─────────────────────────────────────────────────────────┐   │
│         │ │                    SBUS RELAYS (per chamber)            │   │
│         │ │ rel_warm, rel_cool, rel_add_air_max, rel_reventon,     │   │
│         │ │ rel_add_air_save, rel_bypass_open, rel_main_fan,       │   │
│         │ │ rel_humidifier, rel_sleep                               │   │
│         │ └─────────────────────────────────────────────────────────┘   │
│         │                                                                │
│         ▼                                                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    STATISTICS DATABASE                            │   │
│  │  • Periodic: temp, humidity, dew point (every 30s)               │   │
│  │  • Events: heating, cooling, dehumidify state changes            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    TOUCHSCREEN UI                                 │   │
│  │  • Displays: temp, humidity, dew point, status indicators        │   │
│  │  • Inputs: target sliders, mode toggles                          │   │
│  │  • Refresh: every 30 seconds                                      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Communication

All sensors communicate via Modbus RTU protocol on a shared RS-485 bus with asynchronous reads.

| Sensor Type | Chamber 1 | Chamber 2 | Chamber 3 |
|-------------|-----------|-----------|-----------|
| Supply Air | modbus_client[1] | modbus_client[3] | modbus_client[5] |
| Chamber | modbus_client[2] | modbus_client[4] | modbus_client[6] |
| Outdoor | modbus_client[7] (shared) | | |

---

## 2. Variable Mapping System

### 2.1 Dynamic Variable Mapping (V Function)

Variables are accessed via the `V()` function which resolves names to indices using a JSON map stored in `variable_name_map_glbl`.

**In Chamber Controllers (erlelo_kamraN.lua):**
```lua
-- Tries _chN suffix first, then _glbl for global variables
local function V(name)
  local map = loadVarMap()
  local var_name = name .. "_ch" .. CHAMBER_ID  -- Try chamber-specific first
  local idx = map[var_name]
  if not idx then
    var_name = name .. "_glbl"                   -- Fallback to global
    idx = map[var_name]
  end
  return variable[idx]
end

-- Usage
V('kamra_homerseklet'):getValue()   -- Gets kamra_homerseklet_ch1
V('kulso_para'):getValue()          -- Gets kulso_para_glbl
```

**In Outdoor Controller (erlelo_kulso.lua):**
```lua
-- All variables are global, always uses _glbl suffix
local function V(name)
  local map = loadVarMap()
  local var_name = name .. "_glbl"
  return variable[map[var_name]]
end
```

### 2.2 Variable Naming Convention

**Chamber-Specific Variables (suffix `_ch1`, `_ch2`, `_ch3`):**

| Variable Name | Ch1 | Ch2 | Ch3 |
|---------------|-----|-----|-----|
| kamra_homerseklet_chN | Chamber temp ×10 |
| kamra_para_chN | Chamber humidity ×10 |
| kamra_cel_homerseklet_chN | Target temp ×10 |
| kamra_cel_para_chN | Target humidity ×10 |
| befujt_cel_homerseklet_chN | Supply target temp |
| befujt_cel_para_chN | Supply target humidity |
| befujt_homerseklet_akt_chN | Current supply temp |
| befujt_para_akt_chN | Current supply humidity |
| constansok_chN | Control constants (JSON) |
| signals_chN | Control signals (JSON) |
| cycle_variable_chN | Sleep cycle state (JSON) |
| ah_dp_table_chN | Psychrometric data (JSON) |
| ntc1..4_homerseklet_chN | NTC sensors ×10 |

**Global Variables (suffix `_glbl`):**

| Variable | Description |
|----------|-------------|
| kulso_homerseklet_glbl | Outdoor temperature ×10 |
| kulso_para_glbl | Outdoor humidity ×10 |
| kulso_homerseklet_table_glbl | Moving average buffer (JSON) |
| kulso_para_table_glbl | Moving average buffer (JSON) |
| kulso_hibaszam_glbl | Error counter |
| kulso_szimulalt_glbl | Simulation flag |
| kulso_ah_dp_glbl | Psychrometric data (JSON) |
| variable_name_map_glbl | Name→ID mapping (JSON, built by erlelo_store) |

**Note:** Variable indices are assigned dynamically by the Sinum API during creation. The `variable_name_map_glbl` variable stores the mapping from names to actual indices.

---

## 3. Code Section Order (CRITICAL)

The following order is **required** to avoid forward reference errors in Lua.
See Section 15 for the complete updated order including Statistics and UI Refresh.

**Key requirement:** SENSOR DATA PROCESSING must come before MODBUS HANDLING because the Modbus response handlers call `process_*_data()` functions.

---

## 4. Modbus Communication

### 4.1 Single Register Read Pattern

Read both temperature and humidity in a single async call:

```lua
-- Poll: read 2 consecutive registers starting at reg_temperature
mb_client:readInputRegistersAsync(mb_config.reg_temperature, 2)

-- Response handler
local function handle_modbus_response(kind, addr, values)
  if kind ~= "INPUT_REGISTERS" then return end
  
  if addr == mb_config.reg_temperature and values[1] and values[2] then
    process_sensor_data(values[1], values[2])  -- temp, humi
  end
end
```

### 4.2 Always Poll (Regardless of Simulation)

Modbus polling continues even when simulation is enabled. This ensures:
- Moving average buffers stay current
- Psychrometric values are calculated
- Real values are immediately ready when simulation is disabled

```lua
local function poll_sensors()
  -- Always poll - averaging must continue even in simulation mode
  if mb_supply then
    mb_supply:readInputRegistersAsync(mb_cfg.reg_temperature, 2)
  end
  if mb_chamber then
    mb_chamber:readInputRegistersAsync(mb_cfg.reg_temperature, 2)
  end
end
```

### 4.3 Staggered Polling

| Device | Offset | Purpose |
|--------|--------|---------|
| erlelo_kulso | T+100ms | Outdoor data first |
| erlelo_kamra1 | T+1500ms | Chamber 1 |
| erlelo_kamra2 | T+3000ms | Chamber 2 |
| erlelo_kamra3 | T+4500ms | Chamber 3 |

---

## 5. Event Handling

### 5.1 Correct Event Type for SBUS

```lua
-- CORRECT pattern for SBUS events
if event.type == "device_state_changed" and event.source.type == "sbus" then
  -- Handle SBUS input change
end

-- WRONG (will never match)
if event.type == "sbus_state_changed" then  -- This event type doesn't exist!
```

### 5.2 Event Types Reference

| Event Type | Source | Trigger |
|------------|--------|---------|
| lua_timer_elapsed | timer | Timer fires |
| lua_variable_state_changed | variable | Variable changed with stop_propagation=false |
| device_state_changed | sbus/modbus | Device state change |

---

## 6. Propagation Rules

### 6.1 Meaningful Change Thresholds

| Value Type | Threshold | Actual Change |
|------------|-----------|---------------|
| Temperature | 2 units | 0.2°C |
| Humidity | 3 units | 0.3% |

### 6.2 Supply Target Threshold Propagation

Supply air targets only propagate when changed beyond threshold:

```lua
if befujt_cel_temp_var then
  local old_temp = befujt_cel_temp_var:getValue() or 0
  if math.abs(new_befujt_temp - old_temp) >= control.temp_threshold then
    befujt_cel_temp_var:setValue(new_befujt_temp, false)  -- Propagate
  else
    befujt_cel_temp_var:setValue(new_befujt_temp, true)   -- No propagation
  end
end
```

### 6.3 When to Propagate

| Situation | Propagate? | stop_propagation |
|-----------|------------|------------------|
| Sensor changed by threshold | YES | false |
| User changed setpoint | YES | false |
| Control signals changed | YES | false |
| Moving avg buffer filling | NO | true |
| UI display update | NO | true |
| Error counter update | NO | true |

---

## 7. Error Handling

### 7.1 Error Counter Behavior

Each sensor has an error counter starting at `max_error_count` (default: 3).

```lua
-- On successful read: reset counter
hibaszam_var:setValue(control.max_error_count, true)

-- On error (TIMEOUT or BAD_CRC): decrement
if err == "TIMEOUT" or err == "BAD_CRC" then
  local count = hibaszam_var:getValue() or control.max_error_count
  if count > 0 then
    hibaszam_var:setValue(count - 1, true)
  end
end
```

### 7.2 Error State Fallback

When error counter reaches 0, fallback behavior activates:

```lua
-- Check error states
local kamra_hibaflag = kamra_hibaszam_var and (kamra_hibaszam_var:getValue() or 0) <= 0
local befujt_hibaflag = befujt_hibaszam_var and (befujt_hibaszam_var:getValue() or 0) <= 0

-- Skip psychrometric calculations in error state
if not kamra_hibaflag then
  calculate_supply_targets()
end

-- Fallback: use target as measured value (safe operation)
if kamra_hibaflag then
  kamra_hom = kamra_cel_hom
  kamra_para = kamra_cel_para
end
if befujt_hibaflag then
  befujt_hom = befujt_cel_hom
  befujt_para = befujt_cel_para
end
```

---

## 7.5 Water-Air Heat Exchanger System

The chamber climate is controlled via a **water-air heat exchanger**. Air always passes through this heat exchanger - there is no air bypass.

### Operating Modes

| Mode | Bypass Relay | Water Temp | Purpose |
|------|--------------|------------|---------|
| **Dehumidification** | OFF | 0°C | Maximum moisture removal (cold coil condenses water from air) |
| **Cooling Only** | ON | 8°C | Temperature reduction without aggressive dehumidification |

### Bypass Valve Function

The "bypass" refers to **water recirculation**, not air flow:

- **Bypass OFF (normal)**: Fresh chilled water at 0°C flows through the heat exchanger for maximum dehumidification
- **Bypass ON**: Used water is recirculated, raising the coil temperature to ~8°C, which provides cooling while reducing condensation

This allows the system to:
1. Cool aggressively when humidity removal is needed (bypass OFF, 0°C water)
2. Cool gently when only temperature reduction is needed (bypass ON, 8°C water)

```lua
-- Control logic
if kamra_para_hutes then
  -- Dehumidification mode: bypass OFF, use 0°C water
  bypass_open = false
  cooling = true
elseif kamra_hutes then
  -- Cooling only mode: bypass ON, use 8°C recirculated water
  bypass_open = true
  cooling = true
end
```

---

## 8. Control Logic

### 8.1 Absolute Humidity-Based Dehumidification

**User Interface:** Temperature + Relative Humidity % (intuitive, familiar)
**Internal Logic:** Absolute Humidity comparison (physically correct)

The user configures targets and hysteresis in RH%, but the control logic converts to AH internally. This correctly handles temperature differences between current and target states.

**Why RH comparison fails:**

| State | Temp | RH | AH |
|-------|------|----|----|
| Current chamber | 20°C | 68% | 11.7 g/m³ |
| Target | 18°C | 70% | 10.8 g/m³ |

- **RH comparison:** 68% < 70% → no dehumidification (WRONG!)
- **AH comparison:** 11.7 > 10.8 g/m³ → dehumidification needed (CORRECT!)

When cooled to 18°C, the 11.7 g/m³ becomes ~77% RH, exceeding the 70% target.

**Implementation:**

```lua
-- Calculate absolute humidity values
local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)

-- Convert user's RH% hysteresis to AH at TARGET temperature
local deltahi_rh = const.deltahi_kamra_para or 15  -- User sets: +1.5% RH
local deltalo_rh = const.deltalo_kamra_para or 10  -- User sets: -1.0% RH

-- Calculate AH at threshold RH values (at target temperature)
local ah_at_hi = calculate_absolute_humidity(kamra_cel_hom/10, (kamra_cel_para + deltahi_rh)/10)
local ah_at_lo = calculate_absolute_humidity(kamra_cel_hom/10, (kamra_cel_para - deltalo_rh)/10)

-- Derive AH thresholds
local delta_ah_hi = ah_at_hi - target_ah
local delta_ah_lo = target_ah - ah_at_lo

-- Compare using AH
local kamra_para_hutes = hysteresis(current_ah, target_ah, delta_ah_hi, delta_ah_lo, ...)
```

| User Config | Example | Internal Conversion |
|-------------|---------|---------------------|
| Target temp | 18°C | Used for AH calculation |
| Target RH | 70% | → target_ah = 10.8 g/m³ |
| deltahi_kamra_para | 15 (+1.5%) | → delta_ah_hi = 0.19 g/m³ |
| deltalo_kamra_para | 10 (-1.0%) | → delta_ah_lo = 0.13 g/m³ |

### 8.2 "Better Cold Than Dry" Heating Block

When no humidifier is installed, heating is blocked if it would cause over-drying:

```lua
local heating_blocked = false
if not hw_config.has_humidifier and warm then
  local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
  local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
  local min_temp = const.min_temp_no_humidifier or 110  -- 11.0°C
  
  -- Block heating if too dry AND above minimum temp
  if current_ah < target_ah and kamra_hom > min_temp then
    heating_blocked = true
    warm = false
  end
end
```

### 8.3 Humidity-Primary Deadzone Control

The system uses **humidity-primary** deadzone control based on the "better cold than dry" principle.

> ⚠️ **NON-NEGOTIABLE TEMPERATURE LIMIT**
> 
> Regardless of humidity mode, if **chamber temp > target + hysteresis**, cooling **MUST** activate.
> This is a hard safety limit - the chamber cannot be warmer than target + hysteresis.
> Cooling will use water or outdoor air, whichever is beneficial.
> 
> **Humidity-primary mode only affects:**
> - Supply air target calculation (aggressive vs fine)
> - NOT the hard temperature safety limits

**Why humidity-primary:**
- Too dry → **irreversible** product damage (surface cracking, case hardening)
- Too humid → mold risk, critical to address quickly
- Too cold → just slows the process, fully **recoverable**
- Product equilibrium depends on **absolute humidity (AH)**, not temperature

**Control Hierarchy:**
1. **Hard temperature limits** (non-negotiable): Cooling/heating based on temp ± hysteresis
2. **Humidity-primary mode**: Determines supply air target calculation aggressiveness

| AH Error | Control Mode | Priority | Supply Target Calculation |
|----------|--------------|----------|---------------------------|
| Outside deadzone (>5% of target AH) | Aggressive | Fix humidity first | `Befujt_cél = 2 × Kamra_cél - Kamra_mért` |
| Inside deadzone (≤5% of target AH) | Fine | Fine-tune temperature | `Befujt_cél = Kamra_cél - error×(1-mix) - outdoor_offset×mix` |

```lua
-- NON-NEGOTIABLE: Temperature limits are always enforced
local cool = kamra_hutes or befujt_hutes  -- Based on temperature hysteresis
local warm = kamra_futes or befujt_futes  -- Based on temperature hysteresis

-- Humidity-primary mode only affects supply air target calculation
local ah_error = math.abs(current_ah - target_ah)
local inside_ah_deadzone = ah_error <= ah_deadzone

if inside_ah_deadzone then
  -- AH in range → Fine-tune temperature (gentler supply target)
  befujt_target_temp = kamra_cel_hom - chamber_error * (1 - mix_ratio) 
                                     - outdoor_offset * mix_ratio
else
  -- AH out of range → Aggressive correction (stronger supply target)
  befujt_target_temp = kamra_cel_hom - chamber_error * (P / 10)
end
```

**Example at Target 15°C / 75% RH (target AH = 9.61 g/m³):**

| Chamber | RH | Current AH | AH Error | Mode | Cooling? | Action |
|---------|-----|------------|----------|------|----------|--------|
| 12°C | 65% | 7.37 g/m³ | 23% | AGGRESSIVE | NO | Humidify urgently! |
| 15°C | 72% | 9.22 g/m³ | 4% | FINE | NO | AH OK, at target temp |
| 17°C | 60% | 9.77 g/m³ | 2% | FINE | **YES** | AH OK, but temp > 16°C → MUST COOL |
| 22°C | 50% | 9.70 g/m³ | 1% | FINE | **YES** | AH OK, but temp > 16°C → MUST COOL |

### 8.4 Cooling Strategy

**Key principle:** Dehumidification and heating can operate simultaneously.

| Need | dehumi | cool | warm | Water HX | Heater | Result |
|------|--------|------|------|----------|--------|--------|
| Cool only | ✗ | ✓ | ✗ | ON (8°C) | OFF | Cold air |
| Dehumidify | ✓ | ✗ | ✗ | ON (0°C) | OFF | Cold dry air |
| Dehumidify + Heat | ✓ | ✗ | ✓ | ON (0°C) | ON | Warm dry air |
| Heat only | ✗ | ✗ | ✓ | OFF | ON | Warm air |

```lua
-- Water cooling needed for cooling OR dehumidification
relay_cool = (cool or dehumi) and not sleep and use_water_cooling
relay_warm = warm and not sleep

-- Bypass: OFF=0°C (dehumidify), ON=8°C (cooling only)
relay_bypass_open = humi_save or (cool and not dehumi)
```

**Dehumidify + Heat scenario:**
1. Water at 0°C condenses moisture (air becomes cold and dry)
2. Heater warms the cold dry air back up
3. Chamber receives warm, dry air ✓

### 8.5 Outdoor Air Usage

Outdoor air is used **only for cooling**, never for dehumidification (outdoor air cannot remove moisture).

```lua
-- Outdoor beneficial when chamber is 5°C+ warmer than outside
local outdoor_use_threshold = const.outdoor_use_threshold or 50  -- 5.0°C
local outdoor_beneficial = (kamra_hom - kulso_hom) >= outdoor_use_threshold

-- Strategy decision
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

| Condition | Action |
|-----------|--------|
| Need dehumidification | Water at 0°C, no outdoor air |
| Need cooling, outdoor 5°C+ colder | Use outdoor air (free cooling) |
| Need cooling, outdoor not cold enough | Water at 8°C |

### 8.6 Humidifier Control (Independent)

Humidifier control is **completely independent** from main control cycle. Configured per-chamber via `hw_config.has_humidifier`.

```lua
if hw_config.has_humidifier then
  local target_ah = calculate_absolute_humidity(target_temp, target_rh)
  local current_ah = calculate_absolute_humidity(current_temp, current_rh)
  
  -- Start threshold: target RH - 5%
  local start_ah = calculate_absolute_humidity(target_temp, target_rh - 5)
  
  if humidifier_currently_on then
    -- Keep running until target reached
    humidification = current_ah < target_ah
  else
    -- Start only when 5% below target
    humidification = current_ah < start_ah
  end
end
```

| State | Condition | Action |
|-------|-----------|--------|
| OFF | RH < target - 5% | Turn ON |
| ON | RH < target | Keep running |
| ON | RH ≥ target | Turn OFF |

### 8.7 Summer/Winter Mode (`sum_wint_jel`)

The summer/winter signal is a **hardware-only** distinction - it does NOT change the control logic.

| Season | Signal | Air Property | Main Fan |
|--------|--------|--------------|----------|
| **Summer** | OFF | Light (less dense) | Higher speed wiring |
| **Winter** | ON | Dense (heavier) | Lower speed wiring |

**Key points:**
- All control logic works **identically year-round**
- The `sum_wint_jel` input only selects which fan speed wiring is active
- Summer needs higher fan speed to move the same air mass (lighter air)
- Winter needs lower fan speed (denser air moves more mass per rotation)

```lua
relay_main_fan = sum_wint_jel  -- ON=winter speed, OFF=summer speed
```

### 8.8 Signal Table

| Signal | Type | Description |
|--------|------|-------------|
| kamra_hibaflag | boolean | Chamber sensor error state |
| befujt_hibaflag | boolean | Supply air sensor error state |
| heating_blocked | boolean | Heating blocked by humidity strategy |
| kamra_hutes | boolean | Chamber cooling needed |
| kamra_futes | boolean | Chamber heating needed |
| kamra_para_hutes | boolean | Chamber dehumidification needed (dehumi) |
| cool | boolean | Cooling mode active |
| dehumi | boolean | Dehumidification mode active |
| warm | boolean | Heating mode active |
| outdoor_beneficial | boolean | Outdoor air is 5°C+ cooler than chamber |
| use_water_cooling | boolean | Water heat exchanger should run |
| use_outdoor_air | boolean | Outdoor air damper should open |
| humidification | boolean | Humidifier should run |
| sleep | boolean | Sleep mode active |

---

## 9. Configuration Parameters

### 9.1 Control Constants (constansok_ch{N})

| Parameter | Default | Unit | Description |
|-----------|---------|------|-------------|
| outdoor_mix_ratio | 30 | % | Outdoor air ratio in fine control |
| outdoor_use_threshold | 50 | ×10°C | Use outdoor when chamber-outdoor > 5.0°C |
| ah_deadzone | 50 | ×10% | Fine control when AH error < 5% of target |
| proportional_gain | 10 | ×10 | P gain for aggressive control (1.0) |
| min_supply_air_temp | 60 | ×10°C | Minimum supply air 6.0°C |
| max_supply_air_temp | 400 | ×10°C | Maximum supply air 40.0°C |
| min_temp_no_humidifier | 110 | ×10°C | Minimum temp without humidifier 11.0°C |
| humidifier_start_delta | 50 | ×10% | Start humidifier at target - 5.0% |
| deltahi_kamra_homerseklet | 10 | ×10°C | Chamber temp high hysteresis +1.0°C |
| deltalo_kamra_homerseklet | 10 | ×10°C | Chamber temp low hysteresis -1.0°C |
| deltahi_kamra_para | 15 | ×10% | Chamber humidity high hysteresis +1.5% |
| deltalo_kamra_para | 10 | ×10% | Chamber humidity low hysteresis -1.0% |
| deltahi_befujt_homerseklet | 20 | ×10°C | Supply temp high hysteresis +2.0°C |
| deltalo_befujt_homerseklet | 15 | ×10°C | Supply temp low hysteresis -1.5°C |

### 9.2 Per-Chamber Hardware Config

| Parameter | Location | Description |
|-----------|----------|-------------|
| has_humidifier | hw_config.has_humidifier | true if humidifier installed |

### 9.3 Control Config (variable[201])

| Parameter | Default | Description |
|-----------|---------|-------------|
| poll_interval | 5000 | Sensor polling interval (ms) |
| poll_offset_step | 1500 | Stagger between chambers (ms) |
| temp_threshold | 2 | Temperature change threshold (0.2°C) |
| humidity_threshold | 3 | Humidity change threshold (0.3%) |
| buffer_size_outdoor | 5 | Moving average buffer size |
| buffer_size_chamber | 5 | Moving average buffer size |
| buffer_size_supply | 3 | Moving average buffer size |
| max_error_count | 3 | Errors before fallback |

### 9.2 Constants (constansok table)

| Parameter | Default | Description |
|-----------|---------|-------------|
| has_humidifier | false | Humidifier installed |
| min_temp_without_humidifier | 110 | Min temp for heating when dry (11.0°C) |
| outdoor_temp_diff_threshold | 30 | Min diff for outdoor benefit (3.0°C) |
| outdoor_mix_ratio | 30 | Outdoor air mix percentage |
| min_supply_air_temp | 60 | Min supply air temp (6.0°C) |
| deltahi_kamra_homerseklet | 10 | Temp hysteresis high (1.0°C) |
| deltalo_kamra_homerseklet | 10 | Temp hysteresis low (1.0°C) |
| deltahi_kamra_para | 15 | RH hysteresis high (+1.5%) - converted to AH |
| deltalo_kamra_para | 10 | RH hysteresis low (-1.0%) - converted to AH |

---

## 10. Psychrometric Calculations

### 10.1 Magnus Formula Constants

```lua
local PSYCHRO = {
  A = 6.112,      -- Saturation vapor pressure coefficient
  B = 17.67,      -- Temperature coefficient
  C = 243.5,      -- Temperature offset
  MW_RATIO = 2.1674,  -- Molecular weight ratio
}
```

### 10.2 Calculation Functions

```lua
-- Saturation vapor pressure (hPa)
local function saturation_vapor_pressure(temp_c)
  return PSYCHRO.A * math.exp(PSYCHRO.B * temp_c / (PSYCHRO.C + temp_c))
end

-- Absolute humidity (g/m³)
local function calculate_absolute_humidity(temp_c, rh)
  local e_s = saturation_vapor_pressure(temp_c)
  return PSYCHRO.MW_RATIO * (rh / 100) * e_s / (273.15 + temp_c)
end

-- Dew point (°C)
local function calculate_dew_point(temp_c, rh)
  if rh <= 0 then return -999 end
  local gamma = math.log(rh / 100) + PSYCHRO.B * temp_c / (PSYCHRO.C + temp_c)
  return PSYCHRO.C * gamma / (PSYCHRO.B - gamma)
end

-- RH from absolute humidity (%)
local function calculate_rh_from_ah(temp_c, ah)
  local e_s = saturation_vapor_pressure(temp_c)
  return (ah * (273.15 + temp_c) / (PSYCHRO.MW_RATIO * e_s)) * 100
end
```

---

## 11. File Structure

### Core Controllers

| File | Lines | Purpose |
|------|-------|---------|
| erlelo_config.lua | ~473 | One-time initialization (local variables) |
| erlelo_kulso.lua | ~416 | Outdoor sensor reader + stats + UI |
| erlelo_kamra1.lua | ~1145 | Chamber 1 controller + stats + UI |
| erlelo_kamra2.lua | ~1145 | Chamber 2 (CHAMBER_ID=2) |
| erlelo_kamra3.lua | ~1145 | Chamber 3 (CHAMBER_ID=3) |

### API-Based Variable Management

| File | Purpose |
|------|---------|
| erlelo_config_1ch.json | Variable definitions for 1 chamber (40 variables) |
| erlelo_config_2ch.json | Variable definitions for 2 chambers (72 variables) |
| erlelo_config_3ch.json | Variable definitions for 3 chambers (104 variables) |
| erlelo_create.lua | Creates variables via HTTP API from GitHub JSON |
| erlelo_store.lua | Builds name→ID mapping |
| erlelo_delete.lua | Selective delete (erlelo vars only) |

---

## 12. Initialization Sequence

### Installation Workflow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ erlelo_create   │────►│ erlelo_store    │────►│ Configure &     │
│ (run once)      │     │ (run once)      │     │ Enable devices  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
   Fetches JSON from      Builds name→ID          Set MAPPING_VAR_ID
   GitHub, creates        mapping, prints         and hardware IDs
   all variables          MAPPING_VAR_ID          in each controller
```

### Step-by-Step Installation

1. **Upload JSON to GitHub**
   - Choose `erlelo_config_1ch.json`, `_2ch.json`, or `_3ch.json`
   - Upload to `https://github.com/kekhazkft-code/setup/main/`

2. **Run erlelo_create.lua**
   - Set `NUM_CHAMBERS = 1`, `2`, or `3` at top of file
   - Deploy to Sinum, press "Start Install"
   - Creates all variables with defaults from GitHub

3. **Run erlelo_store.lua**
   - Deploy to Sinum, press "Build Mapping"
   - **Copy the printed MAPPING_VAR_ID** (e.g., 42)

4. **Configure Controllers**
   - Set `MAPPING_VAR_ID` in erlelo_kulso.lua and each erlelo_kamraN.lua
   - Set Modbus client IDs and SBUS device IDs

5. **Enable Controllers**
   - Enable `erlelo_kulso.lua` (starts at T+100ms)
   - Enable `erlelo_kamra1.lua` (starts at T+500ms)
   - Enable `erlelo_kamra2.lua` if used (starts at T+1000ms)
   - Enable `erlelo_kamra3.lua` if used (starts at T+1500ms)

**Timing Summary:**
- Poll interval: 1000ms
- Statistics recording: Every 30 polls (~30 seconds)
- UI refresh: Every 30 polls (~30 seconds)
- Control action logging: Immediate on state change

---

## 12.1 Variable Naming Convention

All variables follow a strict naming pattern:

### Chamber-Specific Variables (suffix `_ch1`, `_ch2`, `_ch3`)

```
kamra_homerseklet_ch1     Chamber 1 temperature ×10
kamra_para_ch2            Chamber 2 humidity ×10
constansok_ch3            Chamber 3 control constants (JSON)
signals_ch1               Chamber 1 control signals (JSON)
```

### Global Variables (suffix `_glbl`)

```
kulso_homerseklet_glbl    Outdoor temperature ×10
kulso_para_glbl           Outdoor humidity ×10
kulso_ah_dp_glbl          Outdoor psychrometric data (JSON)
variable_name_map_glbl    Name→ID mapping (built by erlelo_store)
```

---

## 12.2 Variable Management Scripts

### erlelo_create.lua

Creates all variables defined in GitHub JSON config.

```lua
-- Fetches config from GitHub
http:GET(GITHUB_URL):timeout(15):send()

-- Creates each variable
http:POST(API_BASE..'/lua/variables')
  :header('Content-Type','application/json')
  :header('Authorization',TOKEN)
  :body(JSON:encode({
    type = var.type,
    name = var.name,
    description = var.description,
    default_value = var.default_value
  })):send()
```

### erlelo_store.lua

Reads all variables from API and creates name→ID mapping.

```lua
-- Fetch all variables
http:GET(API_BASE..'/lua/variables'):header('Authorization',TOKEN):send()

-- Build mapping
local id_map = {}
for _, v in ipairs(resp.data) do
  id_map[v.name] = v.id
end

-- Store in variable_name_map
variable[variable_name_map_id]:setValue(JSON:encode(id_map))
```

### erlelo_delete.lua

**Selective delete** - only removes variables whose names match the erlelo config.

```lua
-- 1. Fetch erlelo config from GitHub
-- 2. Build set of erlelo variable names
-- 3. Fetch all system variables
-- 4. Delete ONLY variables matching erlelo names
-- 5. Verify deletion

-- Safe: does NOT delete other system variables
```

### erlelo_config.json Structure

```json
{
  "version": "2.2",
  "description": "Erlelo multi-chamber climate control system variables",
  "num_chambers": 3,
  "variables": [
    {"name": "kamra_homerseklet_ch1", "type": "integer", "default_value": 0, "description": "Chamber 1 temperature ×10"},
    {"name": "kamra_para_ch1", "type": "integer", "default_value": 0, "description": "Chamber 1 humidity ×10"},
    ...
  ]
}
```

### Variable Count Summary

| Category | Count | Description |
|----------|-------|-------------|
| Per-chamber | 30 × 3 = 90 | Temperature, humidity, dew point, signals, etc. |
| Shared outdoor | 7 | kulso_* variables at fixed indices |
| Configuration | 4 | variable_name_map, hardware_config, control_config, structure_definition |
| **Total** | **101** | All variables for 3-chamber system |

### API Configuration

Both create and delete scripts require:

```lua
local API_BASE = 'http://192.168.0.122/api/v1'  -- Your Sinum central IP
local TOKEN = 'YOUR_API_TOKEN_HERE'              -- API token from Sinum
```

### Safety Features

- **Selective delete**: Only deletes variables matching erlelo config names
- **Verification step**: Confirms operations completed successfully  
- **Idempotent create**: Can re-run create without duplicating variables
- **GitHub-based config**: Single source of truth for variable definitions

---

## 13. Statistics System

### 13.1 Configuration

Statistics are recorded every 30 polling cycles (~30 seconds with default 1s poll interval):

```lua
local STATS_INTERVAL = 30  -- Record stats every 30 poll cycles
local stats_counter = 0    -- Counter for statistics timing
```

### 13.2 Periodic Statistics (Every 30 seconds)

**Outdoor Sensor (`erlelo_kulso.lua`):**

| Series Name | Unit | Description |
|-------------|------|-------------|
| `outdoor_temp` | unit.celsius_x10 | Outdoor temperature |
| `outdoor_humidity` | unit.relative_humidity_x10 | Outdoor relative humidity |
| `outdoor_dewpoint` | unit.celsius_x10 | Outdoor dew point |

**Chamber Controller (`erlelo_kamra1.lua`):**

| Series Name | Unit | Description |
|-------------|------|-------------|
| `mode_ch{N}` | unit.bool_unit | Operating mode (1=aktív, 0=pihenő) |
| `chamber_temp_ch{N}` | unit.celsius_x10 | Chamber temperature |
| `chamber_humidity_ch{N}` | unit.relative_humidity_x10 | Chamber humidity |
| `supply_temp_ch{N}` | unit.celsius_x10 | Supply air temperature * |
| `supply_humidity_ch{N}` | unit.relative_humidity_x10 | Supply air humidity * |
| `supply_dewpoint_ch{N}` | unit.celsius_x10 | Supply air dew point * |
| `ntc1_ch{N}` | unit.celsius_x10 | NTC water temperature 1 * |
| `ntc2_ch{N}` | unit.celsius_x10 | NTC water temperature 2 * |
| `ntc3_ch{N}` | unit.celsius_x10 | NTC water temperature 3 * |
| `ntc4_ch{N}` | unit.celsius_x10 | NTC water temperature 4 * |
| `target_temp_ch{N}` | unit.celsius_x10 | Target temperature setpoint |
| `target_humidity_ch{N}` | unit.relative_humidity_x10 | Target humidity setpoint |
| `chamber_dewpoint_ch{N}` | unit.celsius_x10 | Chamber dew point |
| `target_dewpoint_ch{N}` | unit.celsius_x10 | Target dew point |

*Note: `{N}` is the chamber ID (1, 2, or 3)*

**\* Supply air and NTC statistics** are only recorded during **aktív** mode, **after a 2-minute warmup delay**. When the system switches from pihenő to aktív, no supply air or NTC data is collected for the first 120 seconds to allow airflow to stabilize. During pihenő (rest) mode there is no airflow, so these readings are not meaningful.

### 13.3 Event-Based Statistics (On Control Changes)

When control signals change, the new state is logged immediately:

| Series Name | Unit | Trigger |
|-------------|------|---------|
| `ch{N}_heating` | unit.bool_unit | Chamber heating ON/OFF |
| `ch{N}_cooling` | unit.bool_unit | Chamber cooling ON/OFF |
| `ch{N}_dehumidify` | unit.bool_unit | Dehumidification ON/OFF |
| `ch{N}_supply_heat` | unit.bool_unit | Supply heating ON/OFF |
| `ch{N}_supply_cool` | unit.bool_unit | Supply cooling ON/OFF |
| `ch{N}_humidifier` | unit.bool_unit | Humidifier ON/OFF |
| `ch{N}_sleep` | unit.bool_unit | Sleep mode ON/OFF |
| `ch{N}_bypass` | unit.bool_unit | Bypass OPEN/CLOSED |

### 13.4 Statistics API Usage

```lua
-- Record a temperature point
statistics:addPoint("chamber_temp_ch1", temp_value, unit.celsius_x10)

-- Record a boolean state (0 or 1)
statistics:addPoint("ch1_heating", new_state and 1 or 0, unit.bool_unit)
```

### 13.5 Throttling

Sinum limits statistics to 60 points/minute per series per device. The pool refills 1 point/minute. With 30-second intervals, this is well within limits.

---

## 14. UI Refresh System

### 14.1 Refresh Timing

UI elements are refreshed every 30 seconds, synchronized with statistics recording:

```lua
-- In onEvent timer handler
stats_counter = stats_counter + 1
if stats_counter >= STATS_INTERVAL then
  stats_counter = 0
  record_statistics()
  refresh_ui(self)
end
```

### 14.2 Chamber Controller UI Elements

**Temperature & Humidity Displays:**

| Element Name | Format | Source |
|--------------|--------|--------|
| `_3_tx_kamra_homerseklet_` | "17.5°C" | kamra_homerseklet |
| `_4_tx_kamra_para_` | "70.0%" | kamra_para |
| `_1_tx_befujt_homerseklet_` | "25.3°C" | befujt_homerseklet_akt |
| `_2_tx_befujt_para_` | "55.0%" | befujt_para_akt |
| `_3_tx_kulso_homerseklet_` | "22.1°C" | kulso_homerseklet |
| `_4_tx_kulso_para_` | "45.0%" | kulso_para |

**Dew Point Displays:**

| Element Name | Format | Source |
|--------------|--------|--------|
| `dp_kamra_tx` | "HP: 12.3°C" | dp_kamra |
| `dp_befujt_tx` | "HP: 15.0°C" | dp_befujt |
| `dp_cel_tx` | "Cél HP: 13.5°C" | dp_cel |
| `dp_kulso_tx` | "HP: 10.2°C" | kulso_ah_dp.dp |

**Absolute Humidity Displays:**

| Element Name | Format | Source |
|--------------|--------|--------|
| `ah_kamra_tx` | "AH: 0.076g/m³" | ah_kamra |
| `ah_befujt_tx` | "AH: 0.095g/m³" | ah_befujt |
| `ah_kulso_tx` | "AH: 0.085g/m³" | kulso_ah_dp.ah |

**Status Indicators:**

| Element Name | Active Text | Inactive |
|--------------|-------------|----------|
| `text_input_0_warm` | "Fűtés Aktív!" | " " |
| `text_input_1_cool` | "Hűtés Aktív!" | " " |
| `text_input_2_wdis` | "Párátlanítás!" | " " |
| `text_input_3_cdis` | "Párásítás!" | " " |

### 14.3 Outdoor Sensor UI Elements

| Element Name | Format | Source |
|--------------|--------|--------|
| `text1_kulso_homerseklet` | "22.1°C" | kulso_homerseklet |
| `text0_kulso_para` | "45.0%" | kulso_para |
| `text2_outside_temp` | "HP: 10.2°C" | kulso_ah_dp.dp |
| `ah_kulso_tx` | "AH: 0.085g/m³" | kulso_ah_dp.ah |

### 14.4 UI Update API

```lua
local function refresh_ui(device)
  local function updateElement(name, value)
    local elem = device:getElement(name)
    if elem then
      elem:setValue('value', value, true)  -- true = no propagation
    end
  end
  
  -- Temperature display
  local temp = V('kamra_homerseklet'):getValue() or 0
  updateElement('_3_tx_kamra_homerseklet_', string.format("%.1f°C", temp / 10))
  
  -- Status indicator
  local signals = V('signals'):getValue() or {}
  updateElement('text_input_0_warm', signals.kamra_futes and "Fűtés Aktív!" or " ")
end
```

---

## 15. Code Section Order (Updated)

The following order is **required** to avoid forward reference errors in Lua:

```
1.  CONFIGURATION (CHAMBER_ID, CONFIG_VAR_ID)
2.  VARIABLE MAPPING SYSTEM (loadVarMap, V function)
3.  LOCAL STATE VARIABLES
4.  STATISTICS CONFIGURATION (STATS_INTERVAL, stats_counter)
5.  PSYCHROMETRIC CALCULATIONS
6.  UTILITY FUNCTIONS (moving_average_update, set_relay, hysteresis)
7.  STATISTICS RECORDING (record_statistics, log_control_action)
8.  UI REFRESH (refresh_ui)
9.  SENSOR DATA PROCESSING (update_*_psychrometric, process_*_data)
10. MODBUS HANDLING (handle_*_response, handle_*_error, poll_sensors)
11. TARGET CALCULATION
12. CONTROL LOGIC (run_control_cycle) ← calls log_control_action
13. RELAY OUTPUT
14. SLEEP CYCLE MANAGEMENT
15. INITIALIZATION (init_hardware, CustomDevice:onInit)
16. EVENT HANDLING (CustomDevice:onEvent) ← calls record_statistics, refresh_ui
17. UI CALLBACKS
```

---

## 16. Version History

### v2.3 (Current)
- **Dehumidification now uses Absolute Humidity internally**
  - User still configures targets and hysteresis in RH% (intuitive)
  - System converts RH% thresholds to AH at target temperature
  - Comparison uses AH values (physically correct)
  - Fixes incorrect behavior when current temp ≠ target temp
- Documented water-air heat exchanger system (bypass = water recirculation, not air)
- Updated config comments for bypass valve function

### v2.2
- Added statistics recording (every 30 seconds)
- Added event-based control action logging
- Added UI refresh (every 30 seconds)
- Statistics series naming with chamber ID suffix
- Control state changes logged immediately
- Added API-based variable management system:
  - erlelo_config.json (101 variable definitions)
  - erlelo_create.lua (HTTP API variable creation)
  - erlelo_store.lua (name→ID mapping builder)
  - erlelo_delete.lua (selective delete, erlelo vars only)
- Added missing dew point variables (dp_kamra, dp_befujt, dp_cel)
- Added missing absolute humidity variables (ah_kamra, ah_befujt)

### v2.1
- Fixed forward reference errors (section order)
- Fixed SBUS event type (device_state_changed)
- Implemented single Modbus register read
- Implemented always-poll (simulation independence)
- Corrected stagger timing (outdoor first)
- Added supply target threshold propagation
- Added error state fallback behavior
- Added "better cold than dry" heating block
- Added diagnostic signals (hibaflag, heating_blocked)

### v2.0
- Initial dynamic variable mapping (V function)
- JSON-based variable index resolution
- Multi-chamber support

---

## 17. Sinum API Reference

```lua
-- Variables
variable[idx]:getValue()
variable[idx]:setValue(value, stop_propagation)

-- Modbus (async)
modbus_client[id]:readInputRegistersAsync(addr, count)
modbus_client[id]:onRegisterAsyncRead(callback)
modbus_client[id]:onAsyncRequestFailure(callback)

-- SBUS
sbus[id]:getValue("state")  -- "on" or "off"
sbus[id]:call("turn_on")
sbus[id]:call("turn_off")

-- Custom Device
CustomDevice:onInit()
CustomDevice:onEvent(event)
self:getComponent("timer")
self:getElement("element_name")

-- UI Elements
element:getValue('value')
element:setValue('value', new_value, stop_propagation)
element:setValue('visibility', 'visible', true)

-- Timer
timer:start(milliseconds)

-- JSON
JSON:encode(table)
JSON:decode(string)

-- Statistics
statistics:addPoint(name, value, unit)
-- Units: unit.celsius_x10, unit.relative_humidity_x10, unit.bool_unit, etc.
```

---

*Document Version: 2.2*
*Platform: Sinum Home Automation*
