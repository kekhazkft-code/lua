--[[
  ERLELO CHAMBER CONTROLLER v2.4
  erlelo_kamra.lua
  
  Humidity-Primary Control System
  
  SETUP: Edit the configuration section below, then deploy to Sinum
  
  Copy this file for each chamber:
    erlelo_kamra1.lua -> CHAMBER_ID = 1
    erlelo_kamra2.lua -> CHAMBER_ID = 2
    erlelo_kamra3.lua -> CHAMBER_ID = 3
]]

-- ============================================================================
-- USER CONFIGURATION - EDIT THESE VALUES
-- ============================================================================

local CHAMBER_ID = 1  -- Chamber number: 1, 2, or 3

-- After running erlelo_store, it will print the mapping variable ID
-- Enter that ID here:
local MAPPING_VAR_ID = nil  -- Set after running erlelo_store (e.g., 42)

-- Modbus client IDs (from Sinum Modbus Client settings)
local MODBUS_SUPPLY_CLIENT = nil   -- Supply air sensor Modbus Client ID
local MODBUS_CHAMBER_CLIENT = nil  -- Chamber sensor Modbus Client ID

-- SBUS device IDs (from Sinum SBUS settings)
local SBUS_CONFIG = {
  inp_humidity_save = nil,  -- Humidity save input
  inp_sum_wint = nil,       -- Summer/winter input
  inp_weight_1 = nil,       -- Weight sensor 1 input
  inp_weight_2 = nil,       -- Weight sensor 2 input
  rel_warm = nil,           -- Heating relay output
  rel_cool = nil,           -- Cooling relay output
  rel_add_air_max = nil,    -- Max air addition relay
  rel_reventon = nil,       -- Reventon relay
  rel_add_air_save = nil,   -- Air save relay
  rel_bypass_open = nil,    -- Bypass open relay
  rel_main_fan = nil,       -- Main fan relay
  rel_humidifier = nil,     -- Humidifier relay
  rel_sleep = nil,          -- Sleep mode relay
}

-- ============================================================================
-- END OF USER CONFIGURATION
-- ============================================================================

-- ============================================================================
-- VARIABLE MAPPING SYSTEM
-- ============================================================================

local VAR_MAP = nil

local function loadVarMap()
  if VAR_MAP then return VAR_MAP end
  
  if not MAPPING_VAR_ID then
    print("ERROR: MAPPING_VAR_ID not set!")
    print("Run erlelo_store first, then set MAPPING_VAR_ID in this file.")
    return nil
  end
  
  local json = variable[MAPPING_VAR_ID]:getValue()
  if not json or json == "" or json == "{}" then
    print("ERROR: Variable mapping empty at ID " .. MAPPING_VAR_ID)
    print("Run erlelo_store to build the mapping.")
    return nil
  end
  
  local ok, parsed = pcall(function() return JSON:decode(json) end)
  if not ok or not parsed then
    print("ERROR: Failed to parse variable mapping JSON")
    return nil
  end
  
  VAR_MAP = parsed
  return VAR_MAP
end

-- Get variable by name (with appropriate suffix)
-- Chamber-specific variables: name_ch1, name_ch2, name_ch3
-- Global variables: name_glbl (outdoor, mapping)
local function V(name)
  local map = loadVarMap()
  if not map then
    print("ERROR: Cannot load variable map")
    return nil
  end
  
  -- First try chamber-specific suffix
  local var_name = name .. "_ch" .. CHAMBER_ID
  local idx = map[var_name]
  
  -- If not found, try global suffix
  if not idx then
    var_name = name .. "_glbl"
    idx = map[var_name]
  end
  
  if not idx then
    print("WARNING: Variable '" .. name .. "' not found (tried _ch" .. CHAMBER_ID .. " and _glbl)")
    return nil
  end
  
  return variable[idx]
end

-- Get table value from a variable (handles JSON string parsing)
local function getTableValue(var)
  if not var then return {} end
  local val = var:getValue()
  if not val then return {} end
  if type(val) == "table" then return val end
  if type(val) == "string" and val ~= "" and val ~= "{}" then
    local ok, parsed = pcall(function() return JSON:decode(val) end)
    if ok and parsed then return parsed end
  end
  return {}
end

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local HW = {}             -- Hardware (SBUS) shortcuts
local mb_supply = nil     -- Modbus client for supply air
local mb_chamber = nil    -- Modbus client for chamber
local poll_timer = nil
local inside_supply_deadzone = false  -- Deadzone state for hysteresis adjustment

-- ============================================================================
-- TIMING CONFIGURATION
-- ============================================================================

local POLL_INTERVAL = 1000      -- Poll sensors every 1000ms (1 second)
local STATS_INTERVAL = 30       -- Record stats every 30 poll cycles (~30 seconds)
local SUPPLY_WARMUP_TIME = 120  -- Wait 120 seconds after active starts before collecting supply data
local stats_counter = 0         -- Counter for statistics timing
local active_start_time = nil   -- Timestamp when active phase started (for warmup delay)
local last_active_state = nil   -- Track active state changes

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Proper rounding function (rounds to nearest integer)
local function round(value)
  if value >= 0 then
    return math.floor(value + 0.5)
  else
    return math.ceil(value - 0.5)
  end
end

-- ============================================================================
-- PSYCHROMETRIC CALCULATIONS
-- ============================================================================

local PSYCHRO = {
  A = 6.112,
  B = 17.67,
  C = 243.5,
  MW_RATIO = 2.1674,
}

local function saturation_vapor_pressure(temp_c)
  return PSYCHRO.A * math.exp(PSYCHRO.B * temp_c / (PSYCHRO.C + temp_c))
end

local function calculate_absolute_humidity(temp_c, rh)
  local e_s = saturation_vapor_pressure(temp_c)
  return PSYCHRO.MW_RATIO * (rh / 100) * e_s / (273.15 + temp_c)
end

local function calculate_rh_from_ah(temp_c, ah)
  local e_s = saturation_vapor_pressure(temp_c)
  return (ah * (273.15 + temp_c) / (PSYCHRO.MW_RATIO * e_s)) * 100
end

local function calculate_dew_point(temp_c, rh)
  if rh <= 0 then return -999 end
  local gamma = math.log(rh / 100) + PSYCHRO.B * temp_c / (PSYCHRO.C + temp_c)
  return PSYCHRO.C * gamma / (PSYCHRO.B - gamma)
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function moving_average_update(buffer_var, result_var, new_value, buffer_size, threshold)
  if not buffer_var or not result_var then return false, nil end
  
  local buffer = buffer_var:getValue() or {}
  
  table.insert(buffer, new_value)
  if #buffer > buffer_size then
    table.remove(buffer, 1)
  end
  
  buffer_var:setValue(buffer, true)  -- No propagation
  
  if #buffer < buffer_size then
    return false, nil
  end
  
  local sum = 0
  for _, v in ipairs(buffer) do sum = sum + v end
  local avg = round(sum / #buffer)
  
  local old_avg = result_var:getValue() or 0
  if math.abs(avg - old_avg) >= threshold then
    result_var:setValue(avg, false)  -- PROPAGATE
    return true, avg
  else
    result_var:setValue(avg, true)   -- No propagation
    return false, avg
  end
end

local function set_relay(should_be_on, relay_sbus)
  if not relay_sbus then return false end
  local current = relay_sbus:getValue("state")
  if should_be_on and current ~= "on" then
    relay_sbus:call("turn_on")
    return true
  elseif not should_be_on and current ~= "off" then
    relay_sbus:call("turn_off")
    return true
  end
  return false
end

local function hysteresis(measured, target, delta_hi, delta_lo, current_state)
  if measured > target + delta_hi then
    return true
  elseif measured < target - delta_lo then
    return false
  else
    return current_state
  end
end

-- ============================================================================
-- STATISTICS RECORDING
-- ============================================================================

local function record_statistics()
  -- Check aktív/pihenő state from cycle variable
  local cycle_var = V('cycle_variable')
  local is_aktiv = true  -- Default to aktív if no cycle data
  if cycle_var then
    local cycle = getTableValue(cycle_var)
    is_aktiv = cycle.aktiv ~= false  -- aktiv unless explicitly false
  end
  
  -- Track active phase transitions for warmup timing
  local current_time = os.time()
  if last_active_state ~= is_aktiv then
    if is_aktiv then
      -- Just switched to active - start warmup timer
      active_start_time = current_time
      print("Active phase started - waiting " .. SUPPLY_WARMUP_TIME .. "s before collecting supply data")
    else
      -- Switched to rest - clear warmup timer
      active_start_time = nil
    end
    last_active_state = is_aktiv
  end
  
  -- Check if warmup period has elapsed (2 minutes after active starts)
  local supply_data_ready = is_aktiv and active_start_time and 
                            (current_time - active_start_time) >= SUPPLY_WARMUP_TIME
  
  -- Record aktív/pihenő state (1=aktív, 0=pihenő)
  statistics:addPoint("mode_ch" .. CHAMBER_ID, is_aktiv and 1 or 0, unit.bool_unit)
  
  -- Chamber temperature and humidity (always record)
  local kamra_hom = V('kamra_homerseklet')
  local kamra_para = V('kamra_para')
  
  if kamra_hom then
    local temp = kamra_hom:getValue()
    if temp then
      statistics:addPoint("chamber_temp_ch" .. CHAMBER_ID, temp, unit.celsius_x10)
    end
  end
  
  if kamra_para then
    local humi = kamra_para:getValue()
    if humi then
      statistics:addPoint("chamber_humidity_ch" .. CHAMBER_ID, humi, unit.relative_humidity_x10)
    end
  end
  
  -- Supply air temperature and humidity (ONLY after 2-min warmup in aktív phase)
  if supply_data_ready then
    local befujt_hom = V('befujt_homerseklet_akt')
    local befujt_para = V('befujt_para_akt')
    
    if befujt_hom then
      local temp = befujt_hom:getValue()
      if temp then
        statistics:addPoint("supply_temp_ch" .. CHAMBER_ID, temp, unit.celsius_x10)
      end
    end
    
    if befujt_para then
      local humi = befujt_para:getValue()
      if humi then
        statistics:addPoint("supply_humidity_ch" .. CHAMBER_ID, humi, unit.relative_humidity_x10)
      end
    end
    
    -- NTC water temperatures (ONLY after 2-min warmup in aktív phase)
    local ntc1 = V('ntc1_homerseklet')
    local ntc2 = V('ntc2_homerseklet')
    local ntc3 = V('ntc3_homerseklet')
    local ntc4 = V('ntc4_homerseklet')
    
    if ntc1 then
      local temp = ntc1:getValue()
      if temp then statistics:addPoint("ntc1_ch" .. CHAMBER_ID, temp, unit.celsius_x10) end
    end
    if ntc2 then
      local temp = ntc2:getValue()
      if temp then statistics:addPoint("ntc2_ch" .. CHAMBER_ID, temp, unit.celsius_x10) end
    end
    if ntc3 then
      local temp = ntc3:getValue()
      if temp then statistics:addPoint("ntc3_ch" .. CHAMBER_ID, temp, unit.celsius_x10) end
    end
    if ntc4 then
      local temp = ntc4:getValue()
      if temp then statistics:addPoint("ntc4_ch" .. CHAMBER_ID, temp, unit.celsius_x10) end
    end
  end
  
  -- Target values (always record)
  local cel_hom = V('kamra_cel_homerseklet')
  local cel_para = V('kamra_cel_para')
  
  if cel_hom then
    local temp = cel_hom:getValue()
    if temp then
      statistics:addPoint("target_temp_ch" .. CHAMBER_ID, temp, unit.celsius_x10)
    end
  end
  
  if cel_para then
    local humi = cel_para:getValue()
    if humi then
      statistics:addPoint("target_humidity_ch" .. CHAMBER_ID, humi, unit.relative_humidity_x10)
    end
  end
  
  -- Dew point values
  local dp_kamra = V('dp_kamra')
  local dp_befujt = V('dp_befujt')
  local dp_cel = V('dp_cel')
  
  if dp_kamra then
    local dp = dp_kamra:getValue()
    if dp then
      statistics:addPoint("chamber_dewpoint_ch" .. CHAMBER_ID, dp, unit.celsius_x10)
    end
  end
  
  -- Supply dew point (ONLY after 2-min warmup)
  if supply_data_ready and dp_befujt then
    local dp = dp_befujt:getValue()
    if dp then
      statistics:addPoint("supply_dewpoint_ch" .. CHAMBER_ID, dp, unit.celsius_x10)
    end
  end
  
  if dp_cel then
    local dp = dp_cel:getValue()
    if dp then
      statistics:addPoint("target_dewpoint_ch" .. CHAMBER_ID, dp, unit.celsius_x10)
    end
  end
end

local function log_control_action(old_signals, new_signals)
  -- Log meaningful control state changes
  local prefix = "ch" .. CHAMBER_ID .. "_"
  
  -- Heating state
  if old_signals.kamra_futes ~= new_signals.kamra_futes then
    statistics:addPoint(prefix .. "heating", new_signals.kamra_futes and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " heating " .. (new_signals.kamra_futes and "ON" or "OFF"))
  end
  
  -- Cooling state
  if old_signals.kamra_hutes ~= new_signals.kamra_hutes then
    statistics:addPoint(prefix .. "cooling", new_signals.kamra_hutes and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " cooling " .. (new_signals.kamra_hutes and "ON" or "OFF"))
  end
  
  -- Dehumidification state
  if old_signals.kamra_para_hutes ~= new_signals.kamra_para_hutes then
    statistics:addPoint(prefix .. "dehumidify", new_signals.kamra_para_hutes and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " dehumidify " .. (new_signals.kamra_para_hutes and "ON" or "OFF"))
  end
  
  -- Supply heating
  if old_signals.befujt_futes ~= new_signals.befujt_futes then
    statistics:addPoint(prefix .. "supply_heat", new_signals.befujt_futes and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " supply heating " .. (new_signals.befujt_futes and "ON" or "OFF"))
  end
  
  -- Supply cooling
  if old_signals.befujt_hutes ~= new_signals.befujt_hutes then
    statistics:addPoint(prefix .. "supply_cool", new_signals.befujt_hutes and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " supply cooling " .. (new_signals.befujt_hutes and "ON" or "OFF"))
  end
  
  -- Humidification
  if old_signals.relay_humidifier ~= new_signals.relay_humidifier then
    statistics:addPoint(prefix .. "humidifier", new_signals.relay_humidifier and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " humidifier " .. (new_signals.relay_humidifier and "ON" or "OFF"))
  end
  
  -- Sleep mode
  if old_signals.sleep ~= new_signals.sleep then
    statistics:addPoint(prefix .. "sleep", new_signals.sleep and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " sleep mode " .. (new_signals.sleep and "ON" or "OFF"))
  end
  
  -- Bypass
  if old_signals.relay_bypass_open ~= new_signals.relay_bypass_open then
    statistics:addPoint(prefix .. "bypass", new_signals.relay_bypass_open and 1 or 0, unit.bool_unit)
    print("STATS: Chamber " .. CHAMBER_ID .. " bypass " .. (new_signals.relay_bypass_open and "OPEN" or "CLOSED"))
  end
end

-- ============================================================================
-- UI REFRESH
-- ============================================================================

local function refresh_ui(device)
  -- Helper to safely update UI element
  local function updateElement(name, value)
    local elem = device:getElement(name)
    if elem then
      elem:setValue('value', value, true)
    end
  end
  
  -- Get current values
  local kamra_hom = V('kamra_homerseklet')
  local kamra_para = V('kamra_para')
  local befujt_hom = V('befujt_homerseklet_akt')
  local befujt_para = V('befujt_para_akt')
  local kulso_hom = V('kulso_homerseklet')
  local kulso_para = V('kulso_para')
  local dp_kamra = V('dp_kamra')
  local dp_befujt = V('dp_befujt')
  local dp_cel = V('dp_cel')
  local ah_kamra = V('ah_kamra')
  local ah_befujt = V('ah_befujt')
  local kulso_ah_dp = V('kulso_ah_dp')
  local signals_var = V('signals')
  
  -- Chamber temperature and humidity
  if kamra_hom then
    local temp = kamra_hom:getValue() or 0
    updateElement('_3_tx_kamra_homerseklet_', string.format("%.1f°C", temp / 10))
  end
  
  if kamra_para then
    local humi = kamra_para:getValue() or 0
    updateElement('_4_tx_kamra_para_', string.format("%.1f%%", humi / 10))
  end
  
  -- Supply air temperature and humidity
  if befujt_hom then
    local temp = befujt_hom:getValue() or 0
    updateElement('_1_tx_befujt_homerseklet_', string.format("%.1f°C", temp / 10))
  end
  
  if befujt_para then
    local humi = befujt_para:getValue() or 0
    updateElement('_2_tx_befujt_para_', string.format("%.1f%%", humi / 10))
  end
  
  -- Outdoor temperature and humidity
  if kulso_hom then
    local temp = kulso_hom:getValue() or 0
    updateElement('_3_tx_kulso_homerseklet_', string.format("%.1f°C", temp / 10))
  end
  
  if kulso_para then
    local humi = kulso_para:getValue() or 0
    updateElement('_4_tx_kulso_para_', string.format("%.1f%%", humi / 10))
  end
  
  -- Dew points
  if dp_kamra then
    local dp = dp_kamra:getValue() or 0
    updateElement('dp_kamra_tx', string.format("HP: %.1f°C", dp / 10))
  end
  
  if dp_befujt then
    local dp = dp_befujt:getValue() or 0
    updateElement('dp_befujt_tx', string.format("HP: %.1f°C", dp / 10))
  end
  
  if dp_cel then
    local dp = dp_cel:getValue() or 0
    updateElement('dp_cel_tx', string.format("Cél HP: %.1f°C", dp / 10))
  end
  
  -- Outdoor dew point
  if kulso_ah_dp then
    local data = getTableValue(kulso_ah_dp)
    if data.dp then
      updateElement('dp_kulso_tx', string.format("HP: %.1f°C", data.dp))
    end
  end
  
  -- Absolute humidity values
  if ah_kamra then
    local ah = ah_kamra:getValue() or 0
    updateElement('ah_kamra_tx', string.format("AH: %.3fg/m³", ah / 1000))
  end
  
  if ah_befujt then
    local ah = ah_befujt:getValue() or 0
    updateElement('ah_befujt_tx', string.format("AH: %.3fg/m³", ah / 1000))
  end
  
  if kulso_ah_dp then
    local data = getTableValue(kulso_ah_dp)
    if data.ah then
      updateElement('ah_kulso_tx', string.format("AH: %.3fg/m³", data.ah))
    end
  end
  
  -- Control status indicators
  if signals_var then
    local signals = getTableValue(signals_var)
    
    -- Heating/Cooling status
    if signals.kamra_futes then
      updateElement('text_input_0_warm', "Fűtés Aktív!")
    else
      updateElement('text_input_0_warm', " ")
    end
    
    if signals.kamra_hutes then
      updateElement('text_input_1_cool', "Hűtés Aktív!")
    else
      updateElement('text_input_1_cool', " ")
    end
    
    -- Dehumidification status
    if signals.kamra_para_hutes then
      updateElement('text_input_2_wdis', "Párátlanítás!")
    else
      updateElement('text_input_2_wdis', " ")
    end
    
    -- Humidification status
    if signals.relay_humidifier then
      updateElement('text_input_3_cdis', "Párásítás!")
    else
      updateElement('text_input_3_cdis', " ")
    end
  end
end

-- ============================================================================
-- SENSOR DATA PROCESSING
-- ============================================================================

local function update_supply_psychrometric()
  local temp_var = V('befujt_homerseklet_akt')
  local humi_var = V('befujt_para_akt')
  
  if not temp_var or not humi_var then return end
  
  local temp = temp_var:getValue() or 0
  local humi = humi_var:getValue() or 0
  
  if temp == 0 or humi == 0 then return end
  
  local temp_c = temp / 10
  local rh = humi / 10
  
  local ah = calculate_absolute_humidity(temp_c, rh)
  local dp = calculate_dew_point(temp_c, rh)
  
  local ah_dp_var = V('ah_dp_table')
  if not ah_dp_var then return end
  
  local data = getTableValue(ah_dp_var)
  data.befujt_ah = math.floor(ah * 100) / 100
  data.befujt_dp = math.floor(dp * 10) / 10
  ah_dp_var:setValue(data, true)
end

local function update_chamber_psychrometric()
  local temp_var = V('kamra_homerseklet')
  local humi_var = V('kamra_para')
  
  if not temp_var or not humi_var then return end
  
  local temp = temp_var:getValue() or 0
  local humi = humi_var:getValue() or 0
  
  if temp == 0 or humi == 0 then return end
  
  local temp_c = temp / 10
  local rh = humi / 10
  
  local ah = calculate_absolute_humidity(temp_c, rh)
  local dp = calculate_dew_point(temp_c, rh)
  
  local ah_dp_var = V('ah_dp_table')
  if not ah_dp_var then return end
  
  local data = getTableValue(ah_dp_var)
  data.kamra_ah = math.floor(ah * 100) / 100
  data.kamra_dp = math.floor(dp * 10) / 10
  ah_dp_var:setValue(data, true)
end

local function process_supply_data(raw_temp, raw_humi)
  local temp_changed = moving_average_update(
    V('befujt_homerseklet_table'),
    V('befujt_homerseklet_akt'),
    raw_temp,
    control.buffer_size_supply,
    control.temp_threshold
  )
  
  local humi_changed = moving_average_update(
    V('befujt_para_table'),
    V('befujt_para_akt'),
    raw_humi,
    control.buffer_size_supply,
    control.humidity_threshold
  )
  
  if temp_changed or humi_changed then
    update_supply_psychrometric()
  end
end

local function process_chamber_data(raw_temp, raw_humi)
  local temp_changed = moving_average_update(
    V('kamra_homerseklet_table'),
    V('kamra_homerseklet'),
    raw_temp,
    control.buffer_size_chamber,
    control.temp_threshold
  )
  
  local humi_changed = moving_average_update(
    V('kamra_para_table'),
    V('kamra_para'),
    raw_humi,
    control.buffer_size_chamber,
    control.humidity_threshold
  )
  
  if temp_changed or humi_changed then
    update_chamber_psychrometric()
  end
end

-- ============================================================================
-- MODBUS HANDLING
-- ============================================================================

local function handle_supply_response(kind, addr, values)
  if kind ~= "INPUT_REGISTERS" then return end
  
  -- Reset error counter on successful read
  local befujt_hibaszam = V('befujt_hibaszam')
  if befujt_hibaszam then
    befujt_hibaszam:setValue(control.max_error_count, true)
  end
  
  local mb_cfg = config.modbus["chamber_" .. CHAMBER_ID]
  
  -- Single read returns both temp and humidity
  if addr == mb_cfg.reg_temperature and values[1] and values[2] then
    process_supply_data(values[1], values[2])
  end
end

local function handle_chamber_response(kind, addr, values)
  if kind ~= "INPUT_REGISTERS" then return end
  
  -- Reset error counter on successful read
  local kamra_hibaszam = V('kamra_hibaszam')
  if kamra_hibaszam then
    kamra_hibaszam:setValue(control.max_error_count, true)
  end
  
  local mb_cfg = config.modbus["chamber_" .. CHAMBER_ID]
  
  -- Single read returns both temp and humidity
  if addr == mb_cfg.reg_temperature and values[1] and values[2] then
    process_chamber_data(values[1], values[2])
  end
end

local function handle_supply_error(request, err, kind, addr)
  if err == "TIMEOUT" or err == "BAD_CRC" then
    local befujt_hibaszam = V('befujt_hibaszam')
    if befujt_hibaszam then
      local count = befujt_hibaszam:getValue() or control.max_error_count
      if count > 0 then
        befujt_hibaszam:setValue(count - 1, true)
      end
    end
  end
end

local function handle_chamber_error(request, err, kind, addr)
  if err == "TIMEOUT" or err == "BAD_CRC" then
    local kamra_hibaszam = V('kamra_hibaszam')
    if kamra_hibaszam then
      local count = kamra_hibaszam:getValue() or control.max_error_count
      if count > 0 then
        kamra_hibaszam:setValue(count - 1, true)
      end
    end
  end
end

local function poll_sensors()
  local mb_cfg = config.modbus["chamber_" .. CHAMBER_ID]
  
  -- Always poll Modbus - averaging must continue even in simulation mode
  -- so real values are immediately ready when simulation is turned off
  
  -- Poll supply air sensor (single read for both registers)
  if mb_supply then
    mb_supply:readInputRegistersAsync(mb_cfg.reg_temperature, 2)
  end
  
  -- Poll chamber sensor (single read for both registers)
  if mb_chamber then
    mb_chamber:readInputRegistersAsync(mb_cfg.reg_temperature, 2)
  end
end

-- ============================================================================
-- TARGET CALCULATION
-- ============================================================================

local function calculate_supply_targets()
  local kamra_cel_temp = V('kamra_cel_homerseklet')
  local kamra_cel_humi = V('kamra_cel_para')
  local kamra_hom_var = V('kamra_homerseklet')
  local kamra_para_var = V('kamra_para')
  local kulso_temp = V('kulso_homerseklet')
  local kulso_ah_dp = V('kulso_ah_dp')
  local constansok = V('constansok')
  
  if not kamra_cel_temp or not kamra_cel_humi or not kamra_hom_var or not kamra_para_var then
    return
  end
  if not kulso_temp or not kulso_ah_dp or not constansok then
    return
  end
  
  local kamra_cel_hom = kamra_cel_temp:getValue() or 0
  local kamra_cel_para = kamra_cel_humi:getValue() or 0
  local kamra_hom = kamra_hom_var:getValue() or 0
  local kamra_para = kamra_para_var:getValue() or 0
  local kulso_hom = kulso_temp:getValue() or 0
  local kulso_data = getTableValue(kulso_ah_dp)
  local const = getTableValue(constansok)
  
  if kamra_cel_hom == 0 or kamra_cel_para == 0 then return end
  
  -- =========================================================================
  -- HUMIDITY-PRIMARY DEADZONE CONTROL
  -- =========================================================================
  -- Two modes based on whether chamber HUMIDITY is within deadzone of target:
  --
  -- 1. OUTSIDE DEADZONE (AH error too large):
  --    Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) * P  where P = 1
  --    Simplified: Befujt_cél = 2 * Kamra_cél - Kamra_mért
  --    → Aggressive humidity correction, normal hysteresis
  --    → Priority: fix humidity first (too dry = damage, too humid = mold)
  --
  -- 2. INSIDE DEADZONE (AH within range, fine control):
  --    Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) * (1 - mix_ratio) 
  --                          - (Külső_mért - Kamra_cél) * mix_ratio
  --    → Fine-tune temperature, HALF hysteresis on supply
  --    → Temperature control is secondary when humidity is OK
  --
  -- WHY HUMIDITY-PRIMARY ("Better cold than dry"):
  --   - Too dry → irreversible product damage (surface cracking, case hardening)
  --   - Too humid → mold risk, critical to address
  --   - Too cold → just slows process, recoverable
  --   - Product equilibrium depends on AH, not temperature
  -- =========================================================================
  
  -- Calculate absolute humidity values for deadzone check
  local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
  local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
  
  -- AH deadzone threshold (from config or default)
  -- Default: 5% of target AH (e.g., 0.48 g/m³ for target 9.61 g/m³)
  local ah_deadzone_percent = (const.ah_deadzone or 50) / 10  -- Default 5.0%
  local ah_deadzone = target_ah * (ah_deadzone_percent / 100)
  
  -- Check if chamber humidity is within deadzone (humidity-primary)
  local ah_error = math.abs(current_ah - target_ah)
  local inside_ah_deadzone = ah_error <= ah_deadzone
  
  -- Store deadzone state for hysteresis adjustment
  inside_supply_deadzone = inside_ah_deadzone
  
  -- Calculate supply air target temperature
  local befujt_target_temp
  
  if inside_ah_deadzone then
    -- INSIDE AH DEADZONE: Fine control with outdoor mixing
    -- Humidity is OK → now fine-tune temperature
    -- Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) * (1 - mix) - (Külső - Kamra_cél) * mix
    local mix_ratio = (const.outdoor_mix_ratio or 30) / 100
    local chamber_error = kamra_hom - kamra_cel_hom
    local outdoor_offset = kulso_hom - kamra_cel_hom
    
    befujt_target_temp = kamra_cel_hom - chamber_error * (1 - mix_ratio) - outdoor_offset * mix_ratio
  else
    -- OUTSIDE AH DEADZONE: Aggressive proportional control
    -- Humidity out of range → aggressive correction, temperature secondary
    -- Befujt_cél = Kamra_cél - (Kamra_mért - Kamra_cél) * P, where P = 1
    -- = 2 * Kamra_cél - Kamra_mért
    local P = const.proportional_gain or 10  -- P gain * 10 (10 = 1.0)
    local chamber_error = kamra_hom - kamra_cel_hom
    
    befujt_target_temp = kamra_cel_hom - chamber_error * (P / 10)
  end
  
  -- Apply minimum temperature constraint
  local min_temp = const.min_supply_air_temp or 60
  if befujt_target_temp < min_temp then
    befujt_target_temp = min_temp
  end
  
  -- Apply maximum temperature constraint
  local max_temp = const.max_supply_air_temp or 400  -- 40°C default max
  if befujt_target_temp > max_temp then
    befujt_target_temp = max_temp
  end
  
  -- Calculate target absolute humidity (same for both modes)
  local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
  
  -- Calculate target humidity from target AH at supply temperature
  local befujt_target_rh = calculate_rh_from_ah(befujt_target_temp / 10, target_ah)
  local befujt_target_para = round(befujt_target_rh * 10)
  
  -- Clamp humidity to valid range
  if befujt_target_para < 0 then befujt_target_para = 0 end
  if befujt_target_para > 1000 then befujt_target_para = 1000 end
  
  -- Store targets (only propagate if changed beyond threshold)
  local befujt_cel_temp_var = V('befujt_cel_homerseklet')
  local befujt_cel_para_var = V('befujt_cel_para')
  
  local new_befujt_temp = round(befujt_target_temp)
  local new_befujt_para = befujt_target_para
  
  if befujt_cel_temp_var then
    local old_temp = befujt_cel_temp_var:getValue() or 0
    if math.abs(new_befujt_temp - old_temp) >= control.temp_threshold then
      befujt_cel_temp_var:setValue(new_befujt_temp, false)  -- Propagate
    else
      befujt_cel_temp_var:setValue(new_befujt_temp, true)   -- No propagation
    end
  end
  
  if befujt_cel_para_var then
    local old_para = befujt_cel_para_var:getValue() or 0
    if math.abs(new_befujt_para - old_para) >= control.humidity_threshold then
      befujt_cel_para_var:setValue(new_befujt_para, false)  -- Propagate
    else
      befujt_cel_para_var:setValue(new_befujt_para, true)   -- No propagation
    end
  end
end

-- ============================================================================
-- CONTROL LOGIC
-- ============================================================================

function run_control_cycle()
  -- Check sensor error states first
  local kamra_hibaszam_var = V('kamra_hibaszam')
  local befujt_hibaszam_var = V('befujt_hibaszam')
  
  local kamra_hibaflag = kamra_hibaszam_var and (kamra_hibaszam_var:getValue() or 0) <= 0
  local befujt_hibaflag = befujt_hibaszam_var and (befujt_hibaszam_var:getValue() or 0) <= 0
  
  -- Calculate supply targets (skip psychrometric calculations in error state)
  if not kamra_hibaflag then
    calculate_supply_targets()
  end
  
  -- Get all needed variables
  local kamra_hom_var = V('kamra_homerseklet')
  local kamra_para_var = V('kamra_para')
  local kamra_cel_hom_var = V('kamra_cel_homerseklet')
  local kamra_cel_para_var = V('kamra_cel_para')
  local befujt_hom_var = V('befujt_homerseklet_akt')
  local befujt_para_var = V('befujt_para_akt')
  local befujt_cel_hom_var = V('befujt_cel_homerseklet')
  local befujt_cel_para_var = V('befujt_cel_para')
  local kulso_hom_var = V('kulso_homerseklet')
  local kulso_para_var = V('kulso_para')
  local signals_var = V('signals')
  local cycle_var = V('cycle_variable')
  local constansok_var = V('constansok')
  
  if not kamra_hom_var or not kamra_para_var or not signals_var then return end
  
  local kamra_hom = kamra_hom_var:getValue() or 0
  local kamra_para = kamra_para_var:getValue() or 0
  local kamra_cel_hom = kamra_cel_hom_var and kamra_cel_hom_var:getValue() or 0
  local kamra_cel_para = kamra_cel_para_var and kamra_cel_para_var:getValue() or 0
  local befujt_hom = befujt_hom_var and befujt_hom_var:getValue() or 0
  local befujt_para = befujt_para_var and befujt_para_var:getValue() or 0
  local befujt_cel_hom = befujt_cel_hom_var and befujt_cel_hom_var:getValue() or 0
  local befujt_cel_para = befujt_cel_para_var and befujt_cel_para_var:getValue() or 0
  local kulso_hom = kulso_hom_var and kulso_hom_var:getValue() or 0
  local kulso_para = kulso_para_var and kulso_para_var:getValue() or 0
  local old_signals = getTableValue(signals_var)
  local cycle = getTableValue(cycle_var)
  local const = getTableValue(constansok_var)
  
  -- Error state fallback: use target as measured value (safe operation)
  if kamra_hibaflag then
    kamra_hom = kamra_cel_hom
    kamra_para = kamra_cel_para
  end
  if befujt_hibaflag then
    befujt_hom = befujt_cel_hom
    befujt_para = befujt_cel_para
  end
  
  -- Read SBUS inputs
  local humi_save = HW.inp_humidity_save and HW.inp_humidity_save:getValue("state") == "on"
  local sum_wint_jel = HW.inp_sum_wint and HW.inp_sum_wint:getValue("state") == "on"
  local sleep = not cycle.aktiv
  
  -- Chamber control with hysteresis
  local kamra_hutes = hysteresis(
    kamra_hom, kamra_cel_hom,
    const.deltahi_kamra_homerseklet or 10,
    const.deltalo_kamra_homerseklet or 10,
    old_signals.kamra_hutes or false
  )
  
  local kamra_futes = hysteresis(
    kamra_cel_hom, kamra_hom,
    const.deltahi_kamra_homerseklet or 10,
    const.deltalo_kamra_homerseklet or 10,
    old_signals.kamra_futes or false
  )
  
  -- =========================================================================
  -- DEHUMIDIFICATION CONTROL using ABSOLUTE HUMIDITY
  -- =========================================================================
  -- User configures hysteresis in RH% (intuitive), but comparison uses AH
  -- This correctly handles temperature differences between current and target
  --
  -- Example: Target 18°C/70%, Current 20°C/68%
  --   RH comparison: 68% < 70% → no dehumidify (WRONG!)
  --   AH comparison: 11.7 > 10.8 g/m³ → dehumidify needed (CORRECT!)
  -- =========================================================================
  
  -- Calculate absolute humidity values
  local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
  local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
  
  -- Convert RH% hysteresis thresholds to AH at TARGET temperature
  -- This makes the hysteresis consistent regardless of current temperature
  local deltahi_rh = const.deltahi_kamra_para or 15  -- User config: +1.5% RH
  local deltalo_rh = const.deltalo_kamra_para or 10  -- User config: -1.0% RH
  
  local ah_at_hi = calculate_absolute_humidity(kamra_cel_hom / 10, (kamra_cel_para + deltahi_rh) / 10)
  local ah_at_lo = calculate_absolute_humidity(kamra_cel_hom / 10, (kamra_cel_para - deltalo_rh) / 10)
  
  local delta_ah_hi = ah_at_hi - target_ah  -- AH difference for high threshold
  local delta_ah_lo = target_ah - ah_at_lo  -- AH difference for low threshold
  
  local kamra_para_hutes = hysteresis(
    current_ah, target_ah,
    delta_ah_hi,
    delta_ah_lo,
    old_signals.kamra_para_hutes or false
  )
  
  -- Supply air control
  local befujt_hutes = hysteresis(
    befujt_hom, befujt_cel_hom,
    const.deltahi_befujt_homerseklet or 20,
    const.deltalo_befujt_homerseklet or 15,
    old_signals.befujt_hutes or false
  )
  
  local befujt_futes = hysteresis(
    befujt_cel_hom, befujt_hom,
    const.deltahi_befujt_homerseklet or 20,
    const.deltalo_befujt_homerseklet or 15,
    old_signals.befujt_futes or false
  )
  
  -- Determine control signals
  -- =========================================================================
  -- NON-NEGOTIABLE TEMPERATURE LIMIT:
  -- If chamber temp > target + hysteresis → MUST COOL (water or outdoor air)
  -- This is independent of humidity-primary mode selection!
  -- Humidity-primary only affects supply air target calculation aggressiveness,
  -- NOT the hard temperature safety limits.
  -- =========================================================================
  local cool = kamra_hutes or befujt_hutes
  local dehumi = kamra_para_hutes
  local warm = kamra_futes or befujt_futes
  
  -- "Better cold than dry" strategy (when no humidifier installed)
  -- Block heating if humidity is too low to prevent further drying
  local heating_blocked = false
  if not hw_config.has_humidifier and warm then
    local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
    local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
    local min_temp = const.min_temp_no_humidifier or 110  -- 11.0°C default
    
    -- Block heating if current AH < target AH (too dry) AND above minimum temp
    if current_ah < target_ah and kamra_hom > min_temp then
      heating_blocked = true
      warm = false
    end
  end
  
  -- Outdoor air beneficial for cooling
  -- Use outdoor air when chamber is significantly warmer than outdoor
  local outdoor_use_threshold = const.outdoor_use_threshold or 50  -- 5.0°C default
  local outdoor_beneficial = (kamra_hom - kulso_hom) >= outdoor_use_threshold
  
  -- Cooling strategy decision:
  -- - Dehumidification (dehumi): ALWAYS use water cooling (0°C) - outdoor air cannot dehumidify
  -- - Cooling only (cool and not dehumi): use outdoor air when beneficial
  local use_water_cooling = true
  local use_outdoor_air = false
  
  if dehumi then
    -- Dehumidification: always water, never outdoor
    use_water_cooling = true
    use_outdoor_air = false
  elseif cool and outdoor_beneficial then
    -- Cooling only with beneficial outdoor: use outdoor air
    use_water_cooling = false
    use_outdoor_air = true
  end
  
  -- Humidification logic (INDEPENDENT from main control cycle)
  -- Only when humidifier installed in this chamber
  local humidification = false
  if hw_config.has_humidifier then
    -- Compare at target temperature using AH (physically correct)
    local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
    local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
    
    -- Calculate AH threshold for "5% RH below target at target temp"
    local start_delta_rh = const.humidifier_start_delta or 50  -- 5.0% RH default
    local start_rh = (kamra_cel_para - start_delta_rh) / 10    -- Target RH - 5%
    local start_ah = calculate_absolute_humidity(kamra_cel_hom / 10, start_rh)
    
    -- Get current humidifier state
    local signals_var = V('signals')
    local current_humidifier = signals_var and signals_var:getValue() and signals_var:getValue().relay_humidifier or false
    
    -- Hysteresis: ON when below start threshold, OFF when target reached
    if current_humidifier then
      -- Currently ON: keep running until target AH reached
      humidification = current_ah < target_ah
    else
      -- Currently OFF: start only when significantly below target
      humidification = current_ah < start_ah
    end
  end
  
  -- Generate relay signals
  -- Note: sum_wint_jel only affects main fan speed (hardware wiring difference)
  -- Summer = lighter air = higher fan speed, Winter = denser air = lower fan speed
  -- All other control logic is identical year-round
  local new_signals = {
    kamra_hutes = kamra_hutes,
    kamra_futes = kamra_futes,
    kamra_para_hutes = kamra_para_hutes,
    befujt_hutes = befujt_hutes,
    befujt_futes = befujt_futes,
    cool = cool,
    dehumi = dehumi,
    warm = warm,
    sleep = sleep,
    sum_wint_jel = sum_wint_jel,
    humi_save = humi_save,
    outdoor_beneficial = outdoor_beneficial,
    use_water_cooling = use_water_cooling,
    use_outdoor_air = use_outdoor_air,
    humidification = humidification,
    heating_blocked = heating_blocked,
    kamra_hibaflag = kamra_hibaflag,
    befujt_hibaflag = befujt_hibaflag,
    relay_warm = warm and not sleep,
    -- Water cooling needed for cooling OR dehumidification
    relay_cool = (cool or dehumi) and not sleep and use_water_cooling,
    relay_add_air_max = use_outdoor_air and not humi_save,
    relay_reventon = humi_save,
    relay_add_air_save = humi_save,
    -- Bypass: OFF=0°C (dehumidify), ON=8°C (cooling only)
    -- When using outdoor air, bypass state doesn't matter (water not used)
    relay_bypass_open = humi_save or (cool and not dehumi),
    relay_main_fan = sum_wint_jel,  -- Hardware: summer=high speed, winter=low speed
    relay_humidifier = humidification,
    relay_sleep = sleep,
  }
  
  -- Check if any signal changed
  local signals_changed = false
  for key, value in pairs(new_signals) do
    if old_signals[key] ~= value then
      signals_changed = true
      break
    end
  end
  
  -- Save signals and apply relays (only if changed)
  if signals_changed then
    -- Log control actions to statistics
    log_control_action(old_signals, new_signals)
    
    signals_var:setValue(new_signals, false)
    apply_relay_outputs(new_signals)
  end
  
  return signals_changed
end

-- ============================================================================
-- RELAY OUTPUT
-- ============================================================================

function apply_relay_outputs(signals)
  set_relay(signals.relay_warm, HW.rel_warm)
  set_relay(signals.relay_cool, HW.rel_cool)
  set_relay(signals.relay_add_air_max, HW.rel_add_air_max)
  set_relay(signals.relay_reventon, HW.rel_reventon)
  set_relay(signals.relay_add_air_save, HW.rel_add_air_save)
  set_relay(signals.relay_bypass_open, HW.rel_bypass_open)
  set_relay(signals.relay_main_fan, HW.rel_main_fan)
  set_relay(signals.relay_humidifier, HW.rel_humidifier)
  set_relay(signals.relay_sleep, HW.rel_sleep)
end

-- ============================================================================
-- SLEEP CYCLE MANAGEMENT
-- ============================================================================

local function advance_sleep_cycle()
  local cycle_var = V('cycle_variable')
  local signals_var = V('signals')
  
  if not cycle_var or not signals_var then return end
  
  local cycle = getTableValue(cycle_var)
  
  if cycle.vez_aktiv then
    return  -- Manual control active
  end
  
  local szamlalo = cycle.szamlalo or cycle.action_time or 540
  szamlalo = szamlalo - 1
  
  if szamlalo <= 0 then
    if cycle.aktiv then
      cycle.aktiv = false
      cycle.szamlalo = cycle.passiv_time or 60
    else
      cycle.aktiv = true
      cycle.szamlalo = cycle.action_time or 540
    end
  else
    cycle.szamlalo = szamlalo
  end
  
  -- Update sleep signal if changed
  local old_signals = getTableValue(signals_var)
  if old_signals.sleep ~= (not cycle.aktiv) then
    old_signals.sleep = not cycle.aktiv
    signals_var:setValue(old_signals, false)
  end
  
  cycle_var:setValue(cycle, true)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init_hardware_shortcuts()
  -- Use SBUS_CONFIG defined at top of file
  HW.inp_humidity_save = SBUS_CONFIG.inp_humidity_save and sbus[SBUS_CONFIG.inp_humidity_save]
  HW.inp_sum_wint = SBUS_CONFIG.inp_sum_wint and sbus[SBUS_CONFIG.inp_sum_wint]
  HW.inp_weight_1 = SBUS_CONFIG.inp_weight_1 and sbus[SBUS_CONFIG.inp_weight_1]
  HW.inp_weight_2 = SBUS_CONFIG.inp_weight_2 and sbus[SBUS_CONFIG.inp_weight_2]
  HW.rel_warm = SBUS_CONFIG.rel_warm and sbus[SBUS_CONFIG.rel_warm]
  HW.rel_cool = SBUS_CONFIG.rel_cool and sbus[SBUS_CONFIG.rel_cool]
  HW.rel_add_air_max = SBUS_CONFIG.rel_add_air_max and sbus[SBUS_CONFIG.rel_add_air_max]
  HW.rel_reventon = SBUS_CONFIG.rel_reventon and sbus[SBUS_CONFIG.rel_reventon]
  HW.rel_add_air_save = SBUS_CONFIG.rel_add_air_save and sbus[SBUS_CONFIG.rel_add_air_save]
  HW.rel_bypass_open = SBUS_CONFIG.rel_bypass_open and sbus[SBUS_CONFIG.rel_bypass_open]
  HW.rel_main_fan = SBUS_CONFIG.rel_main_fan and sbus[SBUS_CONFIG.rel_main_fan]
  HW.rel_humidifier = SBUS_CONFIG.rel_humidifier and sbus[SBUS_CONFIG.rel_humidifier]
  HW.rel_sleep = SBUS_CONFIG.rel_sleep and sbus[SBUS_CONFIG.rel_sleep]
end

-- ============================================================================
-- CUSTOM DEVICE CALLBACKS
-- ============================================================================

function CustomDevice:onInit()
  print("=== ERLELO CHAMBER " .. CHAMBER_ID .. " v2.4 ===")
  print("Humidity-Primary Control")
  
  -- Check required configuration
  if not MAPPING_VAR_ID then
    print("ERROR: MAPPING_VAR_ID not set!")
    print("1. Run erlelo_store first")
    print("2. Note the printed variable ID")
    print("3. Set MAPPING_VAR_ID at top of this file")
    return
  end
  
  -- Load variable mapping
  local map = loadVarMap()
  if not map then
    print("ERROR: Failed to load variable mapping")
    return
  end
  print("Variable mapping loaded: " .. (VAR_MAP and "OK" or "FAIL"))
  
  -- Initialize hardware shortcuts from SBUS_CONFIG
  init_hardware_shortcuts()
  print("SBUS hardware initialized")
  
  -- Get Modbus clients
  if MODBUS_SUPPLY_CLIENT then
    mb_supply = modbus_client[MODBUS_SUPPLY_CLIENT]
    if mb_supply then
      mb_supply:onRegisterAsyncRead(handle_supply_response)
      mb_supply:onAsyncRequestFailure(handle_supply_error)
      print("Supply Modbus client: " .. MODBUS_SUPPLY_CLIENT)
    else
      print("WARNING: Supply Modbus client " .. MODBUS_SUPPLY_CLIENT .. " not found")
    end
  end
  
  if MODBUS_CHAMBER_CLIENT then
    mb_chamber = modbus_client[MODBUS_CHAMBER_CLIENT]
    if mb_chamber then
      mb_chamber:onRegisterAsyncRead(handle_chamber_response)
      mb_chamber:onAsyncRequestFailure(handle_chamber_error)
      print("Chamber Modbus client: " .. MODBUS_CHAMBER_CLIENT)
    else
      print("WARNING: Chamber Modbus client " .. MODBUS_CHAMBER_CLIENT .. " not found")
    end
  end
  
  -- Get timer and start polling
  poll_timer = self:getComponent("timer")
  
  -- Start with staggered offset based on chamber ID
  local poll_offset = 500 * CHAMBER_ID  -- 500ms, 1000ms, 1500ms for chambers 1,2,3
  if poll_timer then
    poll_timer:start(poll_offset)
    print("Polling starts in " .. poll_offset .. "ms")
  end
  
  print("=== Chamber " .. CHAMBER_ID .. " initialization complete ===")
end

function CustomDevice:onEvent(event)
  -- Timer elapsed - poll sensors
  if event.type == "lua_timer_elapsed" then
    poll_sensors()
    advance_sleep_cycle()
    
    -- Statistics recording and UI refresh (every STATS_INTERVAL polls = ~30 sec)
    stats_counter = stats_counter + 1
    if stats_counter >= STATS_INTERVAL then
      stats_counter = 0
      record_statistics()
      refresh_ui(self)
      print("STATS: Recorded statistics and refreshed UI for chamber " .. CHAMBER_ID)
    end
    
    if poll_timer then
      poll_timer:start(POLL_INTERVAL)
    end
    return
  end
  
  -- Variable changed - check if control cycle needed
  if event.type == "lua_variable_state_changed" then
    local src_id = event.source.id
    local map = loadVarMap()
    if not map then return end
    
    local watch_vars = {
      "kamra_homerseklet",
      "kamra_para",
      "befujt_homerseklet_akt",
      "befujt_para_akt",
      "kamra_cel_homerseklet",
      "kamra_cel_para",
      "kulso_homerseklet",
      "kulso_para",
    }
    
    for _, var_name in ipairs(watch_vars) do
      local full_name = var_name .. "_ch" .. CHAMBER_ID
      local idx = map[full_name]
      if not idx then
        idx = map[var_name]  -- Try without chamber suffix (for shared vars)
      end
      if idx and src_id == idx then
        run_control_cycle()
        return
      end
    end
  end
  
  -- SBUS input changed
  if event.type == "device_state_changed" and event.source.type == "sbus" and hw_config then
    local src_id = event.source.id
    if src_id == hw_config.inp_humidity_save or src_id == hw_config.inp_sum_wint then
      run_control_cycle()
    end
  end
end

-- ============================================================================
-- UI ELEMENT CALLBACKS
-- ============================================================================

function CustomDevice:onTargetTempChange(newValue, element)
  local kamra_cel_hom = V('kamra_cel_homerseklet')
  if kamra_cel_hom then
    local raw_value = round(newValue * 10)
    kamra_cel_hom:setValue(raw_value, false)
  end
end

function CustomDevice:onTargetHumiChange(newValue, element)
  local kamra_cel_para = V('kamra_cel_para')
  if kamra_cel_para then
    local raw_value = round(newValue * 10)
    kamra_cel_para:setValue(raw_value, false)
  end
end

function CustomDevice:onSleepManualToggle(newValue, element)
  local cycle_var = V('cycle_variable')
  local signals_var = V('signals')
  
  if cycle_var then
    local cycle = getTableValue(cycle_var)
    cycle.vez_aktiv = true
    cycle.aktiv = not newValue
    cycle_var:setValue(cycle, true)
  end
  
  if signals_var then
    local signals = getTableValue(signals_var)
    signals.sleep = newValue
    signals_var:setValue(signals, false)
  end
end

function CustomDevice:onSleepAutoEnable(newValue, element)
  local cycle_var = V('cycle_variable')
  if cycle_var then
    local cycle = getTableValue(cycle_var)
    cycle.vez_aktiv = not newValue
    cycle_var:setValue(cycle, true)
  end
end
