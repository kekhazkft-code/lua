"""
Test Scenario Generator for Aging Chamber Control System
Generates comprehensive test scenarios covering all aspects
"""

import itertools
from typing import List, Dict, Any


class TestScenario:
    """Represents a single test scenario"""
    def __init__(self, test_id, category, description, initial_state, inputs, expected_output):
        self.test_id = test_id
        self.category = category
        self.description = description
        self.initial_state = initial_state
        self.inputs = inputs
        self.expected_output = expected_output


class ScenarioGenerator:
    """Generates test scenarios for the aging chamber system"""

    def __init__(self):
        self.test_counter = 1
        self.scenarios = []

    def generate_all_scenarios(self) -> List[TestScenario]:
        """Generate all test scenarios"""
        self.scenarios = []

        # Generate different test categories
        self.scenarios.extend(self._generate_event_propagation_tests())
        self.scenarios.extend(self._generate_temperature_control_tests())
        self.scenarios.extend(self._generate_humidity_control_tests())
        self.scenarios.extend(self._generate_mode_switching_tests())
        self.scenarios.extend(self._generate_relay_control_tests())
        self.scenarios.extend(self._generate_psychrometric_tests())
        self.scenarios.extend(self._generate_edge_case_tests())
        self.scenarios.extend(self._generate_integration_tests())

        return self.scenarios

    def _generate_event_propagation_tests(self) -> List[TestScenario]:
        """Test intelligent event propagation"""
        scenarios = []

        # Test 1: Small temperature change (< 0.2°C) should NOT propagate
        scenarios.append(TestScenario(
            test_id=f"EP{self.test_counter:03d}",
            category="Event Propagation",
            description="Small temp change (0.1°C) should block propagation",
            initial_state={
                'variables': {
                    1: 250,  # kamra_homerseklet = 25.0°C
                    3: 260,  # kamra_cel_homerseklet = 26.0°C
                }
            },
            inputs={'kamra_cel_change': 1},  # Change by 0.1°C
            expected_output={'propagated': False, 'blocked': True}
        ))
        self.test_counter += 1

        # Test 2: Large temperature change (≥ 0.2°C) SHOULD propagate
        scenarios.append(TestScenario(
            test_id=f"EP{self.test_counter:03d}",
            category="Event Propagation",
            description="Large temp change (0.5°C) should propagate",
            initial_state={
                'variables': {
                    1: 250,  # kamra_homerseklet = 25.0°C
                    3: 260,  # kamra_cel_homerseklet = 26.0°C
                }
            },
            inputs={'kamra_cel_change': 5},  # Change by 0.5°C
            expected_output={'propagated': True, 'blocked': False}
        ))
        self.test_counter += 1

        # Test 3: Small humidity change (< 0.3%) should NOT propagate
        scenarios.append(TestScenario(
            test_id=f"EP{self.test_counter:03d}",
            category="Event Propagation",
            description="Small humidity change (0.2%) should block propagation",
            initial_state={
                'variables': {
                    2: 500,  # kamra_para = 50.0%
                    4: 550,  # kamra_cel_para = 55.0%
                }
            },
            inputs={'kamra_cel_para_change': 2},  # Change by 0.2%
            expected_output={'propagated': False, 'blocked': True}
        ))
        self.test_counter += 1

        # Test 4: Large humidity change (≥ 0.3%) SHOULD propagate
        scenarios.append(TestScenario(
            test_id=f"EP{self.test_counter:03d}",
            category="Event Propagation",
            description="Large humidity change (0.5%) should propagate",
            initial_state={
                'variables': {
                    2: 500,  # kamra_para = 50.0%
                    4: 550,  # kamra_cel_para = 55.0%
                }
            },
            inputs={'kamra_cel_para_change': 5},  # Change by 0.5%
            expected_output={'propagated': True, 'blocked': False}
        ))
        self.test_counter += 1

        # Generate more propagation tests with different thresholds
        for temp_change in [0, 1, 2, 3, 5, 10, 20, 50]:
            scenarios.append(TestScenario(
                test_id=f"EP{self.test_counter:03d}",
                category="Event Propagation",
                description=f"Temp change {temp_change/10}°C propagation test",
                initial_state={'variables': {1: 250, 3: 260}},
                inputs={'temp_delta': temp_change},
                expected_output={'propagated': temp_change >= 2}
            ))
            self.test_counter += 1

        # Generate humidity propagation tests
        for humi_change in [0, 1, 2, 3, 5, 10, 20, 30]:
            scenarios.append(TestScenario(
                test_id=f"EP{self.test_counter:03d}",
                category="Event Propagation",
                description=f"Humidity change {humi_change/10}% propagation test",
                initial_state={'variables': {2: 500, 4: 550}},
                inputs={'humi_delta': humi_change},
                expected_output={'propagated': humi_change >= 3}
            ))
            self.test_counter += 1

        # User setpoint changes (should ALWAYS propagate)
        scenarios.append(TestScenario(
            test_id=f"EP{self.test_counter:03d}",
            category="Event Propagation",
            description="User setpoint change should always propagate",
            initial_state={'variables': {3: 250}},
            inputs={'user_setpoint_change': 1},  # Even 0.1°C change
            expected_output={'propagated': True, 'user_change': True}
        ))
        self.test_counter += 1

        return scenarios

    def _generate_temperature_control_tests(self) -> List[TestScenario]:
        """Test temperature control logic"""
        scenarios = []

        # Test heating activation when temp below setpoint
        temp_values = [150, 180, 200, 220, 240, 250, 260, 280, 300]
        setpoint_values = [200, 220, 250, 280, 300]

        for temp, setpoint in itertools.product(temp_values, setpoint_values):
            scenarios.append(TestScenario(
                test_id=f"TC{self.test_counter:03d}",
                category="Temperature Control",
                description=f"Temp={temp/10}°C, Setpoint={setpoint/10}°C",
                initial_state={'variables': {1: temp, 3: setpoint}},
                inputs={'control_cycle': 1},
                expected_output={
                    'heating_active': temp < setpoint,
                    'cooling_active': temp > setpoint
                }
            ))
            self.test_counter += 1

        return scenarios

    def _generate_humidity_control_tests(self) -> List[TestScenario]:
        """Test humidity control logic"""
        scenarios = []

        # Test humidity control with various conditions
        humi_values = [300, 400, 500, 600, 700, 800]
        setpoint_values = [400, 500, 600, 700]

        for humi, setpoint in itertools.product(humi_values, setpoint_values):
            scenarios.append(TestScenario(
                test_id=f"HC{self.test_counter:03d}",
                category="Humidity Control",
                description=f"Humidity={humi/10}%, Setpoint={setpoint/10}%",
                initial_state={'variables': {2: humi, 4: setpoint}},
                inputs={'control_cycle': 1},
                expected_output={
                    'humidify_active': humi < setpoint,
                    'dehumidify_active': humi > setpoint
                }
            ))
            self.test_counter += 1

        return scenarios

    def _generate_mode_switching_tests(self) -> List[TestScenario]:
        """Test mode switching (sleep, summer/winter, etc.)"""
        scenarios = []

        # Sleep mode transitions
        for sleep_mode in [True, False]:
            scenarios.append(TestScenario(
                test_id=f"MS{self.test_counter:03d}",
                category="Mode Switching",
                description=f"Sleep mode = {sleep_mode}",
                initial_state={'variables': {34: {'sleep': sleep_mode}}},
                inputs={'mode_change': 'sleep'},
                expected_output={
                    'relay_sleep_state': 'on' if sleep_mode else 'off',
                    'event_propagated': True  # Mode changes should always propagate
                }
            ))
            self.test_counter += 1

        # Summer/Winter mode
        for mode in ['summer', 'winter']:
            scenarios.append(TestScenario(
                test_id=f"MS{self.test_counter:03d}",
                category="Mode Switching",
                description=f"Season mode = {mode}",
                initial_state={'variables': {34: {'sum_wint_jel': mode == 'summer'}}},
                inputs={'mode_change': 'season'},
                expected_output={
                    'season_mode': mode,
                    'event_propagated': True
                }
            ))
            self.test_counter += 1

        # Humidity save mode
        for humi_save in [True, False]:
            scenarios.append(TestScenario(
                test_id=f"MS{self.test_counter:03d}",
                category="Mode Switching",
                description=f"Humidity save mode = {humi_save}",
                initial_state={'variables': {34: {'humi_save': humi_save}}},
                inputs={'mode_change': 'humi_save'},
                expected_output={
                    'humi_save_active': humi_save,
                    'event_propagated': True
                }
            ))
            self.test_counter += 1

        return scenarios

    def _generate_relay_control_tests(self) -> List[TestScenario]:
        """Test relay control logic"""
        scenarios = []

        # Test each relay activation
        relays = {
            60: 'warm',      # Heating relay
            52: 'cool',      # Cooling relay
            53: 'sleep',     # Sleep mode relay
            61: 'add_air',   # Summer/winter air relay
            62: 'fan',       # Main fan
            63: 'bypass',    # Humidity save bypass
        }

        for relay_id, relay_name in relays.items():
            for state in ['on', 'off']:
                scenarios.append(TestScenario(
                    test_id=f"RC{self.test_counter:03d}",
                    category="Relay Control",
                    description=f"Relay {relay_name} set to {state}",
                    initial_state={'relays': {relay_id: 'off'}},
                    inputs={'relay_command': (relay_id, state)},
                    expected_output={'relay_state': state}
                ))
                self.test_counter += 1

        return scenarios

    def _generate_psychrometric_tests(self) -> List[TestScenario]:
        """Test psychrometric calculations"""
        scenarios = []

        # Test absolute humidity calculations
        test_conditions = [
            (20.0, 50.0),  # 20°C, 50% RH
            (25.0, 60.0),  # 25°C, 60% RH
            (15.0, 70.0),  # 15°C, 70% RH
            (30.0, 40.0),  # 30°C, 40% RH
            (10.0, 80.0),  # 10°C, 80% RH
            (-5.0, 90.0),  # -5°C, 90% RH
        ]

        for temp, rh in test_conditions:
            scenarios.append(TestScenario(
                test_id=f"PS{self.test_counter:03d}",
                category="Psychrometric",
                description=f"AH calc: T={temp}°C, RH={rh}%",
                initial_state={'variables': {1: int(temp*10), 2: int(rh*10)}},
                inputs={'calc_type': 'absolute_humidity'},
                expected_output={'ah_calculated': True}
            ))
            self.test_counter += 1

        # Test dew point calculations
        for temp, rh in test_conditions:
            scenarios.append(TestScenario(
                test_id=f"PS{self.test_counter:03d}",
                category="Psychrometric",
                description=f"Dew point: T={temp}°C, RH={rh}%",
                initial_state={'variables': {1: int(temp*10), 2: int(rh*10)}},
                inputs={'calc_type': 'dew_point'},
                expected_output={'dp_calculated': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_edge_case_tests(self) -> List[TestScenario]:
        """Test edge cases and fault scenarios"""
        scenarios = []

        # Test extreme temperatures
        extreme_temps = [-300, -100, 0, 500, 800, 1000]  # -30°C to 100°C
        for temp in extreme_temps:
            scenarios.append(TestScenario(
                test_id=f"EC{self.test_counter:03d}",
                category="Edge Cases",
                description=f"Extreme temperature: {temp/10}°C",
                initial_state={'variables': {1: temp}},
                inputs={'validation': True},
                expected_output={'handled_gracefully': True}
            ))
            self.test_counter += 1

        # Test extreme humidity
        extreme_humi = [0, 10, 1000, 1200]  # 0% to 120%
        for humi in extreme_humi:
            scenarios.append(TestScenario(
                test_id=f"EC{self.test_counter:03d}",
                category="Edge Cases",
                description=f"Extreme humidity: {humi/10}%",
                initial_state={'variables': {2: humi}},
                inputs={'validation': True},
                expected_output={'handled_gracefully': True}
            ))
            self.test_counter += 1

        # Test sensor failures (error counts)
        for error_count in [0, 1, 2, 3, 5, 10]:
            scenarios.append(TestScenario(
                test_id=f"EC{self.test_counter:03d}",
                category="Edge Cases",
                description=f"Sensor error count: {error_count}",
                initial_state={'variables': {29: error_count}},  # befujt_hibaszam1
                inputs={'fault_handling': True},
                expected_output={'fault_mode': error_count > 0}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_integration_tests(self) -> List[TestScenario]:
        """Test system integration and device communication"""
        scenarios = []

        # Test complete control cycle
        scenarios.append(TestScenario(
            test_id=f"IT{self.test_counter:03d}",
            category="Integration",
            description="Complete control cycle with all systems active",
            initial_state={
                'variables': {
                    1: 250,   # Current temp
                    2: 500,   # Current humidity
                    3: 260,   # Target temp
                    4: 600,   # Target humidity
                }
            },
            inputs={'full_cycle': True},
            expected_output={
                'heating_active': True,
                'humidify_active': True,
                'events_propagated': True
            }
        ))
        self.test_counter += 1

        # Test inter-device communication
        scenarios.append(TestScenario(
            test_id=f"IT{self.test_counter:03d}",
            category="Integration",
            description="Device-to-device event propagation",
            initial_state={'variables': {34: {'sleep': False}}},
            inputs={'mode_change': 'sleep', 'new_value': True},
            expected_output={
                'event_sent': True,
                'other_devices_notified': True
            }
        ))
        self.test_counter += 1

        return scenarios


def main():
    """Generate and display scenario count"""
    generator = ScenarioGenerator()
    scenarios = generator.generate_all_scenarios()

    print(f"Generated {len(scenarios)} test scenarios:")

    categories = {}
    for scenario in scenarios:
        cat = scenario.category
        categories[cat] = categories.get(cat, 0) + 1

    for category, count in sorted(categories.items()):
        print(f"  {category}: {count} tests")

    return scenarios


if __name__ == '__main__':
    main()
