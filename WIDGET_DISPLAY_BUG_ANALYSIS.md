# Widget Display Bug Analysis

## Issue Report
**Problem**: Widget sliders (temperature and humidity targets) do not update to reflect actual stored values after device startup or when values are changed from another device.

**User Description**: "values displayed on the widget screen did not match the real target values"

---

## Root Cause Analysis

### Bug #1: Missing Slider Initialization in `onInit()`

**Location**: `aging_chamber_Apar2_0_REFACTORED.lua:58-72`

**Current Code**:
```lua
function CustomDevice:onInit()
  print('init')
  self:setValue('status', 'unknown')

  local com = self:c()
  self:getElement('baudrate'):setValue('value', tostring(com:getValue('baud_rate')), true)
  self:getElement('parity'):setValue('value', com:getValue('parity'), true)
  self:getElement('stopbits'):setValue('value', com:getValue('stop_bits'), true)
  self:getElement('slave_id'):setValue('value', tostring(com:getValue('slave_address')), true)

  local xceiver = com:getValue('associations.transceiver')
  self:getElement('xceiver'):setValue('associations.selected', xceiver, true)
  befujt_hibaszam1:setValue(3,true)

end
```

**Problem**: The function initializes various UI elements (baudrate, parity, etc.) but **never initializes the slider widgets** (slider_0 and slider_1) with the current target values.

**Impact**: When the device starts up, the sliders show default values (likely 0 or last cached value) instead of the actual target values stored in variables 3 and 4.

---

### Bug #2: Backwards Logic in Event Handler

**Location**: `aging_chamber_Apar2_0_REFACTORED.lua:571-578`

**Current Code**:
```lua
elseif source.id == 3 then  -- kamra_cel_homerseklet_v1 changed
  local celh = self:getElement("slider_1"):getValue("value")  -- ← READS slider
  print("slider_1", celh)
  kamra_cel_homerseklet_v1:setValue(celh*10, true)  -- ← OVERWRITES variable with slider value!

  local celp = self:getElement("slider_0"):getValue("value")  -- ← READS slider
  print("slider_0", celp)
  kamra_cel_para_v1:setValue(celp*10, true)  -- ← OVERWRITES variable with slider value!

  print(event.type, source.id, source.type, det, "p3 - target setpoint changed")
```

**Problem**: This event handler is triggered when `kamra_cel_homerseklet_v1` (variable 3) **changes from another device**. The correct behavior should be to **update the sliders to reflect the new variable values**. Instead, the code:

1. **Reads the OLD values from the sliders**
2. **Overwrites the variables** with those old slider values
3. **Never updates the slider displays**

This completely defeats the purpose of multi-device synchronization!

**Impact**: When another device changes the target temperature/humidity, this device:
- Receives the new values in variables 3 and 4
- Immediately overwrites them with the old slider values
- Never updates the sliders to show the new values
- Result: Display shows old values, variables contain old values, new values are lost

---

## Flow Analysis

### Scenario 1: Device Startup

```
1. Device powers on
2. onInit() called
3. Variables loaded from storage:
   - kamra_cel_homerseklet_v1 (var 3) = 220 (22.0°C)
   - kamra_cel_para_v1 (var 4) = 650 (65.0%)
4. UI elements initialized:
   ✓ baudrate, parity, stopbits, slave_id
   ✗ slider_0 (humidity) - NOT initialized
   ✗ slider_1 (temperature) - NOT initialized
5. Result:
   - Variables contain correct values (220, 650)
   - Sliders show default values (0, 0) or cached values
   - MISMATCH between stored values and displayed values
```

### Scenario 2: Remote Device Changes Target

```
1. Another device changes kamra_cel_homerseklet_v1 from 220 → 250
2. Variable 3 propagates to this device
3. Event triggered: lua_variable_state_changed (source.id = 3)
4. Event handler at line 571 executes:
   - Reads slider_1 value: 22.0 (old value)
   - OVERWRITES variable 3: 220 (22.0°C * 10)
   - Reads slider_0 value: 65.0 (old value)
   - OVERWRITES variable 4: 650 (65.0% * 10)
5. Result:
   - New value (250) is LOST
   - Variables reverted to old values (220, 650)
   - Sliders still show old values (22.0, 65.0)
   - Other device thinks this device accepted new value, but it didn't
```

### Scenario 3: Local User Changes Slider

```
1. User moves slider_1 to 25.0°C
2. on_Target_TemperatureChange() called
3. Validation check: |250 - 220| < 19? NO
4. Executes:
   - kamra_cel_homerseklet_v1:setValue(250, false)  ← Propagates
   - kamra_cel_homerseklet_v1:save(false)
   - ah_dp_cel_szamol() updates dew point/absolute humidity displays
5. Variable change triggers event (source.id = 3)
6. Event handler at line 571 executes (BUG #2)
7. Result:
   - Local change works initially
   - But event handler immediately reads and overwrites
   - Creates potential race condition
```

---

## Code Locations

### Slider Widget Names
- `slider_0` - Humidity target (%)
- `slider_1` - Temperature target (°C)

### Variables
- `kamra_cel_homerseklet_v1` (variable 3) - Target temperature (int * 10)
- `kamra_cel_para_v1` (variable 4) - Target humidity (int * 10)

### Event Handlers
- `onInit()` - Line 58: Device initialization
- `on_Target_TemperatureChange()` - Line 623: User changes temperature slider
- `on_Target_HumidityChange()` - Line 636: User changes humidity slider
- `lua_variable_state_changed` - Line 552: Variable changed (from remote device or local)

### Display Update Locations
**Currently only 2 places update sliders:**
1. Line 631: `on_Target_TemperatureChange()` - ELSE branch (when change rejected)
2. Line 646: `on_Target_HumidityChange()` - ELSE branch (when change rejected)

**Missing slider updates:**
- ✗ onInit() - No slider initialization
- ✗ online() - No slider refresh
- ✗ Event handler (line 571) - Backwards logic

---

## Recommended Fixes

### Fix #1: Initialize Sliders in `onInit()`

**Add to end of `onInit()` function (after line 70):**

```lua
function CustomDevice:onInit()
  print('init')
  self:setValue('status', 'unknown')

  local com = self:c()
  self:getElement('baudrate'):setValue('value', tostring(com:getValue('baud_rate')), true)
  self:getElement('parity'):setValue('value', com:getValue('parity'), true)
  self:getElement('stopbits'):setValue('value', com:getValue('stop_bits'), true)
  self:getElement('slave_id'):setValue('value', tostring(com:getValue('slave_address')), true)

  local xceiver = com:getValue('associations.transceiver')
  self:getElement('xceiver'):setValue('associations.selected', xceiver, true)
  befujt_hibaszam1:setValue(3,true)

  -- FIX: Initialize sliders with current target values
  local temp_target = kamra_cel_homerseklet_v1:getValue()
  local humi_target = kamra_cel_para_v1:getValue()
  self:getElement('slider_1'):setValue('value', temp_target/10, true)
  self:getElement('slider_0'):setValue('value', humi_target/10, true)

  -- Also initialize dew point/absolute humidity displays
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))

end
```

---

### Fix #2: Correct Event Handler Logic

**Replace lines 571-578 with:**

```lua
elseif source.id == 3 then  -- kamra_cel_homerseklet_v1 changed from remote device
  -- FIX: Update sliders to match the NEW variable values
  local celh = kamra_cel_homerseklet_v1:getValue()
  local celp = kamra_cel_para_v1:getValue()

  self:getElement("slider_1"):setValue("value", celh/10, true)
  self:getElement("slider_0"):setValue("value", celp/10, true)

  -- Update dew point and absolute humidity displays
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))

  print(event.type, source.id, source.type, det, "p3 - target setpoint changed, sliders updated")
```

**OR if variable 4 has its own event handler:**

```lua
elseif source.id == 3 then  -- kamra_cel_homerseklet_v1 changed
  local celh = kamra_cel_homerseklet_v1:getValue()
  self:getElement("slider_1"):setValue("value", celh/10, true)
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))
  print(event.type, source.id, source.type, det, "p3 - temperature target changed, slider updated")

elseif source.id == 4 then  -- kamra_cel_para_v1 changed
  local celp = kamra_cel_para_v1:getValue()
  self:getElement("slider_0"):setValue("value", celp/10, true)
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))
  print(event.type, source.id, source.type, det, "p4 - humidity target changed, slider updated")
```

---

## Alternative: Comprehensive Refresh Function

**Create a helper function to refresh all target displays:**

```lua
-- Helper function to refresh target value displays
local function refresh_target_displays(self)
  local temp_target = kamra_cel_homerseklet_v1:getValue()
  local humi_target = kamra_cel_para_v1:getValue()

  -- Update sliders
  self:getElement('slider_1'):setValue('value', temp_target/10, true)
  self:getElement('slider_0'):setValue('value', humi_target/10, true)

  -- Update dew point and absolute humidity text
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))
end
```

**Then call it in multiple places:**

```lua
function CustomDevice:onInit()
  -- ... existing code ...

  -- Initialize displays
  refresh_target_displays(self)
end

function CustomDevice:online()
  if self:getValue('status') ~= 'online' then
    self:setValue('status', 'online')
    self:poll()

    -- Refresh displays when coming online
    refresh_target_displays(self)
  end
  befujt_hibaszam1:setValue(3,true)
end

-- In event handler
elseif source.id == 3 or source.id == 4 then  -- Target values changed
  refresh_target_displays(self)
  print(event.type, source.id, source.type, det, "Target setpoint changed, displays refreshed")
```

---

## Validation Tests

### Test Case 1: Fresh Startup
1. Set variables 3 and 4 to specific values (e.g., 220, 650)
2. Restart device
3. **Expected**: Sliders show 22.0°C and 65.0%
4. **Current behavior**: Sliders show 0 or cached values

### Test Case 2: Remote Change
1. From another device, change kamra_cel_homerseklet_v1 to 250
2. **Expected**: This device's slider_1 updates to 25.0°C
3. **Current behavior**: Slider stays at old value, variable reverts to old value

### Test Case 3: Multi-Device Consistency
1. Set target to 25.0°C on Device A
2. **Expected**: Device B slider shows 25.0°C
3. Set target to 30.0°C on Device B
4. **Expected**: Device A slider shows 30.0°C
5. **Current behavior**: Each device keeps its own slider value, overwriting network updates

---

## Impact Assessment

### Severity: **HIGH**

**Affected functionality:**
- Multi-device synchronization (completely broken)
- Display accuracy after startup (always wrong unless user manually adjusts)
- User experience (displayed values don't match actual control values)

**Safety implications:**
- Control system uses correct values from variables (not sliders)
- Physical control is NOT affected
- Only display/user interface is wrong
- User may be misled about actual setpoints

**Production readiness:**
- Single device: Medium severity (display wrong until user touches sliders)
- Multi-device: Critical severity (synchronization broken)

---

## Summary

The widget display bug has **two distinct root causes**:

1. **Initialization Bug**: Sliders never initialized in `onInit()`, so they show wrong values at startup
2. **Event Handler Bug**: Backwards logic overwrites incoming values with old slider values, breaking multi-device sync

**Both bugs must be fixed** to achieve correct behavior. The recommended fix is to use the comprehensive refresh function approach, which provides a single, maintainable solution for all display updates.

After applying these fixes:
- ✓ Sliders initialize correctly at startup
- ✓ Remote changes update local displays
- ✓ Multi-device synchronization works
- ✓ User always sees accurate target values

---

**Generated**: 2025-11-20
**Analyzed File**: aging_chamber_Apar2_0_REFACTORED.lua
**Bug Locations**: Lines 58-72 (onInit), Lines 571-578 (event handler)
