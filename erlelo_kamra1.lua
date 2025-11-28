--[[
  ERLELO CHAMBER CONTROLLER v2.5
  erlelo_kamra.lua
  
  Humidity-Primary Control System with Dual-Layer Cascade
  
  ALL CONTROL PARAMETERS READ FROM constansok VARIABLE
  Use erlelo_constants_editor.lua to modify at runtime
  
  v2.5 CHANGES:
  - Dual-layer cascade: Chamber (outer, wider) + Supply (inner, tighter)
  - Directional hysteresis prevents mode oscillation at boundaries
  - State machine for humidity mode (HUMID/FINE/DRY)
  - All parameters configurable via constansok variable
  - Buffer size reduced to 5 for faster response
  - SAFE INITIALIZATION: 32s startup period with all relays OFF
  
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
-- HUMIDITY MODE CONSTANTS
-- ============================================================================

local MODE_FINE = 0   -- AH within deadzone, fine control
local MODE_HUMID = 1  -- AH too high, dehumidification needed
local MODE_DRY = 2    -- AH too low, humidification needed

-- ============================================================================
-- INITIALIZATION TRACKING
-- ============================================================================

local init_start_time = nil   -- Timestamp when script started
local init_complete = false   -- Flag: initialization period finished

-- ============================================================================
-- TIMING CONSTANTS (not user-configurable)
-- ============================================================================

local POLL_INTERVAL = 1000      -- Poll sensors every 1000ms (1 second)
local STATS_INTERVAL = 30       -- Record stats every 30 poll cycles (~30 seconds)

-- ============================================================================
-- CACHED CONSTANTS (loaded from constansok variable)
-- ============================================================================

local cached_const = nil  -- Loaded from constansok variable

-- Default values (used if constansok not yet loaded)
local DEFAULT_CONST = {
  -- Chamber temperature (outer loop)
  deltahi_kamra_homerseklet = 15,      -- +1.5°C
  deltalo_kamra_homerseklet = 10,      -- -1.0°C
  temp_hysteresis_kamra = 5,           -- 0.5°C
  
  -- Chamber humidity (outer loop)
  ah_deadzone_kamra = 80,              -- 0.8 g/m³
  ah_hysteresis_kamra = 30,            -- 0.3 g/m³
  
  -- Supply temperature (inner loop)
  deltahi_befujt_homerseklet = 10,     -- 1.0°C
  deltalo_befujt_homerseklet = 10,     -- 1.0°C
  temp_hysteresis_befujt = 3,          -- 0.3°C
  
  -- Supply humidity (inner loop)
  ah_deadzone_befujt = 50,             -- 0.5 g/m³
  ah_hysteresis_befujt = 20,           -- 0.2 g/m³
  
  -- Global control
  outdoor_mix_ratio = 30,              -- 30%
  outdoor_use_threshold = 50,          -- 5.0°C
  proportional_gain = 10,              -- 1.0
  min_supply_air_temp = 60,            -- 6.0°C
  max_supply_air_temp = 400,           -- 40.0°C
  min_temp_no_humidifier = 110,        -- 11.0°C
  
  -- Sensor processing
  buffer_size = 5,                     -- samples
  spike_threshold = 50,                -- ±5.0
  max_error_count = 10,                -- errors before failsafe
  temp_change_threshold = 2,           -- 0.2°C for propagation
  humidity_change_threshold = 5,       -- 0.5% for propagation
  
  -- Humidifier
  humidifier_installed = false,
  humidifier_start_delta = 50,         -- 5.0% RH
  
  -- Sleep cycle
  sleep_cycle_enabled = false,
  sleep_on_minutes = 45,
  sleep_off_minutes = 15,
  
  -- Initialization
  init_duration = 32,                   -- 32 seconds initialization period
}

-- Get constant value (from cached_const or default)
local function C(key)
  if cached_const and cached_const[key] ~= nil then
    return cached_const[key]
  end
  return DEFAULT_CONST[key]
end

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

-- Get variable by name
local function V(name)
  local map = loadVarMap()
  if not map then return nil end
  
  -- Try chamber-specific suffix first
  local var_name = name .. "_ch" .. CHAMBER_ID
  local idx = map[var_name]
  
  -- If not found, try global suffix
  if not idx then
    var_name = name .. "_glbl"
    idx = map[var_name]
  end
  
  if not idx then
    return nil
  end
  
  return variable[idx]
end

-- Get table value from a variable
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

-- Load constants from constansok variable
local function loadConstants()
  local constansok_var = V('constansok')
  if constansok_var then
    cached_const = getTableValue(constansok_var)
    if cached_const and next(cached_const) then
      return true
    end
  end
  cached_const = nil
  return false
end

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local HW = {}             -- Hardware (SBUS) shortcuts
local mb_supply = nil     -- Modbus client for supply air
local mb_chamber = nil    -- Modbus client for chamber
local poll_timer = nil

-- State machine variables
local humidity_mode_state = MODE_FINE
local temp_cooling_active = false
local temp_heating_active = false
local supply_cooling_active = false
local supply_heating_active = false

-- Statistics
local stats_counter = 0

-- Moving average buffers (in-memory)
local supply_temp_buffer = {}
local supply_humi_buffer = {}
local chamber_temp_buffer = {}
local chamber_humi_buffer = {}
local buffer_indices = {
  supply_temp = 1,
  supply_humi = 1,
  chamber_temp = 1,
  chamber_humi = 1
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

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

local function calculate_saturation_pressure(temp_c)
  if temp_c >= 0 then
    return 6.112 * math.exp((17.67 * temp_c) / (temp_c + 243.5))
  else
    return 6.112 * math.exp((22.46 * temp_c) / (temp_c + 272.62))
  end
end

local function calculate_absolute_humidity(temp_c, rh_percent)
  local e_s = calculate_saturation_pressure(temp_c)
  local e = (rh_percent / 100) * e_s
  local ah = (216.7 * e) / (temp_c + 273.15)
  return ah
end

local function calculate_dew_point(temp_c, rh_percent)
  local e_s = calculate_saturation_pressure(temp_c)
  local e = (rh_percent / 100) * e_s
  local dp = (243.5 * math.log(e / 6.112)) / (17.67 - math.log(e / 6.112))
  return dp
end

local function calculate_rh_from_ah(temp_c, ah)
  local e_s = calculate_saturation_pressure(temp_c)
  local e = (ah * (temp_c + 273.15)) / 216.7
  local rh = (e / e_s) * 100
  if rh > 100 then rh = 100 end
  if rh < 0 then rh = 0 end
  return rh
end

-- ============================================================================
-- MOVING AVERAGE WITH SPIKE FILTER
-- ============================================================================

local function moving_average_update(buffer, index_key, new_value, result_var)
  local buffer_size = C('buffer_size')
  local spike_threshold = C('spike_threshold')
  
  -- Initialize buffer if needed
  if #buffer < buffer_size then
    table.insert(buffer, new_value)
    buffer_indices[index_key] = #buffer
  else
    -- Trim buffer if buffer_size was reduced
    while #buffer > buffer_size do
      table.remove(buffer, 1)
    end
    
    -- Calculate current average for spike detection
    local sum = 0
    for _, v in ipairs(buffer) do
      sum = sum + v
    end
    local current_avg = sum / #buffer
    
    -- Spike filter: reject if too far from average
    if math.abs(new_value - current_avg) > spike_threshold then
      return current_avg
    end
    
    -- Update circular buffer
    local idx = buffer_indices[index_key]
    if idx > #buffer then idx = 1 end
    buffer[idx] = new_value
    buffer_indices[index_key] = (idx % buffer_size) + 1
  end
  
  -- Calculate new average
  local sum = 0
  for _, v in ipairs(buffer) do
    sum = sum + v
  end
  local avg = sum / #buffer
  
  -- Update result variable if provided
  if result_var then
    result_var:setValue(round(avg), true)
  end
  
  return avg
end

-- ============================================================================
-- HYSTERESIS FUNCTIONS
-- ============================================================================

-- Humidity Mode State Machine
local function update_humidity_mode(current_ah, target_ah, deadzone, hysteresis, current_mode)
  local upper_threshold = target_ah + deadzone
  local lower_threshold = target_ah - deadzone
  local exit_humid = target_ah - hysteresis
  local exit_dry = target_ah + hysteresis
  
  if current_mode == MODE_HUMID then
    if current_ah < exit_humid then
      return MODE_FINE
    else
      return MODE_HUMID
    end
    
  elseif current_mode == MODE_DRY then
    if current_ah > exit_dry then
      return MODE_FINE
    else
      return MODE_DRY
    end
    
  else  -- MODE_FINE
    if current_ah > upper_threshold then
      return MODE_HUMID
    elseif current_ah < lower_threshold then
      return MODE_DRY
    else
      return MODE_FINE
    end
  end
end

-- ============================================================================
-- MODBUS CONFIGURATION
-- ============================================================================

local config = {
  modbus = {
    chamber_1 = { slave_id = 1, reg_temperature = 0 },
    chamber_2 = { slave_id = 2, reg_temperature = 0 },
    chamber_3 = { slave_id = 3, reg_temperature = 0 },
  }
}

-- ============================================================================
-- SENSOR DATA PROCESSING
-- ============================================================================

local function process_supply_data(temp_raw, humi_raw)
  local temp_raw_var = V('befujt_homerseklet_raw')
  local humi_raw_var = V('befujt_para_raw')
  if temp_raw_var then temp_raw_var:setValue(temp_raw, true) end
  if humi_raw_var then humi_raw_var:setValue(humi_raw, true) end
  
  local temp_avg_var = V('befujt_homerseklet_akt')
  local humi_avg_var = V('befujt_para_akt')
  
  moving_average_update(supply_temp_buffer, 'supply_temp', temp_raw, temp_avg_var)
  moving_average_update(supply_humi_buffer, 'supply_humi', humi_raw, humi_avg_var)
  
  local befujt_hibaszam = V('befujt_hibaszam')
  if befujt_hibaszam then
    befujt_hibaszam:setValue(C('max_error_count'), true)
  end
end

local function process_chamber_data(temp_raw, humi_raw)
  local temp_raw_var = V('kamra_homerseklet_raw')
  local humi_raw_var = V('kamra_para_raw')
  if temp_raw_var then temp_raw_var:setValue(temp_raw, true) end
  if humi_raw_var then humi_raw_var:setValue(humi_raw, true) end
  
  local temp_avg_var = V('kamra_homerseklet')
  local humi_avg_var = V('kamra_para')
  
  moving_average_update(chamber_temp_buffer, 'chamber_temp', temp_raw, temp_avg_var)
  moving_average_update(chamber_humi_buffer, 'chamber_humi', humi_raw, humi_avg_var)
  
  local kamra_hibaszam = V('kamra_hibaszam')
  if kamra_hibaszam then
    kamra_hibaszam:setValue(C('max_error_count'), true)
  end
end

-- ============================================================================
-- PSYCHROMETRIC UPDATES
-- ============================================================================

local function update_chamber_psychrometric()
  local temp_var = V('kamra_homerseklet')
  local humi_var = V('kamra_para')
  local dp_var = V('dp_kamra')
  local ah_var = V('ah_kamra')
  
  if not temp_var or not humi_var then return end
  
  local temp = temp_var:getValue() or 0
  local humi = humi_var:getValue() or 0
  
  if temp == 0 or humi == 0 then return end
  
  local temp_c = temp / 10
  local rh = humi / 10
  
  local ah = calculate_absolute_humidity(temp_c, rh)
  local dp = calculate_dew_point(temp_c, rh)
  
  if ah_var then ah_var:setValue(round(ah * 1000), true) end
  if dp_var then dp_var:setValue(round(dp * 10), true) end
end

local function update_supply_psychrometric()
  local temp_var = V('befujt_homerseklet_akt')
  local humi_var = V('befujt_para_akt')
  local ah_var = V('ah_befujt')
  local dp_var = V('dp_befujt')
  
  if not temp_var or not humi_var then return end
  
  local temp = temp_var:getValue() or 0
  local humi = humi_var:getValue() or 0
  
  if temp == 0 or humi == 0 then return end
  
  local temp_c = temp / 10
  local rh = humi / 10
  
  local ah = calculate_absolute_humidity(temp_c, rh)
  local dp = calculate_dew_point(temp_c, rh)
  
  if ah_var then ah_var:setValue(round(ah * 1000), true) end
  if dp_var then dp_var:setValue(round(dp * 10), true) end
end

local function update_target_psychrometric()
  local temp_var = V('kamra_cel_homerseklet')
  local humi_var = V('kamra_cel_para')
  local dp_var = V('dp_cel')
  local ah_var = V('ah_cel')
  
  if not temp_var or not humi_var then return end
  
  local temp = temp_var:getValue() or 0
  local humi = humi_var:getValue() or 0
  
  if temp == 0 or humi == 0 then return end
  
  local temp_c = temp / 10
  local rh = humi / 10
  
  local ah = calculate_absolute_humidity(temp_c, rh)
  local dp = calculate_dew_point(temp_c, rh)
  
  if ah_var then ah_var:setValue(round(ah * 1000), true) end
  if dp_var then dp_var:setValue(round(dp * 10), true) end
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

local previous_signals = {}

local function record_sensor_stats()
  local prefix = "chamber_" .. CHAMBER_ID .. "_"
  
  local kamra_hom_var = V('kamra_homerseklet')
  if kamra_hom_var then
    local temp = kamra_hom_var:getValue() or 0
    statistics:addPoint(prefix .. "temp", temp / 10, unit.temp_c)
  end
  
  local kamra_para_var = V('kamra_para')
  if kamra_para_var then
    local humi = kamra_para_var:getValue() or 0
    statistics:addPoint(prefix .. "humidity", humi / 10, unit.percent)
  end
  
  local ah_kamra_var = V('ah_kamra')
  if ah_kamra_var then
    local ah = ah_kamra_var:getValue() or 0
    statistics:addPoint(prefix .. "ah", ah / 1000, unit.g_per_m3 or unit.percent)
  end
end

local function record_signal_changes(old_signals, new_signals)
  local prefix = "chamber_" .. CHAMBER_ID .. "_"
  
  if old_signals.kamra_futes ~= new_signals.kamra_futes then
    statistics:addPoint(prefix .. "heating", new_signals.kamra_futes and 1 or 0, unit.bool_unit)
  end
  
  if old_signals.kamra_hutes ~= new_signals.kamra_hutes then
    statistics:addPoint(prefix .. "cooling", new_signals.kamra_hutes and 1 or 0, unit.bool_unit)
  end
  
  if old_signals.kamra_para_hutes ~= new_signals.kamra_para_hutes then
    statistics:addPoint(prefix .. "dehumidify", new_signals.kamra_para_hutes and 1 or 0, unit.bool_unit)
  end
  
  if old_signals.relay_humidifier ~= new_signals.relay_humidifier then
    statistics:addPoint(prefix .. "humidifier", new_signals.relay_humidifier and 1 or 0, unit.bool_unit)
  end
  
  if old_signals.humidity_mode ~= new_signals.humidity_mode then
    local mode_names = {[0] = "FINE", [1] = "HUMID", [2] = "DRY"}
    print("MODE: " .. (mode_names[old_signals.humidity_mode] or "?") .. " -> " .. (mode_names[new_signals.humidity_mode] or "?"))
  end
end

-- ============================================================================
-- MODBUS HANDLERS
-- ============================================================================

local function handle_supply_response(request, values, kind, addr)
  local befujt_hibaszam = V('befujt_hibaszam')
  if befujt_hibaszam then
    befujt_hibaszam:setValue(C('max_error_count'), true)
  end
  
  local mb_cfg = config.modbus["chamber_" .. CHAMBER_ID]
  if addr == mb_cfg.reg_temperature and values[1] and values[2] then
    process_supply_data(values[1], values[2])
  end
end

local function handle_chamber_response(request, values, kind, addr)
  local kamra_hibaszam = V('kamra_hibaszam')
  if kamra_hibaszam then
    kamra_hibaszam:setValue(C('max_error_count'), true)
  end
  
  local mb_cfg = config.modbus["chamber_" .. CHAMBER_ID]
  if addr == mb_cfg.reg_temperature and values[1] and values[2] then
    process_chamber_data(values[1], values[2])
  end
end

local function handle_supply_error(request, err, kind, addr)
  if err == "TIMEOUT" or err == "BAD_CRC" then
    local befujt_hibaszam = V('befujt_hibaszam')
    if befujt_hibaszam then
      local count = befujt_hibaszam:getValue() or C('max_error_count')
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
      local count = kamra_hibaszam:getValue() or C('max_error_count')
      if count > 0 then
        kamra_hibaszam:setValue(count - 1, true)
      end
    end
  end
end

local function poll_sensors()
  local mb_cfg = config.modbus["chamber_" .. CHAMBER_ID]
  
  if mb_supply then
    mb_supply:readInputRegistersAsync(mb_cfg.reg_temperature, 2)
  end
  
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
  
  if not kamra_cel_temp or not kamra_cel_humi or not kamra_hom_var or not kamra_para_var then
    return
  end
  
  local kamra_cel_hom = kamra_cel_temp:getValue() or 0
  local kamra_cel_para = kamra_cel_humi:getValue() or 0
  local kamra_hom = kamra_hom_var:getValue() or 0
  local kamra_para = kamra_para_var:getValue() or 0
  local kulso_hom = kulso_temp and kulso_temp:getValue() or 0
  
  if kamra_cel_hom == 0 or kamra_cel_para == 0 then return end
  
  -- Calculate absolute humidity values
  local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
  local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
  
  -- Get chamber AH deadzone and hysteresis from constants
  local ah_deadzone = C('ah_deadzone_kamra') / 100
  local ah_hysteresis = C('ah_hysteresis_kamra') / 100
  
  -- Update humidity mode state machine
  humidity_mode_state = update_humidity_mode(current_ah, target_ah, ah_deadzone, ah_hysteresis, humidity_mode_state)
  
  -- Calculate supply air target temperature based on mode
  local befujt_target_temp
  local inside_ah_deadzone = (humidity_mode_state == MODE_FINE)
  
  if inside_ah_deadzone then
    -- FINE MODE: Fine control with outdoor mixing
    local mix_ratio = C('outdoor_mix_ratio') / 100
    local chamber_error = kamra_hom - kamra_cel_hom
    local outdoor_offset = kulso_hom - kamra_cel_hom
    
    befujt_target_temp = kamra_cel_hom - chamber_error * (1 - mix_ratio) - outdoor_offset * mix_ratio
  else
    -- HUMID or DRY MODE: Aggressive proportional control
    local P = C('proportional_gain') / 10
    local chamber_error = kamra_hom - kamra_cel_hom
    
    befujt_target_temp = kamra_cel_hom - chamber_error * P
  end
  
  -- Apply temperature constraints
  local min_temp = C('min_supply_air_temp')
  local max_temp = C('max_supply_air_temp')
  
  if befujt_target_temp < min_temp then befujt_target_temp = min_temp end
  if befujt_target_temp > max_temp then befujt_target_temp = max_temp end
  
  -- Calculate target humidity from target AH at supply temperature
  local befujt_target_rh = calculate_rh_from_ah(befujt_target_temp / 10, target_ah)
  local befujt_target_para = round(befujt_target_rh * 10)
  
  if befujt_target_para < 0 then befujt_target_para = 0 end
  if befujt_target_para > 1000 then befujt_target_para = 1000 end
  
  -- Store targets
  local befujt_cel_temp_var = V('befujt_cel_homerseklet')
  local befujt_cel_para_var = V('befujt_cel_para')
  
  local new_befujt_temp = round(befujt_target_temp)
  local new_befujt_para = befujt_target_para
  
  if befujt_cel_temp_var then
    local old_temp = befujt_cel_temp_var:getValue() or 0
    local threshold = C('temp_change_threshold')
    if math.abs(new_befujt_temp - old_temp) >= threshold then
      befujt_cel_temp_var:setValue(new_befujt_temp, false)
    else
      befujt_cel_temp_var:setValue(new_befujt_temp, true)
    end
  end
  
  if befujt_cel_para_var then
    local old_para = befujt_cel_para_var:getValue() or 0
    local threshold = C('humidity_change_threshold')
    if math.abs(new_befujt_para - old_para) >= threshold then
      befujt_cel_para_var:setValue(new_befujt_para, false)
    else
      befujt_cel_para_var:setValue(new_befujt_para, true)
    end
  end
end

-- ============================================================================
-- CONTROL LOGIC
-- ============================================================================

function run_control_cycle()
  -- Reload constants (in case they changed)
  loadConstants()
  
  -- Check sensor error states
  local kamra_hibaszam_var = V('kamra_hibaszam')
  local befujt_hibaszam_var = V('befujt_hibaszam')
  
  local kamra_hibaflag = kamra_hibaszam_var and (kamra_hibaszam_var:getValue() or 0) <= 0
  local befujt_hibaflag = befujt_hibaszam_var and (befujt_hibaszam_var:getValue() or 0) <= 0
  
  -- Calculate supply targets
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
  local signals_var = V('signals')
  local cycle_var = V('cycle_variable')
  
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
  local old_signals = getTableValue(signals_var)
  local cycle = getTableValue(cycle_var)
  
  -- Error state fallback
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
  
  -- CHAMBER TEMPERATURE CONTROL (Outer Loop)
  local deltahi_temp = C('deltahi_kamra_homerseklet')
  local deltalo_temp = C('deltalo_kamra_homerseklet')
  local temp_hyst = C('temp_hysteresis_kamra')
  
  -- Cooling with directional hysteresis
  local cooling_entry = kamra_hom > kamra_cel_hom + deltahi_temp
  local cooling_exit = kamra_hom < kamra_cel_hom + temp_hyst
  
  if cooling_entry then
    temp_cooling_active = true
  elseif cooling_exit then
    temp_cooling_active = false
  end
  
  local kamra_hutes = temp_cooling_active
  
  -- Heating with directional hysteresis
  local heating_entry = kamra_hom < kamra_cel_hom - deltalo_temp
  local heating_exit = kamra_hom > kamra_cel_hom - temp_hyst
  
  if heating_entry then
    temp_heating_active = true
  elseif heating_exit then
    temp_heating_active = false
  end
  
  local kamra_futes = temp_heating_active
  
  -- HUMIDITY MODE (from state machine)
  local kamra_para_hutes = (humidity_mode_state == MODE_HUMID)
  local humidity_too_low = (humidity_mode_state == MODE_DRY)
  
  -- SUPPLY AIR CONTROL (Inner Loop)
  local deltahi_supply = C('deltahi_befujt_homerseklet')
  local deltalo_supply = C('deltalo_befujt_homerseklet')
  local temp_hyst_supply = C('temp_hysteresis_befujt')
  
  -- Supply cooling
  local supply_cool_entry = befujt_hom > befujt_cel_hom + deltahi_supply
  local supply_cool_exit = befujt_hom < befujt_cel_hom + temp_hyst_supply
  
  if supply_cool_entry then
    supply_cooling_active = true
  elseif supply_cool_exit then
    supply_cooling_active = false
  end
  
  local befujt_hutes = supply_cooling_active
  
  -- Supply heating
  local supply_heat_entry = befujt_hom < befujt_cel_hom - deltalo_supply
  local supply_heat_exit = befujt_hom > befujt_cel_hom - temp_hyst_supply
  
  if supply_heat_entry then
    supply_heating_active = true
  elseif supply_heat_exit then
    supply_heating_active = false
  end
  
  local befujt_futes = supply_heating_active
  
  -- COMBINE SIGNALS
  local cool = kamra_hutes or befujt_hutes
  local dehumi = kamra_para_hutes
  local warm = kamra_futes or befujt_futes
  
  -- "Better cold than dry" (when no humidifier)
  local heating_blocked = false
  if not C('humidifier_installed') and warm and humidity_too_low then
    local min_temp = C('min_temp_no_humidifier')
    if kamra_hom > min_temp then
      heating_blocked = true
      warm = false
    end
  end
  
  -- Outdoor air benefit check
  local outdoor_use_threshold = C('outdoor_use_threshold')
  local outdoor_beneficial = (kamra_hom - kulso_hom) >= outdoor_use_threshold
  
  -- Cooling strategy
  local use_water_cooling = true
  local use_outdoor_air = false
  
  if dehumi then
    use_water_cooling = true
    use_outdoor_air = false
  elseif cool and outdoor_beneficial then
    use_water_cooling = false
    use_outdoor_air = true
  end
  
  -- Humidification (only if installed)
  local humidification = false
  if C('humidifier_installed') and humidity_too_low then
    local current_ah = calculate_absolute_humidity(kamra_hom / 10, kamra_para / 10)
    local target_ah = calculate_absolute_humidity(kamra_cel_hom / 10, kamra_cel_para / 10)
    local exit_threshold = target_ah + C('ah_hysteresis_kamra') / 100
    
    local current_humidifier = old_signals.relay_humidifier or false
    if current_humidifier then
      humidification = current_ah < exit_threshold
    else
      humidification = true
    end
  end
  
  -- BUILD SIGNALS
  local new_signals = {
    kamra_hutes = kamra_hutes,
    kamra_futes = kamra_futes,
    kamra_para_hutes = kamra_para_hutes,
    befujt_hutes = befujt_hutes,
    befujt_futes = befujt_futes,
    relay_cool = (cool or dehumi) and not sleep and use_water_cooling,
    relay_warm = warm and not sleep,
    relay_add_air_max = use_outdoor_air and not humi_save,
    relay_reventon = humi_save,
    relay_add_air_save = humi_save,
    relay_bypass_open = humi_save or (cool and not dehumi),
    relay_main_fan = sum_wint_jel,
    relay_humidifier = humidification and not sleep,
    sleep = sleep,
    heating_blocked = heating_blocked,
    humidity_mode = humidity_mode_state,
    init_complete = init_complete,
  }
  
  -- Calculate initialization countdown
  local init_countdown = 0
  if not init_complete and init_start_time then
    local elapsed = os.time() - init_start_time
    local init_duration = C('init_duration') or 32
    init_countdown = math.max(0, init_duration - elapsed)
  end
  new_signals.init_countdown = init_countdown
  
  -- Record stats
  record_signal_changes(old_signals, new_signals)
  
  -- Store signals
  signals_var:setValue(JSON:encode(new_signals), true)
  
  -- Apply to SBUS
  -- During initialization OR sleep: all relays OFF
  if not init_complete or sleep then
    if HW.rel_cool then HW.rel_cool:setValue("state", "off") end
    if HW.rel_warm then HW.rel_warm:setValue("state", "off") end
    if HW.rel_add_air_max then HW.rel_add_air_max:setValue("state", "off") end
    if HW.rel_reventon then HW.rel_reventon:setValue("state", "off") end
    if HW.rel_add_air_save then HW.rel_add_air_save:setValue("state", "off") end
    if HW.rel_bypass_open then HW.rel_bypass_open:setValue("state", "off") end
    if HW.rel_main_fan then HW.rel_main_fan:setValue("state", "off") end
    if HW.rel_humidifier then HW.rel_humidifier:setValue("state", "off") end
  else
    -- Normal operation: apply control signals
    if HW.rel_cool then HW.rel_cool:setValue("state", new_signals.relay_cool and "on" or "off") end
    if HW.rel_warm then HW.rel_warm:setValue("state", new_signals.relay_warm and "on" or "off") end
    if HW.rel_add_air_max then HW.rel_add_air_max:setValue("state", new_signals.relay_add_air_max and "on" or "off") end
    if HW.rel_reventon then HW.rel_reventon:setValue("state", new_signals.relay_reventon and "on" or "off") end
    if HW.rel_add_air_save then HW.rel_add_air_save:setValue("state", new_signals.relay_add_air_save and "on" or "off") end
    if HW.rel_bypass_open then HW.rel_bypass_open:setValue("state", new_signals.relay_bypass_open and "on" or "off") end
    if HW.rel_main_fan then HW.rel_main_fan:setValue("state", new_signals.relay_main_fan and "on" or "off") end
    if HW.rel_humidifier then HW.rel_humidifier:setValue("state", new_signals.relay_humidifier and "on" or "off") end
  end
end

-- ============================================================================
-- UI REFRESH
-- ============================================================================

local function refresh_ui(device)
  local function updateElement(name, value)
    local elem = device:getElement(name)
    if elem then
      elem:setValue('value', value, true)
    end
  end
  
  local kamra_hom = V('kamra_homerseklet')
  local kamra_para = V('kamra_para')
  local ah_kamra = V('ah_kamra')
  local signals_var = V('signals')
  
  if kamra_hom then
    local temp = kamra_hom:getValue() or 0
    updateElement('_3_tx_kamra_homerseklet_', string.format("%.1f°C", temp / 10))
  end
  
  if kamra_para then
    local humi = kamra_para:getValue() or 0
    updateElement('_4_tx_kamra_para_', string.format("%.1f%%", humi / 10))
  end
  
  if ah_kamra then
    local ah = ah_kamra:getValue() or 0
    updateElement('ah_kamra_tx', string.format("AH: %.2f g/m³", ah / 1000))
  end
  
  if signals_var then
    local signals = getTableValue(signals_var)
    
    updateElement('text_input_0_warm', signals.kamra_futes and "Fűtés Aktív!" or " ")
    updateElement('text_input_1_cool', signals.kamra_hutes and "Hűtés Aktív!" or " ")
    updateElement('text_input_2_wdis', signals.kamra_para_hutes and "Párátlanítás!" or " ")
    updateElement('text_input_3_cdis', signals.relay_humidifier and "Párásítás!" or " ")
    
    local mode_names = {[0] = "FINOM", [1] = "PÁRÁS", [2] = "SZÁRAZ"}
    updateElement('humidity_mode_tx', "Mód: " .. (mode_names[signals.humidity_mode] or "?"))
  end
end

-- ============================================================================
-- MAIN POLL HANDLER
-- ============================================================================

local function on_poll_timer()
  -- Track initialization time
  if init_start_time == nil then
    init_start_time = os.time()
    print("INIT: Starting " .. C('init_duration') .. "s initialization period")
  end
  
  -- Check if initialization is complete
  if not init_complete then
    local elapsed = os.time() - init_start_time
    local init_duration = C('init_duration') or 32
    if elapsed >= init_duration then
      init_complete = true
      print("INIT: Initialization complete, enabling relay control")
    end
  end
  
  poll_sensors()
  
  update_chamber_psychrometric()
  update_supply_psychrometric()
  update_target_psychrometric()
  
  run_control_cycle()
  
  stats_counter = stats_counter + 1
  if stats_counter >= STATS_INTERVAL then
    record_sensor_stats()
    stats_counter = 0
  end
  
  if poll_timer then
    poll_timer:start(POLL_INTERVAL)
  end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CustomDevice:onInit()
  print("=== ERLELO CHAMBER CONTROLLER v2.5 ===")
  print("Chamber ID: " .. CHAMBER_ID)
  print("All parameters from constansok variable")
  
  -- Load constants
  if loadConstants() then
    print("  Loaded " .. (cached_const and "custom" or "default") .. " constants")
    print("  Buffer size: " .. C('buffer_size'))
    print("  AH deadzone (chamber): " .. C('ah_deadzone_kamra')/100 .. " g/m³")
    print("  Init duration: " .. C('init_duration') .. " seconds")
  else
    print("  Using default constants (constansok not found)")
  end
  
  print("*** SAFE INIT: All relays OFF for " .. C('init_duration') .. "s ***")
  
  -- Initialize SBUS
  for name, id in pairs(SBUS_CONFIG) do
    if id then
      HW[name] = sbus[id]
      if HW[name] then
        print("  SBUS " .. name .. " -> ID " .. id)
      end
    end
  end
  
  -- Initialize Modbus
  if MODBUS_SUPPLY_CLIENT then
    mb_supply = modbus[MODBUS_SUPPLY_CLIENT]
    if mb_supply then
      mb_supply:onResponse(handle_supply_response)
      mb_supply:onError(handle_supply_error)
      print("  Modbus supply: ID " .. MODBUS_SUPPLY_CLIENT)
    end
  end
  
  if MODBUS_CHAMBER_CLIENT then
    mb_chamber = modbus[MODBUS_CHAMBER_CLIENT]
    if mb_chamber then
      mb_chamber:onResponse(handle_chamber_response)
      mb_chamber:onError(handle_chamber_error)
      print("  Modbus chamber: ID " .. MODBUS_CHAMBER_CLIENT)
    end
  end
  
  -- Start timer
  poll_timer = CustomDevice.getComponent(CustomDevice, "timer")
  
  local poll_offset = 500 * CHAMBER_ID
  if poll_timer then
    poll_timer:start(poll_offset)
    print("  Timer started (offset " .. poll_offset .. "ms)")
  end
  
  print("=== INITIALIZATION COMPLETE ===")
end

function CustomDevice:onTimer()
  on_poll_timer()
end

function CustomDevice:onRefresh()
  refresh_ui(self)
end
