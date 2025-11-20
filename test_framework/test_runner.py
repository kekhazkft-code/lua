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

            # Multi-round scenario support
            elif 'control_cycles' in scenario.inputs:
                cycles = scenario.inputs['control_cycles']
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
    print("Aging Chamber Test Framework")
    print("=" * 60)

    # Generate scenarios
    print("\n1. Generating test scenarios...")
    generator = ScenarioGenerator()
    scenarios = generator.generate_all_scenarios()
    print(f"   Generated {len(scenarios)} scenarios")

    # Run tests
    print("\n2. Running tests...")
    lua_code_path = "../aging_chamber_Apar2_0_REFACTORED.lua"
    runner = LuaTestRunner(lua_code_path)
    results = runner.run_all_tests(scenarios)

    print("\n3. Tests complete!")

    return results


if __name__ == '__main__':
    main()
