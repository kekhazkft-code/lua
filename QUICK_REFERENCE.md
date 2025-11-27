# Quick Reference: Using the V() Function

## Basic Usage

### Reading a Variable

```lua
-- Get variable object
local temp_var = V('kulso_homerseklet')

-- Read value
local temp_value = temp_var:getValue()

-- One-liner
local temp = V('kulso_homerseklet'):getValue()
```

### Writing a Variable

```lua
-- With propagation (triggers events)
V('kulso_homerseklet'):setValue(150, false)

-- Without propagation (silent update)
V('kulso_homerseklet'):setValue(150, true)
```

### Checking if Variable Exists

```lua
local temp_var = V('kulso_homerseklet')
if temp_var then
  -- Variable exists and is accessible
  local value = temp_var:getValue()
else
  -- Variable not found in mapping
  print("ERROR: Variable not found")
end
```

## Chamber-Specific Variables (kamra files only)

The V() function in chamber controllers automatically adds the chamber suffix.

### Example: Chamber 1 (CHAMBER_ID = 1)

```lua
-- These all access chamber 1's variables:
V('kamra_homerseklet')        → kamra_homerseklet_ch1
V('kamra_para')               → kamra_para_ch1
V('befujt_homerseklet_akt')   → befujt_homerseklet_akt_ch1
```

### Example: Chamber 2 (CHAMBER_ID = 2)

```lua
-- Same code, different variables:
V('kamra_homerseklet')        → kamra_homerseklet_ch2
V('kamra_para')               → kamra_para_ch2
V('befujt_homerseklet_akt')   → befujt_homerseklet_akt_ch2
```

### Global Variables in Chamber Files

Global variables (with `_glbl` suffix) are accessed automatically:

```lua
V('kulso_homerseklet')  → kulso_homerseklet_glbl
V('kulso_para')         → kulso_para_glbl
```

## Common Patterns

### Safe Read with Default

```lua
local temp_var = V('kamra_homerseklet')
local temp = temp_var and temp_var:getValue() or 0
```

### Safe Write

```lua
local temp_var = V('kamra_homerseklet')
if temp_var then
  temp_var:setValue(150, false)
end
```

### Working with Table Variables

```lua
-- Read table
local signals = V('signals'):getValue() or {}

-- Modify table
signals.relay_warm = true

-- Write back
V('signals'):setValue(signals, false)
```

### Working with Moving Averages

```lua
local buffer = V('kamra_homerseklet_table'):getValue() or {}
table.insert(buffer, new_reading)
if #buffer > 5 then
  table.remove(buffer, 1)
end
V('kamra_homerseklet_table'):setValue(buffer, true)  -- No propagation for buffer
```

## Variable Names by Category

### Outdoor Variables (kulso)
```lua
V('kulso_homerseklet')         -- Outdoor temperature
V('kulso_para')                -- Outdoor humidity
V('kulso_homerseklet_table')   -- Outdoor temp buffer
V('kulso_para_table')          -- Outdoor humidity buffer
V('kulso_hibaszam')            -- Error counter
V('kulso_szimulalt')           -- Simulation mode flag
V('kulso_ah_dp')               -- Absolute humidity & dew point
```

### Chamber Variables (in kamra files - auto-suffixed)
```lua
V('kamra_homerseklet')         -- Chamber temperature
V('kamra_para')                -- Chamber humidity
V('kamra_cel_homerseklet')     -- Target chamber temp
V('kamra_cel_para')            -- Target chamber humidity
V('befujt_homerseklet_akt')    -- Supply air temp
V('befujt_para_akt')           -- Supply air humidity
V('befujt_cel_homerseklet')    -- Target supply air temp
V('befujt_cel_para')           -- Target supply air humidity
V('constansok')                -- Control constants (JSON table)
V('signals')                   -- Control signals (JSON table)
V('cycle_variable')            -- Sleep cycle state (JSON table)
V('ah_dp_table')               -- Psychrometric data (JSON table)
V('befujt_szimulalt')          -- Supply air simulation flag
V('kamra_szimulalt')           -- Chamber simulation flag
V('ntc1_homerseklet')          -- NTC sensor 1 temperature
V('ntc2_homerseklet')          -- NTC sensor 2 temperature
V('ntc3_homerseklet')          -- NTC sensor 3 temperature
V('ntc4_homerseklet')          -- NTC sensor 4 temperature
```

## Migration Examples

### Before (Old Code)

```lua
-- Hardcoded indices
local VAR = {
  kulso_homerseklet = 100,
  kulso_para = 101,
}

variable[VAR.kulso_homerseklet]:setValue(150, false)
local temp = variable[VAR.kulso_homerseklet]:getValue()
```

### After (New Code)

```lua
-- Dynamic mapping
V('kulso_homerseklet'):setValue(150, false)
local temp = V('kulso_homerseklet'):getValue()
```

### Before (Old Chamber Code)

```lua
-- Per-chamber calculation
local function var_idx(base)
  return base + (CHAMBER_ID - 1)
end

local VAR_BASE = {
  kamra_homerseklet = 1,
  kamra_para = 4,
}

variable[var_idx(VAR_BASE.kamra_homerseklet)]:setValue(150, false)
```

### After (New Chamber Code)

```lua
-- Automatic suffix handling
V('kamra_homerseklet'):setValue(150, false)
```

## Advanced: Direct Mapping Access

If you need to get the actual variable index:

```lua
local map = loadVarMap()
local idx = map['kulso_homerseklet']
print("kulso_homerseklet is at index: " .. idx)
```

## Debugging Tips

### Print All Mapped Variables

```lua
function CustomDevice:onInit()
  local map = loadVarMap()
  if map then
    print("=== Variable Mapping ===")
    for name, idx in pairs(map) do
      print(string.format("%s → variable[%d]", name, idx))
    end
  end
end
```

### Check if Mapping is Loaded

```lua
local map = loadVarMap()
if map then
  print("Mapping loaded successfully: " .. #map .. " variables")
else
  print("ERROR: Failed to load mapping")
end
```

### Verify Variable Access

```lua
local function test_variable(name)
  local var = V(name)
  if var then
    print(name .. " ✓ accessible")
  else
    print(name .. " ✗ not found")
  end
end

test_variable('kulso_homerseklet')
test_variable('kamra_homerseklet')  -- In kamra files only
```

## Common Mistakes to Avoid

### ❌ Don't forget to check if V() returns nil

```lua
-- BAD - will crash if variable not found
local temp = V('kulso_homerseklet'):getValue()

-- GOOD - safe handling
local temp_var = V('kulso_homerseklet')
local temp = temp_var and temp_var:getValue() or 0
```

### ❌ Don't add chamber suffix manually in kamra files

```lua
-- BAD - will look for "kamra_homerseklet_ch1_ch1"
V('kamra_homerseklet_ch1')

// GOOD - suffix is added automatically
V('kamra_homerseklet')
```

### ❌ Don't use hardcoded indices anymore

```lua
-- BAD - defeats the purpose of dynamic mapping
variable[100]:setValue(temp, false)

-- GOOD - use the mapping
V('kulso_homerseklet'):setValue(temp, false)
```

## Performance Notes

- `loadVarMap()` caches the result in `VAR_MAP` local variable
- First call parses JSON, subsequent calls return cached map
- Each `V()` call does one table lookup (very fast)
- No performance difference compared to hardcoded indices after initialization
