# ERLELO v2.5 Quick Reference

## Variable Naming

```
Chamber-specific: {name}_ch{1,2,3}    → kamra_homerseklet_ch1
Global:           {name}_glbl         → kulso_homerseklet_glbl
```

## V() Function Resolution

```lua
V('kamra_homerseklet')  -- Tries: kamra_homerseklet_ch1 → kamra_homerseklet_glbl
V('kulso_homerseklet')  -- Finds: kulso_homerseklet_glbl
```

---

## All Variables

### Sensor Readings
| Variable | Type | Description |
|----------|------|-------------|
| `kamra_homerseklet` | int | Chamber temp ×10 |
| `kamra_para` | int | Chamber RH ×10 |
| `kamra_homerseklet_raw` | int | Raw chamber temp |
| `kamra_para_raw` | int | Raw chamber RH |
| `befujt_homerseklet_akt` | int | Supply temp ×10 |
| `befujt_para_akt` | int | Supply RH ×10 |
| `kulso_homerseklet` (glbl) | int | Outdoor temp ×10 |
| `kulso_para` (glbl) | int | Outdoor RH ×10 |

### Targets & Calculated
| Variable | Type | Description |
|----------|------|-------------|
| `kamra_cel_homerseklet` | int | Target chamber temp ×10 |
| `kamra_cel_para` | int | Target chamber RH ×10 |
| `befujt_cel_homerseklet` | int | Calculated supply target temp |
| `befujt_cel_para` | int | Calculated supply target RH |
| `ah_kamra` | int | Chamber AH ×1000 (mg/m³) |
| `ah_befujt` | int | Supply AH ×1000 |
| `ah_cel` | int | Target AH ×1000 |
| `dp_kamra` | int | Chamber dew point ×10 |

### Control State
| Variable | Type | Description |
|----------|------|-------------|
| `constansok` | string | All 20 parameters JSON |
| `signals` | string | Control signals JSON |
| `cycle_variable` | string | Sleep cycle state JSON |

---

## Control Parameters (C() Function)

### Chamber Loop (Outer) - Actually Used
| Parameter | Default | Real | Unit |
|-----------|---------|------|------|
| `deltahi_kamra_homerseklet` | 15 | 1.5 | °C |
| `deltalo_kamra_homerseklet` | 10 | 1.0 | °C |
| `temp_hysteresis_kamra` | 5 | 0.5 | °C |
| `ah_deadzone_kamra` | 80 | 0.8 | g/m³ |
| `ah_hysteresis_kamra` | 30 | 0.3 | g/m³ |

### Supply Loop (Inner) - Actually Used
| Parameter | Default | Real | Unit |
|-----------|---------|------|------|
| `deltahi_befujt_homerseklet` | 10 | 1.0 | °C |
| `deltalo_befujt_homerseklet` | 10 | 1.0 | °C |
| `temp_hysteresis_befujt` | 3 | 0.3 | °C |

### Global - Actually Used
| Parameter | Default | Real | Unit |
|-----------|---------|------|------|
| `outdoor_mix_ratio` | 30 | 30 | % |
| `outdoor_use_threshold` | 50 | 5.0 | °C |
| `proportional_gain` | 10 | 1.0 | - |
| `min_supply_air_temp` | 60 | 6.0 | °C |
| `max_supply_air_temp` | 400 | 40.0 | °C |
| `min_temp_no_humidifier` | 110 | 11.0 | °C |

### Sensor Processing - Actually Used
| Parameter | Default | Real | Unit |
|-----------|---------|------|------|
| `buffer_size` | 5 | 5 | samples |
| `spike_threshold` | 50 | 5.0 | units |
| `max_error_count` | 10 | 10 | errors |
| `temp_change_threshold` | 2 | 0.2 | °C |
| `humidity_change_threshold` | 5 | 0.5 | % |
| `humidifier_installed` | false | - | bool |

### Initialization
| Parameter | Default | Real | Unit |
|-----------|---------|------|------|
| `init_duration` | 32 | 32 | seconds |

### Reserved (In Config, Not Used Yet)
| Parameter | Default | Description |
|-----------|---------|-------------|
| `ah_deadzone_befujt` | 50 | Future supply AH control |
| `ah_hysteresis_befujt` | 20 | Future supply AH control |

---

## Humidity Modes

| Mode | Value | Entry | Exit | Action |
|------|-------|-------|------|--------|
| FINE | 0 | Within deadzone | - | Fine temp, outdoor mix |
| HUMID | 1 | AH > target + 0.8 | AH < target - 0.3 | Aggressive cooling |
| DRY | 2 | AH < target - 0.8 | AH > target + 0.3 | Block heating |

---

## Signal Outputs (signals JSON)

| Signal | Type | Description |
|--------|------|-------------|
| `kamra_hutes` | bool | Chamber cooling request |
| `kamra_futes` | bool | Chamber heating request |
| `kamra_para_hutes` | bool | Dehumidification (MODE_HUMID) |
| `befujt_hutes` | bool | Supply cooling request |
| `befujt_futes` | bool | Supply heating request |
| `relay_cool` | bool | Cooling relay output |
| `relay_warm` | bool | Heating relay output |
| `humidity_mode` | int | Current mode (0/1/2) |
| `heating_blocked` | bool | Blocked due to DRY mode |
| `init_complete` | bool | Initialization finished |
| `init_countdown` | int | Seconds remaining in init |

---

## Files

| File | Purpose |
|------|---------|
| `erlelo_kamra1.lua` | Chamber controller |
| `erlelo_kulso.lua` | Outdoor sensor |
| `erlelo_create.lua` | Variable creator |
| `erlelo_store.lua` | ID mapper |
| `erlelo_delete.lua` | Variable deleter |
| `erlelo_constants_editor.lua` | Runtime tuning UI |
| `erlelo_config_Xch.json` | Config (1/2/3 chambers) |

---

## Formulas

### Absolute Humidity (g/m³)
```
e_s = 6.112 × exp(17.67 × T / (T + 243.5))
AH = 2.1674 × (RH/100) × e_s / (273.15 + T)
```

### Dew Point (°C)
```
γ = ln(RH/100) + 17.67 × T / (243.5 + T)
DP = 243.5 × γ / (17.67 - γ)
```

---

## Component Patterns (Sinum)

```lua
-- Correct v2.5 pattern
http = CustomDevice.getComponent(CustomDevice, 'http')
timer = CustomDevice.getComponent(CustomDevice, 'timer')

-- WRONG (do not use)
http = self:getComponent('http')
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Variable not found | Check suffix (_ch1 vs _glbl) |
| Mode oscillating | Increase ah_hysteresis_kamra |
| Slow response | Decrease buffer_size (min 3) |
| Heating blocked in DRY | Normal! "Better cold than dry" |
| HTTP component error | Use CustomDevice.getComponent pattern |
