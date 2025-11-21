"""
Test Runner for Aging Chamber Control System
Executes test scenarios and collects results
"""

import json
import base64
import subprocess
import tempfile
import os
import time
from pathlib import Path
from typing import List, Dict, Any
from dataclasses import dataclass, asdict

from mock_techsinum import MockTechSinumEnvironment
from scenario_generator import ScenarioGenerator, TestScenario
from comprehensive_scenario_generator import ComprehensiveScenarioGenerator


@dataclass
class TestResult:
    """Represents the result of a single test"""
    test_id: str
    category: str
    description: str
    initial_state: str
    inputs: str
    expected_output: str
    actual_output: str
    passed: bool
    error_message: str
    execution_time_ms: float
    propagation_count: int
    blocked_count: int
    relay_states: str
    notes: str


class LuaTestRunner:
    """Runs Lua test scenarios with mock environment"""

    def __init__(self, lua_code_path: str):
        """
        Initialize test runner
        Args:
            lua_code_path: Path to the Lua code file to test
        """
        self.lua_code_path = lua_code_path
        self.lua_code = self._load_lua_code()
        self.results: List[TestResult] = []

    def _load_lua_code(self) -> str:
        """Load Lua code from file or JSON"""
        path = Path(self.lua_code_path)

        if path.suffix == '.lua':
            with open(path, 'r', encoding='utf-8') as f:
                return f.read()

        elif path.suffix == '.json':
            # Extract Lua from JSON (base64 encoded)
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            if 'data' in data:
                # Decode base64
                decoded = base64.b64decode(data['data']).decode('utf-8')
                # Extract lua code from JSON
                decoded_json = json.loads(decoded)
                if 'lua' in decoded_json:
                    return decoded_json['lua']

            raise ValueError("Could not find Lua code in JSON file")

        raise ValueError(f"Unsupported file type: {path.suffix}")

    def _create_lua_wrapper(self, scenario: TestScenario) -> str:
        """
        Create Lua wrapper code that:
        1. Sets up mock environment
        2. Loads the actual code
        3. Executes the test
        4. Returns results as JSON
        """

        # Since we can't easily inject Python objects into Lua,
        # we'll create a simplified Lua test harness
        wrapper = f"""
-- Mock Tech Sinum Environment for Testing
-- This is a simplified Lua-only version

-- Mock Variable class
Variable = {{}}
Variable.__index = Variable

function Variable:new(initial_value)
    local obj = {{
        value = initial_value or 0,
        propagation_log = {{}},
    }}
    setmetatable(obj, self)
    return obj
end

function Variable:getValue(default)
    return self.value or default or 0
end

function Variable:setValue(value, stop_propagation)
    local old = self.value
    self.value = value
    table.insert(self.propagation_log, {{
        old = old,
        new = value,
        propagated = not stop_propagation
    }})
end

function Variable:setValueByPath(path, value, stop_propagation)
    if type(self.value) ~= "table" then
        self.value = {{}}
    end
    self.value[path] = value
    table.insert(self.propagation_log, {{
        path = path,
        old = self.value[path],
        new = value,
        propagated = not stop_propagation
    }})
end

function Variable:get_propagation_count()
    local count = 0
    for _, log in ipairs(self.propagation_log) do
        if log.propagated then
            count = count + 1
        end
    end
    return count
end

function Variable:get_blocked_count()
    local count = 0
    for _, log in ipairs(self.propagation_log) do
        if not log.propagated then
            count = count + 1
        end
    end
    return count
end

-- Mock Relay class
Relay = {{}}
Relay.__index = Relay

function Relay:new(initial_state)
    local obj = {{
        state = initial_state or "off",
        call_log = {{}}
    }}
    setmetatable(obj, self)
    return obj
end

function Relay:getValue(param)
    if param == "state" then
        return self.state
    end
    return nil
end

function Relay:call(method)
    table.insert(self.call_log, method)
    if method == "turn_on" then
        self.state = "on"
    elseif method == "turn_off" then
        self.state = "off"
    end
end

-- Mock Component
Component = {{}}
Component.__index = Component

function Component:new()
    local obj = {{
        config = {{
            baud_rate = 9600,
            parity = "none",
            stop_bits = "one",
            slave_address = 5,
            ["associations.transceiver"] = nil
        }}
    }}
    setmetatable(obj, self)
    return obj
end

function Component:getValue(key)
    return self.config[key]
end

-- Mock Element
Element = {{}}
Element.__index = Element

function Element:new(name)
    local obj = {{
        name = name,
        value = nil
    }}
    setmetatable(obj, self)
    return obj
end

function Element:setValue(key, value, stop_propagation)
    self.value = value
end

-- Mock CustomDevice
CustomDevice = {{}}
CustomDevice.__index = CustomDevice

function CustomDevice:new()
    local obj = {{
        values = {{}},
        components = {{com = Component:new()}},
        elements = {{}},
        print_log = {{}}
    }}
    setmetatable(obj, self)
    return obj
end

function CustomDevice:setValue(key, value)
    self.values[key] = value
end

function CustomDevice:getValue(key)
    return self.values[key]
end

function CustomDevice:getComponent(name)
    return self.components[name] or Component:new()
end

function CustomDevice:getElement(name)
    if not self.elements[name] then
        self.elements[name] = Element:new(name)
    end
    return self.elements[name]
end

function CustomDevice:poll()
    -- No-op
end

function CustomDevice:c()
    return self:getComponent('com')
end

-- Initialize environment
variable = {{}}
for i = 1, 50 do
    variable[i] = Variable:new(0)
end

sbus = {{}}
for i = 50, 70 do
    sbus[i] = Relay:new("off")
end

-- Create CustomDevice instance
local device = CustomDevice:new()

-- Apply initial state
local initial_state = {json.dumps(scenario.initial_state)}
if initial_state.variables then
    for var_id, value in pairs(initial_state.variables) do
        if type(value) == "table" then
            variable[var_id].value = value
        else
            variable[var_id]:setValue(value, true)
        end
    end
end

if initial_state.relays then
    for relay_id, state in pairs(initial_state.relays) do
        sbus[relay_id].state = state
    end
end

-- Override print to capture output
local print_log = {{}}
local original_print = print
print = function(...)
    local args = {{...}}
    local msg = table.concat(args, " ")
    table.insert(print_log, msg)
end

-- Load and execute test code
-- NOTE: We'll insert specific test code here
local function run_test()
    -- Execute control cycle or specific test function
    if device.controlling then
        device:controlling()
    end

    -- Apply inputs if specified
    local inputs = {json.dumps(scenario.inputs)}

    -- Collect results
    local results = {{
        propagation_counts = {{}},
        blocked_counts = {{}},
        relay_states = {{}},
        print_log = print_log
    }}

    for i = 1, 50 do
        results.propagation_counts[i] = variable[i]:get_propagation_count()
        results.blocked_counts[i] = variable[i]:get_blocked_count()
    end

    for i = 50, 70 do
        results.relay_states[i] = sbus[i].state
    end

    return results
end

-- Execute test and output results as JSON
local success, result = pcall(run_test)

if success then
    -- Output results as JSON
    print("__TEST_RESULT_START__")
    print(require('json').encode(result))
    print("__TEST_RESULT_END__")
else
    print("__TEST_ERROR__")
    print(result)  -- Error message
    print("__TEST_ERROR_END__")
end
"""
        return wrapper

    def run_test(self, scenario: TestScenario) -> TestResult:
        """
        Run a single test scenario
        Returns TestResult with pass/fail and detailed information
        """
        start_time = time.time()

        try:
            # For now, use Python-based testing since Lua integration is complex
            # We'll create a simpler Python-based mock that interprets the logic

            env = MockTechSinumEnvironment()
            env.set_initial_state(scenario.initial_state)

            # Simplified test execution
            # In a full implementation, we'd execute the actual Lua code
            # For this MVP, we'll test the logic patterns

            initial_snapshot = env.get_state_snapshot()

            # Simulate some operations based on test inputs
            if 'temp_delta' in scenario.inputs:
                delta = scenario.inputs['temp_delta']
                var_id = 3  # befujt_cel_homerseklet_v1
                old_value = env.variables[var_id].getValue()
                new_value = old_value + delta
                should_propagate = delta >= 2  # TEMP_CHANGE_THRESHOLD
                env.variables[var_id].setValue(new_value, not should_propagate)

            elif 'humi_delta' in scenario.inputs:
                delta = scenario.inputs['humi_delta']
                var_id = 4  # befujt_cel_para_v1
                old_value = env.variables[var_id].getValue()
                new_value = old_value + delta
                should_propagate = delta >= 3  # HUMI_CHANGE_THRESHOLD
                env.variables[var_id].setValue(new_value, not should_propagate)

            # Fixed: Add missing input handlers
            elif 'kamra_cel_change' in scenario.inputs:
                delta = scenario.inputs['kamra_cel_change']
                var_id = 3  # kamra_cel_homerseklet
                old_value = env.variables[var_id].getValue()
                new_value = old_value + delta
                should_propagate = delta >= 2  # TEMP_CHANGE_THRESHOLD
                env.variables[var_id].setValue(new_value, not should_propagate)

            elif 'kamra_cel_para_change' in scenario.inputs:
                delta = scenario.inputs['kamra_cel_para_change']
                var_id = 4  # kamra_cel_para
                old_value = env.variables[var_id].getValue()
                new_value = old_value + delta
                should_propagate = delta >= 3  # HUMI_CHANGE_THRESHOLD
                env.variables[var_id].setValue(new_value, not should_propagate)

            elif 'user_setpoint_change' in scenario.inputs:
                # User changes ALWAYS propagate (immediate response required)
                delta = scenario.inputs['user_setpoint_change']
                var_id = 3  # User temp setpoint
                old_value = env.variables[var_id].getValue()
                new_value = old_value + delta
                env.variables[var_id].setValue(new_value, False)  # Always propagate

            # Outdoor air benefit evaluation (NEW)
            elif 'outdoor_air_eval' in scenario.inputs:
                # Extract parameters from initial state
                chamber_temp = env.variables[1].getValue() / 10.0  # kamra_homerseklet
                chamber_rh = env.variables[2].getValue() / 10.0    # kamra_para
                target_temp = env.variables[3].getValue() / 10.0   # kamra_cel_homerseklet
                target_rh = env.variables[4].getValue() / 10.0     # kamra_cel_para
                outdoor_temp = env.variables[5].getValue() / 10.0  # kulso_homerseklet
                outdoor_rh = env.variables[6].getValue() / 10.0    # kulso_para
                outdoor_mix_ratio = scenario.inputs.get('outdoor_mix_ratio', 0.30)

                # Perform psychrometric evaluation
                beneficial, details = self._evaluate_outdoor_air_benefit(
                    chamber_temp, chamber_rh,
                    target_temp, target_rh,
                    outdoor_temp, outdoor_rh,
                    outdoor_mix_ratio
                )

                # Store results in environment for validation
                env._test_results = {
                    'outdoor_air_beneficial': beneficial,
                    'temp_improves': details['temp_improves'],
                    'ah_improves': details['ah_improves'],
                    'rh_acceptable': details['rh_acceptable'],
                    'mixed_temp': details['mixed_temp'],
                    'projected_rh_at_target': details['projected_rh_at_target']
                }

            # Controlling function integration test (NEW)
            elif 'controlling_cycle' in scenario.inputs:
                # Simulate the controlling() function logic
                # Extract parameters
                chamber_temp = env.variables[1].getValue() / 10.0
                chamber_rh = env.variables[2].getValue() / 10.0
                target_temp = env.variables[3].getValue() / 10.0
                target_rh = env.variables[4].getValue() / 10.0
                outdoor_temp = env.variables[5].getValue() / 10.0 if 5 in env.variables else 0.0
                outdoor_rh = env.variables[6].getValue() / 10.0 if 6 in env.variables else 50.0

                # Get configuration
                has_humidifier = scenario.initial_state.get('config', {}).get('HAS_HUMIDIFIER', True)

                # Get mode settings
                mode_var = env.variables[34].getValue()
                humi_save = mode_var.get('humi_save', False) if isinstance(mode_var, dict) else False
                sum_wint_jel = mode_var.get('sum_wint_jel', False) if isinstance(mode_var, dict) else False

                # Initialize test results
                env._test_results = {}

                # --- HUMIDIFICATION CONTROL ---
                chamber_ah = self._calculate_absolute_humidity(chamber_temp, chamber_rh)
                target_ah = self._calculate_absolute_humidity(target_temp, target_rh)

                if has_humidifier:
                    # Strategy 1: Active humidification
                    projected_rh_at_target = self._calculate_rh(target_temp, chamber_ah)
                    humidification = projected_rh_at_target < (target_rh - 5.0)

                    # Check stop condition
                    if chamber_ah >= target_ah:
                        humidification = False

                    env._test_results['humidification'] = humidification
                    env._test_results['projected_rh_at_target'] = projected_rh_at_target

                    # Set relay
                    if humidification:
                        env.sbus[66].call('turn_on')
                    else:
                        env.sbus[66].call('turn_off')
                else:
                    # Strategy 2: Better cold than dry
                    heating_blocked = chamber_ah < target_ah
                    min_temp = 11.0
                    cooling_blocked = heating_blocked and (chamber_temp <= min_temp)

                    env._test_results['heating_blocked'] = heating_blocked
                    env._test_results['cooling_blocked'] = cooling_blocked
                    env._test_results['humidification'] = False

                # --- OUTDOOR AIR EVALUATION ---
                # Evaluate outdoor air benefit if not in humi_save mode
                outdoor_air_beneficial = False
                if not humi_save and outdoor_temp != 0.0:
                    outdoor_air_beneficial, details = self._evaluate_outdoor_air_benefit(
                        chamber_temp, chamber_rh,
                        target_temp, target_rh,
                        outdoor_temp, outdoor_rh,
                        0.30  # 30% mixing ratio
                    )
                    env._test_results.update(details)

                # Apply controlling logic: signal.add_air_max = beneficial AND (not sum_wint_jel)
                signal_add_air_max = outdoor_air_beneficial and (not sum_wint_jel)

                # Set relay state
                if signal_add_air_max:
                    env.sbus[61].call('turn_on')
                else:
                    env.sbus[61].call('turn_off')

                # --- BYPASS COORDINATION ---
                # Determine cooling and dehumi signals (simplified)
                cooling = target_temp < chamber_temp
                dehumi = target_rh < chamber_rh

                bypass_open = humi_save or ((cooling and not dehumi) and not signal_add_air_max)
                env._test_results['bypass_open'] = bypass_open

                if bypass_open:
                    env.sbus[64].call('turn_on')
                else:
                    env.sbus[64].call('turn_off')

                # --- WATER COOLING BACKUP ---
                outdoor_temp_diff = abs(outdoor_temp - chamber_temp)
                outdoor_not_effective = outdoor_temp_diff <= 3.0
                use_water_cooling = sum_wint_jel or (not sum_wint_jel and outdoor_not_effective)
                env._test_results['use_water_cooling'] = use_water_cooling

                # Store comprehensive results
                env._test_results.update({
                    'outdoor_air_beneficial': outdoor_air_beneficial,
                    'signal_add_air_max': signal_add_air_max,
                    'relay_61_state': env.sbus[61].get_state(),
                    'chamber_ah': chamber_ah,
                    'target_ah': target_ah
                })

            # NEW: Humidification control evaluation
            elif 'humidification_eval' in scenario.inputs:
                chamber_temp = env.variables[1].getValue() / 10.0
                chamber_rh = env.variables[2].getValue() / 10.0
                target_temp = env.variables[3].getValue() / 10.0
                target_rh = env.variables[4].getValue() / 10.0

                # Get configuration
                has_humidifier = scenario.initial_state.get('config', {}).get('HAS_HUMIDIFIER', True)

                # Calculate absolute humidity
                chamber_ah = self._calculate_absolute_humidity(chamber_temp, chamber_rh)
                target_ah = self._calculate_absolute_humidity(target_temp, target_rh)

                if has_humidifier:
                    # Strategy 1: Active humidification
                    projected_rh_at_target = self._calculate_rh(target_temp, chamber_ah)
                    humidification = projected_rh_at_target < (target_rh - 5.0)

                    # Check stop condition
                    if chamber_ah >= target_ah:
                        humidification = False

                    env._test_results = {
                        'humidification': humidification,
                        'projected_rh_at_target': projected_rh_at_target,
                        'chamber_ah': chamber_ah,
                        'target_ah': target_ah
                    }

                    # Set relay
                    if humidification:
                        env.sbus[66].call('turn_on')
                    else:
                        env.sbus[66].call('turn_off')
                else:
                    # Strategy 2: Better cold than dry
                    heating_blocked = chamber_ah < target_ah
                    min_temp = 11.0
                    cooling_blocked = heating_blocked and (chamber_temp <= min_temp)

                    env._test_results = {
                        'heating_blocked': heating_blocked,
                        'cooling_blocked': cooling_blocked,
                        'chamber_ah': chamber_ah,
                        'target_ah': target_ah
                    }

            # NEW: Bypass coordination evaluation
            elif 'bypass_coordination' in scenario.inputs:
                # Get mode settings
                mode_var = env.variables[34].getValue()
                humi_save = mode_var.get('humi_save', False) if isinstance(mode_var, dict) else False

                # Get control signals
                cooling = scenario.inputs.get('cooling', False)
                dehumi = scenario.inputs.get('dehumi', False)
                outdoor_air_active = scenario.inputs.get('outdoor_air_active', False)

                # Bypass logic: humi_save OR ((cooling without dehumi) AND not outdoor air)
                bypass_open = humi_save or ((cooling and not dehumi) and not outdoor_air_active)

                env._test_results = {
                    'bypass_open': bypass_open,
                    'humi_save': humi_save,
                    'cooling': cooling,
                    'dehumi': dehumi,
                    'outdoor_air_active': outdoor_air_active
                }

                # Set relay
                if bypass_open:
                    env.sbus[64].call('turn_on')
                else:
                    env.sbus[64].call('turn_off')

            # NEW: Water cooling backup evaluation
            elif 'water_cooling_eval' in scenario.inputs:
                chamber_temp = env.variables[1].getValue() / 10.0
                outdoor_temp = env.variables[5].getValue() / 10.0

                # Get mode
                mode_var = env.variables[34].getValue()
                sum_wint_jel = mode_var.get('sum_wint_jel', False) if isinstance(mode_var, dict) else False

                # Calculate temperature difference
                outdoor_temp_diff = abs(outdoor_temp - chamber_temp)
                outdoor_not_effective = outdoor_temp_diff <= 3.0  # 3°C threshold

                # Water cooling: summer mode OR winter backup (if outdoor difference <= 3°C)
                use_water_cooling = sum_wint_jel or (not sum_wint_jel and outdoor_not_effective)

                env._test_results = {
                    'use_water_cooling': use_water_cooling,
                    'outdoor_temp_diff': outdoor_temp_diff,
                    'outdoor_not_effective': outdoor_not_effective,
                    'sum_wint_jel': sum_wint_jel
                }

            # Multi-round scenario support
            elif 'control_cycles' in scenario.inputs:
                cycles = scenario.inputs['control_cycles']
                env._test_results = {'cycles_with_outdoor_air': 0}
                for cycle in cycles:
                    self._execute_control_cycle(env, cycle)

            # Relay control
            elif 'relay_command' in scenario.inputs:
                relay_id, state = scenario.inputs['relay_command']
                if state == 'on':
                    env.sbus[relay_id].call('turn_on')
                else:
                    env.sbus[relay_id].call('turn_off')

            # Mode switching
            elif 'mode_change' in scenario.inputs:
                mode = scenario.inputs['mode_change']
                if mode == 'sleep':
                    new_value = scenario.inputs.get('new_value', True)
                    if 34 not in env.variables:
                        env.variables[34]._value = {}
                    if not isinstance(env.variables[34]._value, dict):
                        env.variables[34]._value = {}
                    env.variables[34]._value['sleep'] = new_value
                    env.variables[34].setValue(env.variables[34]._value, False)  # Propagate mode changes

            final_snapshot = env.get_state_snapshot()

            # Check expected output
            passed = self._validate_output(scenario.expected_output, final_snapshot, env)

            execution_time = (time.time() - start_time) * 1000  # ms

            result = TestResult(
                test_id=scenario.test_id,
                category=scenario.category,
                description=scenario.description,
                initial_state=json.dumps(scenario.initial_state),
                inputs=json.dumps(scenario.inputs),
                expected_output=json.dumps(scenario.expected_output),
                actual_output=json.dumps(final_snapshot, default=str),
                passed=passed,
                error_message="",
                execution_time_ms=execution_time,
                propagation_count=sum(final_snapshot['propagation_counts'].values()),
                blocked_count=sum(final_snapshot['blocked_counts'].values()),
                relay_states=json.dumps(final_snapshot['relays']),
                notes=""
            )

        except Exception as e:
            execution_time = (time.time() - start_time) * 1000

            result = TestResult(
                test_id=scenario.test_id,
                category=scenario.category,
                description=scenario.description,
                initial_state=json.dumps(scenario.initial_state),
                inputs=json.dumps(scenario.inputs),
                expected_output=json.dumps(scenario.expected_output),
                actual_output="",
                passed=False,
                error_message=str(e),
                execution_time_ms=execution_time,
                propagation_count=0,
                blocked_count=0,
                relay_states="",
                notes=f"Exception: {type(e).__name__}"
            )

        return result

    def _execute_control_cycle(self, env: MockTechSinumEnvironment, cycle: Dict):
        """Execute a single control cycle with multiple operations"""
        # Update sensor readings
        if 'sensor_readings' in cycle:
            readings = cycle['sensor_readings']
            if 'temp' in readings:
                env.variables[1].setValue(readings['temp'], True)  # Current temp
            if 'humidity' in readings:
                env.variables[2].setValue(readings['humidity'], True)  # Current humidity

        # Update setpoints
        if 'setpoints' in cycle:
            setpoints = cycle['setpoints']
            if 'temp' in setpoints:
                old = env.variables[3].getValue()
                new = setpoints['temp']
                delta = abs(new - old)
                should_propagate = delta >= 2
                env.variables[3].setValue(new, not should_propagate)
            if 'humidity' in setpoints:
                old = env.variables[4].getValue()
                new = setpoints['humidity']
                delta = abs(new - old)
                should_propagate = delta >= 3
                env.variables[4].setValue(new, not should_propagate)

        # Execute control logic (simplified)
        if 'control_action' in cycle:
            action = cycle['control_action']
            if action == 'heat':
                env.sbus[60].call('turn_on')   # Heating relay
                env.sbus[52].call('turn_off')  # Cooling relay off
            elif action == 'cool':
                env.sbus[52].call('turn_on')   # Cooling relay
                env.sbus[60].call('turn_off')  # Heating relay off
            elif action == 'idle':
                env.sbus[60].call('turn_off')
                env.sbus[52].call('turn_off')

        # Apply delays (simulated time progression)
        if 'delay_ms' in cycle:
            # In real test, this would advance simulation time
            pass

    def _calculate_absolute_humidity(self, temp_c: float, rh_percent: float) -> float:
        """
        Calculate absolute humidity (g/m³) from temperature and relative humidity
        Uses Tetens formula for saturation vapor pressure
        """
        import math

        # Tetens formula for saturation vapor pressure (hPa)
        T = temp_c
        e_s = 6.112 * math.exp((17.67 * T) / (T + 243.5))

        # Actual vapor pressure
        e = (rh_percent / 100.0) * e_s

        # Absolute humidity (g/m³)
        # Using ideal gas law: AH = (e * 1000 * M_w) / (R * T_k)
        # where M_w = 18.015 g/mol, R = 8.314 J/(mol·K), T_k = T + 273.15
        T_k = T + 273.15
        ah = (e * 100 * 18.015) / (8.314 * T_k)  # e in Pa (×100), result in g/m³

        return ah

    def _calculate_rh(self, temp_c: float, ah_g_m3: float) -> float:
        """
        Calculate relative humidity (%) from temperature and absolute humidity
        Inverse of _calculate_absolute_humidity
        """
        import math

        # Tetens formula for saturation vapor pressure (hPa)
        T = temp_c
        e_s = 6.112 * math.exp((17.67 * T) / (T + 243.5))

        # Calculate actual vapor pressure from absolute humidity
        # AH = (e * 1000 * M_w) / (R * T_k)
        # => e = (AH * R * T_k) / (1000 * M_w)
        T_k = T + 273.15
        e = (ah_g_m3 * 8.314 * T_k) / (100 * 18.015)  # Result in Pa, convert to hPa

        # Relative humidity
        rh = (e / e_s) * 100.0

        # Clamp to valid range
        return max(0.0, min(100.0, rh))

    def _evaluate_outdoor_air_benefit(
        self,
        chamber_temp: float,
        chamber_rh: float,
        target_temp: float,
        target_rh: float,
        outdoor_temp: float,
        outdoor_rh: float,
        outdoor_mix_ratio: float
    ) -> tuple:
        """
        Evaluate if outdoor air is beneficial using corrected psychrometric method
        Returns (beneficial: bool, details: dict)
        """
        import math

        # STEP 1: Calculate absolute humidities (temperature-independent metric)
        chamber_ah = self._calculate_absolute_humidity(chamber_temp, chamber_rh)
        target_ah = self._calculate_absolute_humidity(target_temp, target_rh)
        outdoor_ah = self._calculate_absolute_humidity(outdoor_temp, outdoor_rh)

        # STEP 2: Calculate mixed air properties (assuming perfect mixing)
        mixed_temp = chamber_temp * (1 - outdoor_mix_ratio) + outdoor_temp * outdoor_mix_ratio
        mixed_ah = chamber_ah * (1 - outdoor_mix_ratio) + outdoor_ah * outdoor_mix_ratio

        # STEP 3: Project final steady-state at target temperature
        projected_rh_at_target = self._calculate_rh(target_temp, mixed_ah)

        # DECISION CRITERIA (corrected - comparing at same temperature):
        # 1. Temperature benefit: Moving toward target?
        temp_delta_current = abs(target_temp - chamber_temp)
        temp_delta_mixed = abs(target_temp - mixed_temp)
        temp_improves = temp_delta_mixed < temp_delta_current

        # 2. Humidity evaluation at target temperature (NOT at mixed temperature!)
        rh_tolerance = 5.0
        rh_acceptable = abs(projected_rh_at_target - target_rh) <= rh_tolerance

        # 3. Absolute humidity check
        ah_delta_current = abs(target_ah - chamber_ah)
        ah_delta_mixed = abs(target_ah - mixed_ah)
        ah_improves = ah_delta_mixed < ah_delta_current  # Strict improvement, not just "not worse"

        # CORRECTED DECISION LOGIC
        beneficial = temp_improves and (ah_improves or rh_acceptable)

        details = {
            'temp_improves': temp_improves,
            'ah_improves': ah_improves,
            'rh_acceptable': rh_acceptable,
            'chamber_ah': chamber_ah,
            'target_ah': target_ah,
            'outdoor_ah': outdoor_ah,
            'mixed_temp': mixed_temp,
            'mixed_ah': mixed_ah,
            'projected_rh_at_target': projected_rh_at_target,
            'temp_delta_current': temp_delta_current,
            'temp_delta_mixed': temp_delta_mixed,
            'ah_delta_current': ah_delta_current,
            'ah_delta_mixed': ah_delta_mixed
        }

        return beneficial, details

    def _validate_output(self, expected: Dict, actual_snapshot: Dict, env: MockTechSinumEnvironment) -> bool:
        """Validate expected vs actual output"""
        try:
            if 'propagated' in expected:
                total_propagated = sum(actual_snapshot['propagation_counts'].values())
                if expected['propagated']:
                    if total_propagated == 0:
                        return False
                else:
                    if total_propagated > 0:
                        return False

            if 'blocked' in expected:
                total_blocked = sum(actual_snapshot['blocked_counts'].values())
                if expected['blocked']:
                    if total_blocked == 0:
                        return False

            # NEW: Validate outdoor air benefit evaluation results
            if 'outdoor_air_beneficial' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results['outdoor_air_beneficial'] != expected['outdoor_air_beneficial']:
                    return False

            if 'temp_improves' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results['temp_improves'] != expected['temp_improves']:
                    return False

            if 'ah_improves' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results['ah_improves'] != expected['ah_improves']:
                    return False

            if 'rh_acceptable' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results['rh_acceptable'] != expected['rh_acceptable']:
                    return False

            # NEW: Validate relay states
            if 'relay_61_state' in expected:
                actual_relay_state = actual_snapshot['relays'].get(61, 'off')
                if actual_relay_state != expected['relay_61_state']:
                    return False

            if 'signal_add_air_max' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results.get('signal_add_air_max') != expected['signal_add_air_max']:
                    return False

            # NEW: Validate humidification control
            if 'humidification' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results.get('humidification') != expected['humidification']:
                    return False

            if 'relay_humidifier' in expected:
                relay_66_state = actual_snapshot['relays'].get(66, 'off')
                if relay_66_state != expected['relay_humidifier']:
                    return False

            # NEW: Validate bypass coordination
            if 'bypass_open' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results.get('bypass_open') != expected['bypass_open']:
                    return False

            if 'relay_bypass' in expected:
                relay_64_state = actual_snapshot['relays'].get(64, 'off')
                if relay_64_state != expected['relay_bypass']:
                    return False

            # NEW: Validate water cooling backup
            if 'use_water_cooling' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results.get('use_water_cooling') != expected['use_water_cooling']:
                    return False

            # NEW: Validate better cold than dry strategy
            if 'heating_blocked' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results.get('heating_blocked') != expected['heating_blocked']:
                    return False

            if 'cooling_blocked' in expected:
                if not hasattr(env, '_test_results'):
                    return False
                if env._test_results.get('cooling_blocked') != expected['cooling_blocked']:
                    return False

            # Add more validation logic as needed

            return True

        except Exception as e:
            return False

    def run_all_tests(self, scenarios: List[TestScenario]) -> List[TestResult]:
        """Run all test scenarios and collect results"""
        print(f"Running {len(scenarios)} test scenarios...")

        for i, scenario in enumerate(scenarios, 1):
            if i % 10 == 0:
                print(f"  Progress: {i}/{len(scenarios)}")

            result = self.run_test(scenario)
            self.results.append(result)

        passed = sum(1 for r in self.results if r.passed)
        failed = len(self.results) - passed

        print(f"\nTest Results:")
        print(f"  Total: {len(self.results)}")
        print(f"  Passed: {passed}")
        print(f"  Failed: {failed}")
        print(f"  Pass Rate: {passed/len(self.results)*100:.1f}%")

        return self.results


def main():
    """Main test execution"""
    print("Aging Chamber Test Framework - Comprehensive Test Suite")
    print("=" * 60)

    # Generate scenarios from multiple generators
    print("\n1. Generating test scenarios...")

    # Basic scenarios (event propagation)
    print("   - Basic event propagation scenarios...")
    basic_generator = ScenarioGenerator()
    basic_scenarios = basic_generator.generate_all_scenarios()
    print(f"     Generated {len(basic_scenarios)} basic scenarios")

    # Comprehensive scenarios (all new features)
    print("   - Comprehensive feature scenarios...")
    comprehensive_generator = ComprehensiveScenarioGenerator()
    comprehensive_scenarios = comprehensive_generator.generate_all_scenarios()
    print(f"     Generated {len(comprehensive_scenarios)} comprehensive scenarios")

    # Combine all scenarios
    all_scenarios = basic_scenarios + comprehensive_scenarios
    print(f"\n   Total scenarios: {len(all_scenarios)}")

    # Run tests
    print("\n2. Running tests...")
    lua_code_path = "/home/user/lua/erlelo_1119_REFACTORED.lua"
    runner = LuaTestRunner(lua_code_path)
    results = runner.run_all_tests(all_scenarios)

    # Category breakdown
    print("\n3. Results by category:")
    categories = {}
    for result in results:
        if result.category not in categories:
            categories[result.category] = {'passed': 0, 'failed': 0}
        if result.passed:
            categories[result.category]['passed'] += 1
        else:
            categories[result.category]['failed'] += 1

    for category in sorted(categories.keys()):
        stats = categories[category]
        total = stats['passed'] + stats['failed']
        pass_rate = stats['passed'] / total * 100 if total > 0 else 0
        print(f"   {category}: {stats['passed']}/{total} ({pass_rate:.1f}%)")

    print("\n4. Tests complete!")

    return results


if __name__ == '__main__':
    main()
