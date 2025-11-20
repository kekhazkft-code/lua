-- APAR4.1

-- ZP 2024.09.23 --
local txt = {
  yes = '☑',
  no = '☐',
}


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
            local ah_dp_table1 = variable[42]

            local mert_sulyok_table1 = variable[39]
            local suly_meres_table1 = variable[40]
            local atlagsuly_mv1 = variable[41]
            local mert_sulyok2_table1 = variable[43]
            local suly_meres2_table1 = variable[44]
            local atlagsuly2_mv1 = variable[45] 


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
  kulso_hibaszam1:setValue(3)
end

                         --- reg érték ---



                            --- Reg olv ---


function CustomDevice:online()

  if self:getValue('status') ~= 'online' then
 
    self:setValue('status', 'online')
    self:emptyStats()
    self:poll()
  end
  kulso_hibaszam1:setValue(3,true)
end

function CustomDevice:offline()
  if self:getValue('status') ~= 'offline' then
    self:setValue('status', 'offline')
    self:emptyStats()
    self:clear()
  end
end

local function statpush(value, stats)
  if stats then
    if type(value) == 'boolean' then
      value = value and 1 or 0
    end
    statistics:addPoint(stats.name, value * stats.mul, stats.unit)
  end
end

local SPRINTF = string.format


function CustomDevice:updateText(text_id, format, value --[[, stats]])
  local text = (
    type(value) ~= 'boolean'
    and SPRINTF(format, value)
    or (value and txt.yes or txt.no)
  )
  self:getElement(text_id):setValue('value', text, true)
 -- statpush(value, stats)
end
-- mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call "_back = false", simulate) --!!

  --átlagérték képzése és tárolása átlagérték változóban ha 'simulate' == false
local function mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call, simulate)

  local instab = {}
  -- átlagolás 5 mérés      
  for ind, value in pairs(tablazat:getValue({})) do
    table.insert(instab,value)
  end
  table.insert(instab,akt_meres)        
  if #instab > mertdb then
    table.remove(instab,1)
  end
  local sum = 0
  for _, value in ipairs(instab) do
    sum = sum + value
  end
  tablazat:setValue(instab,kiir_call)
  if not simulate then atlag_ertek:setValue( (sum /#instab)+0.5,true)
  end
end

--frissítés 5000 msec - 5 sec

function CustomDevice:onEvent(event)
--local profiler1 = utils:profiler()
--profiler1:start()

local timerState = self:getComponent("timer"):getState() 
  if --[[dateTime:changed() or]] (timerState == "elapsed" or timerState == "off") then
   -- print(self:getComponent("timer"):getState())
    
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
          --átlagérték képzése külső hőmérséklet és pára
          -- mozgoatlag(tablazat, akt_meres, atlag_ertek, mertdb, kiir_call "_back = false", simulate) --!!         
          mozgoatlag(kulso_homerseklet_table1,var1,kulso_homerseklet_v1, 5, true, kulso_szimulalt_ertekek_v1:getValue())
          mozgoatlag(kulso_para_table1,var2,kulso_para_v1, 5, false, kulso_szimulalt_ertekek_v1:getValue())  
 
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
        local   kulso_hiba = kulso_hibaszam1:getValue()
        if kulso_hiba > 0 then kulso_hiba = kulso_hiba-1
        kulso_hibaszam1:setValue(kulso_hiba,true)
        end
        --self:offline()
      end
    end)

  elseif dateTime:changed() then
    self:pushStats()

  end 
        --  profiler1:stop()
        --  profiler1:print()
--  local source = event.source
--  print (event.type, source.id, source.type)
end



function CustomDevice:poll()
  local com = self:c()

  com:readInputRegistersAsync(1, 2)
end


function CustomDevice:clear()
  local e = { 
    '_3_tx_kulso_homerseklet_', '_4_tx_kulso_para_', 
  }
  for i = 1, #e do
    self:getElement(e[i]):setValue('value', 'N/A', true)
  end
end


function CustomDevice:emptyStats()
  local e = {
    ['Befujt_Mert_homerseklet_'] = unit.celsius,
    ['Befujt_Mert_para_'] = unit.percent,
    ['Befujt_Cel_homerseklet_'] = unit.celsius,
    ['Befujt_cel_para_'] = unit.percent,
    ['Kamra_Mert_homerseklet_'] = unit.celsius,
    ['Kamra_Mert_para_'] = unit.percent,
    ['Kamra_Cel_homerseklet_'] = unit.celsius,
    ['Kamra_Cel_para_'] = unit.percent,
    ['Kulso_Mert_homerseklet_'] = unit.celsius, 
    ['Kulso_Mert_para_'] = unit.percent,
  }
  for name, unit in pairs(e) do
    statistics:addPoint(name, -1, unit)
  end
end

function CustomDevice:pushStats()
    
    statistics:addPoint('Befujt_Mert_homerseklet_', befujt_homerseklet_akt1:getValue(), unit.celsius_x10)
    statistics:addPoint('Befujt_Mert_para_', befujt_para_akt1:getValue(), unit.percent_x10)
    statistics:addPoint('Befujt_Cel_homerseklet_', befujt_cel_homerseklet_v1:getValue() , unit.celsius_x10)
    statistics:addPoint('Befujt_Cel_para_', befujt_cel_para_v1:getValue(), unit.percent_x10) 
    statistics:addPoint('Kamra_Mert_homerseklet_', kamra_homerseklet_v1:getValue(), unit.celsius_x10)
    statistics:addPoint('Kamra_Mert_para_', kamra_para_v1:getValue(), unit.percent_x10)
    statistics:addPoint('Kamra_Cel_homerseklet_', kamra_cel_homerseklet_v1:getValue(), unit.celsius_x10)
    statistics:addPoint('Kamra_Cel_para_', kamra_cel_para_v1:getValue(), unit.percent_x10)
    statistics:addPoint('Kulso_Mert_homerseklet_', kulso_homerseklet_v1:getValue(), unit.celsius_x10)
    statistics:addPoint('Kulso_Mert_para_', kulso_para_v1:getValue(), unit.percent_x10)
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









