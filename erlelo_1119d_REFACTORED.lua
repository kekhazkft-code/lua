--kamra pára és szimulált értékek modulja

local txt = {
  yes = '☑',
  no = '☐',
}
local kamra_homerseklet_v1 = variable[1]
local kamra_para_v1 = variable[2]
local befujt_cel_homerseklet_v1 = variable[5]
local befujt_cel_para_v1 = variable[6]
local kulso_homerseklet_v1 = variable[7]
local kulso_para_v1 = variable[8]
local befujt_para_akt1 = variable[24]
local befujt_homerseklet_akt1 = variable[23]
local kulso_szimulalt_ertekek_v1 = variable[9]
local kamra_homerseklet_table1 = variable[19]
local kamra_para_table1 = variable[20]
local kamra_hibaszam1 = variable[30]
local kamra_switch = false
local befujt_szimulalt1 = variable[25]
local befujt_flag=befujt_szimulalt1:getValue()

local ah_dp_table1 = variable[42]	--***


function CustomDevice:c()
  return self:getComponent('com')
end

function CustomDevice:onInit()
  print('init')
  self:setValue('status', 'unknown')
  kulso_szimulalt_ertekek_v1:setValue(false,true)
  --** _2_tx_befujt_relativ_para) = false
  kamra_switch = false
  local com = self:c()
  self:getElement('baudrate'):setValue('value', tostring(com:getValue('baud_rate')), true)
  self:getElement('parity'):setValue('value', com:getValue('parity'), true)
  self:getElement('stopbits'):setValue('value', com:getValue('stop_bits'), true)
  self:getElement('slave_id'):setValue('value', tostring(com:getValue('slave_address')), true)
  
  local xceiver = com:getValue('associations.transceiver')
  self:getElement('xceiver'):setValue('associations.selected', xceiver, true)
  kamra_hibaszam1:setValue(3,true)
end

                         --- reg érték ---



                            --- Reg olv ---


function CustomDevice:online()

  if self:getValue('status') ~= 'online' then
    self:setValue('status', 'online')
  --  self:emptyStats()
    self:poll()
  end
  kamra_hibaszam1:setValue(3,true)
end

function CustomDevice:offline()
  if self:getValue('status') ~= 'offline' then
    self:setValue('status', 'offline')
  --  self:emptyStats()
    self:clear()
  end
end

local SPRINTF = string.format



-- mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call "_back = false", simulate) --!!

local function mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call, simulate)--!!

  local instab = {}
  for ind, value in pairs(tablazat:getValue({})) do
    table.insert(instab,value)
  end  table.insert(instab,akt_meres)        
  if #instab > mertdb then
    table.remove(instab,1)
  end
  local sum = 0
  for _, value in ipairs(instab) do
    sum = sum + value
  end
  tablazat:setValue(instab, kiir_call)	--!!
  if not simulate then  atlag_ertek:setValue( (sum /#instab)+0.5,true)
  end
end

--harmatpont és abszolut páratartalom

-- Constants
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
  if rh <= 0 or rh > 100 then
    return nil, "Invalid humidity"
  end

  local a = 17.62
  local b = 243.12

  local gamma = (a * temp) / (b + temp) + math.log(rh / 100)
  local dew_point = (b * gamma) / (a - gamma)

  return dew_point
end

-- Példa használat
local T = 25.0          -- hőmérséklet Celsius
local RH = 60.0         -- relatív páratartalom százalékban

local dp, err = calc_dew_point(T, RH)
if dp then
  print(string.format("Harmatpont: %.2f °C", dp))
else
  print("Hiba:", err)
end


-- frissítés 5000 msec - 5 sec
function CustomDevice:onEvent(event)
local timerState = self:getComponent("timer"):getState() 
  if dateTime:changed() or (timerState == "elapsed" or timerState == "off") then
    
    self:poll()

    self:getComponent("timer"):start(5000)
    
  elseif event.type == 'modbus_client_async_read_response' then
    
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
          local var1= value(1)
          local var2= value(2)
          -- mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call "_back = false", simulate) --!!
              mozgoatlag(kamra_homerseklet_table1,var1,kamra_homerseklet_v1, 5, true, kamra_switch)
		          mozgoatlag(kamra_para_table1,var2,kamra_para_v1, 5, false, kamra_switch)
          --// AH és harmatpont
          self:kamra_ah_dp()
          self:getElement('_1_tx_befujt_homerseklet_'):setValue("value", string.format("%3.1f°C", befujt_cel_homerseklet_v1:getValue()/10),true)
          self:getElement('_2_tx_befujt_relativ_para'):setValue("value", string.format("%3.1f%%", befujt_cel_para_v1:getValue()/10),true)
          self:getElement("dp_celbefujt_tx"):setValue("value", string.format("harmatpont:  %3.1f°C", ah_dp_table1:getValue().dp_befujt_cel),true)
          self:getElement("ah_celbefujt_tx"):setValue("value", string.format("absolut pára:  %0.3fg/m3", ah_dp_table1:getValue().ah_befujt_cel),true)

          self:getElement("txt_kamra_hom_szimul"):setValue("value", string.format("%3.1f°C", kamra_homerseklet_v1:getValue()/10),true)
          self:getElement("txt_kamra_para_szimul"):setValue("value", string.format("%3.1f%%", kamra_para_v1:getValue()/10),true)
          self:getElement("text2_outside_temp"):setValue("value", string.format("%3.1f°C", kulso_homerseklet_v1:getValue()/10),true)
          self:getElement("text1_outside_humidity"):setValue("value", string.format("%3.1f%%", kulso_para_v1:getValue()/10),true)

        
        end
      end
    end)

  elseif event.type == 'modbus_client_async_write_response' then

    self:c():onRegisterAsyncWrite(function ()
      self:online()
    end)

  elseif event.type == 'modbus_client_async_request_failure' then
       
    self:c():onAsyncRequestFailure(function (req, err, kind, addrBase)
      utils:printf('Failed to %s %s: %s', req, kind, err)
      if err == 'TIMEOUT' then
      local kamra_hiba= kamra_hibaszam1:getValue()
        if kamra_hiba > 0 then kamra_hiba = kamra_hiba-1
        kamra_hibaszam1:setValue(kamra_hiba,true)
        end
        --self:offline()
      end
    end)
    
  end
    local source = event.source
  local det = event.details
  print (event.type, source.id, source.type,det,variable[18]:changed())
end

  --külső hőmérséklet szimulált
 function CustomDevice:on_Outside_TemperatureChange (newValue, element)
  if kulso_szimulalt_ertekek_v1:getValue() then
   kulso_homerseklet_v1:setValue( newValue*10,false)
    self:kulso_ah_dp()
  end
    self:getElement("text2_outside_temp"):setValue("value", string.format("%3.1f°C", kulso_homerseklet_v1:getValue()/10),true)
 end

  --külső pára szimulált
function CustomDevice:on_Outside_HumidityChange (newValue, element)
  if kulso_szimulalt_ertekek_v1:getValue() then
  kulso_para_v1:setValue( newValue*10,false)
  self:kulso_ah_dp()
  end
    self:getElement("text1_outside_humidity"):setValue("value", string.format("%3.1f%%", kulso_para_v1:getValue()/10),true)
  
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


function CustomDevice:onKulsoSwitcherValueChanged (newValue, element)
  kulso_szimulalt_ertekek_v1:setValue(newValue,true) 
    if kulso_szimulalt_ertekek_v1:getValue() then
  local temp1= kulso_homerseklet_v1:getValue()/10
  local humi1= kulso_para_v1:getValue()/10
  self:kulso_ah_dp()
  self:getElement('slider_1'):setValue('value',temp1,true )
  self:getElement("text2_outside_temp"):setValue("value", string.format("%3.1f°C", temp1),true)

  self:getElement('slider_0'):setValue('value',humi1 ,true)
  self:getElement("text1_outside_humidity"):setValue("value", string.format("%3.1f%%", humi1),true)


  end

end



function CustomDevice:onKamra_hom_szimul_ValueChanged (newValue, element)
--*******
local com = self:c()
print(com)

 if kamra_switch then
   kamra_homerseklet_v1:setValue( newValue*10,false)
  end
    self:kamra_ah_dp()
    self:getElement("txt_kamra_hom_szimul"):setValue("value", string.format("%3.1f°C", kamra_homerseklet_v1:getValue()/10),true)
end

function CustomDevice:onKamra_para_szimul_ValueChanged (newValue, element)
 --******
-- print(system_modul[3])
 if kamra_switch then
   kamra_para_v1:setValue( newValue*10,false)
  end
    self:kamra_ah_dp()
    self:getElement("txt_kamra_para_szimul"):setValue("value", string.format("%3.1f%%", kamra_para_v1:getValue()/10),true)

end

function CustomDevice:onKamra_szimulSwitcherValueChanged (newValue, element)
  kamra_switch = newValue
  if kamra_switch then
  local temp1= kamra_homerseklet_v1:getValue()/10
  local humi1= kamra_para_v1:getValue()/10
 -- print(temp1,humi1)
  self:getElement('kamra_hom_szimul'):setValue('value',temp1,true )
  self:getElement("txt_kamra_hom_szimul"):setValue("value", string.format("%3.1f°C", temp1),true)

  self:getElement('kamra_para_szimul'):setValue('value',humi1 )
  self:getElement("txt_kamra_para_szimul"):setValue("value", string.format("%3.1f%%", humi1),true)
  end
  self:kamra_ah_dp()
end

--befujt_hom_slider
function CustomDevice:on_befujt_hom_change (newValue, element)
    if befujt_szimulalt1:getValue() then
    befujt_homerseklet_akt1:setValue(newValue*10, false)
    self:befujt_ah_dp()
    end

end

--befujt_para_slider
function CustomDevice:on_befujt_para_change (newValue, element)
    if befujt_szimulalt1:getValue() then
    befujt_para_akt1:setValue(newValue*10, false)
    self:befujt_ah_dp()
    end 

end


--befujt_switcher
function CustomDevice:on_befujt_switcher_change (newValue, element)
    
 befujt_szimulalt1:setValue(newValue,true)
 
 --print(befujt_szimulalt1:getValue(), variable[25])
  if befujt_szimulalt1:getValue() then
  local temp1= befujt_homerseklet_akt1:getValue()
  local humi1= befujt_para_akt1:getValue()

  self:getElement('befujt_hom_slider'):setValue('value',temp1/10,true )
  --self:getElement("temperature_text"):setValue("value", string.format("%3.1f°C", temp1/10),true)

  self:getElement('befujt_para_slider'):setValue('value',humi1/10,true )
  --self:getElement("text_3_humi"):setValue("value", string.format("%3.1f%%", humi1/10),true)
  end
  self:befujt_ah_dp()
end

function CustomDevice:befujt_ah_dp()
          local rh = befujt_para_akt1:getValue()/10
          local temp = befujt_homerseklet_akt1:getValue()/10
          local dp, err = calc_dew_point(temp, rh)
          local ah =calculate_absolute_humidity (temp, rh)
          ah_dp_table1:setValueByPath("dp_befujt",dp,true)
          ah_dp_table1:setValueByPath("ah_befujt",ah,true)  
end

function CustomDevice:kamra_ah_dp()
          local rh_kamra = kamra_para_v1:getValue()/10
          local temp_kamra = kamra_homerseklet_v1:getValue()/10
          local dp_kamra, err = calc_dew_point(temp_kamra, rh_kamra)
          local ah_kamra =calculate_absolute_humidity (temp_kamra, rh_kamra)
          ah_dp_table1:setValueByPath("dp_kamra",dp_kamra,true)
          ah_dp_table1:setValueByPath("ah_kamra",ah_kamra,true)  
end

function CustomDevice:kulso_ah_dp()
          local rh = kulso_para_v1:getValue()/10
          local temp = kulso_homerseklet_v1:getValue()/10
          local dp, err = calc_dew_point(temp, rh)
          local ah =calculate_absolute_humidity (temp, rh)
          ah_dp_table1:setValueByPath("dp_kulso",dp,true)
          ah_dp_table1:setValueByPath("ah_kulso",ah,true)
end
