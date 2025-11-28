--sensor_ini kk03 (REFACTORED with intelligent event propagation)


            local kamra_homerseklet_v1 = variable[1]    --int*10
            local kamra_para_v1 = variable[2]    --int*10
            local kamra_cel_homerseklet_v1 = variable[3]    --int*10
            local kamra_cel_para_v1 = variable[4]    --int*10
            local befujt_cel_homerseklet_v1 = variable[5]    --int*10
            local befujt_cel_para_v1 = variable[6]    --int*10
            local kulso_homerseklet_v1 = variable[7]    --int*10
            local kulso_para_v1 = variable[8]    --int*10
            local kulso_szimulalt_ertekek_v1 = variable[9]      --boolean
            local befujt_homerseklet_mert_table1 = variable[17]   --table
            local befujt_para_mert_table1 = variable[18]   --table
            local kamra_homerseklet_table1 = variable[19]   --table
            local kamra_para_table1 = variable[20]   --table
            local kulso_homerseklet_table1=variable[21]   --table
            local kulso_para_table1 = variable[22]    --int*10
            local befujt_homerseklet_akt1 = variable[23]    --int*10
            local befujt_para_akt1 = variable[24]    --int*10
            local befujt_szimulalt1 = variable[25]
            local biztonsagi_hom_akt1 = variable[26]    --int*10
            local biztonsagi_hom_table1 = variable[27]   --table
            local last_sent_table1 = variable[28]   --table
            local befujt_hibaszam1 = variable[29]    --int
            local kamra_hibaszam1 = variable[30]    --int
            local kulso_hibaszam1 = variable[31]    --int
            local biztonsagi_hom_hibaszam1 = variable[32]
            local constansok1 = variable[33]
            local signals1 = variable[34]
            local biztonsagi_para_akt1 = variable[35]
            local biztonsagi_para_table1 = variable[36]
            local hibajel1 = variable[37]
            local cycle_variable1 = variable[38]
            local mert_sulyok_table1 = variable[39]
            local suly_meres_table1 = variable[40]
            local atlagsuly_mv1 = variable[41]
   			local ah_dp_table1 = variable[42]
            local mert_sulyok2_table1 = variable[43]
            local suly_meres2_table1 = variable[44]
            local atlagsuly2_mv1 = variable[45]
--KK03 - *****************************
            local humidity_save_inp = sbus[48]
            local sum_wint_inp = sbus[50]

            local relay_warm= sbus[60]         --fűtés kapcsoló relé
            local relay_add_air_max= sbus[61]  -- tél/nyár váltó relé
			local relay_reventon = sbus[62]    -- főmotor beáll-user	
			local relay_add_air_save = sbus[63] -- befujt plusz levegő
            local relay_bypass_open = sbus[64]    --pára mentő relé (bypass nyit)
			local relay_main_fan = sbus[65]    -- fömotor    1-2 fokozat

            local relay_cool=sbus[52]  -- hűtés kapcsoló relé
            local relay_sleep= sbus[53] -- pihenőidő relé
            local suly_meres_input = sbus[44]
            local suly_meres_input2 = sbus[45]
--KK03 **************************            
--[[
--KK04 - Páasztó *********************
            local humidity_save_inp = sbus[17]
            local sum_wint_inp = sbus[19]

            local relay_warm= sbus[68]         --fűtés kapcsoló relé
            local relay_add_air_max= sbus[69]  -- tél/nyár váltó relé
			local relay_reventon = sbus[70]    -- főmotor beáll-user	
			local relay_add_air_save = sbus[71] -- befujt plusz levegő
            local relay_bypass_open = sbus[72]    --pára mentő relé (bypass nyit)
			local relay_main_fan = sbus[73]    -- fömotor    1-2 fokozat

            local relay_cool=sbus[21]  -- hűtés kapcsoló relé
            local relay_sleep= sbus[22] -- pihenőidő relé
            local suly_meres_input = sbus[13]
            local suly_meres_input2 = sbus[14]
--KK04 ***********************
]]
--[[
--KK02 - st_ivan **************************
            local humidity_save_inp = sbus[76]
            local sum_wint_inp = sbus[78]

            local relay_warm= sbus[104]         --fűtés kapcsoló relé
            local relay_add_air_max= sbus[105]  -- tél/nyár váltó relé
			local relay_reventon = sbus[106]    -- főmotor beáll-user	
			local relay_add_air_save = sbus[107] -- befujt plusz levegő
            local relay_bypass_open = sbus[108]    --pára mentő relé (bypass nyit)
			local relay_main_fan = sbus[109]    -- fömotor    1-2 fokozat

            local relay_cool=sbus[96]  -- hűtés kapcsoló relé
            local relay_sleep= sbus[97] -- pihenőidő relé
            local suly_meres_input = sbus[88]
            local suly_meres_input2 = sbus[89]
--KK02 ********************************
]]
 function CustomDevice:pihenoido()
    local sleep = cycle_variable1:getValue({}).sleep_time
    local cycle = cycle_variable1:getValue({}).cycle_time
    cycle_variable1:setValueByPath("passiv_time", (sleep/10)*(cycle/10), true)
    cycle_variable1:setValueByPath("action_time", (10-sleep/10)*(cycle/10), true)
    cycle_variable1:save(true)
    end

function CustomDevice:simul_off(virt_Id,simul_switch)
   local tempreg = virt_Id:getElement(simul_switch)
    tempreg:setValue("value",false, true)
--*    print ("virtual-id: ",tempreg:getValue("device_id"), simul_switch, ": ", tempreg:getValue("value"))
    end

local function devcheck (devname, devtxt)
    local devicename = devname:getValue('name')
   if devicename == devtxt then
        print(devicename," OK!!")
   else
        print(devicename," megváltozott !!!!")
    end
end

local function devset (logname, relayname, txtaddr, outtxt1, outtxt0)
        if logname then
        relayname:call("turn_on")
        txtaddr:setValue("value",outtxt1,true)
        else
        relayname:call("turn_off")
        txtaddr:setValue("value",outtxt0,true)
        end
    end

local function txtset (logname, txtaddr, outtxt1, outtxt0)
        if logname then
        txtaddr:setValue("value",outtxt1,true)
        else
        txtaddr:setValue("value",outtxt0,true)
        end
    end

local function suly_check(table,raw_suly)

local sulymeres = table:getValue({})
local e ={
    mert_db = 20,
    tara = 30,
    akt_meres = raw_suly, --suly_meres_input:getValue("raw_value"),
    suly_szorzo = 250, --mV/kg 
    kezdeti_anyag = raw_suly,
    maradek_anyag = raw_suly,
    indulo_suly = raw_suly,
    suly_adat = {}
}
    if  sulymeres.akt_meres == nil then
        sulymeres.akt_meres = raw_suly
    end
    if sulymeres.suly_szorzo == nil then
        sulymeres.suly_szorzo = e.suly_szorzo
    end
    if  sulymeres.kezdeti_anyag == nil then
        sulymeres.kezdeti_anyag = raw_suly
    end
    if  sulymeres.maradek_anyag == nil then
        sulymeres.maradek_anyag = raw_suly
    end
    if sulymeres.suly_adat == nil then
        sulymeres.suly_adat = e.suly_adat
    end
--  sulymeres = e
  table:setValue(sulymeres,true)
end

local function suly_szamol(mert_sulyok_table,atlagsuly_mv, raw_suly,kiir_call)
  local sulymeres = mert_sulyok_table:getValue({})
  
  local instab = {}
  for ind, value in pairs(sulymeres.suly_adat) do
    table.insert(instab,value)
  end
  table.insert(instab,raw_suly)
  if #instab > sulymeres.mert_db then
    table.remove(instab,1)
  end
  local sum = 0
  for _, value in ipairs(instab) do
    sum = sum + value
  end
  sulymeres.suly_adat = instab
  sulymeres.akt_meres = raw_suly
  mert_sulyok_table:setValue(sulymeres, kiir_call)
  local atlag_raw = (sum /#instab)
  local atlag_kg = (atlag_raw - sulymeres.tara) / sulymeres.suly_szorzo
  sulymeres.maradek_anyag = atlag_kg
  atlagsuly_mv:setValue( atlag_raw , true)
  if not kiir_call then
    print("raw suly tábla kiiras: ", mert_sulyok_table)
  end
end

function CustomDevice:onInit()
  print('init szensor ')
  local constansok = constansok1:getValue({})
  if constansok.deltahi_befujt_homerseklet == nil then
    constansok.deltahi_befujt_homerseklet = 20
    constansok.deltalo_befujt_homerseklet = 15
    constansok.deltahi_befujt_para = 20
    constansok.deltalo_befujt_para = 15
    constansok.deltahi_kamra_homerseklet = 10
    constansok.deltalo_kamra_homerseklet = 10
    constansok.deltahi_kamra_para = 15
    constansok.deltalo_kamra_para = 10
    constansok.deltahi_kulso_homerseklet = 20
    constansok.deltalo_kulso_homerseklet = 20
    constansok.deltahi_kulso_para = 20
    constansok.deltalo_kulso_para = 20
    constansok.gradiens_homerseklet = 30
    constansok.gradiens_para = 30
    constansok1:setValue(constansok,true)
    constansok1:save(true)
  end
  
  local signal = signals1:getValue({})
  if signal.warm_dis == nil then
    signal.warm_dis = false
    signal.dehumi = false
    signal.cool = false
    signal.warm = false
    signal.cool_dis = false
    signal.sleep = false
    signal.sum_wint_jel = false
    signal.humi_save = false
    signal.add_air_max = false
    signal.reventon = false
    signal.add_air_save = false
    signal.bypass_open = false
    signal.main_fan = false
    signals1:setValue(signal,true)
    signals1:save(true)
  end
  
  local cyclevar = cycle_variable1:getValue({})
  if cyclevar.cycle_time == nil then
    cyclevar.cycle_time = 600
    cyclevar.sleep_time = 10
    cyclevar.action_time = 540
    cyclevar.passiv_time = 60
    cyclevar.szamlalo = 540
    cycle_variable1:setValue(cyclevar,true)
    cycle_variable1:save(true)
  end
  
  suly_check(mert_sulyok_table1, suly_meres_input:getValue("raw_value"))
  suly_check(mert_sulyok2_table1, suly_meres_input2:getValue("raw_value"))
  
  self:setValue('status', 'online')
end

-- REFACTORED EVENT HANDLER with intelligent propagation
function CustomDevice:onEvent(event)
    local timerState = self:getComponent("timer4"):getState()
    local signal = signals1:getValue({})
    local old_signal = {}
    for k, v in pairs(signal) do
        old_signal[k] = v
    end
    
    local teszt = false
    
    if (timerState == "elapsed" or timerState == "off") then
        self:getComponent("timer4"):start(1000)
        teszt = self:getElement("min_sec_sw"):getValue("value")
    end
    
    -- ciklus számláló léptetése 1 percenként ha nincs teszt üzemmód
    if dateTime:changed() or teszt then
        teszt = false
        local cyclevar = cycle_variable1:getValue({})
        local kezi = self:getElement("pihi_vez_sw"):getValue("value")
        
        local old_cyclevar_szamlalo = cyclevar.szamlalo
        
        if not kezi then
            cyclevar.szamlalo = cyclevar.szamlalo - 1
            if cyclevar.szamlalo <= 0 then
                if signal.sleep then
                    cyclevar.szamlalo = cyclevar.action_time
                    signal.sleep = false
                    relay_sleep:call("turn_on")
                else
                    cyclevar.szamlalo = cyclevar.passiv_time
                    signal.sleep = true
                    relay_sleep:call("turn_off")              
                end
                
                -- CRITICAL: Sleep mode changed - MUST propagate
                signals1:setValue(signal, false)
                print("Sleep mode changed to:", signal.sleep, "- Event propagated")
            end 
            
            self:getElement("txt_ido"):setValue("value", string.format("%3d perc", cyclevar.szamlalo), true)
            
            -- INTELLIGENT PROPAGATION: Only propagate if counter changed
            local counter_changed = (old_cyclevar_szamlalo ~= cyclevar.szamlalo)
            cycle_variable1:setValue(cyclevar, not counter_changed)
            
            if signal.sleep then
                self:getElement('sleep_field'):setValue("value", "Pihenőidő!!!", true)
            else
                self:getElement('sleep_field'):setValue("value", "Aktív idő!!!", true)
            end
        else
            signal.sleep = self:getElement("pihi_aktiv_sw"):getValue("value")
            if signal.sleep then
                self:getElement('sleep_field'):setValue("value", "Kikapcsolva", true)
            else
                self:getElement('sleep_field'):setValue("value", "Bekapcsolva", true)
            end
        end
        
    elseif humidity_save_inp:changed() then
        signal.humi_save = humidity_save_inp:getValue("state")
        txtset(signal.humi_save, self:getElement('humi_save_txt'), "Páramentő mód", "Páracsökkentő mód")
        
        -- Check if value actually changed
        if old_signal.humi_save ~= signal.humi_save then
            signals1:setValue(signal, false)
            print("Humidity save mode changed to:", signal.humi_save, "- Event propagated")
        end
        
    elseif sum_wint_inp:changed() then
        signal.sum_wint_jel = sum_wint_inp:getValue("state")
        txtset(signal.sum_wint_jel, self:getElement('sum_wint_field'), "Nyári üzemmód!", "Téli üzemmód!")
        
        -- Check if value actually changed
        if old_signal.sum_wint_jel ~= signal.sum_wint_jel then
            signals1:setValue(signal, false)
            print("Summer/Winter mode changed to:", signal.sum_wint_jel, "- Event propagated")
        end
        
    elseif kamra_cel_homerseklet_v1:changed() then
        print("Target temperature changed - received from other device")
    end
    
    -- FINAL CHECK: Save signals only if something changed
    local signal_changed = false
    for k, v in pairs(signal) do
        if old_signal[k] ~= v then
            signal_changed = true
            break
        end
    end
    
    if signal_changed then
        signals1:setValue(signal, false)
        signals1:save(false)
        print("Signals saved and propagated")
    end
end


  local function setrelay(signal, relayname )
    if signal then if relayname:getValue("state") ~= "on" then relayname:call("turn_on")
        end
    end
    if not signal then if relayname:getValue("state") ~= "off" then relayname:call("turn_off")
      end
    end
  end


-- REFACTORED with intelligent propagation  
function CustomDevice:on_pihi_vez_change(newValue, element)
    local sleep = self:getElement("pihi_aktiv_sw"):getValue("value")
    local old_sleep = signals1:getValue({}).sleep
    
    if newValue then
        if old_sleep ~= sleep then
            signals1:setValueByPath("sleep", sleep, false)
            signals1:save(false)
            print("Manual sleep mode set to:", sleep, "- Event propagated")
        else
            signals1:setValueByPath("sleep", sleep, true)
            signals1:save(true)
        end
        
        setrelay(not sleep, relay_sleep)
        
        if sleep then 
            self:getElement('sleep_field'):setValue("value", "Kikapcsolva", true)
        else
            self:getElement('sleep_field'):setValue("value", "Bekapcsolva", true)
        end
    else
        if sleep then
            self:getElement('sleep_field'):setValue("value", "Pihenőidő!!!", true)
        else
            self:getElement('sleep_field'):setValue("value", "Aktív idő!!!", true)
        end
    end
end

-- REFACTORED with intelligent propagation
function CustomDevice:on_pihi_aktiv_change(newValue, element)
    if self:getElement("pihi_vez_sw"):getValue("value") then
        local old_sleep = signals1:getValue({}).sleep
        
        if old_sleep ~= newValue then
            signals1:setValueByPath("sleep", newValue, false)
            signals1:save(false)
            print("Sleep mode toggled to:", newValue, "- Event propagated")
        else
            signals1:setValueByPath("sleep", newValue, true)
            signals1:save(true)
        end
        
        setrelay(not newValue, relay_sleep)
        
        if newValue then 
            self:getElement('sleep_field'):setValue("value", "Kikapcsolva", true)
        else
            self:getElement('sleep_field'):setValue("value", "Bekapcsolva", true)
        end
    end
end


function CustomDevice:on_init_enable_change (newValue, element)
    self:getElement("button_0"):setValue("enabled",newValue,true)
    print("init enable:", newValue)
end
