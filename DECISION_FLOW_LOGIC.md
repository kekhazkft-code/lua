# Aging Chamber Control System - Decision Flow Logic

## System Overview

This document describes the complete decision flow logic for the aging chamber climate control system with psychrometric evaluation and humidification control.

**System Version**: v2.0 with Humidification Control
**Last Updated**: 2025-11-20
**Git Commit**: 6ed88a0

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Control Cycle Overview](#control-cycle-overview)
3. [Temperature Control Logic](#temperature-control-logic)
4. [Humidity Control Logic](#humidity-control-logic)
5. [Outdoor Air Evaluation (Psychrometric)](#outdoor-air-evaluation-psychrometric)
6. [Humidification Control](#humidification-control)
7. [Relay Outputs](#relay-outputs)
8. [Decision Flow Diagrams](#decision-flow-diagrams)

---

## System Architecture

### Input Variables

| Variable | ID | Description | Units |
|----------|------|-------------|-------|
| kamra_homerseklet | var[1] | Current chamber temperature | °C × 10 |
| kamra_para | var[2] | Current chamber humidity | % × 10 |
| kamra_cel_homerseklet | var[3] | Target chamber temperature | °C × 10 |
| kamra_cel_para | var[4] | Target chamber humidity | % × 10 |
| kulso_homerseklet | var[7] | Outdoor temperature | °C × 10 |
| kulso_para | var[8] | Outdoor humidity | % × 10 |
| befujt_homerseklet_akt1 | var[23] | Supply air temperature (measured) | °C × 10 |
| befujt_para_akt1 | var[24] | Supply air humidity (measured) | % × 10 |

### Output Relays

| Relay | ID | Description | Function |
|-------|------|-------------|----------|
| relay_warm | sbus[60] | Heating relay | Activates heating coils |
| relay_cool | sbus[52] | Cooling relay | Activates cooling/dehumidification |
| relay_humidifier | sbus[66] | **NEW** Humidifier relay | Activates humidification system |
| relay_add_air_max | sbus[61] | Outdoor air relay | Summer/winter outdoor air control |
| relay_reventon | sbus[62] | Main fan user control | Manual fan override |
| relay_add_air_save | sbus[63] | Additional air | Extra outdoor air mixing |
| relay_bypass_open | sbus[64] | Bypass damper | Humidity save mode bypass |
| relay_main_fan | sbus[65] | Main fan speed | 1-2 speed control |

### Control Flags

| Flag | Description |
|------|-------------|
| sum_wint_jel | Summer/winter mode selector |
| humi_save | Humidity save mode (bypass outdoor air) |
| sleep | Sleep mode (disable heating/cooling) |
| kamra_hibaflag | Chamber sensor fault flag |

---

## Control Cycle Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN CONTROL CYCLE                       │
│                  controlling() function                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ├─► 1. Read Sensor Values
                            │
                            ├─► 2. Calculate Supply Air Targets
                            │      (befujt_cel_homerseklet, befujt_cel_para)
                            │
                            ├─► 3. Chamber Temperature Control
                            │      (kamra_hutes, kamra_futes)
                            │
                            ├─► 4. Chamber Humidity Control
                            │      (kamra_para_hutes, kamra_para_futes_tiltas)
                            │
                            ├─► 5. Supply Air Temperature Control
                            │      (befujt_hutes, befujt_futes)
                            │
                            ├─► 6. Supply Air Humidity Control
                            │      (befujt_para_hutes)
                            │
                            ├─► 7. Outdoor Air Psychrometric Evaluation
                            │      (evaluate_outdoor_air_benefit)
                            │
                            ├─► 8. Humidification Control (NEW)
                            │      (kamra_humidification)
                            │
                            ├─► 9. Combine Signals
                            │      (warm, cool, dehumi, humidification)
                            │
                            └─► 10. Update Relays and UI
```

**Cycle Time**: 5 seconds (configurable via timer)

---

## Temperature Control Logic

### 1. Supply Air Target Calculation

```
IF sensor_fault:
    befujt_cel_temp = kamra_cel_temp
ELSE:
    befujt_cel_temp = kamra_cel_temp + (kamra_cel_temp - kamra_current_temp) / 2
```

**Purpose**: Predictive control - supply air target leads chamber target to accelerate convergence.

### 2. Chamber Temperature Control

```
┌────────────────────────────────────────────────────────────┐
│            CHAMBER TEMPERATURE HYSTERESIS                  │
└────────────────────────────────────────────────────────────┘

Cooling Logic:
    IF current > target + 2×deltaHi:
        kamra_hutes = TRUE    // Start cooling

    IF current < target + deltaHi:
        kamra_hutes = FALSE   // Stop cooling

Heating Logic:
    IF current < target - 2×deltaLo:
        kamra_futes = TRUE    // Start heating

    IF current > target - deltaLo:
        kamra_futes = FALSE   // Stop heating

Cooling Prohibition:
    IF current < target - 3×deltaLo:
        kamra_hutes_tiltas = TRUE   // Prohibit cooling

    IF current > target - deltaLo:
        kamra_hutes_tiltas = FALSE  // Allow cooling
```

**Hysteresis Bands**:
- `deltaHi`: Typically 1.0°C (10 in int×10 format)
- `deltaLo`: Typically 1.0°C (10 in int×10 format)

### 3. Supply Air Temperature Control

```
IF supply_temp > target + deltaHi:
    befujt_hutes = TRUE
    befujt_futes = FALSE

IF supply_temp > target:
    befujt_futes = FALSE

IF supply_temp < target:
    befujt_hutes = FALSE

IF supply_temp < target - deltaLo:
    befujt_futes = TRUE
    befujt_hutes = FALSE

IF supply_temp < target - 2×deltaLo:
    hutes_tiltas = TRUE    // Prohibit cooling

IF supply_temp < MIN_SUPPLY_AIR_TEMP (5°C):
    hutes_tiltas = TRUE    // Safety limit
```

---

## Humidity Control Logic

### 1. Chamber Humidity Control (Dehumidification)

```
┌────────────────────────────────────────────────────────────┐
│         CHAMBER HUMIDITY DEHUMIDIFICATION                  │
└────────────────────────────────────────────────────────────┘

Dehumidification (Cooling to condense):
    IF current_RH > target_RH + 2×deltaHi:
        kamra_para_hutes = TRUE    // Start dehumidification

    IF current_RH < target_RH + deltaHi:
        kamra_para_hutes = FALSE   // Stop dehumidification

Heating Prohibition (when humidity too low):
    IF current_RH < target_RH - 2×deltaLo:
        kamra_para_futes_tiltas = TRUE   // Prohibit heating

    IF current_RH > target_RH - deltaLo:
        kamra_para_futes_tiltas = FALSE  // Allow heating
```

**Note**: The "heating prohibition" prevents heating when humidity is already below target, which would further reduce RH.

### 2. Supply Air Humidity Control

```
IF supply_RH > target_RH + deltaHi:
    befujt_para_hutes = TRUE
    futes_tiltas = FALSE

IF supply_RH > target_RH:
    futes_tiltas = FALSE

IF supply_RH < target_RH:
    befujt_para_hutes = FALSE

IF supply_RH < target_RH - deltaLo:
    futes_tiltas = TRUE    // Prohibit heating
```

---

## Outdoor Air Evaluation (Psychrometric)

### Purpose

Determine if introducing outdoor air will help achieve target conditions more efficiently than mechanical heating/cooling.

### Algorithm

```
FUNCTION evaluate_outdoor_air_benefit():

    // STEP 1: Calculate absolute humidities (temperature-independent)
    chamber_AH = calculate_absolute_humidity(chamber_temp, chamber_RH)
    target_AH  = calculate_absolute_humidity(target_temp, target_RH)
    outdoor_AH = calculate_absolute_humidity(outdoor_temp, outdoor_RH)

    // STEP 2: Calculate mixed air properties (30% outdoor, 70% chamber)
    mixed_temp = chamber_temp × 0.70 + outdoor_temp × 0.30
    mixed_AH   = chamber_AH × 0.70 + outdoor_AH × 0.30

    // STEP 3: Project to target temperature
    // Calculate what RH would be at target temp with mixed AH
    projected_RH_at_target = calculate_rh(target_temp, mixed_AH)

    // STEP 4: Decision criteria
    temp_improves = |target_temp - mixed_temp| < |target_temp - chamber_temp|

    rh_acceptable = |projected_RH_at_target - target_RH| ≤ 5.0%

    ah_improves = |target_AH - mixed_AH| < |target_AH - chamber_AH|  // STRICT <

    // DECISION
    beneficial = temp_improves AND (ah_improves OR rh_acceptable)

    RETURN beneficial
```

### Activation Conditions

```
signal.add_air_max = outdoor_air_beneficial
                     AND (NOT sum_wint_jel)      // Winter mode only
                     AND (NOT humi_save)         // Not in humidity save mode
```

**Why Winter Mode Only?**
- In summer, cooling coils are more efficient than outdoor air
- In winter, cold outdoor air can provide "free cooling" and dehumidification

### Energy Savings

When outdoor air is beneficial:
- **Cooling savings**: ~3000W (compressor power saved)
- **Dehumidification savings**: Natural condensation from cold air vs. mechanical

---

## Humidification Control

### **NEW FEATURE** - Active Humidification

### Purpose

Actively add moisture when chamber is too dry. Independent of seasonal modes.

### Algorithm

```
FUNCTION humidification_control():

    IF kamra_hibaflag:   // Sensor fault
        kamra_humidification = FALSE
        RETURN

    // Calculate absolute humidities
    chamber_AH = calculate_absolute_humidity(chamber_temp, chamber_RH)
    target_AH  = calculate_absolute_humidity(target_temp, target_RH)

    // Project current AH to what RH would be at target temperature
    projected_RH_at_target = calculate_rh(target_temp, chamber_AH)

    // START CONDITION: Projected RH is 5% below target
    IF projected_RH_at_target < (target_RH - 5.0):
        kamra_humidification = TRUE

    // STOP CONDITION: Current AH meets or exceeds target AH
    IF chamber_AH >= target_AH:
        kamra_humidification = FALSE

    signal.humidification = kamra_humidification
```

### Decision Flowchart

```
                    START HUMIDIFICATION EVALUATION
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Sensor Fault?       │
                    └──────────────────────┘
                          YES │  │ NO
                  ┌───────────┘  └────────────┐
                  ▼                            ▼
         ┌────────────────┐        ┌─────────────────────────┐
         │ Humidifier OFF │        │ Calculate chamber_AH     │
         └────────────────┘        │ Calculate target_AH      │
                                   │ Calculate projected_RH   │
                                   └─────────────────────────┘
                                              │
                                              ▼
                              ┌──────────────────────────────┐
                              │ projected_RH < target_RH - 5%?│
                              └──────────────────────────────┘
                                   YES │         │ NO
                         ┌─────────────┘         └──────────┐
                         ▼                                   ▼
              ┌──────────────────┐                ┌────────────────┐
              │ START Humidifier │                │ chamber_AH >=  │
              │ (set TRUE)       │                │   target_AH?   │
              └──────────────────┘                └────────────────┘
                                                   YES │     │ NO
                                         ┌─────────────┘     └─────┐
                                         ▼                          ▼
                              ┌──────────────────┐      ┌───────────────┐
                              │ STOP Humidifier  │      │ No change     │
                              │ (set FALSE)      │      │ (maintain     │
                              └──────────────────┘      │  current)     │
                                                        └───────────────┘
```

### Key Features

1. **Temperature Compensation**: Uses projected RH at target temperature for accurate start decision
2. **Absolute Humidity Stop**: Stops based on AH to prevent over-humidification
3. **Independent Operation**: Works in both summer and winter modes
4. **5% Hysteresis**: Prevents rapid on/off cycling

### Example Scenarios

**Scenario 1: Winter - Low Humidity**
```
Current: 5°C, 50% RH → AH = 0.034 g/m³
Target:  10°C, 85% RH → AH = 0.080 g/m³
Projected RH at 10°C = 36.2%

Decision: START humidification
Reason: 36.2% < (85% - 5%) = 80%
```

**Scenario 2: Approaching Target**
```
Current: 5°C, 90% RH → AH = 0.061 g/m³
Target:  10°C, 85% RH → AH = 0.080 g/m³
Projected RH at 10°C = 64.5%

Decision: CONTINUE humidification
Reason: AH not yet at target (0.061 < 0.080)
```

**Scenario 3: Target Reached**
```
Current: 10°C, 85% RH → AH = 0.080 g/m³
Target:  10°C, 85% RH → AH = 0.080 g/m³

Decision: STOP humidification
Reason: chamber_AH >= target_AH
```

---

## Relay Outputs

### Combined Signal Logic

```
warm = NOT(kamra_para_futes_tiltas OR futes_tiltas)
       AND (kamra_futes OR befujt_futes)
       AND (NOT sleep)

cool = NOT(kamra_hutes_tiltas)
       AND (kamra_hutes OR befujt_hutes OR kamra_para_hutes)

cool_rel = cool AND (NOT sleep) AND sum_wint_jel

warm_dis = kamra_para_futes_tiltas OR futes_tiltas

dehumi = kamra_para_hutes OR befujt_para_hutes

cool_dis = kamra_hutes_tiltas

humidification = kamra_humidification   // NEW

add_air_max = outdoor_air_beneficial AND (NOT sum_wint_jel)

reventon = humi_save

add_air_save = humi_save

bypass_open = humi_save OR (cool AND NOT dehumi)

main_fan = sum_wint_jel
```

### Relay Activation Table

| Condition | Warm | Cool | Humidifier | Add Air | Dehumi |
|-----------|------|------|------------|---------|--------|
| **Too Cold** | ✅ ON | ❌ OFF | ⚪ - | ⚪ - | ❌ OFF |
| **Too Hot** | ❌ OFF | ✅ ON | ⚪ - | ⚪ (eval) | ⚪ - |
| **Too Dry** | ⚪ - | ❌ OFF | ✅ **ON** | ⚪ - | ❌ OFF |
| **Too Humid** | ❌ OFF | ✅ ON | ❌ **OFF** | ⚪ (eval) | ✅ ON |
| **Cold + Dry (Winter)** | ✅ ON | ❌ OFF | ✅ **ON** | ⚪ (eval) | ❌ OFF |
| **Hot + Humid (Summer)** | ❌ OFF | ✅ ON | ❌ **OFF** | ❌ OFF | ✅ ON |
| **Sleep Mode** | ❌ OFF | ❌ OFF | ✅ **ON** | ⚪ (eval) | ❌ OFF |

⚪ = Depends on conditions
✅ = Active
❌ = Inactive
**Bold** = New humidification feature

---

## Decision Flow Diagrams

### Master Control Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   MASTER CONTROL FLOW                       │
└─────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
        ┌───────▼────────┐    ┌────────▼────────┐
        │  TEMPERATURE   │    │    HUMIDITY     │
        │    CONTROL     │    │    CONTROL      │
        └───────┬────────┘    └────────┬────────┘
                │                      │
                │         ┌────────────┴────────────┐
                │         │                         │
                │    ┌────▼──────┐         ┌────────▼────────┐
                │    │ DEHUMI    │         │  HUMIDIFIER     │
                │    │ (Cooling) │         │  (Add Moisture) │
                │    └────┬──────┘         └────────┬────────┘
                │         │                         │
                └─────────┴─────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │  OUTDOOR AIR   │
                    │  EVALUATION    │
                    │ (Psychrometric)│
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │  RELAY OUTPUT  │
                    │   ACTIVATION   │
                    └────────────────┘
```

### Temperature Control Flow

```
                        TEMPERATURE CONTROL
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
    ┌────▼─────┐         ┌────▼─────┐         ┌────▼─────┐
    │ CHAMBER  │         │  SUPPLY  │         │ OUTDOOR  │
    │   TEMP   │         │   TEMP   │         │   TEMP   │
    └────┬─────┘         └────┬─────┘         └────┬─────┘
         │                    │                     │
         │    TOO COLD?       │                     │
         ├────YES────► HEAT   │                     │
         │                    │                     │
         │    TOO HOT?        │                     │
         ├────YES────► COOL   │                     │
         │                    │                     │
         │                    │    OUTDOOR BETTER?  │
         │                    └────YES──────────────┤
         │                                          │
         └──────────────┬───────────────────────────┘
                        │
                   ┌────▼─────┐
                   │  COMBINE │
                   │  SIGNALS │
                   └────┬─────┘
                        │
                   ┌────▼─────┐
                   │  RELAYS  │
                   └──────────┘
```

### Humidity Control Flow

```
                        HUMIDITY CONTROL
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
    ┌────▼─────┐         ┌────▼─────┐         ┌────▼─────┐
    │ CHAMBER  │         │  SUPPLY  │         │ OUTDOOR  │
    │    RH    │         │    RH    │         │    RH    │
    └────┬─────┘         └────┬─────┘         └────┬─────┘
         │                    │                     │
         │    TOO WET?        │                     │
         ├────YES────► DEHUMI │                     │
         │           (COOL)   │                     │
         │                    │                     │
         │    TOO DRY?        │                     │
         ├────YES──► HUMIDIFY │                     │
         │           (NEW)    │                     │
         │                    │    OUTDOOR BETTER?  │
         │                    └────YES──────────────┤
         │                                          │
         └──────────────┬───────────────────────────┘
                        │
                   ┌────▼─────┐
                   │  COMBINE │
                   │  SIGNALS │
                   └────┬─────┘
                        │
                   ┌────▼─────┐
                   │  RELAYS  │
                   │  - Cool  │
                   │  - Humid │
                   └──────────┘
```

### Psychrometric Outdoor Air Decision

```
                    OUTDOOR AIR EVALUATION
                            │
                    ┌───────▼────────┐
                    │ Calculate AH   │
                    │ for all points │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │ Calculate      │
                    │ Mixed Air      │
                    │ (70% + 30%)    │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │ Project RH     │
                    │ at Target Temp │
                    └───────┬────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
      ┌───────▼────────┐          ┌──────▼──────┐
      │ Temp Improves? │          │ RH/AH Check │
      └───────┬────────┘          └──────┬──────┘
          YES │                       YES │
              │                           │
              └─────────────┬─────────────┘
                            │
                     ┌──────▼──────┐
                     │  BENEFICIAL │
                     │  Use Outdoor│
                     └──────┬──────┘
                            │
                     ┌──────▼──────┐
                     │ Activate    │
                     │ Add Air Max │
                     │ Relay       │
                     └─────────────┘
```

---

## Priority and Conflict Resolution

### Control Priority (Highest to Lowest)

1. **Safety Limits**
   - MIN_SUPPLY_AIR_TEMP (5°C)
   - Sensor fault protection

2. **Sleep Mode**
   - Disables heating and cooling
   - Allows humidification to continue

3. **Temperature Control**
   - Heating/cooling take precedence over humidity
   - Temperature prohibitions override requests

4. **Humidity Control**
   - Dehumidification via cooling
   - **NEW**: Active humidification when too dry

5. **Energy Optimization**
   - Outdoor air when beneficial
   - Free cooling/dehumidification

### Conflict Resolution Rules

**Heating vs. Humidity Prohibition**
```
IF kamra_para_futes_tiltas == TRUE:
    warm = FALSE    // Humidity prohibition overrides
```

**Cooling vs. Temperature Prohibition**
```
IF kamra_hutes_tiltas == TRUE:
    cool = FALSE    // Temperature prohibition overrides
```

**Humidification vs. Dehumidification**
```
IF dehumi == TRUE:
    humidification = FALSE    // Cannot do both simultaneously
```

**Outdoor Air vs. Modes**
```
IF sum_wint_jel == TRUE:    // Summer mode
    add_air_max = FALSE     // Disable outdoor air

IF humi_save == TRUE:       // Humidity save mode
    add_air_max = FALSE     // Disable outdoor air
```

---

## Timing and Hysteresis

### Control Cycle Timing

- **Main cycle**: 5 seconds
- **Sensor averaging**: 5 samples (moving average)
- **Simulation mode**: Real-time override

### Hysteresis Values

**Temperature**:
- deltaHi: 1.0°C (prevents rapid cycling when cooling)
- deltaLo: 1.0°C (prevents rapid cycling when heating)

**Humidity**:
- deltaHi: 1.0% RH (dehumidification)
- deltaLo: 1.0% RH (heating prohibition)
- Humidifier start: 5.0% RH below target
- Humidifier stop: When AH ≥ target AH

**Propagation Thresholds**:
- Temperature change: 0.2°C minimum
- Humidity change: 0.3% RH minimum

---

## Error Handling

### Sensor Fault Detection

```
IF kamra_hibaszam1 <= 0:
    kamra_hibaflag = TRUE

    // Fallback actions:
    befujt_cel_temp = kamra_cel_temp     // Use target directly
    befujt_cel_para = kamra_cel_para
    kamra_hutes = FALSE
    kamra_futes = FALSE
    kamra_para_hutes = FALSE
    kamra_humidification = FALSE
```

### Safety Overrides

```
IF befujt_temp < MIN_SUPPLY_AIR_TEMP (5°C):
    hutes_tiltas = TRUE    // Prevent freezing
    befujt_futes = TRUE    // Force heating
```

---

## Summary

The aging chamber control system uses a multi-layered approach:

1. **Predictive Target Calculation**: Supply air targets lead chamber targets
2. **Hysteresis Control**: Prevents rapid cycling with dead bands
3. **Psychrometric Evaluation**: Scientific outdoor air benefit calculation
4. **NEW: Active Humidification**: Intelligent moisture addition when too dry
5. **Priority Management**: Safety > Sleep > Temperature > Humidity > Optimization
6. **Intelligent Propagation**: Only updates when meaningful changes occur

**Key Innovations**:
- Three-step psychrometric method (AH → mixed → project RH at target temp)
- Strict improvement logic (`<` not `<=`) prevents unnecessary outdoor air use
- **NEW**: Temperature-compensated humidification start/stop logic
- Independent humidification (works in all modes)

**Energy Efficiency**:
- Outdoor air provides "free" cooling/dehumidification in winter
- Psychrometric evaluation prevents wasteful mechanical operations
- **NEW**: Precise humidification control prevents over-humidification

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-20 | v2.0 | Added humidification control with psychrometric logic |
| 2025-11-19 | v1.2 | Fixed critical bugs in simulation and psychrometric logic |
| 2025-11-18 | v1.1 | Added psychrometric outdoor air evaluation |
| 2025-11-17 | v1.0 | Initial system with basic temperature/humidity control |

---

**END OF DOCUMENT**
