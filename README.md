# ERLELO Climate Control System v2.4

## Overview

Multi-chamber curing room climate control with **Humidity-Primary Control** strategy.

**Key Features:**
- 1, 2, or 3 chamber configurations
- Absolute humidity (AH) based deadzone control
- Non-negotiable temperature limits
- NTC temperature sensor logging
- Per-chamber humidifier support
- Sleep cycle management
- Statistics collection

## Quick Start

### Step 1: Upload JSON Config to GitHub

Choose the appropriate config file for your installation:

| File | Chambers | Variables |
|------|----------|-----------|
| `erlelo_config_1ch.json` | 1 | 40 |
| `erlelo_config_2ch.json` | 2 | 72 |
| `erlelo_config_3ch.json` | 3 | 104 |

Upload to: `https://github.com/kekhazkft-code/setup/main/`

### Step 2: Create Variables

1. Open `erlelo_create.lua`
2. Set `NUM_CHAMBERS = 1`, `2`, or `3` at the top
3. Deploy to Sinum as a Custom Device
4. Press "Start Install" button
5. Wait for completion message

### Step 3: Build Variable Mapping

1. Deploy `erlelo_store.lua` to Sinum
2. Press "Build Mapping" button
3. **IMPORTANT:** Copy the printed `MAPPING_VAR_ID` value

```
╔════════════════════════════════════════════════════════════╗
║  IMPORTANT: Copy this ID to your controller files!        ║
║                                                            ║
║  MAPPING_VAR_ID = 42                                       ║
╚════════════════════════════════════════════════════════════╝
```

### Step 4: Configure Controllers

Edit each controller file with your hardware settings:

**erlelo_kulso.lua** (outdoor sensor):
```lua
local MAPPING_VAR_ID = 42              -- From step 3
local MODBUS_OUTDOOR_CLIENT = 7        -- Your Modbus client ID
```

**erlelo_kamra1.lua** (chamber 1):
```lua
local CHAMBER_ID = 1
local MAPPING_VAR_ID = 42              -- From step 3
local MODBUS_SUPPLY_CLIENT = 8         -- Supply air sensor
local MODBUS_CHAMBER_CLIENT = 9        -- Chamber sensor

local SBUS_CONFIG = {
  rel_warm = 1,                        -- Heating relay
  rel_cool = 2,                        -- Cooling relay
  -- ... set all your SBUS IDs
}
```

### Step 5: Deploy and Enable

1. Deploy `erlelo_kulso.lua` - enable it
2. Deploy `erlelo_kamra1.lua` - enable it
3. (Optional) Copy kamra1, change `CHAMBER_ID = 2` or `3`, deploy

## Variable Naming Convention

All variables follow a strict naming pattern:

**Chamber-specific** (suffix `_ch1`, `_ch2`, `_ch3`):
```
kamra_homerseklet_ch1    Chamber 1 temperature
kamra_para_ch2           Chamber 2 humidity
signals_ch3              Chamber 3 control signals
```

**Global** (suffix `_glbl`):
```
kulso_homerseklet_glbl   Outdoor temperature
kulso_para_glbl          Outdoor humidity
variable_name_map_glbl   Name→ID mapping (built by erlelo_store)
```

## File Structure

```
erlelo_config_1ch.json   ─┐
erlelo_config_2ch.json    ├── Upload ONE to GitHub
erlelo_config_3ch.json   ─┘

erlelo_create.lua        Step 1: Creates variables from GitHub JSON
erlelo_store.lua         Step 2: Builds name→ID mapping
erlelo_kulso.lua         Outdoor sensor controller
erlelo_kamra1.lua        Chamber controller (copy for kamra2, kamra3)
erlelo_delete.lua        Cleanup: removes all erlelo variables
```

## Reinstallation

To start fresh:
1. Run `erlelo_delete.lua` - removes all erlelo variables
2. Repeat installation from Step 2

## Control Logic Summary

The system uses **Humidity-Primary Control**:

1. Calculate Absolute Humidity (AH) for chamber, supply, target, and outdoor
2. Determine mode based on AH difference from target:
   - **HUMID mode**: AH too high → need dehumidification
   - **FINE mode**: AH within deadzone → maintain
   - **DRY mode**: AH too low → need humidification

3. **Non-negotiable temperature limit**: If chamber temp > target + hysteresis → MUST COOL regardless of humidity mode

4. Control supply air temperature to achieve humidity goals while respecting temperature limits

## Troubleshooting

**"MAPPING_VAR_ID not set!"**
→ Run erlelo_store.lua and copy the printed ID to your controller file

**"Variable mapping empty"**
→ Run erlelo_store.lua after erlelo_create.lua

**"Modbus client not found"**
→ Check your Modbus Client IDs in Sinum settings match the values in your controller

**Chamber not responding**
→ Verify SBUS device IDs are correct for your relay outputs

## Documentation

- `SYSTEM_ARCHITECTURE.md` - Complete technical documentation
- `CHAMBER_SETUP_GUIDE.md` - Hardware configuration guide
- `QUICK_REFERENCE.md` - Control constants reference
- `SINUM_UI_GUIDE.md` - UI element setup

## Version History

- **v2.4**: Simplified workflow, 3 JSON configs, _ch/_glbl naming convention
- **v2.3**: Humidity-primary control, AH deadzone
- **v2.2**: Statistics system, NTC logging
- **v2.1**: Multi-chamber support
