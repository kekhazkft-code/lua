# ERLELO v2.5 - Humidity-Primary Climate Control System

## Overview

ERLELO (Érlelő = Ripening/Aging Chamber) is a climate control system for agricultural product storage chambers. It implements **humidity-primary control** using absolute humidity (AH) as the primary control variable, with temperature as secondary.

### Design Philosophy: "Better Cold Than Dry"

Humidity takes priority because:
- **Dry conditions cause irreversible product damage** (weight loss, quality degradation)
- **Cold only slows the process** (fully recoverable)
- Product equilibrium depends on **absolute humidity**, not relative humidity

---

## v2.5 Key Features

### 1. Dual-Layer Cascade Control

Two control loops work together:

| Layer | Scope | Thresholds | Response |
|-------|-------|------------|----------|
| **Chamber (Outer)** | AH mode + temp | Wider (+1.5/-1.0°C, 0.8 g/m³) | Slower, stable |
| **Supply (Inner)** | Temp only | Tighter (+1.0/-1.0°C) | Faster, reactive |

**Important:** The supply loop controls temperature only. AH control is mode-based at chamber level.

### 2. Directional Hysteresis

Mode transitions require crossing **opposite thresholds**:
- Entry to HUMID: AH > target + deadzone (must rise above)
- Exit from HUMID: AH < target - hysteresis (must fall below)

This creates a "gap" that prevents rapid mode switching.

### 3. Humidity State Machine

Three explicit modes with clear transitions:

| Mode | Condition | Action |
|------|-----------|--------|
| **FINE** | AH within ±0.8 g/m³ | Fine temp control, outdoor mixing |
| **HUMID** | AH > target + 0.8 g/m³ | Aggressive cooling/dehumidification |
| **DRY** | AH < target - 0.8 g/m³ | Block heating, humidify if available |

### 4. All Parameters Configurable

**21 control parameters** read from the `constansok` variable at runtime:
- No hardcoded control values
- Adjustable via `erlelo_constants_editor.lua`
- Changes take effect on next cycle (no restart)

### 5. Safe Initialization

On system reboot, all variables reset to defaults (0). To prevent dangerous responses:
- **32-second initialization period** after startup
- All relays held in **safe OFF state** during init
- Normal control logic runs (sensors, buffers, calculations)
- Relay control enabled only after initialization completes

---

## Variable Naming Convention

```
Chamber-specific: {name}_ch{1,2,3}    Example: kamra_homerseklet_ch1
Global:           {name}_glbl         Example: kulso_homerseklet_glbl
```

The V() function resolves names automatically:
```lua
V('kamra_homerseklet')  -- Tries _ch1 first, then _glbl
V('kulso_homerseklet')  -- Finds kulso_homerseklet_glbl
```

---

## Control Parameters (constansok)

### Chamber Loop Parameters (Used)
| Parameter | Default | Real Value | Description |
|-----------|---------|------------|-------------|
| `deltahi_kamra_homerseklet` | 15 | +1.5°C | Upper temp threshold |
| `deltalo_kamra_homerseklet` | 10 | -1.0°C | Lower temp threshold |
| `temp_hysteresis_kamra` | 5 | 0.5°C | Temp exit hysteresis |
| `ah_deadzone_kamra` | 80 | 0.8 g/m³ | AH mode deadzone |
| `ah_hysteresis_kamra` | 30 | 0.3 g/m³ | AH mode exit hysteresis |

### Supply Loop Parameters (Used)
| Parameter | Default | Real Value | Description |
|-----------|---------|------------|-------------|
| `deltahi_befujt_homerseklet` | 10 | +1.0°C | Upper temp threshold |
| `deltalo_befujt_homerseklet` | 10 | -1.0°C | Lower temp threshold |
| `temp_hysteresis_befujt` | 3 | 0.3°C | Temp exit hysteresis |

### Global Parameters (Used)
| Parameter | Default | Real Value | Description |
|-----------|---------|------------|-------------|
| `outdoor_mix_ratio` | 30 | 30% | Outdoor air mix in FINE mode |
| `outdoor_use_threshold` | 50 | 5.0°C | Min advantage for outdoor |
| `proportional_gain` | 10 | 1.0 | P gain in aggressive modes |
| `min_supply_air_temp` | 60 | 6.0°C | Minimum supply temp |
| `max_supply_air_temp` | 400 | 40.0°C | Maximum supply temp |
| `min_temp_no_humidifier` | 110 | 11.0°C | Min temp when blocking heat |

### Sensor Processing Parameters (Used)
| Parameter | Default | Real Value | Description |
|-----------|---------|------------|-------------|
| `buffer_size` | 5 | 5 samples | Moving average buffer |
| `spike_threshold` | 50 | ±5.0 | Spike filter threshold |
| `max_error_count` | 10 | 10 errors | Before failsafe mode |
| `temp_change_threshold` | 2 | 0.2°C | Propagation threshold |
| `humidity_change_threshold` | 5 | 0.5% | Propagation threshold |

### Initialization Parameters
| Parameter | Default | Real Value | Description |
|-----------|---------|------------|-------------|
| `init_duration` | 32 | 32 seconds | Safe initialization period |

### Reserved Parameters (In Config, Not Currently Used)
| Parameter | Default | Description |
|-----------|---------|-------------|
| `ah_deadzone_befujt` | 50 | Reserved for future supply AH control |
| `ah_hysteresis_befujt` | 20 | Reserved for future supply AH control |
| `humidifier_start_delta` | 50 | Humidifier start threshold |
| `sleep_cycle_enabled` | false | Sleep cycle feature |
| `sleep_on_minutes` | 45 | Sleep cycle on period |
| `sleep_off_minutes` | 15 | Sleep cycle off period |

---

## Files Included

### Controllers
| File | Description |
|------|-------------|
| `erlelo_kamra1.lua` | Chamber controller (copy for kamra2, kamra3) |
| `erlelo_kulso.lua` | Outdoor sensor controller |

### Utilities
| File | Description |
|------|-------------|
| `erlelo_create.lua` | Creates variables from config JSON |
| `erlelo_store.lua` | Builds name→ID mapping |
| `erlelo_delete.lua` | Removes erlelo variables |
| `erlelo_constants_editor.lua` | Runtime parameter editor UI |

### Configuration
| File | Variables | Description |
|------|-----------|-------------|
| `erlelo_config_1ch.json` | 41 | 1-chamber setup |
| `erlelo_config_2ch.json` | 73 | 2-chamber setup |
| `erlelo_config_3ch.json` | 105 | 3-chamber setup |

---

## Quick Start

### 1. Create Variables
```
1. Upload erlelo_config_Xch.json to GitHub (raw URL)
2. Edit erlelo_create.lua: set CONFIG_URL
3. Run in Sinum → Note variable count
```

### 2. Build Mapping
```
1. Run erlelo_store.lua in Sinum
2. Note the MAPPING_VAR_ID printed
```

### 3. Configure Controllers
```
erlelo_kulso.lua:
  - MAPPING_VAR_ID
  - MODBUS_OUTDOOR_CLIENT

erlelo_kamra1.lua:
  - CHAMBER_ID (1, 2, or 3)
  - MAPPING_VAR_ID  
  - MODBUS_SUPPLY_CLIENT
  - MODBUS_CHAMBER_CLIENT
  - SBUS_CONFIG relay IDs
```

### 4. Deploy
```
1. Deploy erlelo_kulso.lua
2. Deploy erlelo_kamra1.lua (copy for additional chambers)
3. Monitor via Sinum UI
```

---

## Runtime Tuning

Use `erlelo_constants_editor.lua`:
1. Select chamber (1, 2, or 3)
2. Press Refresh to load current values
3. Modify parameters
4. Press Save (updates immediately)

---

## Version History

| Version | Changes |
|---------|---------|
| **v2.5** | Dual-layer cascade, directional hysteresis, humidity state machine, all 20 parameters configurable via constansok |
| v2.4 | Humidity-primary control, HTTP component pattern fixes |
| v2.3 | Variable naming standardization |
| v2.2 | Psychrometric calculations |
| v2.1 | Moving average buffers |
| v2.0 | Initial humidity-primary design |
