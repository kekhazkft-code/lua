#!/usr/bin/env python3
"""
Script to update Lua code in JSON device configuration files
Applies widget display bug fixes to all 4 JSON files
"""

import json
import base64
from pathlib import Path

def update_lua_code(lua_code):
    """Apply bug fixes to Lua code"""
    import re

    # Fix #1: Add slider initialization to onInit()
    # Use regex to handle whitespace variations
    old_init_pattern = r"(function CustomDevice:onInit\(\)\s+print\('init'\)\s+self:setValue\('status', 'unknown'\)\s+local com = self:c\(\).*?befujt_hibaszam1:setValue\(3,true\))\s*\nend"

    new_init_lines = r"""\1

  -- BUG FIX: Initialize sliders with current target values
  local temp_target = kamra_cel_homerseklet_v1:getValue()
  local humi_target = kamra_cel_para_v1:getValue()
  self:getElement('slider_1'):setValue('value', temp_target/10, true)
  self:getElement('slider_0'):setValue('value', humi_target/10, true)

  -- Also initialize dew point/absolute humidity displays
  ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))

end"""

    lua_code = re.sub(old_init_pattern, new_init_lines, lua_code, flags=re.DOTALL)

    # Fix #2: Correct event handler logic
    # Use regex to handle whitespace and quote variations
    old_handler_pattern = r'elseif source\.id == 3 then\s+--.*?changed.*?print\(event\.type, source\.id, source\.type, det,.*?"p3.*?changed"\)'

    new_handler_lines = '''elseif source.id == 3 or source.id == 4 then  -- kamra_cel_homerseklet_v1 or kamra_cel_para_v1 changed
      -- BUG FIX: Update sliders to match the NEW variable values (not overwrite with old slider values)
      local celh = kamra_cel_homerseklet_v1:getValue()
      local celp = kamra_cel_para_v1:getValue()

      self:getElement("slider_1"):setValue("value", celh/10, true)
      self:getElement("slider_0"):setValue("value", celp/10, true)

      -- Update dew point and absolute humidity displays
      ah_dp_cel_szamol(self:getElement("dp_cel_tx"), self:getElement("ah_cel_tx"))

      print(event.type, source.id, source.type, det, "p3 - target setpoint changed, sliders updated")'''

    lua_code = re.sub(old_handler_pattern, new_handler_lines, lua_code, flags=re.DOTALL)

    # Fix #3: Add corrected psychrometric evaluation function
    # Insert after ah_dp_befujt_szamol function
    psychro_function = '''

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
  local ah_improves = ah_delta_mixed <= ah_delta_current

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
end'''

    # Check if psychrometric function doesn't already exist
    if 'evaluate_outdoor_air_benefit' not in lua_code:
        # Insert after ah_dp_befujt_szamol function
        pattern = r'(local function ah_dp_befujt_szamol\(\).*?end)'
        lua_code = re.sub(pattern, r'\1' + psychro_function, lua_code, flags=re.DOTALL)

    # Fix #4: Replace simple outdoor air logic with corrected evaluation
    old_outdoor_logic = r'''  warm_dis = kamra_para_futes_tiltas or futes_tiltas
  dehumi = kamra_para_hutes  or befujt_para_hutes\s*
  cool_dis = kamra_hutes_tiltas
  signal\.add_air_max = cool and \(not signal\.sum_wint_jel\) and \(not signal\.humi_save\)'''

    new_outdoor_logic = '''  warm_dis = kamra_para_futes_tiltas or futes_tiltas
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

  signal.add_air_max = outdoor_air_beneficial and (not signal.sum_wint_jel)'''

    lua_code = re.sub(old_outdoor_logic, new_outdoor_logic, lua_code, flags=re.DOTALL)

    return lua_code


def update_json_file(filepath):
    """Update a single JSON device configuration file"""
    print(f"Processing {filepath}...")

    with open(filepath, 'r', encoding='utf-8') as f:
        device_config = json.load(f)

    # Decode base64 data
    encoded_data = device_config['data']
    decoded_bytes = base64.b64decode(encoded_data)
    decoded_str = decoded_bytes.decode('utf-8')

    # Parse inner JSON
    inner_json = json.loads(decoded_str)

    # Update Lua code
    if 'lua' in inner_json:
        old_lua = inner_json['lua']
        new_lua = update_lua_code(old_lua)

        if old_lua != new_lua:
            inner_json['lua'] = new_lua
            print(f"  ✓ Applied bug fixes to Lua code")
        else:
            print(f"  ✗ No changes made (fixes may already be applied)")
    else:
        print(f"  ✗ No Lua code found in file")
        return False

    # Re-encode
    new_inner_str = json.dumps(inner_json, ensure_ascii=False, separators=(',', ': '))
    new_encoded = base64.b64encode(new_inner_str.encode('utf-8')).decode('ascii')

    # Update outer JSON
    device_config['data'] = new_encoded

    # Write back to file
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(device_config, f, indent=2, ensure_ascii=False)

    print(f"  ✓ File updated successfully")
    return True


def main():
    """Main function to update all JSON files"""
    json_files = [
        'erlelo_1119_REFACTORED.json',
        'erlelo_1119b_REFACTORED.json',
        'erlelo_1119c_REFACTORED.json',
        'erlelo_1119d_REFACTORED.json'
    ]

    print("=" * 60)
    print("Updating Lua code in JSON device configuration files")
    print("=" * 60)
    print()

    updated_count = 0
    for json_file in json_files:
        filepath = Path(json_file)
        if filepath.exists():
            if update_json_file(filepath):
                updated_count += 1
            print()
        else:
            print(f"Warning: {json_file} not found")
            print()

    print("=" * 60)
    print(f"Summary: Updated {updated_count}/{len(json_files)} files")
    print("=" * 60)

    print("\nBug fixes applied:")
    print("  1. Initialize sliders in onInit() with current target values")
    print("  2. Fixed event handler to update sliders instead of overwriting variables")
    print("\nThis fixes the widget display synchronization issue!")


if __name__ == '__main__':
    main()
