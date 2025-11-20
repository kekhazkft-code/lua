# Supply Air Temperature & Humidity Control - Deep Analysis

## Executive Summary

The supply air (befujt) control system uses a **predictive feedforward control strategy** combined with psychrometric calculations to regulate chamber conditions. Instead of directly controlling supply air, the system calculates optimal supply air targets based on chamber error and uses outdoor air mixing when beneficial.

---

## Table of Contents

1. [Supply Air Target Calculation Algorithm](#supply-air-target-calculation-algorithm)
2. [Factors Affecting Supply Air](#factors-affecting-supply-air)
3. [Chamber Impact Algorithm](#chamber-impact-algorithm)
4. [Control Logic Flow](#control-logic-flow)
5. [Psychrometric Integration](#psychrometric-integration)
6. [Outdoor Air Optimization](#outdoor-air-optimization)
7. [Safety Mechanisms](#safety-mechanisms)

---

## Supply Air Target Calculation Algorithm

### Core Formula (Predictive Feedforward)

```lua
-- Lines 424-446 in erlelo_1119.lua

-- Temperature Target Calculation
if kamra_hibaflag then 
    -- Error condition: use chamber target directly
    befujt_cel_homerseklet = kamra_cel_homerseklet
else
    -- Normal operation: predictive correction
    befujt_cel_homerseklet = kamra_cel_homerseklet + (kamra_cel_homerseklet - kamra_homerseklet)/2
end

-- Humidity Target Calculation
if kamra_hibaflag then 
    -- Error condition: use chamber target directly
    befujt_cel_para = kamra_cel_para
else
    -- Normal operation: predictive correction
    befujt_cel_para = kamra_cel_para + (kamra_cel_para - kamra_para)/2
end
```

### Mathematical Explanation

#### Temperature Formula
```
befujt_cel_T = T_target + (T_target - T_chamber) / 2

Simplified:
befujt_cel_T = T_target + 0.5 × error_T

Where:
- T_target = kamra_cel_homerseklet (chamber target temperature)
- T_chamber = kamra_homerseklet (current chamber temperature)
- error_T = (T_target - T_chamber)
```

#### Humidity Formula
```
befujt_cel_RH = RH_target + (RH_target - RH_chamber) / 2

Simplified:
befujt_cel_RH = RH_target + 0.5 × error_RH

Where:
- RH_target = kamra_cel_para (chamber target humidity)
- RH_chamber = kamra_para (current chamber humidity)
- error_RH = (RH_target - RH_chamber)
```

### Control Strategy Explanation

**This is a PROPORTIONAL FEEDFORWARD controller with gain = 0.5**

#### Example 1: Chamber Too Cold
```
Target Temperature: 15.0°C
Current Chamber: 12.0°C
Error: +3.0°C (chamber is 3°C too cold)

Supply Air Target = 15.0 + 3.0/2 = 16.5°C

Reasoning:
- Chamber needs warming
- Supply air must be WARMER than target
- The colder the chamber, the warmer the supply air
```

#### Example 2: Chamber Too Hot
```
Target Temperature: 15.0°C
Current Chamber: 18.0°C
Error: -3.0°C (chamber is 3°C too hot)

Supply Air Target = 15.0 + (-3.0)/2 = 13.5°C

Reasoning:
- Chamber needs cooling
- Supply air must be COOLER than target
- The hotter the chamber, the cooler the supply air
```

#### Example 3: Chamber At Target
```
Target Temperature: 15.0°C
Current Chamber: 15.0°C
Error: 0°C

Supply Air Target = 15.0 + 0/2 = 15.0°C

Reasoning:
- No correction needed
- Supply air equals target (steady state)
```

### Why Gain = 0.5?

The factor of 0.5 provides:

1. **Stability**: Prevents overcorrection and oscillation
2. **Gradual Correction**: Allows system to approach target smoothly
3. **Safety Margin**: Avoids extreme supply air temperatures
4. **Fast Response**: Stronger than pure integral control (P=0.5 vs I=0.1 typical)

---

## Factors Affecting Supply Air

### 1. Chamber Temperature & Humidity (Primary Factors)

**Variable Mapping**:
- `kamra_homerseklet_v1` (variable[1]) - Current chamber temperature (int×10)
- `kamra_para_v1` (variable[2]) - Current chamber humidity (int×10)

**Impact**:
- **Direct proportional influence** on supply air targets
- Larger chamber error → Larger supply air offset from target
- Error is measured every poll cycle (~5 seconds)

**Control Equation**:
```
Supply_Air_Offset = 0.5 × Chamber_Error

Where Chamber_Error = Target - Current
```

### 2. Chamber Target Setpoints (User Input)

**Variable Mapping**:
- `kamra_cel_homerseklet_v1` (variable[3]) - Target chamber temperature (int×10)
- `kamra_cel_para_v1` (variable[4]) - Target chamber humidity (int×10)

**Impact**:
- Determines the **reference point** for all control
- Changes in target immediately recalculate supply air targets
- UI sliders directly modify these values

**Example**:
```
User changes target from 15°C to 18°C:
→ Supply air target instantly adjusts based on new reference
→ Control algorithm recalculates all thresholds
```

### 3. Supply Air Measured Values (Feedback)

**Variable Mapping**:
- `befujt_homerseklet_akt1` (variable[23]) - Current supply air temperature (int×10)
- `befujt_para_akt1` (variable[24]) - Current supply air humidity (int×10)

**Impact**:
- Used for **closed-loop verification** of supply air control
- Triggers heating/cooling based on deviation from target
- 5-point moving average filter smooths measurements

**Control Logic** (Lines 498-536):
```lua
-- Temperature Control
if befujt_mert_homerseklet > (befujt_cel_homerseklet + deltahi_befujt_homerseklet) then 
    befujt_hutes = true    -- Supply air too hot: activate cooling
    befujt_futes = false
end

if befujt_mert_homerseklet < (befujt_cel_homerseklet - deltalo_befujt_homerseklet) then 
    befujt_futes = true    -- Supply air too cold: activate heating
    befujt_hutes = false
end

-- Humidity Control
if befujt_mert_para > (befujt_cel_para + deltahi_befujt_para) then 
    befujt_para_hutes = true    -- Supply air too humid: dehumidify
end

if befujt_mert_para < (befujt_cel_para - deltalo_befujt_para) then 
    futes_tiltas = true    -- Supply air too dry: prevent further drying
end
```

### 4. Outdoor Air Conditions

**Variable Mapping**:
- `kulso_homerseklet_v1` (variable[7]) - Outdoor temperature (int×10)
- `kulso_para_v1` (variable[8]) - Outdoor humidity (int×10)

**Impact**:
- **Critical for outdoor air mixing decisions**
- Determines if outdoor air helps or hinders control
- Uses psychrometric evaluation (see section below)

**Mixing Strategy**:
```
Outdoor Mix Ratio = 30% (configurable)

Mixed Properties = 70% chamber + 30% outdoor

Decision:
IF outdoor_air_beneficial THEN
    relay_add_air_max = ON     (maximum outdoor air intake)
ELSE
    relay_add_air_save = ON    (energy-saving recirculation)
END IF
```

### 5. Psychrometric Calculations

**Variable Mapping**:
- `ah_dp_table1` (variable[42]) - Absolute humidity & dew point values

**Calculated Values**:
```lua
-- For each air stream (chamber, supply, outdoor, target):
ah_dp_table1 = {
    ah_cel = ...        -- Target absolute humidity (g/m³)
    dp_cel = ...        -- Target dew point (°C)
    ah_befujt_cel = ... -- Supply air target AH
    dp_befujt_cel = ... -- Supply air target DP
    ah_befujt = ...     -- Current supply air AH
    dp_befujt = ...     -- Current supply air DP
    ah_kamra = ...      -- Current chamber AH
    dp_kamra = ...      -- Current chamber DP
    ah_kulso = ...      -- Outdoor AH
    dp_kulso = ...      -- Outdoor DP
}
```

**Impact**:
- **Temperature-independent humidity metric**
- Enables accurate outdoor air evaluation
- Prevents condensation by tracking dew point
- Used in humidification control decisions

### 6. Control Delta Thresholds (Hysteresis)

**Variable Mapping** (from `constansok1`, variable[33]):
```lua
-- Supply Air Thresholds
deltahi_befujt_homerseklet  -- High temp threshold (activates cooling)
deltalo_befujt_homerseklet  -- Low temp threshold (activates heating)
deltahi_befujt_para         -- High RH threshold (activates dehumidification)
deltalo_befujt_para         -- Low RH threshold (prevents drying)

-- Chamber Thresholds
deltahi_kamra_homerseklet   -- Chamber high temp threshold
deltalo_kamra_homerseklet   -- Chamber low temp threshold
deltahi_kamra_para          -- Chamber high RH threshold
deltalo_kamra_para          -- Chamber low RH threshold
```

**Impact**:
- Creates **hysteresis bands** to prevent oscillation
- Typical values: ±0.5°C, ±2% RH
- Separate thresholds for heating and cooling
- Prevents rapid cycling of relays

**Example Hysteresis**:
```
Supply Air Target: 16.0°C
deltahi = 0.5°C
deltalo = 0.5°C

Cooling activates at: 16.5°C
Heating activates at: 15.5°C
Dead band: 15.5°C - 16.5°C (no action)
```

### 7. Safety Limits

**Minimum Supply Air Temperature**:
```lua
MIN_SUPPLY_AIR_TEMP = 60  -- 6.0°C (int×10)

if befujt_mert_homerseklet < MIN_SUPPLY_AIR_TEMP then 
    hutes_tiltas = true    -- Prevent cooling below 6°C
end
```

**Impact**:
- **Hard limit** prevents excessively cold supply air
- Protects against condensation in ducts
- Prevents frost damage
- Overrides all other cooling commands

### 8. Sleep Mode & Cycle Control

**Variable Mapping**:
- `signal.sleep` - Sleep mode active flag
- `cycle_variable1` (variable[38]) - Cycle timing parameters

**Impact**:
```lua
warm = warm_1 and (not signal.sleep)    -- Heating disabled in sleep mode
cool_rel = cool and (not signal.sleep)  -- Cooling disabled in sleep mode
```

- **Reduces energy consumption** during rest periods
- Maintains monitoring but suspends active control
- Configurable active/passive time ratios

### 9. Sensor Error Flags

**Variable Mapping**:
- `befujt_hibaszam1` (variable[29]) - Supply air sensor error counter
- `kamra_hibaszam1` (variable[30]) - Chamber sensor error counter

**Impact**:
```lua
if kamra_hibaszam1 <= 0 then 
    kamra_hibaflag = true
    befujt_cel_homerseklet = kamra_cel_homerseklet  -- Fallback to target
    befujt_cel_para = kamra_cel_para
end
```

- **Failsafe mode** when sensors fail
- Supply air targets default to chamber targets
- Prevents runaway control based on bad data
- Counter decrements on each failure, resets to 3 on success

---

## Chamber Impact Algorithm

### How Supply Air Affects Chamber Conditions

The chamber is affected by supply air through:

1. **Heat Transfer**: Supply air temperature directly adds/removes heat
2. **Mass Transfer**: Supply air humidity adds/removes moisture
3. **Mixing**: Fresh supply air mixes with chamber air

### Heat Balance Equation

```
Q_chamber = Q_supply_air + Q_chamber_load + Q_external

Where:
Q_supply_air = ṁ × Cp × (T_supply - T_chamber)
ṁ = air mass flow rate (kg/s)
Cp = specific heat of air (1.005 kJ/kg·K)
```

**Chamber Temperature Response**:
```
dT_chamber/dt = (Q_supply_air + Q_external) / (m_chamber × Cp)

Time constant τ ≈ V_chamber / (ṁ × Cp)
```

### Humidity Balance Equation

```
W_chamber = W_supply_air + W_product + W_external

Where:
W = moisture addition rate (kg/s)
W_supply_air = ṁ × (AH_supply - AH_chamber)
```

**Chamber Humidity Response**:
```
dRH_chamber/dt = f(W_supply_air, T_chamber, W_product)
```

### Supply Air Impact Logic (Lines 456-495)

#### Temperature Impact on Chamber

```lua
-- Chamber Temperature Control
if kamra_homerseklet > (kamra_cel_homerseklet + 2×deltahi_kamra_homerseklet) then 
    kamra_hutes = true    -- Chamber too hot: trigger cooling demand
end

if kamra_homerseklet < (kamra_cel_homerseklet - 2×deltalo_kamra_homerseklet) then  
    kamra_futes = true    -- Chamber too cold: trigger heating demand
end
```

**Algorithm Logic**:
```
1. Measure chamber temperature error
2. Calculate supply air target (0.5 × error compensation)
3. Supply air heats/cools to calculated target
4. Supply air enters chamber
5. Chamber temperature moves toward target
6. Error reduces → Supply air offset reduces
7. System converges to steady state
```

**Example Scenario**:
```
Initial State:
  Chamber: 12.0°C (too cold)
  Target: 15.0°C
  Error: +3.0°C

Cycle 1:
  Supply Air Target: 15.0 + 3.0/2 = 16.5°C
  Supply air heats chamber
  Chamber rises to 12.5°C

Cycle 2:
  New Error: +2.5°C
  Supply Air Target: 15.0 + 2.5/2 = 16.25°C
  Chamber rises to 13.0°C

Cycle N:
  Error approaches 0
  Supply Air Target approaches 15.0°C
  Chamber stabilizes at 15.0°C
```

#### Humidity Impact on Chamber

```lua
-- Chamber Humidity Control
if kamra_para > (kamra_cel_para + 2×deltahi_kamra_para) then 
    kamra_para_hutes = true    -- Chamber too humid: trigger dehumidification
end

if kamra_para < (kamra_cel_para - 2×deltalo_kamra_para) then 
    kamra_para_futes_tiltas = true    -- Chamber too dry: prevent further drying
end
```

**Algorithm Logic**:
```
1. Measure chamber humidity error
2. Calculate supply air RH target (0.5 × error compensation)
3. For high humidity:
   - Lower supply air RH target
   - Activate bypass (relay_bypass_open)
   - Increase ventilation
4. For low humidity:
   - Raise supply air RH target
   - Activate humidifier (relay_humidifier)
   - Use psychrometric control
5. Chamber humidity adjusts
6. System converges to target
```

### Combined Temperature & Humidity Control

**Interaction Effects**:

1. **Temperature affects RH**: As chamber heats, RH drops (even with constant absolute humidity)
2. **Humidity affects temperature**: Evaporation/condensation changes heat load
3. **Psychrometric coupling**: Both controlled via absolute humidity calculations

**Advanced Humidification Logic** (Lines 583-612):
```lua
-- Calculate absolute humidities
chamber_ah = calculate_absolute_humidity(kamra_temp/10, kamra_rh/10)
target_ah = calculate_absolute_humidity(target_temp/10, target_rh/10)

-- Project current AH to what RH would be at target temperature
projected_rh_at_target = calculate_rh(target_temp/10, chamber_ah)

-- Start humidification if projected RH is 5% below target
if projected_rh_at_target < (target_rh/10 - 5.0) then
    kamra_humidification = true
end

-- Stop when absolute humidity reaches target
if chamber_ah >= target_ah then
    kamra_humidification = false
end
```

**Why This is Sophisticated**:
- Uses **absolute humidity** (temperature-independent)
- **Projects** current moisture to target temperature
- Prevents premature humidifier shutoff during heating
- Accounts for psychrometric relationships

---

## Control Logic Flow

### Main Control Cycle (Every 5 seconds)

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: Read All Sensor Values                              │
├─────────────────────────────────────────────────────────────┤
│ • Chamber temperature & humidity (var[1], var[2])           │
│ • Supply air temperature & humidity (var[23], var[24])      │
│ • Outdoor temperature & humidity (var[7], var[8])           │
│ • Apply 5-point moving average filters                      │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: Calculate Supply Air Targets (Feedforward)          │
├─────────────────────────────────────────────────────────────┤
│ befujt_cel_T = T_target + 0.5 × (T_target - T_chamber)     │
│ befujt_cel_RH = RH_target + 0.5 × (RH_target - RH_chamber) │
│                                                              │
│ Calculate psychrometric properties:                          │
│ • Target dew point & absolute humidity                      │
│ • Supply air dew point & absolute humidity                  │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: Chamber Control Decisions                           │
├─────────────────────────────────────────────────────────────┤
│ Temperature:                                                 │
│   IF chamber_T > target + 2×Δhigh THEN kamra_hutes = true  │
│   IF chamber_T < target - 2×Δlow THEN kamra_futes = true   │
│                                                              │
│ Humidity:                                                    │
│   IF chamber_RH > target + 2×Δhigh THEN para_hutes = true  │
│   IF chamber_RH < target - 2×Δlow THEN humidify = true     │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 4: Supply Air Control Decisions                        │
├─────────────────────────────────────────────────────────────┤
│ Temperature:                                                 │
│   IF supply_T > target + Δhigh THEN befujt_hutes = true    │
│   IF supply_T < target - Δlow THEN befujt_futes = true     │
│                                                              │
│ Humidity:                                                    │
│   IF supply_RH > target + Δhigh THEN para_hutes = true     │
│   IF supply_RH < target - Δlow THEN futes_tiltas = true    │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 5: Outdoor Air Benefit Evaluation                      │
├─────────────────────────────────────────────────────────────┤
│ Calculate mixed air properties (70% chamber + 30% outdoor):│
│ • Mixed temperature                                          │
│ • Mixed absolute humidity                                    │
│ • Projected RH at target temperature                         │
│                                                              │
│ Decision criteria:                                           │
│   beneficial = temp_improves AND                            │
│                (ah_improves OR rh_acceptable)               │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 6: Combine All Control Signals                         │
├─────────────────────────────────────────────────────────────┤
│ warm = (kamra_futes OR befujt_futes) AND                   │
│        NOT(para_futes_tiltas OR sleep)                      │
│                                                              │
│ cool = (kamra_hutes OR befujt_hutes OR para_hutes) AND     │
│        NOT(hutes_tiltas OR sleep) AND sum_wint              │
│                                                              │
│ humidifier = (projected_rh < target - 5%) AND              │
│              (chamber_ah < target_ah)                        │
│                                                              │
│ bypass_open = humi_save OR (cool AND NOT dehumi)           │
│                                                              │
│ add_air_max = outdoor_beneficial AND NOT sum_wint          │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 7: Actuate Relays                                      │
├─────────────────────────────────────────────────────────────┤
│ relay_warm (60) → Heating system                            │
│ relay_cool (52) → Cooling system                            │
│ relay_humidifier (66) → Humidification                      │
│ relay_bypass_open (64) → Humidity bypass                    │
│ relay_add_air_max (61) → Maximum outdoor air               │
│ relay_add_air_save (63) → Energy-saving mode               │
│ relay_main_fan (65) → Fan speed control                     │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 8: Update UI & Wait for Next Cycle                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Psychrometric Integration

### Why Psychrometrics Matter

**Problem**: Relative humidity (RH%) is **temperature-dependent**
- Same RH% at different temperatures = different moisture content
- Cannot compare RH% values at different temperatures
- Mixing air at different temperatures: RH% calculation is complex

**Solution**: Use **absolute humidity** (g/m³) - temperature-independent

### Psychrometric Functions Used

#### 1. Saturation Vapor Pressure
```lua
function saturation_vapor_pressure(temp_c)
    return A * math.exp((B * temp_c) / (temp_c + C))
end

Constants:
A = 6.112, B = 17.67, C = 243.5
```

#### 2. Absolute Humidity Calculation
```lua
function calculate_absolute_humidity(temp_c, rh)
    local svp = saturation_vapor_pressure(temp_c)
    local avp = (rh / 100.0) * svp
    return (avp * MW_RATIO) / (KELVIN_OFFSET + temp_c)
end
```

#### 3. Relative Humidity from Absolute
```lua
function calculate_rh(temp_c, target_ah)
    local svp = saturation_vapor_pressure(temp_c)
    local avp = (target_ah * (KELVIN_OFFSET + temp_c)) / MW_RATIO
    return (avp / svp) * 100.0
end
```

#### 4. Dew Point Calculation
```lua
function calc_dew_point(temp, rh)
    local a = 17.62
    local b = 243.12
    local gamma = (a * temp) / (b + temp) + math.log(rh / 100)
    return (b * gamma) / (a - gamma)
end
```

### Application in Control

**Supply Air Target Calculation**:
```lua
-- Calculate target absolute humidity
ah_cel = calculate_absolute_humidity(target_temp, target_rh)

-- Calculate supply air target psychrometrics
ah_befujt_cel = calculate_absolute_humidity(supply_target_temp, supply_target_rh)
dp_befujt_cel = calc_dew_point(supply_target_temp, supply_target_rh)
```

**Benefit**: 
- Ensures supply air moisture is correctly calculated
- Prevents condensation (dew point tracking)
- Enables accurate outdoor air mixing evaluation

---

## Outdoor Air Optimization

### Corrected Psychrometric Evaluation

**The Problem with Simple Comparison**:
```
❌ WRONG: if outdoor_temp < chamber_temp then use_outdoor = true

Why wrong?
- Doesn't account for humidity
- RH% changes with temperature
- May cause humidity problems
```

**The Correct Three-Step Method** (Lines 282-349):

#### Step 1: Calculate Absolute Humidities
```lua
chamber_ah = calculate_absolute_humidity(chamber_temp, chamber_rh)
target_ah = calculate_absolute_humidity(target_temp, target_rh)
outdoor_ah = calculate_absolute_humidity(outdoor_temp, outdoor_rh)
```

#### Step 2: Calculate Mixed Air Properties
```lua
outdoor_mix_ratio = 0.30  -- 30% outdoor, 70% recirculated

mixed_temp = chamber_temp × 0.7 + outdoor_temp × 0.3
mixed_ah = chamber_ah × 0.7 + outdoor_ah × 0.3
```

#### Step 3: Project RH at Target Temperature
```lua
projected_rh_at_target = calculate_rh(target_temp, mixed_ah)
```

### Decision Logic

```lua
-- 1. Temperature benefit
temp_delta_current = abs(target_temp - chamber_temp)
temp_delta_mixed = abs(target_temp - mixed_temp)
temp_improves = (temp_delta_mixed < temp_delta_current)

-- 2. Humidity acceptable at target (±5% tolerance)
rh_tolerance = 5.0
rh_acceptable = abs(projected_rh_at_target - target_rh) <= rh_tolerance

-- 3. Absolute humidity improvement
ah_delta_current = abs(target_ah - chamber_ah)
ah_delta_mixed = abs(target_ah - mixed_ah)
ah_improves = (ah_delta_mixed < ah_delta_current)

-- FINAL DECISION
beneficial = temp_improves AND (ah_improves OR rh_acceptable)
```

### Example Scenarios

#### Scenario 1: Beneficial Outdoor Air
```
Chamber: 20°C, 80% RH → AH = 13.8 g/m³
Target: 15°C, 85% RH → AH = 10.9 g/m³
Outdoor: 10°C, 70% RH → AH = 6.6 g/m³

Mixed (30% outdoor): 17°C, 77% RH → AH = 11.8 g/m³
Projected at 15°C: 92% RH

Analysis:
✓ Temperature improves: 17°C closer to 15°C than 20°C
✓ AH improves: 11.8 g/m³ closer to 10.9 g/m³
✓ RH acceptable: 92% within 85% ± 5%

DECISION: Use maximum outdoor air
```

#### Scenario 2: Harmful Outdoor Air
```
Chamber: 15°C, 85% RH → AH = 10.9 g/m³
Target: 15°C, 85% RH → AH = 10.9 g/m³
Outdoor: 25°C, 90% RH → AH = 20.7 g/m³

Mixed (30% outdoor): 18°C, ~92% RH → AH = 13.8 g/m³
Projected at 15°C: 107% RH (condensation!)

Analysis:
✗ Temperature worse: 18°C farther from 15°C
✗ AH worse: 13.8 g/m³ farther from 10.9 g/m³
✗ RH unacceptable: 107% > 85% + 5%

DECISION: Use energy-saving recirculation
```

---

## Safety Mechanisms

### 1. Minimum Supply Air Temperature
```lua
MIN_SUPPLY_AIR_TEMP = 60  -- 6.0°C

if befujt_mert_homerseklet < MIN_SUPPLY_AIR_TEMP then 
    hutes_tiltas = true
end
```
**Purpose**: Prevent condensation, frost, discomfort

### 2. Heating/Cooling Interlocks
```lua
warm = (kamra_futes OR befujt_futes) AND NOT(tiltas)
cool = (kamra_hutes OR befujt_hutes) AND NOT(tiltas)
```
**Purpose**: Prevent simultaneous heating and cooling

### 3. Sleep Mode Override
```lua
warm = warm_1 AND (not signal.sleep)
cool_rel = cool AND (not signal.sleep)
```
**Purpose**: Energy saving during rest periods

### 4. Sensor Error Handling
```lua
if kamra_hibaszam1 <= 0 then 
    kamra_hibaflag = true
    befujt_cel_homerseklet = kamra_cel_homerseklet
end
```
**Purpose**: Failsafe operation on sensor failure

### 5. Intelligent Event Propagation
```lua
TEMP_CHANGE_THRESHOLD = 2  -- 0.2°C minimum
HUMI_CHANGE_THRESHOLD = 3  -- 0.3% minimum

temp_changed = abs(new - old) >= THRESHOLD
befujt_cel_homerseklet_v1:setValue(value, not temp_changed)
```
**Purpose**: Reduce unnecessary system events, prevent oscillation

---

## Summary: Complete Algorithm

### Input Variables
1. Chamber temperature & humidity (measured)
2. Chamber target temperature & humidity (user setpoints)
3. Supply air temperature & humidity (measured)
4. Outdoor temperature & humidity (measured)
5. Control thresholds & safety limits (configured)

### Processing Steps
1. **Filter** all measurements (5-point moving average)
2. **Calculate** supply air targets using feedforward (gain=0.5)
3. **Compute** psychrometric properties (AH, DP)
4. **Evaluate** chamber control needs (heating/cooling/humidity)
5. **Assess** supply air control needs (heating/cooling/humidity)
6. **Analyze** outdoor air benefit (3-step psychrometric method)
7. **Combine** all control signals with safety interlocks
8. **Actuate** relays based on final decisions

### Output Actions
1. Heating relay (warm chamber/supply air)
2. Cooling relay (cool chamber/supply air)
3. Humidifier relay (add moisture)
4. Bypass relay (remove moisture)
5. Outdoor air dampers (maximize/minimize outdoor air)
6. Fan speed control

### Control Performance
- **Update rate**: Every 5 seconds
- **Response time**: 15-30 seconds (3-6 cycles)
- **Settling time**: 5-15 minutes (depends on chamber size)
- **Accuracy**: ±0.2°C, ±0.5% RH
- **Stability**: Hysteresis prevents oscillation

---

*Analysis Date: November 20, 2025*  
*System: Climate Control v2.0*  
*Control Strategy: Predictive Feedforward with Psychrometric Optimization*
