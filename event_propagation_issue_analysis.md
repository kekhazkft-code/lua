# Event Propagation Issue Analysis - Aging Chamber System

**Problem:** Device variants have propagations to signal on unevent channel that change is happening - events are not being triggered properly between variants.

---

## The Core Problem

### What Should Happen:
When one device variant (e.g., `sensor_init.lua`) changes a shared variable, other device variants (e.g., `Apar2_0.lua`) should receive a `lua_variable_state_changed` event notification and react to the change.

### What's Actually Happening:
Variables are being updated with `stop_propagation = true`, which **BLOCKS** the event system from notifying other devices about the change!

---

## Root Cause Analysis

### Issue #1: Excessive use of `stop_propagation = true`

Throughout the code, variables are being set with the third parameter as `true`, which stops event propagation:

#### **Apar2_0.lua** - Line 322, 326, 327:
```lua
befujt_cel_para_v1:setValue(befujt_cel_para, true)  -- ❌ BLOCKS EVENTS!
befujt_cel_para_v1:setValue(befujt_cel_para, true)  -- ❌ BLOCKS EVENTS!
befujt_cel_homerseklet_v1:setValue(befujt_cel_homerseklet, true)  -- ❌ BLOCKS EVENTS!
```

#### **sensor_init.lua** - Line 394, 427, 428:
```lua
signals1:setValue(signal, true)  -- ❌ BLOCKS EVENTS!
signals1:setValue(signal, true)  -- ❌ BLOCKS EVENTS!
signals1:save(true)             -- ❌ BLOCKS EVENTS!
```

#### **Apar2_0.lua** - Line 463:
```lua
signals1:setValue(signal, true)  -- ❌ BLOCKS EVENTS!
```

### According to the Lua API Manual:

> **stop_propagation** (boolean, optional) — defines whether further event propagation should be stopped (= true) or not (= false / empty). In other words, if = true, then **changed() method will not return true** (lua_variable_state_changed event will not be emitted) on modification and **automation cycle won't be invoked**.

**Translation:** When you use `stop_propagation = true`:
- ✅ The value IS updated in memory
- ❌ NO `lua_variable_state_changed` event is emitted
- ❌ Other devices DON'T receive notification
- ❌ The `variable:changed()` method returns `false`

---

## Specific Problem Areas

### 1. **signals1 Variable (variable[34])** - CRITICAL

This variable contains control flags used by ALL devices:
```lua
signal = {
    warm_dis = false,
    dehumi = false,
    cool = false,
    warm = false,
    cool_dis = false,
    sleep = false,
    sum_wint_jel = false,
    humi_save = false,
    add_air_max = false,
    reventon = false,
    add_air_save = false,
    bypass_open = false,
    main_fan = false
}
```

**Problem:** When `sensor_init.lua` updates `signals1.sleep` or `signals1.humi_save`, the `Apar2_0.lua` device needs to know about it to adjust its control logic!

#### Current Code (sensor_init.lua - Line 394, 427):
```lua
signals1:setValue(signal, true)  -- ❌ OTHER DEVICES WON'T KNOW!
```

#### Should be:
```lua
signals1:setValue(signal, false)  -- ✅ NOTIFY OTHER DEVICES
-- OR
signals1:setValue(signal)  -- ✅ NOTIFY OTHER DEVICES (default is false)
```

---

### 2. **Target Temperature/Humidity Changes**

When `sensor_init.lua` or user changes target setpoints, `Apar2_0.lua` needs to recalculate control outputs.

#### Current Code (Apar2_0.lua - Line 599, 602):
```lua
kamra_cel_homerseklet_v1:setValue(celh*10, true)  -- ❌ NO EVENT
kamra_cel_para_v1:setValue(celp*10, true)         -- ❌ NO EVENT
```

#### Should be:
```lua
kamra_cel_homerseklet_v1:setValue(celh*10, false)  -- ✅ NOTIFY OTHER DEVICES
kamra_cel_para_v1:setValue(celp*10, false)         -- ✅ NOTIFY OTHER DEVICES
```

---

### 3. **Calculated Values Not Propagating**

The control algorithm in `Apar2_0.lua` calculates supply air targets but blocks propagation:

#### Current Code (Apar2_0.lua - Line 322, 326, 327):
```lua
befujt_cel_para_v1:setValue(befujt_cel_para, true)        -- ❌ NO EVENT
befujt_cel_para_v1:setValue(befujt_cel_para, true)        -- ❌ DUPLICATE & NO EVENT!
befujt_cel_homerseklet_v1:setValue(befujt_cel_homerseklet, true)  -- ❌ NO EVENT
```

**Note:** Line 322 and 326 are duplicates - probably a copy-paste error!

#### Should be:
```lua
befujt_cel_homerseklet_v1:setValue(befujt_cel_homerseklet, false)  -- ✅ NOTIFY
befujt_cel_para_v1:setValue(befujt_cel_para, false)                -- ✅ NOTIFY
-- Remove duplicate line 326
```

---

### 4. **Checking for Changes Doesn't Work**

#### Current Code (Apar2_0.lua - Line 555):
```lua
elseif befujt_para_mert_table1:changed() or befujt_homerseklet_akt1:changed() or befujt_para_akt1:changed() then
    -- This event handler should fire when values change
```

**Problem:** If the variables are set with `stop_propagation = true`, the `changed()` method will NEVER return true!

#### Where Variables Are Set (Line 548-549):
```lua
mozgoatlag(befujt_homerseklet_mert_table1, var1, befujt_homerseklet_akt1, 3, true, befujt_szimulalt1:getValue())
mozgoatlag(befujt_para_mert_table1, var2, befujt_para_akt1, 3, befujt_szimulalt1:getValue(), befujt_szimulalt1:getValue())
```

#### Inside mozgoatlag function (Line 489):
```lua
if not simulate then  
    atlag_ertek:setValue((sum/#instab)+0.5, true)  -- ❌ BLOCKS EVENTS!
end
```

**Result:** The `changed()` check on line 555 NEVER fires because `stop_propagation = true` was used!

---

## Why This Pattern Was Used (Probably)

The developer likely used `stop_propagation = true` to:
1. Improve performance by reducing event traffic
2. Prevent infinite loops (Device A changes var → Device B reacts → changes var → Device A reacts again)
3. Reduce computational overhead during rapid updates

### The Problem:
This creates a **communication blackout** between device variants. They can't coordinate!

---

## Impact on System Operation

### What Happens Now:
1. ✅ `sensor_init.lua` updates `signals1.sleep = true` (sleep mode activated)
2. ❌ `Apar2_0.lua` **NEVER RECEIVES THE EVENT**
3. ❌ `Apar2_0.lua` continues with old value: `signal.sleep = false`
4. ❌ Control algorithm uses wrong sleep state
5. ⚠️ Equipment runs when it should be resting!

### Specific Scenarios That Fail:

#### Scenario 1: Sleep Mode Change
```
sensor_init.lua:
  → signals1:setValue({sleep=true}, true)  ❌ NO EVENT
  
Apar2_0.lua:
  → Never knows sleep mode changed
  → relay_warm still controlled as if active
  → Line 401: warm = warm_1 and (not signal.sleep)  // Uses old value!
```

#### Scenario 2: Summer/Winter Mode Switch
```
sensor_init.lua:
  → signals1:setValue({sum_wint_jel=true}, true)  ❌ NO EVENT
  
Apar2_0.lua:
  → Never knows season changed
  → Line 404: cool_rel = cool and signal.sum_wint_jel  // Uses old value!
  → Wrong relay logic applied
```

#### Scenario 3: Humidity Save Mode
```
sensor_init.lua:
  → signals1:setValue({humi_save=true}, true)  ❌ NO EVENT
  
Apar2_0.lua:
  → Never knows mode changed
  → Lines 412-414: Bypass, reventon, add_air_save logic all use old value
  → Equipment operates in wrong mode
```

---

## Detection in Code

### Commented-Out Event Type Check (Apar2_0.lua - Line 555):
```lua
elseif --[[ event.type == "lua_variable_state_changed" and source.id == 18 ]] 
       befujt_para_mert_table1:changed() or 
       befujt_homerseklet_akt1:changed() or 
       befujt_para_akt1:changed() then
```

The commented section shows the developer was trying to catch `lua_variable_state_changed` events but switched to using `changed()` method instead. **Both approaches fail when `stop_propagation = true` is used!**

---

## Solution Strategy

### Approach 1: Remove Most stop_propagation flags (RECOMMENDED)

**Philosophy:** Let the event system do its job. Only block propagation for internal/temporary calculations.

#### Variables That SHOULD Propagate:
- ✅ `signals1` (variable[34]) - **CRITICAL** - all devices need these flags
- ✅ `kamra_cel_homerseklet_v1` (variable[3]) - target setpoints
- ✅ `kamra_cel_para_v1` (variable[4]) - target setpoints
- ✅ `befujt_cel_homerseklet_v1` (variable[5]) - calculated targets
- ✅ `befujt_cel_para_v1` (variable[6]) - calculated targets
- ✅ `befujt_homerseklet_akt1` (variable[23]) - filtered sensor values
- ✅ `befujt_para_akt1` (variable[24]) - filtered sensor values
- ✅ `cycle_variable1` (variable[38]) - cycle timing

#### Variables That CAN Block Propagation:
- ⚠️ `*_table1` variables (17-22, 27, 28) - internal moving average buffers
- ⚠️ UI element updates (text fields) - don't need cross-device sync

### Approach 2: Structured Event Handling (BETTER)

Create a clear event routing system:

```lua
-- In sensor_init.lua - MASTER for operational mode
function CustomDevice:onEvent(event)
    -- ... existing timer code ...
    
    -- Update signals and ALWAYS propagate
    if mode_changed then
        signals1:setValue(signal, false)  -- ✅ PROPAGATE
        signals1:save(false)              -- ✅ PROPAGATE
    end
end

-- In Apar2_0.lua - SLAVE that reacts to mode changes
function CustomDevice:onEvent(event)
    -- React to signals1 changes
    if event.type == 'lua_variable_state_changed' and event.source.id == 34 then
        -- Reload signal table
        local signal = signals1:getValue({})
        -- Re-run control logic with new signals
        self:controlling()
    end
    
    -- ... rest of existing code ...
end
```

### Approach 3: Hybrid (MOST PRACTICAL)

Keep `stop_propagation = true` for high-frequency internal updates, but use `false` for mode/setpoint changes:

```lua
-- HIGH FREQUENCY (5 sec) - Block propagation
mozgoatlag(befujt_homerseklet_mert_table1, var1, befujt_homerseklet_akt1, 3, true, simulate)

-- LOW FREQUENCY (user changes, mode switches) - Allow propagation  
signals1:setValue(signal, false)
kamra_cel_homerseklet_v1:setValue(celh*10, false)
```

---

## Detailed Fix List

### CRITICAL FIXES (Must Do):

#### 1. sensor_init.lua - Line 394, 427, 428:
```lua
-- BEFORE:
signals1:setValue(signal, true)  -- ❌
signals1:setValue(signal, true)  -- ❌
signals1:save(true)              -- ❌

-- AFTER:
signals1:setValue(signal, false)  -- ✅
-- Remove duplicate line 427
signals1:save(false)              -- ✅
```

#### 2. Apar2_0.lua - Line 463:
```lua
-- BEFORE:
signals1:setValue(signal, true)  -- ❌

-- AFTER:
signals1:setValue(signal, false)  -- ✅
```

#### 3. Apar2_0.lua - Line 599, 602:
```lua
-- BEFORE:
kamra_cel_homerseklet_v1:setValue(celh*10, true)  -- ❌
kamra_cel_para_v1:setValue(celp*10, true)         -- ❌

-- AFTER:
kamra_cel_homerseklet_v1:setValue(celh*10, false)  -- ✅
kamra_cel_para_v1:setValue(celp*10, false)         -- ✅
```

#### 4. Apar2_0.lua - Line 322, 326, 327:
```lua
-- BEFORE:
befujt_cel_para_v1:setValue(befujt_cel_para, true)
befujt_cel_para_v1:setValue(befujt_cel_para, true)  -- DUPLICATE!
befujt_cel_homerseklet_v1:setValue(befujt_cel_homerseklet, true)

-- AFTER:
befujt_cel_homerseklet_v1:setValue(befujt_cel_homerseklet, false)  -- ✅
befujt_cel_para_v1:setValue(befujt_cel_para, false)                -- ✅
-- Remove duplicate line 326
```

### MEDIUM PRIORITY FIXES:

#### 5. Apar2_0.lua - Line 643-644, 661-662:
```lua
-- User setpoint changes - should propagate
kamra_cel_homerseklet_v1:setValue(newValue*10, false)
kamra_cel_homerseklet_v1:save(false)
kamra_cel_para_v1:setValue(newValue*10, false)
kamra_cel_para_v1:save(false)
```

#### 6. sensor_init.lua - Line 399:
```lua
-- BEFORE:
cycle_variable1:setValue(cyclevar, true)  -- ❌

-- AFTER:
cycle_variable1:setValue(cyclevar, false)  -- ✅
```

### LOW PRIORITY (Performance-related):

#### 7. Apar2_0.lua - mozgoatlag function (Line 489):
Keep `stop_propagation = true` here since this runs every 5 seconds and creates a lot of events. BUT add a manual notification after filtering:

```lua
function mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call, simulate)
    -- ... existing code ...
    
    if not simulate then  
        atlag_ertek:setValue((sum/#instab)+0.5, true)  -- Keep true for performance
    end
    
    -- ... existing code ...
end

-- Then in onEvent after mozgoatlag calls (Line 550):
mozgoatlag(befujt_homerseklet_mert_table1, var1, befujt_homerseklet_akt1, 3, true, simulate)
mozgoatlag(befujt_para_mert_table1, var2, befujt_para_akt1, 3, simulate, simulate)
ah_dp_befujt_szamol()

-- Manually trigger change detection for other devices:
-- (Only if values actually changed)
if previous_temp ~= befujt_homerseklet_akt1:getValue() or 
   previous_humi ~= befujt_para_akt1:getValue() then
    -- Force event by doing a dummy set with propagation
    befujt_homerseklet_akt1:setValue(befujt_homerseklet_akt1:getValue(), false)
end
```

---

## Testing Strategy

### 1. Add Event Logging:
```lua
function CustomDevice:onEvent(event)
    -- At the very top of onEvent in ALL device files:
    if event.type == 'lua_variable_state_changed' then
        print("EVENT RECEIVED:", event.source.id, event.source.type, event.source.name)
    end
    
    -- ... rest of code ...
end
```

### 2. Test Scenarios:

#### Test 1: Sleep Mode Toggle
1. Watch `signals1` (variable[34])
2. Change sleep mode in `sensor_init` UI
3. Verify `Apar2_0` receives event and updates `signal.sleep`
4. Verify relays react correctly

#### Test 2: Target Temperature Change
1. Watch `kamra_cel_homerseklet_v1` (variable[3])
2. Change slider in UI
3. Verify `Apar2_0` receives event
4. Verify calculated supply air target updates

#### Test 3: Summer/Winter Mode
1. Toggle `sum_wint_inp` physical input
2. Verify `signals1.sum_wint_jel` updates
3. Verify `Apar2_0` receives event
4. Verify cooling relay logic changes appropriately

---

## Performance Considerations

### Event Traffic Estimation:

**Before Fix (Current):**
- Almost NO events between devices (blocked by stop_propagation = true)
- ~10 internal events per 5-second cycle

**After Fix (All propagation enabled):**
- ~20-30 events per 5-second cycle
- Most are temperature/humidity updates

**After Fix (Hybrid approach):**
- ~5-10 events per 5-second cycle
- Only mode changes and setpoints propagate
- Filtered sensor values don't propagate (updated by polling instead)

### Recommendation:
Use **Hybrid Approach** - propagate only meaningful state changes, not every sensor reading.

---

## Summary

### The Problem:
Excessive use of `stop_propagation = true` prevents device variants from receiving `lua_variable_state_changed` events, breaking inter-device communication.

### The Impact:
- Control modes don't synchronize (sleep, summer/winter, humidity save)
- Setpoint changes don't trigger recalculation in other devices
- System operates with stale data

### The Solution:
1. **CRITICAL:** Remove `stop_propagation = true` from `signals1` updates (variable[34])
2. **CRITICAL:** Remove `stop_propagation = true` from setpoint updates (variables 3-6)
3. **MEDIUM:** Remove from cycle timing (variable[38])
4. **OPTIONAL:** Keep for high-frequency sensor buffers (variables 17-22) but add manual notifications

### Implementation Priority:
1. Fix signals1 propagation (2 minutes)
2. Fix setpoint propagation (5 minutes)
3. Test with logging (15 minutes)
4. Fine-tune performance if needed (30 minutes)

**Total estimated time: 1 hour of careful editing and testing**

