--[[
    ERLELO ID MAPPER
    
    Reads all variables from API, creates name->ID mapping,
    stores it in variable_name_map for all erlelo devices to use.
    
    Run this AFTER erlelo_create has created all variables.
    
    ============================================================
    UI SETUP - Add these elements in the device editor:
    ============================================================
    1. Add Button element:
       - Name: btn_start
       - Text: "Build Mapping"
       - Icon: play
       - On Press: onStartPress
    
    2. Add Text element:
       - Name: status_text
       - Value: "Ready"
    
    3. Arrange in widget layout (column, centered)
    ============================================================
]]

local API_BASE = 'http://192.168.0.122/api/v1'
local TOKEN = 'YOUR_API_TOKEN_HERE'

local http = nil
local state = nil

function CustomDevice:onInit()
    print('=== ERLELO ID MAPPER ===')
    print('Press "Build Mapping" button to begin')
    http = self:getComponent('http')
    state = { step = 'idle' }
    
    local status = self:getElement('status_text')
    if status then
        status:setValue('value', 'Ready - Press Start', true)
    end
end

function CustomDevice:onStartPress()
    if not http then
        print('ERROR: HTTP component not available')
        return
    end
    
    if state.step ~= 'idle' then
        print('Already running...')
        return
    end
    
    print('[1] Fetching all variables from API...')
    state.step = 'fetch'
    
    local status = self:getElement('status_text')
    if status then
        status:setValue('value', 'Fetching variables...', true)
    end
    
    http:GET(API_BASE..'/lua/variables'):header('Authorization',TOKEN):timeout(15):send()
end

function CustomDevice:onEvent(event)
    if not http or not state then return end
    
    http:onMessage(function(status_code, payload, url)
        local status = self:getElement('status_text')
        
        if state.step ~= 'fetch' then return end
        
        if status_code ~= 200 then
            print('ERROR: HTTP ' .. tostring(status_code))
            if status then
                status:setValue('value', 'ERROR: ' .. tostring(status_code), true)
            end
            state.step = 'idle'
            return
        end
        
        local resp = JSON:decode(payload)
        local vars = resp.data
        
        print('[1] Found ' .. #vars .. ' variables')
        
        -- Build name -> ID mapping
        local id_map = {}
        local variable_name_map_id = nil
        
        for _, v in ipairs(vars) do
            id_map[v.name] = v.id
            -- Look for the mapping variable (now with _glbl suffix)
            if v.name == 'variable_name_map_glbl' then
                variable_name_map_id = v.id
            end
        end
        
        if not variable_name_map_id then
            print('ERROR: variable_name_map_glbl not found!')
            print('Make sure erlelo_create was run first.')
            if status then
                status:setValue('value', 'ERROR: var not found!', true)
            end
            state.step = 'idle'
            return
        end
        
        -- Store mapping as JSON string
        local map_json = JSON:encode(id_map)
        variable[variable_name_map_id]:setValue(map_json)
        
        print('')
        print('=== MAPPING COMPLETE ===')
        print('Total variables mapped: ' .. #vars)
        print('')
        print('╔════════════════════════════════════════════════════════════╗')
        print('║  IMPORTANT: Copy this ID to your controller files!        ║')
        print('║                                                            ║')
        print('║  MAPPING_VAR_ID = ' .. variable_name_map_id .. string.rep(' ', 39 - #tostring(variable_name_map_id)) .. '║')
        print('║                                                            ║')
        print('║  Set this value in:                                        ║')
        print('║    - erlelo_kulso.lua                                      ║')
        print('║    - erlelo_kamra1.lua                                     ║')
        print('║    - erlelo_kamra2.lua (if using)                          ║')
        print('║    - erlelo_kamra3.lua (if using)                          ║')
        print('╚════════════════════════════════════════════════════════════╝')
        print('')
        print('Then enable the controller devices.')
        
        if status then
            status:setValue('value', 'DONE! ID=' .. variable_name_map_id, true)
        end
        
        state.step = 'idle'
    end)
end

