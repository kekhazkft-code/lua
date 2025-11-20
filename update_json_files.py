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
