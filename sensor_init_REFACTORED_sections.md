# Sensor_Init Refactored - Key Sections with Intelligent Event Propagation

## Critical Changes to sensor_init.lua onEvent function (Lines 364-438)

Replace the entire `onEvent` function with this refactored version:

```lua
function CustomDevice:onEvent(event)
    local timerState = self:getComponent("timer4"):getState()
    local signal = signals1:getValue({})  -- Load current signals
    local old_signal = {}  -- Store old values for change detection
    for k, v in pairs(signal) do
        old_signal[k] = v
    end
    
    local teszt = false
    
    if (timerState == "elapsed" or timerState == "off") then
        self:getComponent("timer4"):start(1000)
        teszt = self:getElement("min_sec_sw"):getValue("value")
    end
    
    -- ciklus számláló léptetése 1 percenként ha nincs teszt üzemmód
    if dateTime:changed() or teszt then
        teszt = false
        local cyclevar = cycle_variable1:getValue({})
        local kezi = self:getElement("pihi_vez_sw"):getValue("value")
        
        local old_cyclevar_szamlalo = cyclevar.szamlalo  -- Store old value
        
        if not kezi then
            cyclevar.szamlalo = cyclevar.szamlalo - 1
            if cyclevar.szamlalo <= 0 then
                if signal.sleep then  -- pihenőidő volt
                    cyclevar.szamlalo = cyclevar.action_time
                    signal.sleep = false  -- aktiv idő jön
                    relay_sleep:call("turn_on")
                else
                    cyclevar.szamlalo = cyclevar.passiv_time
                    signal.sleep = true  -- pihenő jön 
                    relay_sleep:call("turn_off")              
                end
                
                -- CRITICAL: Sleep mode changed - MUST propagate to other devices!
                signals1:setValue(signal, false)  -- ✅ PROPAGATE
                print("Sleep mode changed to:", signal.sleep, "- Event propagated to other devices")
            end 
            
            self:getElement("txt_ido"):setValue("value", string.format("%3d perc", cyclevar.szamlalo), true)
            
            -- INTELLIGENT PROPAGATION: Only propagate cycle_variable if counter actually changed
            local counter_changed = (old_cyclevar_szamlalo ~= cyclevar.szamlalo)
            cycle_variable1:setValue(cyclevar, not counter_changed)
            
            if signal.sleep then
                self:getElement('sleep_field'):setValue("value", "Pihenőidő!!!", true)
            else
                self:getElement('sleep_field'):setValue("value", "Aktív idő!!!", true)
            end
        else
            -- Manual control mode
            signal.sleep = self:getElement("pihi_aktiv_sw"):getValue("value")
            if signal.sleep then
                self:getElement('sleep_field'):setValue("value", "Kikapcsolva", true)
            else
                self:getElement('sleep_field'):setValue("value", "Bekapcsolva", true)
            end
        end
        
    elseif humidity_save_inp:changed() then
        -- CRITICAL: Hardware input changed - MUST propagate
        signal.humi_save = humidity_save_inp:getValue("state")
        txtset(signal.humi_save, self:getElement('humi_save_txt'), "Páramentő mód", "Páracsökkentő mód")
        
        -- Check if value actually changed
        if old_signal.humi_save ~= signal.humi_save then
            signals1:setValue(signal, false)  -- ✅ PROPAGATE
            print("Humidity save mode changed to:", signal.humi_save, "- Event propagated")
        end
        
    elseif sum_wint_inp:changed() then
        -- CRITICAL: Summer/Winter mode changed - MUST propagate
        signal.sum_wint_jel = sum_wint_inp:getValue("state")
        txtset(signal.sum_wint_jel, self:getElement('sum_wint_field'), "Nyári üzemmód!", "Téli üzemmód!")
        
        -- Check if value actually changed
        if old_signal.sum_wint_jel ~= signal.sum_wint_jel then
            signals1:setValue(signal, false)  -- ✅ PROPAGATE
            print("Summer/Winter mode changed to:", signal.sum_wint_jel, "- Event propagated")
        end
        
    elseif kamra_cel_homerseklet_v1:changed() then
        print("Target temperature changed - received from other device")
    end
    
    -- FINAL CHECK: Save signals only if something actually changed
    local signal_changed = false
    for k, v in pairs(signal) do
        if old_signal[k] ~= v then
            signal_changed = true
            break
        end
    end
    
    if signal_changed then
        -- At least one signal changed - propagate and save
        signals1:setValue(signal, false)  -- ✅ PROPAGATE
        signals1:save(false)               -- ✅ PROPAGATE
        print("Signals saved and propagated")
    end
end
```

## Critical Changes to on_pihi_vez_change function (Lines 452-472)

Replace with:

```lua
function CustomDevice:on_pihi_vez_change(newValue, element)
    local sleep = self:getElement("pihi_aktiv_sw"):getValue("value")
    local old_sleep = signals1:getValue({}).sleep
    
    if newValue then
        -- Entering manual control mode
        if old_sleep ~= sleep then
            -- Sleep state changed - MUST propagate
            signals1:setValueByPath("sleep", sleep, false)  -- ✅ PROPAGATE
            signals1:save(false)  -- ✅ PROPAGATE
            print("Manual sleep mode set to:", sleep, "- Event propagated")
        else
            -- No change - don't propagate
            signals1:setValueByPath("sleep", sleep, true)
            signals1:save(true)
        end
        
        setrelay(not sleep, relay_sleep)
        
        if sleep then 
            self:getElement('sleep_field'):setValue("value", "Kikapcsolva", true)
        else
            self:getElement('sleep_field'):setValue("value", "Bekapcsolva", true)
        end
    else
        -- Returning to automatic control
        if sleep then
            self:getElement('sleep_field'):setValue("value", "Pihenőidő!!!", true)
        else
            self:getElement('sleep_field'):setValue("value", "Aktív idő!!!", true)
        end
    end
end
```

## Critical Changes to on_pihi_aktiv_change function (Lines 474-485)

Replace with:

```lua
function CustomDevice:on_pihi_aktiv_change(newValue, element)
    if self:getElement("pihi_vez_sw"):getValue("value") then
        local old_sleep = signals1:getValue({}).sleep
        
        -- Check if sleep state actually changed
        if old_sleep ~= newValue then
            -- Sleep state changed - MUST propagate
            signals1:setValueByPath("sleep", newValue, false)  -- ✅ PROPAGATE
            signals1:save(false)  -- ✅ PROPAGATE
            print("Sleep mode toggled to:", newValue, "- Event propagated")
        else
            -- No change - don't propagate
            signals1:setValueByPath("sleep", newValue, true)
            signals1:save(true)
        end
        
        setrelay(not newValue, relay_sleep)
        
        if newValue then 
            self:getElement('sleep_field'):setValue("value", "Kikapcsolva", true)
        else
            self:getElement('sleep_field'):setValue("value", "Bekapcsolva", true)
        end
    end
end
```

## Summary of Changes

### What Changed:

1. **Store Old Values Before Modification**
   - Keep a copy of signal states before changes
   - Compare old vs new to detect meaningful changes

2. **Intelligent Propagation Logic**
   ```lua
   if old_value ~= new_value then
       variable:setValue(new_value, false)  -- ✅ PROPAGATE
   else
       variable:setValue(new_value, true)   -- ❌ NO PROPAGATION
   end
   ```

3. **Always Propagate Critical Mode Changes**
   - `signal.sleep` changes (affects all relay logic)
   - `signal.humi_save` changes (humidity save mode)
   - `signal.sum_wint_jel` changes (summer/winter mode)

4. **Debug Logging Added**
   - Print messages when events are propagated
   - Helps verify communication between devices

### Key Variables That Now Propagate Correctly:

| Variable | ID | When to Propagate |
|----------|-----|-------------------|
| signals1 | 34 | When any signal flag changes |
| cycle_variable1 | 38 | When counter changes (not every cycle) |

### Testing Checklist:

1. ✅ Toggle sleep mode → Verify Apar2_0 receives event
2. ✅ Switch humidity save mode → Verify relay logic updates in Apar2_0
3. ✅ Change summer/winter → Verify cooling logic updates in Apar2_0
4. ✅ Check debug prints show "Event propagated" messages
5. ✅ Verify no excessive event traffic (should only propagate on actual changes)

