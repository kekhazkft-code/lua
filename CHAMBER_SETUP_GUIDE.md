# Chamber Setup Guide v2.4

This guide explains how to configure chamber controllers for your specific hardware.

## Prerequisites

Before configuring chambers:
1. Run `erlelo_create.lua` to create all variables
2. Run `erlelo_store.lua` and note the **MAPPING_VAR_ID**
3. Know your Modbus Client IDs from Sinum settings
4. Know your SBUS device IDs for relays and inputs

## Configuration Structure

Each controller file has a **USER CONFIGURATION** section at the top:

### erlelo_kulso.lua (Outdoor Sensor)

```lua
-- ============================================================================
-- USER CONFIGURATION - EDIT THESE VALUES
-- ============================================================================

-- After running erlelo_store, it will print the mapping variable ID
local MAPPING_VAR_ID = 42              -- ← Set from erlelo_store output

-- Modbus client ID for outdoor sensor
local MODBUS_OUTDOOR_CLIENT = 7        -- ← Your Modbus Client ID

-- Modbus register addresses (check your sensor documentation)
local MODBUS_REG_TEMPERATURE = 1       -- ← Input register for temp
local MODBUS_REG_HUMIDITY = 2          -- ← Input register for humidity
```

### erlelo_kamra1.lua (Chamber Controller)

```lua
-- ============================================================================
-- USER CONFIGURATION - EDIT THESE VALUES
-- ============================================================================

local CHAMBER_ID = 1                   -- Chamber number: 1, 2, or 3

-- After running erlelo_store, it will print the mapping variable ID
local MAPPING_VAR_ID = 42              -- ← Same ID for all controllers!

-- Modbus client IDs (from Sinum Modbus Client settings)
local MODBUS_SUPPLY_CLIENT = 8         -- ← Supply air sensor client
local MODBUS_CHAMBER_CLIENT = 9        -- ← Chamber sensor client

-- SBUS device IDs (from Sinum SBUS settings)
local SBUS_CONFIG = {
  inp_humidity_save = 1,               -- Humidity save input
  inp_sum_wint = 2,                    -- Summer/winter input
  inp_weight_1 = nil,                  -- Weight sensor 1 (nil if not used)
  inp_weight_2 = nil,                  -- Weight sensor 2 (nil if not used)
  rel_warm = 10,                       -- Heating relay output
  rel_cool = 11,                       -- Cooling relay output
  rel_add_air_max = 12,                -- Max air addition relay
  rel_reventon = 13,                   -- Reventon relay
  rel_add_air_save = 14,               -- Air save relay
  rel_bypass_open = 15,                -- Bypass open relay
  rel_main_fan = 16,                   -- Main fan relay
  rel_humidifier = nil,                -- Humidifier relay (nil if not installed)
  rel_sleep = nil,                     -- Sleep mode relay (nil if not used)
}
```

## Creating Multiple Chambers

### Chamber 2

1. Copy `erlelo_kamra1.lua` to `erlelo_kamra2.lua`
2. Change CHAMBER_ID:
   ```lua
   local CHAMBER_ID = 2
   ```
3. Update Modbus client IDs for chamber 2's sensors:
   ```lua
   local MODBUS_SUPPLY_CLIENT = 10    -- Chamber 2 supply sensor
   local MODBUS_CHAMBER_CLIENT = 11   -- Chamber 2 chamber sensor
   ```
4. Update SBUS_CONFIG with chamber 2's relay IDs:
   ```lua
   local SBUS_CONFIG = {
     rel_warm = 20,    -- Chamber 2 heating
     rel_cool = 21,    -- Chamber 2 cooling
     -- ... etc
   }
   ```

### Chamber 3

Same process - change `CHAMBER_ID = 3` and update hardware IDs.

## Finding Your Hardware IDs

### Modbus Client IDs

1. Open Sinum → Settings → Modbus Clients
2. Find your sensor devices
3. Note the **Client ID** number for each

Example:
| Client ID | Device | Used In |
|-----------|--------|---------|
| 7 | Outdoor T/H Sensor | erlelo_kulso |
| 8 | Chamber 1 Supply Air | erlelo_kamra1 |
| 9 | Chamber 1 Room | erlelo_kamra1 |
| 10 | Chamber 2 Supply Air | erlelo_kamra2 |
| 11 | Chamber 2 Room | erlelo_kamra2 |

### SBUS Device IDs

1. Open Sinum → Settings → SBUS
2. Find each relay/input device
3. Note the **SBUS ID** for each

Example for Chamber 1:
| SBUS ID | Device | Config Key |
|---------|--------|------------|
| 1 | Humidity Save Input | inp_humidity_save |
| 2 | Summer/Winter Switch | inp_sum_wint |
| 10 | Heating Relay | rel_warm |
| 11 | Cooling Relay | rel_cool |
| 12 | Max Air Relay | rel_add_air_max |
| 13 | Reventon Relay | rel_reventon |
| 14 | Air Save Relay | rel_add_air_save |
| 15 | Bypass Relay | rel_bypass_open |
| 16 | Main Fan Relay | rel_main_fan |

## Hardware Not Used?

Set any unused hardware to `nil`:

```lua
local SBUS_CONFIG = {
  inp_weight_1 = nil,      -- No weight sensor
  inp_weight_2 = nil,      -- No weight sensor
  rel_humidifier = nil,    -- No humidifier installed
  rel_sleep = nil,         -- No sleep mode relay
  -- ... other entries with their actual IDs
}
```

The controller will skip operations for nil devices.

## Common Configuration Mistakes

### ❌ Different MAPPING_VAR_ID in each file

```lua
-- erlelo_kulso.lua
local MAPPING_VAR_ID = 42    -- ✓

-- erlelo_kamra1.lua
local MAPPING_VAR_ID = 43    -- ✗ WRONG! Should be 42
```

**All controllers must use the same MAPPING_VAR_ID** from erlelo_store output.

### ❌ Same CHAMBER_ID in multiple chamber files

```lua
-- erlelo_kamra1.lua
local CHAMBER_ID = 1    -- ✓

-- erlelo_kamra2.lua
local CHAMBER_ID = 1    -- ✗ WRONG! Should be 2
```

### ❌ Same Modbus clients in multiple chambers

```lua
-- erlelo_kamra1.lua
local MODBUS_SUPPLY_CLIENT = 8
local MODBUS_CHAMBER_CLIENT = 9

-- erlelo_kamra2.lua
local MODBUS_SUPPLY_CLIENT = 8    -- ✗ Same as chamber 1!
local MODBUS_CHAMBER_CLIENT = 9   -- ✗ Same as chamber 1!
```

Each chamber needs its own Modbus clients connected to its own sensors.

## Verification After Deployment

Check the Sinum console output when each device starts:

**Good output:**
```
=== ERLELO CHAMBER 1 v2.4 ===
Humidity-Primary Control
Variable mapping loaded: OK
SBUS hardware initialized
Supply Modbus client: 8
Chamber Modbus client: 9
Polling starts in 500ms
=== Chamber 1 initialization complete ===
```

**Bad output (missing MAPPING_VAR_ID):**
```
=== ERLELO CHAMBER 1 v2.4 ===
ERROR: MAPPING_VAR_ID not set!
1. Run erlelo_store first
2. Note the printed variable ID
3. Set MAPPING_VAR_ID at top of this file
```

**Bad output (missing Modbus):**
```
WARNING: Supply Modbus client 8 not found
WARNING: Chamber Modbus client 9 not found
```

## Quick Reference: What to Change

| Setting | erlelo_kulso | erlelo_kamra1 | erlelo_kamra2 | erlelo_kamra3 |
|---------|--------------|---------------|---------------|---------------|
| MAPPING_VAR_ID | Same for all (from erlelo_store) |
| CHAMBER_ID | N/A | 1 | 2 | 3 |
| MODBUS_*_CLIENT | Outdoor sensor | Ch1 sensors | Ch2 sensors | Ch3 sensors |
| SBUS_CONFIG | N/A | Ch1 relays | Ch2 relays | Ch3 relays |
