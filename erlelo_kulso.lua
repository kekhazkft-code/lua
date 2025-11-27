--[[
  ERLELO OUTDOOR SENSOR v2.4
  erlelo_kulso.lua
  
  Reads shared outdoor temperature/humidity sensor via Modbus
  Writes to global variables (*_glbl) that all chamber controllers read
  
  SETUP: Edit the configuration section below, then deploy to Sinum
]]

-- ============================================================================
-- USER CONFIGURATION - EDIT THESE VALUES
-- ============================================================================

-- After running erlelo_store, it will print the mapping variable ID
-- Enter that ID here:
local MAPPING_VAR_ID = nil  -- Set after running erlelo_store (e.g., 42)

-- Modbus client ID for outdoor sensor (from Sinum Modbus Client settings)
local MODBUS_OUTDOOR_CLIENT = nil  -- Outdoor sensor Modbus Client ID

-- Modbus register addresses (check your sensor documentation)
local MODBUS_REG_TEMPERATURE = 1   -- Input register for temperature
local MODBUS_REG_HUMIDITY = 2      -- Input register for humidity (usually temp+1)

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

-- Get variable by name (global variables use _glbl suffix)
local function V(name)
  local map = loadVarMap()
  if not map then
    print("ERROR: Cannot load variable map")
    return nil
  end
  
  -- All kulso variables are global, use _glbl suffix
  local var_name = name .. "_glbl"
  local idx = map[var_name]
  
  if not idx then
    print("WARNING: Variable '" .. var_name .. "' not found in mapping")
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

local mb_client = nil
local poll_timer = nil

-- ============================================================================
-- CONTROL CONSTANTS (previously from config)
-- ============================================================================

local POLL_INTERVAL = 1000         -- Poll every 1000ms (1 second)
local MAX_ERROR_COUNT = 3          -- Max consecutive errors before simulation
local BUFFER_SIZE_OUTDOOR = 10     -- Moving average buffer size
local TEMP_THRESHOLD = 3           -- Temperature change threshold ×10 (0.3°C)
local HUMIDITY_THRESHOLD = 10      -- Humidity change threshold ×10 (1.0%)

-- ============================================================================
-- STATISTICS CONFIGURATION
-- ============================================================================

local STATS_INTERVAL = 30  -- Record stats every 30 poll cycles (~30 seconds)
local stats_counter = 0    -- Counter for statistics timing

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

local function calculate_dew_point(temp_c, rh)
  if rh <= 0 then return -999 end
  local gamma = math.log(rh / 100) + PSYCHRO.B * temp_c / (PSYCHRO.C + temp_c)
  return PSYCHRO.C * gamma / (PSYCHRO.B - gamma)
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function moving_average_update(buffer_var, result_var, new_value, buffer_size, threshold)
  if not buffer_var or not result_var then return false end
  
  local buffer = buffer_var:getValue() or {}
  
  table.insert(buffer, new_value)
  if #buffer > buffer_size then
    table.remove(buffer, 1)
  end
  
  buffer_var:setValue(buffer, true)  -- No propagation
  
  if #buffer < buffer_size then
    return false
  end
  
  local sum = 0
  for _, v in ipairs(buffer) do sum = sum + v end
  local avg = math.floor(sum / #buffer)
  
  local old_avg = result_var:getValue() or 0
  if math.abs(avg - old_avg) >= threshold then
    result_var:setValue(avg, false)  -- PROPAGATE
    return true
  else
    result_var:setValue(avg, true)   -- No propagation
    return false
  end
end

-- ============================================================================
-- MODBUS HANDLING
-- ============================================================================

local function handle_modbus_response(kind, addr, values)
  if kind ~= "INPUT_REGISTERS" then return end
  
  local mb_config = config.modbus.outdoor
  
  -- Reset error counter on successful read
  local hibaszam_var = V('kulso_hibaszam')
  if hibaszam_var then
    hibaszam_var:setValue(MAX_ERROR_COUNT, true)
  end
  
  -- Single read returns both temp and humidity
  if addr == MODBUS_REG_TEMPERATURE and values[1] and values[2] then
    process_sensor_data(values[1], values[2])
  end
end

local function handle_modbus_error(request, err, kind, addr)
  if err == "TIMEOUT" or err == "BAD_CRC" then
    local error_var = V('kulso_hibaszam')
    if error_var then
      local count = error_var:getValue() or MAX_ERROR_COUNT
      if count > 0 then
        error_var:setValue(count - 1, true)
      end
      print(string.format("Outdoor sensor error: %s (remaining: %d)", err, count - 1))
    end
  end
end

local function poll_sensor()
  -- Always poll Modbus - averaging must continue even in simulation mode
  -- so real values are immediately ready when simulation is turned off
  if mb_client then
    -- Read both registers in single call (temp=reg1, humi=reg2)
    mb_client:readInputRegistersAsync(MODBUS_REG_TEMPERATURE, 2)
  end
end

-- ============================================================================
-- DATA PROCESSING
-- ============================================================================

local function update_psychrometric()
  local temp_var = V('kulso_homerseklet')
  local humi_var = V('kulso_para')
  
  if not temp_var or not humi_var then return end
  
  local temp = temp_var:getValue() or 0
  local humi = humi_var:getValue() or 0
  
  if temp == 0 or humi == 0 then return end
  
  local temp_c = temp / 10
  local rh = humi / 10
  
  local ah = calculate_absolute_humidity(temp_c, rh)
  local dp = calculate_dew_point(temp_c, rh)
  
  local ah_dp_var = V('kulso_ah_dp')
  if not ah_dp_var then return end
  
  local old_data = getTableValue(ah_dp_var)
  
  local ah_changed = math.abs((old_data.ah or 0) - ah) >= 0.01
  local dp_changed = math.abs((old_data.dp or 0) - dp) >= 0.1
  
  if ah_changed or dp_changed then
    ah_dp_var:setValue({
      ah = math.floor(ah * 100) / 100,
      dp = math.floor(dp * 10) / 10,
    }, true)
  end
end

-- ============================================================================
-- STATISTICS RECORDING
-- ============================================================================

local function record_statistics()
  local temp_var = V('kulso_homerseklet')
  local humi_var = V('kulso_para')
  local ah_dp_var = V('kulso_ah_dp')
  
  -- Outdoor temperature
  if temp_var then
    local temp = temp_var:getValue()
    if temp then
      statistics:addPoint("outdoor_temp", temp, unit.celsius_x10)
    end
  end
  
  -- Outdoor humidity
  if humi_var then
    local humi = humi_var:getValue()
    if humi then
      statistics:addPoint("outdoor_humidity", humi, unit.relative_humidity_x10)
    end
  end
  
  -- Outdoor dew point
  if ah_dp_var then
    local data = ah_dp_var:getValue()
    if data and data.dp then
      statistics:addPoint("outdoor_dewpoint", math.floor(data.dp * 10), unit.celsius_x10)
    end
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
  
  local temp_var = V('kulso_homerseklet')
  local humi_var = V('kulso_para')
  local ah_dp_var = V('kulso_ah_dp')
  
  -- Outdoor temperature
  if temp_var then
    local temp = temp_var:getValue() or 0
    updateElement('text1_kulso_homerseklet', string.format("%.1f°C", temp / 10))
  end
  
  -- Outdoor humidity
  if humi_var then
    local humi = humi_var:getValue() or 0
    updateElement('text0_kulso_para', string.format("%.1f%%", humi / 10))
  end
  
  -- Outdoor dew point and absolute humidity
  if ah_dp_var then
    local data = getTableValue(ah_dp_var)
    if data.dp then
      updateElement('text2_outside_temp', string.format("HP: %.1f°C", data.dp))
    end
    if data.ah then
      updateElement('ah_kulso_tx', string.format("AH: %.3fg/m³", data.ah))
    end
  end
end

local function process_sensor_data(raw_temp, raw_humi)
  local temp_changed = moving_average_update(
    V('kulso_homerseklet_table'),
    V('kulso_homerseklet'),
    raw_temp,
    BUFFER_SIZE_OUTDOOR,
    TEMP_THRESHOLD
  )
  
  local humi_changed = moving_average_update(
    V('kulso_para_table'),
    V('kulso_para'),
    raw_humi,
    BUFFER_SIZE_OUTDOOR,
    HUMIDITY_THRESHOLD
  )
  
  if temp_changed or humi_changed then
    update_psychrometric()
  end
end

-- ============================================================================
-- CUSTOM DEVICE CALLBACKS
-- ============================================================================

function CustomDevice:onInit()
  print("=== ERLELO OUTDOOR SENSOR v2.4 ===")
  
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
  print("Variable mapping loaded: OK")
  
  -- Get Modbus client using configured ID
  if MODBUS_OUTDOOR_CLIENT then
    mb_client = modbus_client[MODBUS_OUTDOOR_CLIENT]
    if mb_client then
      mb_client:onRegisterAsyncRead(handle_modbus_response)
      mb_client:onAsyncRequestFailure(handle_modbus_error)
      print("Outdoor Modbus client: " .. MODBUS_OUTDOOR_CLIENT)
    else
      print("WARNING: Modbus client " .. MODBUS_OUTDOOR_CLIENT .. " not found!")
    end
  else
    print("WARNING: MODBUS_OUTDOOR_CLIENT not configured!")
  end
  
  -- Get timer component
  poll_timer = self:getComponent("timer")
  
  -- Start polling immediately (outdoor data needed first by chambers)
  if poll_timer then
    poll_timer:start(100)  -- Quick first poll at T+100ms
    print("Polling started: first poll in 100ms, then every " .. POLL_INTERVAL .. "ms")
  end
  
  print("=== Outdoor sensor initialization complete ===")
end

function CustomDevice:onEvent(event)
  if event.type == "lua_timer_elapsed" then
    poll_sensor()
    
    -- Statistics recording and UI refresh (every STATS_INTERVAL polls = ~30 sec)
    stats_counter = stats_counter + 1
    if stats_counter >= STATS_INTERVAL then
      stats_counter = 0
      record_statistics()
      refresh_ui(self)
      print("STATS: Recorded outdoor statistics and refreshed UI")
    end
    
    if poll_timer then
      poll_timer:start(POLL_INTERVAL)
    end
  end
  
  if event.type == "lua_variable_state_changed" then
    local szimulalt_var = V('kulso_szimulalt')
    if szimulalt_var then
      local src_id = event.source.id
      local map = loadVarMap()
      if map and src_id == map['kulso_szimulalt'] then
        local sim_enabled = szimulalt_var:getValue()
        print("Outdoor simulation mode: " .. tostring(sim_enabled))
      end
    end
  end
end

-- ============================================================================
-- UI CALLBACKS FOR SIMULATION
-- ============================================================================

function CustomDevice:onSimTempChange(newValue, element)
  local szimulalt_var = V('kulso_szimulalt')
  local para_var = V('kulso_para')
  
  if szimulalt_var and szimulalt_var:getValue() then
    local raw_temp = math.floor(newValue * 10)
    process_sensor_data(raw_temp, para_var and para_var:getValue() or 0)
  end
end

function CustomDevice:onSimHumiChange(newValue, element)
  local szimulalt_var = V('kulso_szimulalt')
  local temp_var = V('kulso_homerseklet')
  
  if szimulalt_var and szimulalt_var:getValue() then
    local raw_humi = math.floor(newValue * 10)
    process_sensor_data(temp_var and temp_var:getValue() or 0, raw_humi)
  end
end

function CustomDevice:onSimEnableChange(newValue, element)
  local szimulalt_var = V('kulso_szimulalt')
  if szimulalt_var then
    szimulalt_var:setValue(newValue, false)
  end
end
