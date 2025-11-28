--[[
    ERLELO CONSTANTS EDITOR v2.5
    
    UI for viewing and updating control system constants.
    Updates both current value AND default value via API.
    
    v2.5 PARAMETERS:
    - Dual-layer cascade: Chamber (outer) + Supply (inner)
    - Directional hysteresis for mode stability
    - Buffer size = 5 for faster response
    - Safe initialization period (32s default)
    
    ============================================================
    COMPONENT SETUP:
    ============================================================
    1. Add HTTP Client component:
       - Name: http
    
    ============================================================
    UI ELEMENTS TO ADD:
    ============================================================
    
    -- CHAMBER SELECTION --
    inp_chamber_id        (Number Input) - Chamber ID (1, 2, or 3)
    
    -- CHAMBER TEMPERATURE (Outer Loop) --
    inp_deltahi_temp      (Number Input) - Upper threshold ×10 (default 15 = 1.5°C)
    txt_deltahi_temp      (Text) - Current value
    inp_deltalo_temp      (Number Input) - Lower threshold ×10 (default 10 = 1.0°C)
    txt_deltalo_temp      (Text) - Current value
    inp_temp_hyst_kamra   (Number Input) - Hysteresis ×10 (default 5 = 0.5°C)
    txt_temp_hyst_kamra   (Text) - Current value
    
    -- CHAMBER HUMIDITY (Outer Loop) --
    inp_ah_dz_kamra       (Number Input) - AH deadzone ×100 (default 80 = 0.8 g/m³)
    txt_ah_dz_kamra       (Text) - Current value
    inp_ah_hyst_kamra     (Number Input) - AH hysteresis ×100 (default 30 = 0.3 g/m³)
    txt_ah_hyst_kamra     (Text) - Current value
    
    -- SUPPLY TEMPERATURE (Inner Loop) --
    inp_deltahi_supply    (Number Input) - Upper threshold ×10 (default 10 = 1.0°C)
    txt_deltahi_supply    (Text) - Current value
    inp_deltalo_supply    (Number Input) - Lower threshold ×10 (default 10 = 1.0°C)
    txt_deltalo_supply    (Text) - Current value
    inp_temp_hyst_supply  (Number Input) - Hysteresis ×10 (default 3 = 0.3°C)
    txt_temp_hyst_supply  (Text) - Current value
    
    -- SUPPLY HUMIDITY (Inner Loop) --
    inp_ah_dz_supply      (Number Input) - AH deadzone ×100 (default 50 = 0.5 g/m³)
    txt_ah_dz_supply      (Text) - Current value
    inp_ah_hyst_supply    (Number Input) - AH hysteresis ×100 (default 20 = 0.2 g/m³)
    txt_ah_hyst_supply    (Text) - Current value
    
    -- GLOBAL PARAMETERS --
    inp_outdoor_mix       (Number Input) - Outdoor mix ratio % (default 30)
    txt_outdoor_mix       (Text) - Current value
    inp_outdoor_thresh    (Number Input) - Outdoor use threshold ×10 (default 50 = 5.0°C)
    txt_outdoor_thresh    (Text) - Current value
    inp_prop_gain         (Number Input) - Proportional gain ×10 (default 10 = 1.0)
    txt_prop_gain         (Text) - Current value
    inp_buffer_size       (Number Input) - Buffer size (default 5)
    txt_buffer_size       (Text) - Current value
    inp_spike_thresh      (Number Input) - Spike threshold ×10 (default 50 = 5.0)
    txt_spike_thresh      (Text) - Current value
    
    -- TEMPERATURE LIMITS --
    inp_min_supply        (Number Input) - Min supply temp ×10 (default 60 = 6.0°C)
    txt_min_supply        (Text) - Current value
    inp_max_supply        (Number Input) - Max supply temp ×10 (default 400 = 40.0°C)
    txt_max_supply        (Text) - Current value
    inp_min_no_humi       (Number Input) - Min temp without humidifier ×10 (default 110 = 11.0°C)
    txt_min_no_humi       (Text) - Current value
    
    -- SENSOR PROCESSING --
    inp_max_error         (Number Input) - Max error count (default 10)
    txt_max_error         (Text) - Current value
    inp_temp_thresh       (Number Input) - Temp change threshold ×10 (default 2 = 0.2°C)
    txt_temp_thresh       (Text) - Current value
    inp_humi_thresh       (Number Input) - Humidity change threshold ×10 (default 5 = 0.5%)
    txt_humi_thresh       (Text) - Current value
    
    -- INITIALIZATION --
    inp_init_duration     (Number Input) - Initialization period (default 32 seconds)
    txt_init_duration     (Text) - Current value
    
    -- BUTTONS --
    btn_refresh           (Button) - On Press: onRefreshPress
    btn_save              (Button) - On Press: onSavePress
    
    -- STATUS --
    status_text           (Text) - Status display
    
    ============================================================
]]

-- Sinum API configuration
local API_BASE = 'http://192.168.0.122/api/v1'
local TOKEN = 'YOUR_API_TOKEN_HERE'  -- Replace with your API token

-- Module-level state
local http = nil
local state = { 
    step = 'idle', 
    var_map = {},
    pending_saves = 0,
    chamber_id = 1
}

-- v2.5 Parameter definitions
-- Format: {const_key, input_element, display_element, description, divisor}
local CHAMBER_PARAMS = {
    -- Chamber temperature (outer loop)
    {key = 'deltahi_kamra_homerseklet', inp = 'inp_deltahi_temp', txt = 'txt_deltahi_temp', desc = 'Chamber Temp Hi', div = 10},
    {key = 'deltalo_kamra_homerseklet', inp = 'inp_deltalo_temp', txt = 'txt_deltalo_temp', desc = 'Chamber Temp Lo', div = 10},
    {key = 'temp_hysteresis_kamra', inp = 'inp_temp_hyst_kamra', txt = 'txt_temp_hyst_kamra', desc = 'Chamber Temp Hyst', div = 10},
    
    -- Chamber humidity (outer loop)
    {key = 'ah_deadzone_kamra', inp = 'inp_ah_dz_kamra', txt = 'txt_ah_dz_kamra', desc = 'Chamber AH DZ', div = 100},
    {key = 'ah_hysteresis_kamra', inp = 'inp_ah_hyst_kamra', txt = 'txt_ah_hyst_kamra', desc = 'Chamber AH Hyst', div = 100},
    
    -- Supply temperature (inner loop)
    {key = 'deltahi_befujt_homerseklet', inp = 'inp_deltahi_supply', txt = 'txt_deltahi_supply', desc = 'Supply Temp Hi', div = 10},
    {key = 'deltalo_befujt_homerseklet', inp = 'inp_deltalo_supply', txt = 'txt_deltalo_supply', desc = 'Supply Temp Lo', div = 10},
    {key = 'temp_hysteresis_befujt', inp = 'inp_temp_hyst_supply', txt = 'txt_temp_hyst_supply', desc = 'Supply Temp Hyst', div = 10},
    
    -- Supply humidity (inner loop)
    {key = 'ah_deadzone_befujt', inp = 'inp_ah_dz_supply', txt = 'txt_ah_dz_supply', desc = 'Supply AH DZ', div = 100},
    {key = 'ah_hysteresis_befujt', inp = 'inp_ah_hyst_supply', txt = 'txt_ah_hyst_supply', desc = 'Supply AH Hyst', div = 100},
    
    -- Global parameters (stored per chamber but typically same)
    {key = 'outdoor_mix_ratio', inp = 'inp_outdoor_mix', txt = 'txt_outdoor_mix', desc = 'Outdoor Mix %', div = 1},
    {key = 'outdoor_use_threshold', inp = 'inp_outdoor_thresh', txt = 'txt_outdoor_thresh', desc = 'Outdoor Thresh', div = 10},
    {key = 'proportional_gain', inp = 'inp_prop_gain', txt = 'txt_prop_gain', desc = 'P Gain', div = 10},
    {key = 'buffer_size', inp = 'inp_buffer_size', txt = 'txt_buffer_size', desc = 'Buffer Size', div = 1},
    {key = 'spike_threshold', inp = 'inp_spike_thresh', txt = 'txt_spike_thresh', desc = 'Spike Thresh', div = 10},
    {key = 'min_supply_air_temp', inp = 'inp_min_supply', txt = 'txt_min_supply', desc = 'Min Supply', div = 10},
    {key = 'max_supply_air_temp', inp = 'inp_max_supply', txt = 'txt_max_supply', desc = 'Max Supply', div = 10},
    {key = 'min_temp_no_humidifier', inp = 'inp_min_no_humi', txt = 'txt_min_no_humi', desc = 'Min No Humi', div = 10},
    
    -- Sensor processing
    {key = 'max_error_count', inp = 'inp_max_error', txt = 'txt_max_error', desc = 'Max Errors', div = 1},
    {key = 'temp_change_threshold', inp = 'inp_temp_thresh', txt = 'txt_temp_thresh', desc = 'Temp Thresh', div = 10},
    {key = 'humidity_change_threshold', inp = 'inp_humi_thresh', txt = 'txt_humi_thresh', desc = 'Humi Thresh', div = 10},
    
    -- Initialization
    {key = 'init_duration', inp = 'inp_init_duration', txt = 'txt_init_duration', desc = 'Init Duration (s)', div = 1},
}

-- Get current chamber ID from UI
local function getSelectedChamber()
    local chamberEl = CustomDevice.getElement(CustomDevice, 'inp_chamber_id')
    if chamberEl then
        local val = chamberEl:getValue('value')
        val = tonumber(val)
        if val and val >= 1 and val <= 3 then
            return math.floor(val)
        end
    end
    return 1
end

function CustomDevice:onInit()
    print('=== ERLELO CONSTANTS EDITOR v2.5 ===')
    print('Dual-Layer Cascade Parameters')
    print('Select chamber and press Refresh')
    
    http = CustomDevice.getComponent(CustomDevice, 'http')
    
    if not http then
        print('WARNING: HTTP component not found')
    end
    
    local chamberEl = CustomDevice.getElement(CustomDevice, 'inp_chamber_id')
    if chamberEl then
        chamberEl:setValue('value', 1, true)
    end
    
    local statusEl = CustomDevice.getElement(CustomDevice, 'status_text')
    if statusEl then
        statusEl:setValue('value', 'Select chamber, press Refresh', true)
    end
end

function CustomDevice:onRefreshPress()
    if not http then
        http = CustomDevice.getComponent(CustomDevice, 'http')
    end
    
    if not http then
        print('ERROR: HTTP component not available')
        return
    end
    
    if state.step ~= 'idle' then
        print('Busy...')
        return
    end
    
    state.chamber_id = getSelectedChamber()
    
    print('[1] Fetching values for Chamber ' .. state.chamber_id .. '...')
    state.step = 'fetch'
    state.var_map = {}
    
    local statusEl = CustomDevice.getElement(CustomDevice, 'status_text')
    if statusEl then
        statusEl:setValue('value', 'Loading CH' .. state.chamber_id .. '...', true)
    end
    
    http:GET(API_BASE .. '/lua/variables')
        :header('Authorization', TOKEN)
        :timeout(15)
        :send()
end

function CustomDevice:onSavePress()
    if not http then
        http = CustomDevice.getComponent(CustomDevice, 'http')
    end
    
    if not http then
        print('ERROR: HTTP component not available')
        return
    end
    
    if state.step ~= 'idle' then
        print('Busy...')
        return
    end
    
    state.chamber_id = getSelectedChamber()
    
    print('[SAVE] Building new constansok for Chamber ' .. state.chamber_id .. '...')
    state.step = 'saving'
    state.pending_saves = 0
    
    local statusEl = CustomDevice.getElement(CustomDevice, 'status_text')
    if statusEl then
        statusEl:setValue('value', 'Saving CH' .. state.chamber_id .. '...', true)
    end
    
    -- Build new constansok JSON from all input fields
    local new_const = {}
    for _, param in ipairs(CHAMBER_PARAMS) do
        local inputEl = CustomDevice.getElement(CustomDevice, param.inp)
        if inputEl then
            local val = inputEl:getValue('value')
            val = tonumber(val)
            if val then
                new_const[param.key] = math.floor(val + 0.5)
            end
        end
    end
    
    -- Add non-editable defaults
    new_const.humidifier_installed = false
    new_const.sleep_cycle_enabled = false
    new_const.sleep_on_minutes = 45
    new_const.sleep_off_minutes = 15
    new_const.humidifier_start_delta = 50
    new_const.min_temp_no_humidifier = 110
    
    -- Find constansok variable and update it
    local const_var_name = 'constansok_ch' .. state.chamber_id
    local const_info = state.var_map[const_var_name]
    
    if not const_info then
        print('ERROR: constansok variable not found for chamber ' .. state.chamber_id)
        state.step = 'idle'
        return
    end
    
    local const_json = JSON:encode(new_const)
    print('[SAVE] New constansok: ' .. const_json)
    
    -- Update via API
    local body = JSON:encode({
        value = const_json,
        default_value = const_json
    })
    
    http:PUT(API_BASE .. '/lua/variables/' .. const_info.id)
        :header('Content-Type', 'application/json')
        :header('Authorization', TOKEN)
        :body(body)
        :send()
    
    state.pending_saves = 1
    
    -- Refresh to verify
    print('[SAVE] Update sent, refreshing...')
    state.step = 'fetch'
    http:GET(API_BASE .. '/lua/variables')
        :header('Authorization', TOKEN)
        :timeout(15)
        :send()
end

function CustomDevice:onEvent(event)
    if not http then return end
    if not state then return end
    
    http:onMessage(function(status_code, payload, url)
        local statusEl = CustomDevice.getElement(CustomDevice, 'status_text')
        
        if state.step == 'fetch' then
            if status_code ~= 200 then
                print('ERROR: HTTP ' .. tostring(status_code))
                if statusEl then
                    statusEl:setValue('value', 'ERROR: HTTP ' .. status_code, true)
                end
                state.step = 'idle'
                return
            end
            
            local ok, resp = pcall(function() return JSON:decode(payload) end)
            if not ok or not resp or not resp.data then
                print('ERROR: Failed to parse response')
                if statusEl then
                    statusEl:setValue('value', 'ERROR: Bad response', true)
                end
                state.step = 'idle'
                return
            end
            
            -- Build variable map
            state.var_map = {}
            for _, v in ipairs(resp.data) do
                state.var_map[v.name] = {
                    id = v.id,
                    value = v.value,
                    default_value = v.default_value
                }
            end
            
            print('[1] Loaded ' .. #resp.data .. ' variables')
            
            -- Find constansok for this chamber
            local const_var_name = 'constansok_ch' .. state.chamber_id
            local const_info = state.var_map[const_var_name]
            
            if not const_info then
                print('ERROR: ' .. const_var_name .. ' not found')
                if statusEl then
                    statusEl:setValue('value', 'ERROR: constansok not found', true)
                end
                state.step = 'idle'
                return
            end
            
            -- Parse constansok JSON
            local const_ok, const_data = pcall(function() return JSON:decode(const_info.value) end)
            if not const_ok or not const_data then
                print('ERROR: Failed to parse constansok')
                if statusEl then
                    statusEl:setValue('value', 'ERROR: Bad constansok', true)
                end
                state.step = 'idle'
                return
            end
            
            -- Update display fields
            local updated = 0
            for _, param in ipairs(CHAMBER_PARAMS) do
                local raw_value = const_data[param.key]
                if raw_value then
                    local display_value = raw_value / param.div
                    
                    -- Update display text
                    local txtEl = CustomDevice.getElement(CustomDevice, param.txt)
                    if txtEl then
                        local display_str = string.format('%.2f', display_value)
                        txtEl:setValue('value', param.desc .. ': ' .. display_str .. ' (raw: ' .. raw_value .. ')', true)
                    end
                    
                    -- Pre-fill input
                    local inpEl = CustomDevice.getElement(CustomDevice, param.inp)
                    if inpEl then
                        inpEl:setValue('value', raw_value, true)
                    end
                    
                    updated = updated + 1
                end
            end
            
            print('[2] Updated ' .. updated .. ' display fields for Chamber ' .. state.chamber_id)
            
            if statusEl then
                statusEl:setValue('value', 'CH' .. state.chamber_id .. ': ' .. updated .. ' params', true)
            end
            
            state.step = 'idle'
        end
    end)
end
