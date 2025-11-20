-- apar2_0 XY-MD1.1

local txt = {
  yes = '☑',
}
local kamra_homerseklet_v1 = variable[1]
local kamra_para_v1 = variable[2]
local kamra_cel_homerseklet_v1 = variable[3]
local kamra_cel_para_v1 = variable[4]
local befujt_cel_homerseklet_v1 = variable[5]

local befujt_cel_para_v1 = variable[6]
local kulso_homerseklet_v1 = variable[7]
local kulso_para_v1 = variable[8]
local befujt_homerseklet_mert_table1 = variable[17]
local befujt_para_mert_table1 = variable[18]
local befujt_homerseklet_akt1 = variable[23]
local befujt_para_akt1 = variable[24]
local befujt_szimulalt1 = variable[25]
local biztonsagi_hom_akt1 = variable[26]
local last_sent_table1 = variable[28]
local befujt_hibaszam1 = variable[29]
local kamra_hibaszam1 = variable[30]
local kulso_hibaszam1 = variable[31]

local biztonsagi_hom_table1 = variable[27]
local kulso_szimulalt_ertekek_v1 = variable[9]
local kamra_homerseklet_table1 = variable[19]
local kamra_para_table1 = variable[20]
local kulso_homerseklet_table1 = variable[21]
local kulso_para_table1 = variable[22]
local ah_dp_table1 = variable[42]

local relay_warm = sbus[60]         --fűtés kapcsoló relé
local relay_add_air_max= sbus[61]  -- tél/nyár váltó relé
local relay_reventon = sbus[62]    -- főmotor beáll-user	
local relay_add_air_save = sbus[63] -- befujt plusz levegő
local relay_bypass_open = sbus[64]    --pára mentő relé (bypass nyit)
local relay_main_fan = sbus[65]    -- fömotor    1-2 fokozat

local relay_cool=sbus[52]  -- hűtés kapcsoló relé
local relay_sleep= sbus[53] -- pihenőidő relé

-- Configuration constants for meaningful change detection
local TEMP_CHANGE_THRESHOLD = 2  -- 0.2°C minimum change to propagate (int*10)
local HUMI_CHANGE_THRESHOLD = 3  -- 0.3% minimum change to propagate (int*10)
local MIN_SUPPLY_AIR_TEMP = 60   -- 6.0°C minimum supply air temperature (int*10)

function CustomDevice:c()
  return self:getComponent('com')
end

function CustomDevice:onInit()
  print('init')
  self:setValue('status', 'unknown')
  
  local com = self:c()
  self:getElement('baudrate'):setValue('value', tostring(com:getValue('baud_rate')), true)
  self:getElement('parity'):setValue('value', com:getValue('parity'), true)
  self:getElement('stopbits'):setValue('value', com:getValue('stop_bits'), true)
  self:getElement('slave_id'):setValue('value', tostring(com:getValue('slave_address')), true)
  
  local xceiver = com:getValue('associations.transceiver')
  self:getElement('xceiver'):setValue('associations.selected', xceiver, true)
  befujt_hibaszam1:setValue(3,true)

  -- BUG FIX: Initialize sliders with current target values
  local temp_target = kamra_cel_homerseklet_v1:getValue()
  local humi_target = kamra_cel_para_v1:getValue()
  self:getElement('slider_1'):setValue('value', temp_target/10, true)
  self:getElement('slider_0'):setValue('value', humi_target/10, true)

  -- Also initialize dew point/absolute humidity displays
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))

end

function CustomDevice:online()
  if self:getValue('status') ~= 'online' then
    self:setValue('status', 'online')
    self:poll()   
  end
  befujt_hibaszam1:setValue(3,true)

  -- BUG FIX: Initialize sliders with current target values
  local temp_target = kamra_cel_homerseklet_v1:getValue()
  local humi_target = kamra_cel_para_v1:getValue()
  self:getElement('slider_1'):setValue('value', temp_target/10, true)
  self:getElement('slider_0'):setValue('value', humi_target/10, true)

  -- Also initialize dew point/absolute humidity displays
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))

end

function CustomDevice:offline()
  if self:getValue('status') ~= 'offline' then
    self:setValue('status', 'offline')
  end
end

local SPRINTF = string.format

function CustomDevice:updateText(text_id, format, value)
  local text = (
    type(value) ~= 'boolean'
    and SPRINTF(format, value)
    or (value and txt.yes or txt.no)
  )
  self:getElement(text_id):setValue('value', text, true)
end

local function setrelay(signal, relayname)
  if signal then 
    if relayname:getValue("state") ~= "on" then 
      relayname:call("turn_on")
    end
  else
    if relayname:getValue("state") ~= "off" then 
      relayname:call("turn_off")
    end
  end
end

--harmatpont és abszolut páratartalom

-- Constants for psychrometric calculations
local A = 6.112
local B = 17.67
local C = 243.5
local MW_RATIO = 2.1674
local KELVIN_OFFSET = 273.15

-- Saturation vapor pressure (hPa)
local function saturation_vapor_pressure(temp_c)
    return A * math.exp((B * temp_c) / (temp_c + C))
end

-- Calculate absolute humidity from T and RH
local function calculate_absolute_humidity(temp_c, rh)
    local svp = saturation_vapor_pressure(temp_c)
    local avp = (rh / 100.0) * svp
    return (avp * MW_RATIO) / (KELVIN_OFFSET + temp_c)
end

-- Calculate RH from AH and T
local function calculate_rh(temp_c, target_ah)
    local svp = saturation_vapor_pressure(temp_c)
    local avp = (target_ah * (KELVIN_OFFSET + temp_c)) / MW_RATIO
    return (avp / svp) * 100.0
end

-- Calculate T from AH and RH using numerical method
local function calculate_temp_from_ah_and_rh(target_ah, rh)
    local guess = -30.0
    local max_temp = 60.0
    local step = 0.01
    local tolerance = 0.001

    while guess <= max_temp do
        local svp = saturation_vapor_pressure(guess)
        local avp = (rh / 100.0) * svp
        local ah = (avp * MW_RATIO) / (KELVIN_OFFSET + guess)

        if math.abs(ah - target_ah) < tolerance then
            return guess
        end

        guess = guess + step
    end

    return nil -- not found
end

function calc_dew_point(temp, rh)
  if temp == nil or rh == nil then
    return nil, "Missing input"
  end
  if rh > 100 then
    rh=99
  elseif rh <= 0 then 
    rh= 1
  end

  local a = 17.62
  local b = 243.12

  local gamma = (a * temp) / (b + temp) + math.log(rh / 100)
  local dew_point = (b * gamma) / (a - gamma)

  return dew_point
end

local function ah_dp_set()
  local ah_cel = calculate_absolute_humidity(kamra_cel_homerseklet_v1:getValue()/10,kamra_cel_para_v1:getValue()/10)
  local dp_cel = calc_dew_point(kamra_cel_homerseklet_v1:getValue()/10,kamra_cel_para_v1:getValue()/10)
  local ah_dp	= {
    ah_cel = ah_cel,
    ah_befujt_cel = ah_cel,
    ah_befujt = ah_cel,
    ah_kamra = ah_cel,
    ah_kulso = ah_cel,
    dp_cel = dp_cel,
    dp_befujt_cel = dp_cel,
    dp_befujt = dp_cel,
    dp_kamra = dp_cel,
    dp_kulso = dp_cel
  }
  ah_dp_table1:setValue(ah_dp,true)
end

local function ah_dp_cel_szamol(dp_tx, ah_tx)
  local ah = calculate_absolute_humidity(kamra_cel_homerseklet_v1:getValue()/10,kamra_cel_para_v1:getValue()/10)
  local dp = calc_dew_point(kamra_cel_homerseklet_v1:getValue()/10,kamra_cel_para_v1:getValue()/10)
  ah_dp_table1:setValueByPath("ah_cel",ah,true)
  ah_dp_table1:setValueByPath("dp_cel",dp,true)
  dp_tx:setValue("value", string.format("harmatpont:  %3.1f°C", dp),true)
  ah_tx:setValue("value", string.format("absolut pára:  %0.3fg/m3", ah),true)
end

local function ah_dp_befujt_szamol()
  local ah = calculate_absolute_humidity(befujt_homerseklet_akt1:getValue()/10,befujt_para_akt1:getValue()/10)
  local dp = calc_dew_point(befujt_homerseklet_akt1:getValue()/10,befujt_para_akt1:getValue()/10)
  ah_dp_table1:setValueByPath("ah_befujt",ah,true)
  ah_dp_table1:setValueByPath("dp_befujt",dp,true)
end

-- CORRECTED PSYCHROMETRIC EVALUATION for outdoor air benefit
-- Implements three-step method to avoid comparing RH at different temperatures
-- Reference: CORRECTED_PSYCHROMETRIC_EVALUATION.md
local function evaluate_outdoor_air_benefit(
  chamber_temp,     -- Current chamber temperature (°C)
  chamber_rh,       -- Current chamber RH (%)
  target_temp,      -- Target chamber temperature (°C)
  target_rh,        -- Target chamber RH (%)
  outdoor_temp,     -- Outdoor temperature (°C)
  outdoor_rh,       -- Outdoor RH (%)
  outdoor_mix_ratio -- Outdoor air mixing ratio (0.0-1.0, e.g., 0.3 = 30%)
)
  -- STEP 1: Calculate absolute humidities (temperature-independent metric)
  local chamber_ah = calculate_absolute_humidity(chamber_temp, chamber_rh)
  local target_ah = calculate_absolute_humidity(target_temp, target_rh)
  local outdoor_ah = calculate_absolute_humidity(outdoor_temp, outdoor_rh)

  -- STEP 2: Calculate mixed air properties (assuming perfect mixing)
  local mixed_temp = chamber_temp * (1 - outdoor_mix_ratio) + outdoor_temp * outdoor_mix_ratio
  local mixed_ah = chamber_ah * (1 - outdoor_mix_ratio) + outdoor_ah * outdoor_mix_ratio

  -- STEP 3: Project final steady-state at target temperature
  -- Calculate what RH would be at target temperature with mixed absolute humidity
  local projected_rh_at_target = calculate_rh(target_temp, mixed_ah)

  -- DECISION CRITERIA (corrected - comparing at same temperature):
  -- 1. Temperature benefit: Moving toward target?
  local temp_delta_current = math.abs(target_temp - chamber_temp)
  local temp_delta_mixed = math.abs(target_temp - mixed_temp)
  local temp_improves = temp_delta_mixed < temp_delta_current

  -- 2. Humidity evaluation at target temperature (NOT at mixed temperature!)
  -- Allow ±5% RH tolerance to avoid rejecting beneficial temperature improvements
  local rh_tolerance = 5.0
  local rh_acceptable = math.abs(projected_rh_at_target - target_rh) <= rh_tolerance

  -- 3. Absolute humidity check: Is mixed AH closer to target than current?
  local ah_delta_current = math.abs(target_ah - chamber_ah)
  local ah_delta_mixed = math.abs(target_ah - mixed_ah)
  local ah_improves = ah_delta_mixed < ah_delta_current  -- Strict improvement, not just "not worse"

  -- CORRECTED DECISION LOGIC:
  -- Use outdoor air if temperature improves AND (humidity improves OR remains acceptable)
  local beneficial = temp_improves and (ah_improves or rh_acceptable)

  -- Debug output (can be removed in production)
  if beneficial then
    print(string.format("Outdoor air BENEFICIAL: Temp %.1f→%.1f°C (target %.1f°C), " ..
                        "RH@target %.1f%% (target %.1f%%), AH %.2f→%.2f g/m³ (target %.2f g/m³)",
                        chamber_temp, mixed_temp, target_temp,
                        projected_rh_at_target, target_rh,
                        chamber_ah, mixed_ah, target_ah))
  end

  return beneficial, {
    mixed_temp = mixed_temp,
    mixed_ah = mixed_ah,
    projected_rh_at_target = projected_rh_at_target,
    temp_improves = temp_improves,
    ah_improves = ah_improves,
    rh_acceptable = rh_acceptable
  }
end

--Fő szabályozási ciklus
function CustomDevice:controlling()

  local kamra_homerseklet     = kamra_homerseklet_v1:getValue()	--	int*10
  local kamra_para            = kamra_para_v1:getValue()	--	int*10
  local kamra_cel_homerseklet  = kamra_cel_homerseklet_v1:getValue()	--	int*10
  local kamra_cel_para	    	 = kamra_cel_para_v1:getValue()	--	int*10
  local befujt_cel_homerseklet = befujt_cel_homerseklet_v1:getValue()	--	int*10
  local befujt_cel_para		     = befujt_cel_para_v1:getValue()	--	int*10
  local kulso_homerseklet	     = kulso_homerseklet_v1:getValue()	--	int*10
  local kulso_para			       = kulso_para_v1:getValue()	--	int*10
  local befujt_mert_para       = befujt_para_akt1:getValue()
  local befujt_mert_homerseklet = befujt_homerseklet_akt1:getValue()
  local kulso_szimulalt_ertekek	= variable[9]:getValue()	--boolean

  local constansok1 = variable[33]
  local konst= {}
  konst= constansok1:getValue({})

  local deltahi_befujt_homerseklet = konst.deltahi_befujt_homerseklet	--int*10
  local deltalo_befujt_homerseklet = konst.deltalo_befujt_homerseklet	--int*10
  local	deltahi_befujt_para			  = konst.deltahi_befujt_para
  local	deltalo_befujt_para			  = konst.deltalo_befujt_para  --int*10
  local	deltahi_kamra_homerseklet	= konst.deltahi_kamra_homerseklet  --int*10
  local	deltalo_kamra_homerseklet	= konst.deltalo_kamra_homerseklet  --int*10
  local	deltahi_kamra_para			  = konst.deltahi_kamra_para  --int*10
  local	deltalo_kamra_para			  = konst.deltalo_kamra_para  --int*10
  local	deltahi_kulso_homerseklet	= konst.deltahi_kulso_homerseklet	  --int*10
  local	deltalo_kulso_homerseklet	= konst.deltalo_kulso_homerseklet  --int*10
  local	deltahi_kulso_para			  = konst.deltahi_kulso_para  --int*10
  local	deltalo_kulso_para			  = konst.deltalo_kulso_para  --int*10
  local	gradiens_homerseklet		  = konst.gradiens_homerseklet   --int*10
  local	gradiens_para				      = konst.gradiens_para  --int*10

  --Boolean változók:
  local signals1 = variable[34]
  local signal = signals1:getValue({})
  local cycle_variable1 = variable[38]
  local cyclevar = cycle_variable1:getValue({})
  local	kamra_hutes_tiltas = false
  local	kamra_hutes = false
  local	kamra_futes = false
  local	kamra_para_hutes = false
  local	kamra_para_futes_tiltas = false
  local	befujt_futes = false
  local	befujt_hutes = false
  local	hutes_tiltas = false
  local	futes_tiltas = false
  local	befujt_para_hutes = false
  local warm_dis = signal.warm_dis 
  local dehumi = signal.dehumi
  local cool = signal.cool
  local warm = signal.warm
  local cool_dis = signal.cool_dis
  local sleep = signal.sleep
  local sum_wint_jel = signal.sum_wint_jel
  local humi_save = signal.humi_save
  local add_air_max = signal.add_air_max

  local kamra_hibaflag
  if kamra_hibaszam1:getValue()<= 0 then 
    kamra_hibaflag=true
  else 
    kamra_hibaflag=false
  end
  
  -- 1. befujt cél értékek számítása
  -- Store old values to detect meaningful changes
  local old_befujt_cel_homerseklet = befujt_cel_homerseklet_v1:getValue()
  local old_befujt_cel_para = befujt_cel_para_v1:getValue()
  
  if kamra_hibaflag then 
    befujt_cel_para = kamra_cel_para_v1:getValue() 
  else
    befujt_cel_para = kamra_cel_para + (kamra_cel_para - kamra_para)/2
  end
  
  if kamra_hibaflag then 
    befujt_cel_homerseklet = kamra_cel_homerseklet_v1:getValue() 
  else
    befujt_cel_homerseklet = kamra_cel_homerseklet + (kamra_cel_homerseklet - kamra_homerseklet)/2
  end
  
  -- INTELLIGENT PROPAGATION: Only propagate if values changed meaningfully
  local temp_changed = math.abs(befujt_cel_homerseklet - old_befujt_cel_homerseklet) >= TEMP_CHANGE_THRESHOLD
  local humi_changed = math.abs(befujt_cel_para - old_befujt_cel_para) >= HUMI_CHANGE_THRESHOLD
  
  befujt_cel_homerseklet_v1:setValue(befujt_cel_homerseklet, not temp_changed)
  befujt_cel_para_v1:setValue(befujt_cel_para, not humi_changed)
  
  --Befujt cél dp és ah számolása
  local ah = calculate_absolute_humidity(befujt_cel_homerseklet_v1:getValue()/10,befujt_cel_para_v1:getValue()/10)
  local dp = calc_dew_point(befujt_cel_homerseklet_v1:getValue()/10,befujt_cel_para_v1:getValue()/10)
  ah_dp_table1:setValueByPath("dp_befujt_cel",dp,true)
  ah_dp_table1:setValueByPath("ah_befujt_cel",ah,true)
  ah_dp_table1:save(true)

  -- 2.	szabályozás kamra_cel_ értékekre (hőmérséklet)
  if not kamra_hibaflag then 
    if kamra_homerseklet >(kamra_cel_homerseklet+2*deltahi_kamra_homerseklet) then 
      kamra_hutes =true 
    end
    if kamra_homerseklet <(kamra_cel_homerseklet+deltahi_kamra_homerseklet) then 
      kamra_hutes =false 
    end
    if kamra_homerseklet >(kamra_cel_homerseklet-deltalo_kamra_homerseklet) then 
      kamra_hutes_tiltas =false
      kamra_futes =false 
    end
    if kamra_homerseklet <(kamra_cel_homerseklet-2*deltalo_kamra_homerseklet) then  
      kamra_futes =true
    end
    if kamra_homerseklet <(kamra_cel_homerseklet-3*deltalo_kamra_homerseklet) then 
      kamra_hutes_tiltas =true
    end

    -- (pára tartalom)
    if kamra_para >(kamra_cel_para+2*deltahi_kamra_para) then 
      kamra_para_hutes =true
    end
    if kamra_para <(kamra_cel_para+deltahi_kamra_para) then 
      kamra_para_hutes =false 
    end
    if kamra_para >(kamra_cel_para-deltalo_kamra_para) then 
      kamra_para_futes_tiltas =false 
    end
    if kamra_para <(kamra_cel_para-2*deltalo_kamra_para) then 
      kamra_para_futes_tiltas =true	
    end
  else 
    kamra_hutes =false
    kamra_hutes_tiltas =false
    kamra_futes =false
    kamra_para_hutes =false
    kamra_para_futes_tiltas =false
  end  

  --3.	szabályozás befujt_cel_ értékekre	
  if befujt_mert_homerseklet > (befujt_cel_homerseklet+deltahi_befujt_homerseklet) then 
    befujt_hutes =true
    befujt_futes =false
  end
  if befujt_mert_homerseklet > befujt_cel_homerseklet then 
    befujt_futes =false 
  end
  if befujt_mert_homerseklet < befujt_cel_homerseklet then 
    befujt_hutes =false 
  end
  if befujt_mert_homerseklet >(befujt_cel_homerseklet - deltalo_befujt_homerseklet) then 
    hutes_tiltas =false 
  end
  if befujt_mert_homerseklet <(befujt_cel_homerseklet - deltalo_befujt_homerseklet) then 
    befujt_futes =true 
    befujt_hutes =false 
  end
  if befujt_mert_homerseklet	<(befujt_cel_homerseklet - 2*deltalo_befujt_homerseklet) then 
    hutes_tiltas =true 
  end
  if befujt_mert_homerseklet < MIN_SUPPLY_AIR_TEMP then 
    hutes_tiltas =true 
  end

  if befujt_mert_para > (befujt_cel_para+deltahi_befujt_para) then 
    befujt_para_hutes =true
    futes_tiltas =false 
  end
  if befujt_mert_para > befujt_cel_para then 
    futes_tiltas =false 
  end
  if befujt_mert_para < befujt_cel_para then 
    befujt_para_hutes =false 
  end
  if befujt_mert_para < befujt_cel_para - deltalo_befujt_para then 
    futes_tiltas =true
  end
  
  --szabályozási jel állítások vége 

  local warm_1 = not(kamra_para_futes_tiltas or futes_tiltas) and (kamra_futes or befujt_futes)
  warm = warm_1 and (not signal.sleep)

  cool = not(kamra_hutes_tiltas) and (kamra_hutes or befujt_hutes or kamra_para_hutes)
  local cool_rel = cool and (not signal.sleep) and signal.sum_wint_jel

  warm_dis = kamra_para_futes_tiltas or futes_tiltas
  dehumi = kamra_para_hutes  or befujt_para_hutes
  cool_dis = kamra_hutes_tiltas

  -- CORRECTED OUTDOOR AIR EVALUATION (replaces simple boolean logic)
  -- Old logic: signal.add_air_max = cool and (not signal.sum_wint_jel) and (not signal.humi_save)
  -- New logic: Psychrometric evaluation to determine actual benefit
  local outdoor_air_beneficial = false
  if not signal.humi_save then  -- Only evaluate if not in humidity save mode
    -- Assume 30% outdoor air mixing ratio (configurable)
    local outdoor_mix_ratio = 0.30

    -- Evaluate if outdoor air is beneficial using corrected psychrometric logic
    outdoor_air_beneficial = evaluate_outdoor_air_benefit(
      kamra_homerseklet / 10,      -- Current chamber temp (°C)
      kamra_para / 10,              -- Current chamber RH (%)
      kamra_cel_homerseklet / 10,   -- Target chamber temp (°C)
      kamra_cel_para / 10,          -- Target chamber RH (%)
      kulso_homerseklet / 10,       -- Outdoor temp (°C)
      kulso_para / 10,              -- Outdoor RH (%)
      outdoor_mix_ratio             -- 30% outdoor air
    )
  end

  signal.add_air_max = outdoor_air_beneficial and (not signal.sum_wint_jel)
  signal.reventon = signal.humi_save
  signal.add_air_save = signal.humi_save
  signal.bypass_open = signal.humi_save or (cool and not dehumi)
  signal.main_fan = signal.sum_wint_jel

  --relék állapotának aktualizálása ( warm, cool)
  setrelay(warm, relay_warm)
  setrelay(cool_rel, relay_cool)
  setrelay(signal.add_air_max, relay_add_air_max)
  setrelay(signal.reventon, relay_reventon)
  setrelay(signal.add_air_save, relay_add_air_save)
  setrelay(signal.bypass_open, relay_bypass_open)
  setrelay(signal.main_fan, relay_main_fan)

  -- widget kimenetek aktualizálása
  local output_text = " "
  if warm then output_text ="Fűtés Aktív!" else  output_text = " " end
  self:getElement('text_input_0_warm'):setValue("value",  output_text,true)
  if cool then output_text ="Hűtés Aktív!" else  output_text = " " end
  self:getElement('text_input_1_cool'):setValue("value",  output_text,true)
  if warm_dis then output_text ="Fűtés Tiltva!" else  output_text = " " end
  self:getElement('text_input_2_wdis'):setValue("value",  output_text,true)
  if dehumi then output_text ="Páramentesítés!" else output_text = " " end
  if cool_dis then output_text ="Hűtés Tiltva!" end
  self:getElement('text_input_3_cdis'):setValue("value",  output_text,true)
  
  --jelzések és flag-ek - CRITICAL: Store old values to detect changes
  local old_signal = signals1:getValue({})
  
  signal.warm_dis = warm_dis
  signal.dehumi = dehumi 
  signal.cool = cool
  signal.warm = warm
  signal.cool_dis = cool_dis

  -- INTELLIGENT PROPAGATION: Only propagate if signal state actually changed
  local signal_changed = (
    old_signal.warm_dis ~= signal.warm_dis or
    old_signal.dehumi ~= signal.dehumi or
    old_signal.cool ~= signal.cool or
    old_signal.warm ~= signal.warm or
    old_signal.cool_dis ~= signal.cool_dis or
    old_signal.add_air_max ~= signal.add_air_max or
    old_signal.reventon ~= signal.reventon or
    old_signal.add_air_save ~= signal.add_air_save or
    old_signal.bypass_open ~= signal.bypass_open or
    old_signal.main_fan ~= signal.main_fan
  )
  
  signals1:setValue(signal, not signal_changed)  -- Propagate only if changed

end --controlling vége


-- REFACTORED: Moving average with intelligent propagation
-- Propagates event only when:
-- 1. Buffer is full (has mertdb measurements)
-- 2. Value has changed significantly
local function mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call, simulate)
  local instab = {}
  for ind, value in pairs(tablazat:getValue({})) do
    table.insert(instab, value)
  end
  
  table.insert(instab, akt_meres)        
  if #instab > mertdb then
    table.remove(instab, 1)
  end
  
  local sum = 0
  for _, value in ipairs(instab) do
    sum = sum + value
  end
  
  -- Always update the table buffer (internal use)
  tablazat:setValue(instab, kiir_call)
  
  if not simulate then  
    local new_avg = math.floor((sum / #instab) + 0.5)  -- Round to nearest integer
    local old_avg = atlag_ertek:getValue()
    
    -- INTELLIGENT PROPAGATION CONDITIONS:
    -- 1. Buffer must be full (has enough measurements for valid average)
    -- 2. Value must have changed meaningfully
    local buffer_ready = (#instab >= mertdb)
    local value_changed = math.abs(new_avg - old_avg) >= 1  -- At least 0.1 degree/% change
    
    local should_propagate = buffer_ready and value_changed
    
    atlag_ertek:setValue(new_avg, not should_propagate)
    
    if should_propagate then
      print("Moving average propagated:", atlag_ertek, "old:", old_avg, "new:", new_avg)
    end
  end
  
  if not kiir_call then
    print(tablazat)
  end
end


-- frissítés 5000 msec - 5 sec
function CustomDevice:onEvent(event)
  local source = event.source
  local det = event.details

  local timerState = self:getComponent("timer"):getState() 
  
  -- Timer-based polling and control cycle
  if (timerState == "elapsed" or timerState == "off") then
    self:getComponent("timer"):start(5000)
    self:poll()
    self:controlling()
    print(befujt_homerseklet_akt1:getValue(), befujt_para_akt1:getValue(), befujt_szimulalt1:getValue())
    
  -- Process Modbus read response
  elseif event.type == 'modbus_client_async_read_response' then
    local profiler1 = utils:profiler()
    profiler1:start()
    
    local var1, var2
    self:c():onRegisterAsyncRead(function (kind, addrBase, values)
      self:online()
      
      local function value(addr)
        if type(values) == 'table' then
          return values[addr - addrBase + 1]
        else
          return values
        end
      end
      
      if kind == 'INPUT_REGISTERS' then     
        if addrBase == 1 then
          var1 = value(1)
          var2 = value(2)
        end
      end
    end)
    
    -- REFACTORED: mozgoatlag now handles intelligent propagation internally
    mozgoatlag(befujt_homerseklet_mert_table1, var1, befujt_homerseklet_akt1, 3, true, befujt_szimulalt1:getValue())
    mozgoatlag(befujt_para_mert_table1, var2, befujt_para_akt1, 3, befujt_szimulalt1:getValue(), befujt_szimulalt1:getValue())   
    ah_dp_befujt_szamol()
    
    profiler1:stop()
    profiler1:print()

  -- React to sensor value changes from other devices or propagated events
  elseif event.type == "lua_variable_state_changed" then
    -- Handle different variable changes
    if source.id == 23 or source.id == 24 then  -- befujt_homerseklet_akt1 or befujt_para_akt1
      self:getElement('_1_tx_befujt_homerseklet_'):setValue("value", string.format("%3.1f°C", befujt_homerseklet_akt1:getValue()/10), true)
      self:getElement('_tx_2_tx_befujt_para'):setValue("value", string.format('%3.1f%%', befujt_para_akt1:getValue()/10), true)
      self:getElement("dp_befujt_tx"):setValue("value", string.format("harmatpont:  %3.1f°C", ah_dp_table1:getValue().dp_befujt), true)
      self:getElement("ah_befujt_tx"):setValue("value", string.format("absolut pára:  %0.3fg/m3", ah_dp_table1:getValue().ah_befujt), true)
      print(event.type, source.id, source.type, det, "p1 - befujt values changed")
      
    elseif source.id == 1 or source.id == 2 or source.id == 19 or source.id == 20 then  -- kamra values
      local kamra_para = kamra_para_v1:getValue()
      local kamra_homerseklet = kamra_homerseklet_v1:getValue()
      
      self:getElement("_3_tx_kamra_homerseklet_"):setValue("value", string.format("%3.1f°C", kamra_homerseklet/10), true)
      self:getElement("_4_tx_kamra_para_"):setValue("value", string.format("%3.1f%%", kamra_para/10), true)
      self:getElement("dp_kamra_tx"):setValue("value", string.format("harmatpont:  %3.1f°C", ah_dp_table1:getValue().dp_kamra), true)
      self:getElement("ah_kamra_tx"):setValue("value", string.format("absolut pára:  %0.3fg/m3", ah_dp_table1:getValue().ah_kamra), true)
      print(event.type, source.id, source.type, det, "p2 - kamra values changed")
      
    elseif source.id == 3 or source.id == 4 then  -- kamra_cel_homerseklet_v1 or kamra_cel_para_v1 changed
      -- BUG FIX: Update sliders to match the NEW variable values (not overwrite with old slider values)
      local celh = kamra_cel_homerseklet_v1:getValue()
      local celp = kamra_cel_para_v1:getValue()

      self:getElement("slider_1"):setValue("value", celh/10, true)
      self:getElement("slider_0"):setValue("value", celp/10, true)

      -- Update dew point and absolute humidity displays
      ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))

      print(event.type, source.id, source.type, det, "p3 - target setpoint changed, sliders updated")
      
    elseif source.id == 7 or source.id == 8 or source.id == 21 or source.id == 22 then  -- kulso values
      self:getElement("_3_tx_kulso_homerseklet_"):setValue("value", string.format("%3.1f°C", kulso_homerseklet_v1:getValue()/10), true)
      self:getElement("_4_tx_kulso_para_"):setValue("value", string.format("%3.1f%%", kulso_para_v1:getValue()/10), true)
      
      local ah_k = calculate_absolute_humidity(kulso_homerseklet_v1:getValue()/10, kulso_para_v1:getValue()/10)
      local dp_k = calc_dew_point(kulso_homerseklet_v1:getValue()/10, kulso_para_v1:getValue()/10)
      ah_dp_table1:setValueByPath("ah_kulso", ah_k, true)
      ah_dp_table1:setValueByPath("dp_kulso", dp_k, true)
      self:getElement("dp_kulso_tx"):setValue("value", string.format("harmatpont: %3.1f°C", dp_k), true)
      self:getElement("ah_kulso_tx"):setValue("value", string.format("absolut pára: %0.3fg/m3", ah_k), true)
      print(event.type, source.id, source.type, det, "p4 - outdoor values changed")
      
    elseif source.id == 34 then  -- signals1 changed - CRITICAL
      print("SIGNAL STATE CHANGED - Reloading control signals from other device")
      -- Re-run control algorithm with updated signals
      self:controlling()
    end

  elseif event.type == 'modbus_client_async_write_response' then
    self:c():onRegisterAsyncWrite(function ()
      self:online()
    end)

  elseif event.type == 'modbus_client_async_request_failure' then
    self:c():onAsyncRequestFailure(function (req, err, kind, addrBase)
      utils:printf('Failed to %s %s: %s', req, kind, err)
      if err == 'TIMEOUT' then
        local befujt_hiba = befujt_hibaszam1:getValue()
        if befujt_hiba > 0 then 
          befujt_hiba = befujt_hiba - 1
          befujt_hibaszam1:setValue(befujt_hiba, true)
        end 
      end
    end)
  end
  
  local source = event.source
  local det = event.details
  print(event.type, source.id, source.type, det)
end

 

function CustomDevice:on_Target_TemperatureChange(newValue, element)
  local temp1 = kamra_cel_homerseklet_v1:getValue()
  if (temp1+19 > newValue*10) and (temp1-19 < newValue*10) then
    -- CRITICAL: User setpoint changes MUST propagate to other devices
    kamra_cel_homerseklet_v1:setValue(newValue*10, false)  -- PROPAGATE
    kamra_cel_homerseklet_v1:save(false)  -- PROPAGATE
    ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))
  else
    self:getElement('slider_1'):setValue('value', temp1/10, true)
  end
end


function CustomDevice:on_Target_HumidityChange(newValue, element)
  local com = self:c()
  print(com)
  local humi1 = kamra_cel_para_v1:getValue()
  if (humi1+19 > newValue*10) and (humi1-19 < newValue*10) then
    -- CRITICAL: User setpoint changes MUST propagate to other devices
    kamra_cel_para_v1:setValue(newValue*10, false)  -- PROPAGATE
    kamra_cel_para_v1:save(false)  -- PROPAGATE
    ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))
  else
    self:getElement('slider_0'):setValue('value', humi1/10)
  end  
end


function CustomDevice:poll()
  local com = self:c()
  com:readInputRegistersAsync(1, 2)
end


function CustomDevice:onXceiver(new)
  self:c():setValue('associations.transceiver', JSON:decode(new))
end

function CustomDevice:onBaudrate(br)
  local com = self:c()
  com:setValue('baud_rate', tonumber(br))
  print(com:getValue 'baud_rate')
end

function CustomDevice:onParity(par)
  self:c():setValue('parity', par)
end

function CustomDevice:onStopbits(sb)
  self:c():setValue('stop_bits', sb)
end

function CustomDevice:onSlaveId(id, ref)
  id = tonumber(id)
  if id == nil then
    id = 1
    ref:setValue('value', '1', true)
  end
  
  self:c():setValue('slave_address', id)
end
