# Aging Chamber Control System - Code Analysis & Review

**Date:** November 19, 2025  
**Device:** Tech Sinum (Modbus RTU)  
**Code Files:** 4 Lua scripts (Apar2_0, sensor_init, Apar3_4, Apar4_0)

---

## Executive Summary

This is a sophisticated climate control system for an aging chamber (érlelő kamra) that maintains precise temperature and humidity conditions. The system uses Modbus RTU communication to read sensors and control multiple relays for heating, cooling, ventilation, and humidity management.

**Overall Assessment:** 
- ✅ Functional and well-structured for its purpose
- ⚠️ Contains some code quality issues and opportunities for improvement
- ⚠️ Limited error handling and documentation
- ⚠️ Some commented-out code suggests ongoing development

---

## System Architecture

### 1. **Main Components**

#### Hardware:
- **Sensors:**
  - Chamber temperature & humidity (kamra)
  - Supply air temperature & humidity (befújt)
  - External/outdoor temperature & humidity (külső)
  - Safety temperature sensor (biztonsági)
  - Weight sensors (súly mérés) - for material monitoring

- **Relays (8 total):**
  - `relay_warm` (sbus[60]) - Heating relay
  - `relay_cool` (sbus[52]) - Cooling relay
  - `relay_add_air_max` (sbus[61]) - Summer/winter mode switch
  - `relay_reventon` (sbus[62]) - Main fan user setting
  - `relay_add_air_save` (sbus[63]) - Additional air supply
  - `relay_bypass_open` (sbus[64]) - Humidity saving relay (bypass open)
  - `relay_main_fan` (sbus[65]) - Main fan speed (1-2 levels)
  - `relay_sleep` (sbus[53]) - Rest period relay

#### Software:
- **Communication:** Modbus RTU over RS485
- **Variables:** 45+ global variables for state management
- **Control Loop:** 5-second update cycle

---

## Code Structure Analysis

### File: **Apar2_0.lua** (Main Controller - 709 lines)

#### Key Functions:

1. **`CustomDevice:onInit()`** (Lines 52-66)
   - Initializes Modbus communication parameters
   - Sets up baud rate, parity, stop bits, slave address
   - **Issue:** Hard-coded error counter initialization `befujt_hibaszam1:setValue(3,true)`

2. **`CustomDevice:controlling()`** (Lines 231-470)
   - **THE HEART OF THE SYSTEM** - Main control algorithm
   - Calculates target values for supply air based on chamber conditions
   - Implements hysteresis-based temperature control
   - Manages heating/cooling/humidity control logic
   
3. **Temperature/Humidity Calculations:**
   - `saturation_vapor_pressure()` (Line 133)
   - `calculate_absolute_humidity()` (Line 138)
   - `calculate_rh()` (Line 145)
   - `calc_dew_point()` (Line 175)
   - Uses Magnus-Tetens formula for psychrometric calculations

4. **`mozgoatlag()`** (Line 474) - Moving Average Filter
   - Filters sensor readings using a sliding window
   - Reduces noise in temperature/humidity measurements
   - Default: 3 measurements per average

5. **`CustomDevice:onEvent()`** (Lines 500-634)
   - Main event handler
   - Processes Modbus responses
   - Updates UI elements
   - Handles variable changes

---

## Control Logic Deep Dive

### Target Value Calculation (Lines 318-327)

```lua
-- Supply air target calculated as:
befujt_cel_para = kamra_cel_para + (kamra_cel_para - kamra_para)/2
befujt_cel_homerseklet = kamra_cel_homerseklet + (kamra_cel_homerseklet - kamra_homerseklet)/2
```

**Logic:** The supply air target is set to chamber target PLUS half the error between target and actual.
- If chamber is too cold → supply air target increases
- If chamber is too humid → supply air humidity target increases
- **This is a proportional control element**

### Hysteresis Control (Lines 338-396)

The system uses **dual-hysteresis** control with separate thresholds:

#### Temperature Control:
```
deltahi_kamra_homerseklet = upper deadband (default 10 = 1.0°C)
deltalo_kamra_homerseklet = lower deadband (default 10 = 1.0°C)
```

**Cooling Activation:**
- Starts: `kamra_temp > target + 2*deltahi` 
- Stops: `kamra_temp < target + deltahi`

**Heating Activation:**
- Starts: `kamra_temp < target - 2*deltalo`
- Stops: `kamra_temp > target - deltalo`

**Cooling Lock:**
- Activates: `kamra_temp < target - 3*deltalo` (prevents cooling when too cold)

#### Humidity Control:
Similar logic for humidity with `deltahi_kamra_para` and `deltalo_kamra_para`

---

## Key Variables (stored in variable[])

| ID | Variable | Type | Purpose |
|----|----------|------|---------|
| 1 | kamra_homerseklet_v1 | int*10 | Chamber temperature |
| 2 | kamra_para_v1 | int*10 | Chamber humidity |
| 3 | kamra_cel_homerseklet_v1 | int*10 | Chamber target temperature |
| 4 | kamra_cel_para_v1 | int*10 | Chamber target humidity |
| 5 | befujt_cel_homerseklet_v1 | int*10 | Supply air target temp |
| 6 | befujt_cel_para_v1 | int*10 | Supply air target humidity |
| 17-22 | *_table1 | table | Moving average buffers |
| 23-24 | befujt_homerseklet_akt1, befujt_para_akt1 | int*10 | Filtered supply air readings |
| 29-31 | *_hibaszam1 | int | Error counters for sensors |
| 33 | constansok1 | table | Configuration constants |
| 34 | signals1 | table | Control signals/flags |
| 42 | ah_dp_table1 | table | Absolute humidity & dew point values |

**Note:** All temperature/humidity values are stored as `int*10` (e.g., 255 = 25.5°C)

---

## Issues & Concerns

### 🔴 **Critical Issues:**

1. **Hard-coded Magic Numbers**
   - Line 384: `if befujt_mert_homerseklet < 60 then hutes_tiltas = true`
   - 6°C minimum supply air temp is hard-coded (should be in constansok1)

2. **Incomplete Error Handling**
   - Modbus timeout handling decrements error counter but doesn't disable faulty sensors
   - No recovery mechanism when error count reaches zero
   - Lines 575-582: Only prints error, doesn't take corrective action

3. **Redundant Code**
   - Lines 427-440: Commented-out relay control code duplicates `setrelay()` function
   - Multiple commented sections suggest incomplete refactoring

### ⚠️ **Medium Priority Issues:**

4. **Inconsistent Naming Convention**
   - Mix of Hungarian (kamra_homerseklet) and English (relay_warm)
   - Makes code harder to maintain for international developers

5. **Missing Safety Checks**
   - No maximum temperature limit enforcement
   - No sensor validation (range checking)
   - Could accept impossible values (e.g., 200°C or -50°C)

6. **Moving Average Implementation**
   - Line 489: `atlag_ertek:setValue((sum/#instab)+0.5, true)` 
   - Adding 0.5 for rounding, but should use `math.floor()` or `math.ceil()` explicitly

7. **Variable Scope Issues**
   - Many variables defined at file level that could be local
   - Example: Lines 38-46 relay definitions should be in a table

### ℹ️ **Minor Issues:**

8. **Code Comments**
   - Most comments are in Hungarian, limiting international collaboration
   - Critical sections lack explanatory comments

9. **Debug Prints**
   - Multiple `print()` statements (Lines 517, 494, 563, etc.)
   - Should use a proper logging system with levels (DEBUG, INFO, WARN, ERROR)

10. **Statistics Code Commented Out**
    - Lines 91-99: `statpush()` function disabled
    - Suggests incomplete feature or debugging

---

## Psychrometric Calculations

The system implements proper psychrometric formulas:

### Saturation Vapor Pressure (Magnus-Tetens)
```lua
SVP = 6.112 * exp((17.67 * T) / (T + 243.5))
```

### Absolute Humidity
```lua
AH = (RH/100 * SVP * 2.1674) / (T + 273.15)
```

### Dew Point
```lua
γ = (17.62 * T)/(243.12 + T) + ln(RH/100)
DP = (243.12 * γ)/(17.62 - γ)
```

**✅ These calculations are mathematically correct and properly implemented.**

---

## Control Algorithm Assessment

### ✅ **Strengths:**

1. **Cascade Control Structure:**
   - Chamber setpoint → Supply air target → Equipment control
   - This is proper HVAC control design

2. **Hysteresis Implementation:**
   - Prevents rapid cycling (relay chatter)
   - Different thresholds for activation and deactivation

3. **Multiple Operating Modes:**
   - Summer/Winter mode switching
   - Humidity saving mode
   - Sleep/rest periods for the chamber

4. **Sensor Filtering:**
   - 3-point moving average reduces noise
   - Good balance between responsiveness and stability

### ⚠️ **Weaknesses:**

1. **No Integral Action:**
   - Pure ON/OFF control with hysteresis
   - Cannot eliminate steady-state error
   - For aging chambers, this may cause ±1°C variation

2. **No Feedforward Control:**
   - System reacts only to chamber conditions
   - Could use external weather data to anticipate changes

3. **Fixed Hysteresis Values:**
   - Constants are in variable[33] but no automatic tuning
   - Different products may need different settings

4. **No Rate Limiting:**
   - Equipment can cycle as fast as conditions allow
   - Should implement minimum ON/OFF times for equipment protection

---

## Sensor_init.lua Analysis (492 lines)

This file handles:
- Variable initialization
- Weight sensor processing
- Sleep cycle management
- Device name verification
- Relay state management functions

### Key Functions:

1. **`pihenoido()`** (Line 99) - Sleep Period Calculator
   - Calculates active vs. passive time in aging cycles
   - Used for certain cheese types that need rest periods

2. **`suly_check()`** (Line 140) - Weight Monitoring
   - Tracks material weight loss during aging
   - Important for quality control

3. **Helper Functions:**
   - `devcheck()` - Verifies device names match expected values
   - `devset()` - Combined relay + text output update
   - `txtset()` - Text display update only

### Issues:
- Contains multiple commented sections for different installations (KK02, KK03, KK04)
- Suggests code is being reused across multiple chambers without proper abstraction

---

## File Organization

```
aging_chamber_Apar2_0.lua  (25.8 KB) - Main sensor device
    ├─ Modbus communication
    ├─ Psychrometric calculations  
    ├─ Main control algorithm
    └─ UI update functions

aging_chamber_sensor_init.lua (19.0 KB) - System initialization
    ├─ Variable setup
    ├─ Weight sensor handling
    └─ Helper functions

aging_chamber_Apar3_4.lua (13.2 KB) - Sensor variant 3
    └─ (Similar structure to Apar2_0)

aging_chamber_Apar4_0.lua (9.3 KB) - Sensor variant 4
    └─ (Similar structure to Apar2_0)
```

---

## Recommendations

### 🔥 **High Priority:**

1. **Add Safety Limits**
   ```lua
   local TEMP_MAX = 400  -- 40°C maximum
   local TEMP_MIN = -100 -- -10°C minimum
   local HUM_MAX = 1000  -- 100% maximum
   local HUM_MIN = 0     -- 0% minimum
   ```

2. **Implement Proper Error Handling**
   ```lua
   if befujt_hibaszam1:getValue() <= 0 then
       -- Disable heating/cooling using this sensor
       -- Switch to backup control mode
       -- Generate alarm notification
   end
   ```

3. **Add Equipment Protection**
   ```lua
   local MIN_CYCLE_TIME = 300000  -- 5 minutes minimum between cycles
   local last_relay_change = {}
   -- Check time since last change before switching
   ```

4. **Validate Sensor Readings**
   ```lua
   function validate_sensor(value, min, max, sensor_name)
       if value < min or value > max then
           log_error("Invalid " .. sensor_name .. " reading: " .. value)
           increment_error_counter(sensor_name)
           return false
       end
       return true
   end
   ```

### ⚙️ **Medium Priority:**

5. **Create Configuration Management System**
   - Move all magic numbers to configuration table
   - Add config validation on startup
   - Allow runtime parameter adjustment with limits

6. **Implement Proper Logging**
   ```lua
   local LOG_LEVEL = { DEBUG=1, INFO=2, WARN=3, ERROR=4 }
   function log(level, message)
       if level >= current_log_level then
           print(os.date() .. " [" .. level .. "] " .. message)
       end
   end
   ```

7. **Add Alarm System**
   - Temperature out of range
   - Humidity out of range
   - Sensor communication failure
   - Equipment malfunction

8. **Improve Code Organization**
   - Separate control logic from UI updates
   - Create modules for psychrometric calculations
   - Use object-oriented structure for sensors

### 📚 **Low Priority:**

9. **Documentation**
   - Add function headers with parameter descriptions
   - Create system operation manual
   - Document control algorithm tuning procedures

10. **Performance Optimization**
    - Cache frequently accessed variable values
    - Reduce redundant calculations
    - Profile and optimize hot paths

---

## Control Tuning Guide

For optimal performance, the following constants in `variable[33]` should be tuned:

| Parameter | Default | Purpose | Tuning Advice |
|-----------|---------|---------|---------------|
| deltahi_kamra_homerseklet | 10 (1.0°C) | Chamber temp upper deadband | Increase for less frequent cycles, decrease for tighter control |
| deltalo_kamra_homerseklet | 10 (1.0°C) | Chamber temp lower deadband | Same as above |
| deltahi_kamra_para | 15 (1.5%) | Chamber humidity upper deadband | Increase if humidity cycles too often |
| deltalo_kamra_para | 10 (1.0%) | Chamber humidity lower deadband | Same as above |
| deltahi_befujt_homerseklet | 20 (2.0°C) | Supply air temp upper deadband | Larger than chamber values - supply air is more dynamic |
| deltalo_befujt_homerseklet | 15 (1.5°C) | Supply air temp lower deadband | Same as above |

**Tuning Process:**
1. Start with conservative (larger) deadbands
2. Monitor cycle frequency (should be > 5 minutes)
3. Gradually tighten deadbands if stability is good
4. Watch for equipment wear (compressor cycles)

---

## Security Considerations

### Current State:
- ❌ No authentication on Modbus communication
- ❌ No input validation from UI elements
- ❌ No checksum verification on critical values
- ⚠️ `blockade_pin_code_enabled: false` - UI not protected

### Recommendations:
1. Implement PIN protection for setpoint changes
2. Add value range validation for all user inputs
3. Consider encrypting configuration data
4. Log all setpoint changes with timestamps

---

## Performance Analysis

### Update Cycle:
- **Timer:** 5000ms (5 seconds) - Line 512
- **Modbus Read:** 2 registers from address 1 - Line 674
- **Processing Time:** < 10ms (based on profiler remnants)

### Resource Usage:
- **Variables:** 45 global variables
- **Memory:** Moderate (tables for moving averages)
- **CPU:** Low (simple calculations, no heavy loops)

**✅ Performance is adequate for the application**

---

## Conclusion

### Overall Grade: **B+ (Good, with room for improvement)**

#### What Works Well:
- ✅ Solid control algorithm with proper hysteresis
- ✅ Accurate psychrometric calculations
- ✅ Sensor filtering reduces noise
- ✅ Multiple operating modes for different seasons
- ✅ Clear structure and logical flow

#### What Needs Improvement:
- ❌ Error handling is incomplete
- ❌ Safety limits are not enforced
- ❌ Documentation is minimal
- ❌ Code organization could be better
- ❌ Hard-coded values should be configurable

#### Critical Next Steps:
1. Add comprehensive error handling
2. Implement safety limits and alarms
3. Add equipment protection (minimum cycle times)
4. Improve logging for troubleshooting
5. Create operator manual

This is a functional aging chamber control system that works in practice but would benefit from additional safety features, better error handling, and improved maintainability before deployment in critical production environments.

---

**Reviewer Notes:**
- Code appears to be in active development (many commented sections)
- Suggests multiple installations with slight variations
- Would benefit from proper version control and configuration management
- Psychrometric calculations are a strong point
- Control logic is sound but could be more sophisticated (PID instead of ON/OFF)

