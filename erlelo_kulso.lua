--[[
  ERLELO OUTDOOR SENSOR v2.5
  erlelo_kulso.lua
  
  Reads shared outdoor temperature/humidity sensor via Modbus
  Writes to global variables (*_glbl) that all chamber controllers read
  
  v2.5 CHANGES:
  - Buffer size reduced to 5 for faster response
  - Spike filter added
  - Updated getComponent pattern
  
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
-- v2.5 CONTROL CONSTANTS
-- ============================================================================

local POLL_INTERVAL = 1000         -- Poll every 1000ms (1 second)
local MAX_ERROR_COUNT = 3          -- Max consecutive errors before simulation
local BUFFER_SIZE = 5              -- v2.5: Reduced from 10 for faster response
local SPIKE_THRESHOLD = 50         -- v2.5: ±5.0 spike filter
local TEMP_THRESHOLD = 3           -- Temperature change threshold ×10 (0.3°C)
local HUMIDITY_THRESHOLD = 10      -- Humidity change threshold ×10 (1.0%)

-- Moving average buffers (in-memory for v2.5)
local temp_buffer = {}
local humi_buffer = {}
local buffer_indices = {
  temp = 1,
  humi = 1
}

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

local function round(value)
  if value >= 0 then
    return math.floor(value + 0.5)
  else
    return math.ceil(value - 0.5)
  end
end

-- v2.5: Moving average with spike filter (in-memory buffers)
local function moving_average_update(buffer, index_key, new_value, result_var, threshold)
  if not result_var then return 0 end
  
  -- Initialize buffer if needed
  if #buffer < BUFFER_SIZE then
    table.insert(buffer, new_value)
    buffer_indices[index_key] = #buffer
  else
    -- Calculate current average for spike detection
    local sum = 0
    for _, v in ipairs(buffer) do
      sum = sum + v
    end
    local current_avg = sum / #buffer
    
    -- Spike filter: reject if too far from average
    if math.abs(new_value - current_avg) > SPIKE_THRESHOLD then
      -- Spike detected, ignore this reading
      return current_avg
    end
    
    -- Update circular buffer
    local idx = buffer_indices[index_key]
    buffer[idx] = new_value
    buffer_indices[index_key] = (idx % BUFFER_SIZE) + 1
  end
  
  -- Calculate new average
  local sum = 0
  for _, v in ipairs(buffer) do
    sum = sum + v
  end
  local avg = sum / #buffer
  local avg_rounded = round(avg)
  
  -- Update result variable with threshold check
  local old_avg = result_var:getValue() or 0
  if math.abs(avg_rounded - old_avg) >= threshold then
    result_var:setValue(avg_rounded, false)  -- PROPAGATE
  else
    result_var:setValue(avg_rounded, true)   -- No propagation
  end
  
  return avg
end

-- ============================================================================
-- SENSOR DATA PROCESSING
-- ============================================================================

local function process_sensor_data(temp_raw, humi_raw)
  -- Store raw values
  local temp_raw_var = V('kulso_homerseklet_raw')
  local humi_raw_var = V('kulso_para_raw')
  if temp_raw_var then temp_raw_var:setValue(temp_raw, true) end
  if humi_raw_var then humi_raw_var:setValue(humi_raw, true) end
  
  -- Apply moving average with spike filter
  local temp_var = V('kulso_homerseklet')
  local humi_var = V('kulso_para')
  
  moving_average_update(temp_buffer, 'temp', temp_raw, temp_var, TEMP_THRESHOLD)
  moving_average_update(humi_buffer, 'humi', humi_raw, humi_var, HUMIDITY_THRESHOLD)
  
  -- Update psychrometric calculations
  update_psychrometrics()
end

local function update_psychrometrics()
  local temp_var = V('kulso_homerseklet')
  local humi_var = V('kulso_para')
  local ah_dp_var = V('kulso_ah_dp')
  
  if not temp_var or not humi_var or not ah_dp_var then return end
  
  local temp = temp_var:getValue() or 0
  local humi = humi_var:getValue() or 0
  
  if temp == 0 or humi == 0 then return end
  
  local temp_c = temp / 10
  local rh = humi / 10
  
  local ah = calculate_absolute_humidity(temp_c, rh)
  local dp = calculate_dew_point(temp_c, rh)
  
  local data = {
    ah = math.floor(ah * 100) / 100,  -- Round to 2 decimals
    dp = math.floor(dp * 10) / 10     -- Round to 1 decimal
  }
  
  ah_dp_var:setValue(JSON:encode(data), true)
end

-- ============================================================================
-- MODBUS HANDLING
-- ============================================================================

local function handle_modbus_response(request, values, kind, addr)
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
    local hibaszam_var = V('kulso_hibaszam')
    if hibaszam_var then
      local count = hibaszam_var:getValue() or MAX_ERROR_COUNT
      if count > 0 then
        hibaszam_var:setValue(count - 1, true)
      end
    end
    print("Outdoor sensor error: " .. tostring(err))
  end
end

local function poll_sensor()
  if mb_client then
    -- Read both temperature and humidity in single request
    mb_client:readInputRegistersAsync(MODBUS_REG_TEMPERATURE, 2)
  end
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

local function record_stats()
  local temp_var = V('kulso_homerseklet')
  local humi_var = V('kulso_para')
  local ah_dp_var = V('kulso_ah_dp')
  
  if temp_var then
    local temp = temp_var:getValue() or 0
    statistics:addPoint("outdoor_temp", temp / 10, unit.temp_c)
  end
  
  if humi_var then
    local humi = humi_var:getValue() or 0
    statistics:addPoint("outdoor_humidity", humi / 10, unit.percent)
  end
  
  if ah_dp_var then
    local data = getTableValue(ah_dp_var)
    if data.ah then
      statistics:addPoint("outdoor_ah", data.ah, unit.g_per_m3 or unit.percent)
    end
    if data.dp then
      statistics:addPoint("outdoor_dp", data.dp, unit.temp_c)
    end
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
  
  local temp_var = V('kulso_homerseklet')
  local humi_var = V('kulso_para')
  local ah_dp_var = V('kulso_ah_dp')
  
  if temp_var then
    local temp = temp_var:getValue() or 0
    updateElement('kulso_homerseklet_tx', string.format("%.1f°C", temp / 10))
  end
  
  if humi_var then
    local humi = humi_var:getValue() or 0
    updateElement('kulso_para_tx', string.format("%.1f%%", humi / 10))
  end
  
  if ah_dp_var then
    local data = getTableValue(ah_dp_var)
    if data.ah then
      updateElement('kulso_ah_tx', string.format("AH: %.2f g/m³", data.ah))
    end
    if data.dp then
      updateElement('kulso_dp_tx', string.format("HP: %.1f°C", data.dp))
    end
  end
end

-- ============================================================================
-- MAIN POLL HANDLER
-- ============================================================================

local function on_poll_timer()
  -- Poll sensor
  poll_sensor()
  
  -- Statistics
  stats_counter = stats_counter + 1
  if stats_counter >= STATS_INTERVAL then
    record_stats()
    stats_counter = 0
  end
  
  -- Restart timer
  if poll_timer then
    poll_timer:start(POLL_INTERVAL)
  end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CustomDevice:onInit()
  print("=== ERLELO OUTDOOR SENSOR v2.5 ===")
  print("Buffer size: " .. BUFFER_SIZE .. " (with spike filter)")
  
  -- Initialize Modbus client
  if MODBUS_OUTDOOR_CLIENT then
    mb_client = modbus[MODBUS_OUTDOOR_CLIENT]
    if mb_client then
      mb_client:onResponse(handle_modbus_response)
      mb_client:onError(handle_modbus_error)
      print("  Modbus client: ID " .. MODBUS_OUTDOOR_CLIENT)
    else
      print("  WARNING: Modbus client " .. MODBUS_OUTDOOR_CLIENT .. " not found")
    end
  else
    print("  WARNING: MODBUS_OUTDOOR_CLIENT not configured")
  end
  
  -- Get timer and start polling
  poll_timer = CustomDevice.getComponent(CustomDevice, "timer")
  
  if poll_timer then
    poll_timer:start(100)  -- Start quickly
    print("  Poll timer started")
  else
    print("  WARNING: Timer component not found")
  end
  
  print("=== INITIALIZATION COMPLETE ===")
end

function CustomDevice:onTimer()
  on_poll_timer()
end

function CustomDevice:onRefresh()
  refresh_ui(self)
end
