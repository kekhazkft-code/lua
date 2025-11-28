--[[
    ERLELO VARIABLE DELETE v2.5
    
    Reads variable_name_map_glbl from local Sinum variable (created by erlelo_store),
    then deletes ONLY the variables listed in that map.
    
    Uses local data - no GitHub dependency. Deletes exactly what was created.
    
    HOW IT WORKS:
    1. Fetches all system variables from API
    2. Finds the variable_name_map_glbl variable (created by erlelo_store)
    3. Parses the name→ID mapping from it
    4. Deletes each variable by its API ID
    
    ============================================================
    UI SETUP - Add these elements in the device editor:
    ============================================================
    1. Add HTTP Client component:
       - Name: http (must be exactly "http")
    
    2. Add Button element:
       - Name: btn_start
       - Text: "Delete Erlelo"
       - Icon: power
       - On Press: onStartPress
    
    3. Add Text element:
       - Name: status_text
       - Value: "Ready"
    ============================================================
    
    PREREQUISITE: erlelo_store must have been run first to create the mapping!
]]

-- Sinum API configuration
local API_BASE = 'http://192.168.0.122/api/v1'
local TOKEN = 'YOUR_API_TOKEN_HERE'  -- Replace with your API token

-- Module-level state (like working code pattern)
local http = nil
local state = { step = 'idle', name_to_id = nil, delete_count = 0 }

function CustomDevice:onInit()
    print('=== ERLELO SELECTIVE DELETE v2.5 ===')
    print('Uses variable_name_map created by erlelo_store')
    print('Press "Delete Erlelo" button to begin')
    
    http = CustomDevice.getComponent(CustomDevice, 'http')
    
    if not http then
        print('WARNING: HTTP component not found at init')
        print('Add HTTP Client component named "http" in device editor')
    end
    
    local statusEl = CustomDevice.getElement(CustomDevice, 'status_text')
    if statusEl then
        statusEl:setValue('value', 'Ready - Press Delete', true)
    end
end

function CustomDevice:onStartPress()
    -- Try to get http again in case it wasn't ready at init
    if not http then
        http = CustomDevice.getComponent(CustomDevice, 'http')
    end
    
    if not http then
        print('ERROR: HTTP component not available')
        local statusEl = CustomDevice.getElement(CustomDevice, 'status_text')
        if statusEl then
            statusEl:setValue('value', 'ERROR: No HTTP component', true)
        end
        return
    end
    
    if state.step ~= 'idle' then
        print('Already running...')
        return
    end
    
    print('[1] Fetching variables to find variable_name_map...')
    state.step = 'fetch_vars'
    state.delete_count = 0
    
    local statusEl = CustomDevice.getElement(CustomDevice, 'status_text')
    if statusEl then
        statusEl:setValue('value', 'Finding name map...', true)
    end
    
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
        
        if status_code ~= 200 then
            print('ERROR: HTTP ' .. tostring(status_code))
            if statusEl then
                statusEl:setValue('value', 'ERROR: HTTP ' .. tostring(status_code), true)
            end
            state.step = 'idle'
            return
        end
        
        if state.step == 'fetch_vars' then
            local ok, resp = pcall(function() return JSON:decode(payload) end)
            if not ok or not resp or not resp.data then
                print('ERROR: Failed to parse API response')
                if statusEl then statusEl:setValue('value', 'ERROR: Bad response', true) end
                state.step = 'idle'
                return
            end
            
            -- Find the variable_name_map_glbl variable and parse its value
            local map_found = false
            for _, v in ipairs(resp.data) do
                if v.name == 'variable_name_map_glbl' then
                    if v.value and v.value ~= '' and v.value ~= '{}' then
                        local parse_ok, parsed = pcall(function() return JSON:decode(v.value) end)
                        if parse_ok and parsed and next(parsed) then
                            state.name_to_id = parsed
                            map_found = true
                        end
                    end
                    break
                end
            end
            
            if not map_found or not state.name_to_id then
                print('ERROR: variable_name_map_glbl not found or empty!')
                print('Make sure erlelo_store was run after erlelo_create.')
                if statusEl then
                    statusEl:setValue('value', 'ERROR: No name map!', true)
                end
                state.step = 'idle'
                return
            end
            
            -- Count variables to delete
            local count = 0
            for name, id in pairs(state.name_to_id) do
                count = count + 1
            end
            
            print('[1] Found variable_name_map_glbl with ' .. count .. ' entries')
            
            if statusEl then
                statusEl:setValue('value', 'Deleting ' .. count .. ' vars...', true)
            end
            
            -- Delete all variables listed in the map
            print('[2] Deleting erlelo variables by API ID...')
            local deleted = 0
            for name, id in pairs(state.name_to_id) do
                -- Log first few and every 20th
                if deleted < 5 or deleted % 20 == 0 then
                    print('    Deleting: ' .. name .. ' (ID ' .. id .. ')')
                end
                
                http:DELETE(API_BASE .. '/lua/variables/' .. id)
                    :header('Authorization', TOKEN)
                    :send()
                
                deleted = deleted + 1
            end
            
            state.delete_count = deleted
            print('[2] Sent ' .. deleted .. ' delete requests')
            
            -- Verify deletion
            state.step = 'verify'
            print('[3] Verifying deletion...')
            http:GET(API_BASE .. '/lua/variables')
                :header('Authorization', TOKEN)
                :timeout(10)
                :send()
            
        elseif state.step == 'verify' then
            local ok, resp = pcall(function() return JSON:decode(payload) end)
            if not ok or not resp or not resp.data then
                print('Verification failed - check manually')
                state.step = 'idle'
                return
            end
            
            -- Check how many erlelo vars remain
            local remaining = 0
            for _, v in ipairs(resp.data) do
                if state.name_to_id and state.name_to_id[v.name] then
                    remaining = remaining + 1
                end
            end
            
            print('[3] Remaining erlelo vars: ' .. remaining)
            print('    Total system vars: ' .. #resp.data)
            
            if remaining == 0 then
                print('')
                print('=== ALL ERLELO VARIABLES DELETED ===')
                print('Deleted ' .. state.delete_count .. ' variables')
                if statusEl then
                    statusEl:setValue('value', 'DONE! All ' .. state.delete_count .. ' deleted', true)
                end
            else
                print('Some variables remain - run again if needed')
                if statusEl then
                    statusEl:setValue('value', remaining .. ' left - run again', true)
                end
            end
            
            state.step = 'idle'
        end
    end)
end
