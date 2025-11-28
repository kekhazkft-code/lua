# Quick Start - Implementing Intelligent Event Propagation

## 🎯 What You Have

1. **aging_chamber_Apar2_0_REFACTORED.lua** - Complete refactored main controller
2. **sensor_init_REFACTORED_sections.md** - Key sections to update in sensor_init
3. **REFACTORING_GUIDE_hybrid_propagation.md** - Complete technical documentation
4. **aging_chamber_code_analysis.md** - Original code analysis
5. **event_propagation_issue_analysis.md** - Problem diagnosis

---

## 🚀 Implementation Steps (30 minutes)

### Step 1: Backup Everything (2 minutes)
```bash
# On your Tech Sinum device, backup current code
cp erlelo_1119.json erlelo_1119_backup_$(date +%Y%m%d).json
cp erlelo_1119b.json erlelo_1119b_backup_$(date +%Y%m%d).json
```

### Step 2: Deploy Refactored Apar2_0 (5 minutes)

1. Open `aging_chamber_Apar2_0_REFACTORED.lua`
2. Copy the entire content
3. In Tech Sinum web interface:
   - Navigate to your Apar2_0 device
   - Open the Lua code editor
   - Replace entire code with refactored version
   - **Save** the device

### Step 3: Update sensor_init (15 minutes)

1. Open `sensor_init_REFACTORED_sections.md`
2. In Tech Sinum, open your sensor_init device code editor
3. Find and replace these three functions:

   **Function 1: onEvent (Line ~364)**
   - Copy the entire refactored onEvent function
   - Replace the original (Lines 364-438)
   
   **Function 2: on_pihi_vez_change (Line ~452)**
   - Copy the refactored version
   - Replace the original (Lines 452-472)
   
   **Function 3: on_pihi_aktiv_change (Line ~474)**
   - Copy the refactored version
   - Replace the original (Lines 474-485)

4. **Save** the device

### Step 4: Initial Testing (5 minutes)

1. **Test Sleep Mode:**
   - Toggle sleep mode in sensor_init UI
   - Watch system log for: `"Sleep mode changed to: X - Event propagated"`
   - Check if Apar2_0 heating relay responds correctly

2. **Test Temperature Reading:**
   - Wait for 3 Modbus poll cycles (15 seconds)
   - Watch for: `"Moving average propagated"`
   - Verify UI shows updated temperature

3. **Test Setpoint Change:**
   - Change target temperature slider
   - Verify both devices update immediately
   - Check calculated supply air target changes

### Step 5: Monitoring (3 minutes)

Add this to the **top** of onEvent in BOTH files for debugging:

```lua
function CustomDevice:onEvent(event)
    -- Debug logging - remove after testing
    if event.type == 'lua_variable_state_changed' then
        print(string.format("[EVENT] Received: id=%d name=%s", 
            event.source.id, event.source.name or "unknown"))
    end
    
    -- ... rest of your code ...
end
```

---

## ✅ Verification Checklist

After deployment, verify these behaviors:

### Critical Functions (Must Work):
- [ ] Sleep mode changes propagate between devices
- [ ] Summer/Winter mode switch updates relay logic
- [ ] Humidity save mode activates bypass correctly
- [ ] Target temperature changes trigger recalculation
- [ ] Sensor readings update UI after buffer fills
- [ ] Relay states match control logic

### Performance (Should Observe):
- [ ] Event log shows 1-2 events per second (not 10+)
- [ ] No duplicate events for same change
- [ ] Changes propagate within 1-2 seconds
- [ ] System responds to user input immediately
- [ ] No "event storms" in the logs

### Expected Log Messages:
```
[15:23:45] Sleep mode changed to: true - Event propagated
[15:23:45] [EVENT] Received: id=34 name=signals1
[15:23:50] Moving average propagated: variable[23] old: 253 new: 254
[15:23:50] [EVENT] Received: id=23 name=befujt_homerseklet_akt1
```

---

## 🔧 Troubleshooting

### Problem: No events received

**Check:**
1. Did you update BOTH Apar2_0 AND sensor_init?
2. Are debug print statements showing "Event propagated"?
3. Is the variable ID correct in event handler?

**Fix:**
```lua
-- Verify variable IDs match:
if event.source.id == 34 then  -- signals1
    print("Signal change detected!")
    -- Your code here
end
```

### Problem: Too many events

**Check:**
1. Are values changing every cycle even when stable?
2. Is the threshold too low?

**Fix:**
```lua
-- Increase thresholds at top of Apar2_0:
local TEMP_CHANGE_THRESHOLD = 5   -- Was 2, now 0.5°C
local HUMI_CHANGE_THRESHOLD = 5   -- Was 3, now 0.5%
```

### Problem: Relay not responding to sleep mode

**Check:**
1. Event log - is event propagated?
2. Event log - is event received in Apar2_0?
3. Is controlling() being called after event?

**Fix:**
```lua
-- In Apar2_0 onEvent, when signals1 changes:
elseif source.id == 34 then  -- signals1 changed
    print("SIGNAL STATE CHANGED - Rerunning control")
    self:controlling()  -- ← Make sure this is called!
end
```

### Problem: Moving average not propagating

**Check:**
1. Is buffer size reached? (need 3 measurements)
2. Is value actually changing?

**Debug:**
```lua
-- Add to mozgoatlag function:
print(string.format("Buffer: %d/%d, Old: %d, New: %d, Changed: %s",
    #instab, mertdb, old_avg, new_avg, tostring(value_changed)))
```

---

## 📊 Key Changes Summary

### What Changed in Apar2_0:

1. **mozgoatlag function** - Now checks buffer ready AND value changed
2. **controlling() function** - Compares old vs new signal state
3. **befujt_cel_* updates** - Checks for meaningful change (±0.2°C/0.3%)
4. **User setpoint functions** - Always propagate (false instead of true)
5. **onEvent handler** - Structured by event.type, reacts to signals1 changes

### What Changed in sensor_init:

1. **onEvent function** - Stores old values, compares before propagating
2. **Sleep mode changes** - Propagate when state flips
3. **Mode switches** - Propagate when hardware inputs change
4. **Manual controls** - Propagate when user changes settings

### The Pattern:

```lua
-- OLD WAY (always blocks):
variable:setValue(new_value, true)  -- ❌ Never propagates

-- NEW WAY (intelligent):
local old_value = variable:getValue()
if math.abs(new_value - old_value) >= THRESHOLD then
    variable:setValue(new_value, false)  -- ✅ Propagates
else
    variable:setValue(new_value, true)   -- ❌ Blocks (no change)
end
```

---

## 🎓 Understanding the System

### Event Flow Diagram:

```
sensor_init (Master)                    Apar2_0 (Slave)
     |                                       |
     | 1. Sleep timer expires                |
     | 2. signal.sleep = true                |
     | 3. signals1:setValue(signal, false) ──┼─> Event sent
     |                                       |
     |                           4. onEvent triggered
     |                           5. source.id == 34
     |                           6. Reload signals
     |                           7. self:controlling()
     |                           8. warm = warm_1 and (not signal.sleep)
     |                           9. relay_warm turns OFF
     |
```

### Three Types of Updates:

1. **User Action** → Always propagate (immediate response needed)
2. **Hardware Input** → Always propagate (mode change)
3. **Calculated Value** → Conditional propagate (only if meaningful)

---

## 📞 Need Help?

### Check These Documents:

- **event_propagation_issue_analysis.md** - Detailed problem explanation
- **REFACTORING_GUIDE_hybrid_propagation.md** - Complete technical guide
- **aging_chamber_code_analysis.md** - Original system understanding

### Common Questions:

**Q: Do I need to update all 4 device files?**
A: Minimum: Update Apar2_0 and sensor_init. Others (Apar3_4, Apar4_0) can be updated later using same pattern.

**Q: Will this break my existing system?**
A: No - the refactored code preserves all functionality, just fixes event propagation. Backup first anyway!

**Q: How do I know if it's working?**
A: Watch for "Event propagated" messages in logs, and verify relay responds to sleep mode changes.

**Q: Can I roll back?**
A: Yes - just restore your backup .json files from Step 1.

---

## 🎉 Success Criteria

Your refactoring is successful when:

✅ Sleep mode toggle in sensor_init → Heating stops in Apar2_0  
✅ Summer/Winter switch → Cooling logic changes immediately  
✅ Temperature setpoint change → UI updates in both devices  
✅ Log shows "Event propagated" for mode changes  
✅ Log shows "Event received" in Apar2_0  
✅ System stable for 24 hours with no issues  

Good luck! 🚀

