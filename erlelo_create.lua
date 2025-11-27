--[[
    ERLELO VARIABLE CREATOR v2.4
    
    Fetches variable config from GitHub and creates all variables.
    Run this ONCE on a new system to initialize all erlelo variables.
    
    ============================================================
    CONFIGURATION - SET YOUR CHAMBER COUNT HERE:
    ============================================================
]]

local NUM_CHAMBERS = 3  -- Set to 1, 2, or 3

--[[
    ============================================================
    UI SETUP - Add these elements in the device editor:
    ============================================================
    1. Add Button element:
       - Name: btn_start
       - Text: "Start Install"
       - Icon: play
       - On Press: onStartPress
    
    2. Add Text element:
       - Name: status_text
       - Value: "Ready"
    
    3. Arrange in widget layout (column, centered)
    ============================================================
    
    WORKFLOW:
    1. Set NUM_CHAMBERS above (1, 2, or 3)
    2. Press "Start Install" → fetches config from GitHub
    3. Creates all variables via Sinum API
    4. Run erlelo_store next to build name→ID mapping
    5. Enable kulso and kamra controllers
]]

-- GitHub raw URLs for config JSONs
local GITHUB_BASE = 'https://raw.githubusercontent.com/kekhazkft-code/setup/main/'
local CONFIG_FILES = {
  [1] = 'erlelo_config_1ch.json',
  [2] = 'erlelo_config_2ch.json',
  [3] = 'erlelo_config_3ch.json',
}

-- Sinum API configuration
local API_BASE = 'http://192.168.0.122/api/v1'
local TOKEN = 'YOUR_API_TOKEN_HERE'  -- Replace with your API token

local http = nil
local state = nil

function CustomDevice:onInit()
    local config_file = CONFIG_FILES[NUM_CHAMBERS] or CONFIG_FILES[3]
    
    print('=== ERLELO VARIABLE INSTALLER v2.4 ===')
    print('Humidity-Primary Control System')
    print('Chamber count: ' .. NUM_CHAMBERS)
    print('Config file: ' .. config_file)
    print('')
    print('Press "Start Install" button to begin')
    
    http = self:getComponent('http')
    state = { 
        step = 'idle', 
        config = nil, 
        created = 0, 
        total = 0,
        config_url = GITHUB_BASE .. config_file
    }
    
    local status = self:getElement('status_text')
    if status then
        status:setValue('value', NUM_CHAMBERS .. '-chamber ready', true)
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
    
    print('[1] Fetching ' .. NUM_CHAMBERS .. '-chamber config from GitHub...')
    print('    URL: ' .. state.config_url)
    state.step = 'fetch'
    state.created = 0
    
    local status = self:getElement('status_text')
    if status then
        status:setValue('value', 'Fetching config...', true)
    end
    
    http:GET(state.config_url):timeout(15):send()
end

function CustomDevice:onEvent(event)
    if not http or not state then return end
    
    http:onMessage(function(status_code, payload, url)
        local statusEl = self:getElement('status_text')
        
        if state.step == 'fetch' then
            if status_code == 200 then
                local ok, config = pcall(function() return JSON:decode(payload) end)
                if not ok or not config or not config.variables then
                    print('ERROR: Failed to parse config JSON')
                    if statusEl then statusEl:setValue('value', 'ERROR: Bad JSON', true) end
                    state.step = 'idle'
                    return
                end
                
                state.config = config
                state.total = #config.variables
                print('[1] Loaded config v' .. (config.version or '?'))
                print('    ' .. config.description)
                print('    Variables to create: ' .. state.total)
                print('')
                print('    Naming convention:')
                print('      Chamber-specific: _ch1, _ch2, _ch3')
                print('      Global: _glbl')
                
                if statusEl then
                    statusEl:setValue('value', 'Creating ' .. state.total .. ' vars...', true)
                end
                
                state.step = 'create'
                print('')
                print('[2] Creating variables...')
                self:createAllVariables()
            else
                print('ERROR: HTTP ' .. tostring(status_code) .. ' fetching config')
                if statusEl then statusEl:setValue('value', 'ERROR: HTTP ' .. tostring(status_code), true) end
                state.step = 'idle'
            end
            
        elseif state.step == 'verify' then
            if status_code == 200 then
                local ok, resp = pcall(function() return JSON:decode(payload) end)
                if ok and resp and resp.data then
                    print('[3] VERIFICATION COMPLETE')
                    print('    Total system variables: ' .. #resp.data)
                    print('')
                    print('=== INSTALLATION COMPLETE ===')
                    print('NEXT STEPS:')
                    print('  1. Run erlelo_store to build name->ID mapping')
                    print('  2. Enable erlelo_kulso controller')
                    for i = 1, NUM_CHAMBERS do
                        print('  ' .. (i+2) .. '. Enable erlelo_kamra' .. i .. ' controller')
                    end
                    
                    if statusEl then
                        statusEl:setValue('value', 'DONE! Run erlelo_store', true)
                    end
                end
            end
            state.step = 'idle'
        end
    end)
end

function CustomDevice:createAllVariables()
    local count = 0
    
    for i, var in ipairs(state.config.variables) do
        local body = JSON:encode({
            type = var.type,
            name = var.name,
            description = var.description or '',
            default_value = var.default_value,
            value = var.default_value
        })
        
        http:POST(API_BASE .. '/lua/variables')
            :header('Content-Type', 'application/json')
            :header('Authorization', TOKEN)
            :body(body)
            :send()
        
        count = count + 1
        
        if count % 20 == 0 then
            print('    Created ' .. count .. '/' .. state.total)
        end
    end
    
    print('[2] Sent ' .. count .. ' create requests')
    
    state.step = 'verify'
    print('[3] Verifying...')
    http:GET(API_BASE .. '/lua/variables')
        :header('Authorization', TOKEN)
        :timeout(15)
        :send()
end
