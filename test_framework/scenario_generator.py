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
        self.scenarios.extend(self._generate_cycle_time_tests())  # NEW: Multi-round cycle tests

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

        # === NEW: Outdoor Air Benefit Evaluation Tests ===

        # Test Scenario 1: Winter - Cold Dry Outdoor Air (BENEFICIAL)
        scenarios.append(TestScenario(
            test_id=f"PS{self.test_counter:03d}",
            category="Psychrometric",
            description="Winter: Cold dry outdoor air beneficial for cooling+dehumidification",
            initial_state={
                'variables': {
                    1: 120,   # kamra_homerseklet = 12.0°C (current chamber)
                    2: 850,   # kamra_para = 85.0% RH (current chamber)
                    3: 100,   # kamra_cel_homerseklet = 10.0°C (target)
                    4: 850,   # kamra_cel_para = 85.0% RH (target)
                    5: 0,     # kulso_homerseklet = 0.0°C (outdoor)
                    6: 600,   # kulso_para = 60.0% RH (outdoor)
                }
            },
            inputs={
                'outdoor_air_eval': True,
                'outdoor_mix_ratio': 0.30
            },
            expected_output={
                'outdoor_air_beneficial': True,
                'temp_improves': True,
                'ah_improves': True,
                'energy_savings': True  # Saves ~3000W cooling
            }
        ))
        self.test_counter += 1

        # Test Scenario 2: Summer - Hot Humid Outdoor Air (NOT BENEFICIAL)
        scenarios.append(TestScenario(
            test_id=f"PS{self.test_counter:03d}",
            category="Psychrometric",
            description="Summer: Hot humid outdoor air NOT beneficial",
            initial_state={
                'variables': {
                    1: 220,   # kamra_homerseklet = 22.0°C (current)
                    2: 600,   # kamra_para = 60.0% RH
                    3: 200,   # kamra_cel_homerseklet = 20.0°C (target)
                    4: 550,   # kamra_cel_para = 55.0% RH (target)
                    5: 320,   # kulso_homerseklet = 32.0°C (hot outdoor)
                    6: 800,   # kulso_para = 80.0% RH (humid outdoor)
                }
            },
            inputs={
                'outdoor_air_eval': True,
                'outdoor_mix_ratio': 0.30
            },
            expected_output={
                'outdoor_air_beneficial': False,
                'temp_improves': False,  # Would increase temp
                'ah_improves': False,    # Would increase moisture
                'energy_waste': True     # Would waste energy
            }
        ))
        self.test_counter += 1

        # Test Scenario 3: Mild Conditions - Marginal Benefit
        scenarios.append(TestScenario(
            test_id=f"PS{self.test_counter:03d}",
            category="Psychrometric",
            description="Mild: Outdoor air marginally beneficial",
            initial_state={
                'variables': {
                    1: 180,   # kamra_homerseklet = 18.0°C
                    2: 700,   # kamra_para = 70.0% RH
                    3: 150,   # kamra_cel_homerseklet = 15.0°C (target)
                    4: 650,   # kamra_cel_para = 65.0% RH (target)
                    5: 100,   # kulso_homerseklet = 10.0°C
                    6: 700,   # kulso_para = 70.0% RH
                }
            },
            inputs={
                'outdoor_air_eval': True,
                'outdoor_mix_ratio': 0.30
            },
            expected_output={
                'outdoor_air_beneficial': True,
                'temp_improves': True,
                'rh_acceptable': True,  # Within ±5% tolerance
            }
        ))
        self.test_counter += 1

        # Test Scenario 4: Extreme Cold - Very Dry Outdoor Air
        scenarios.append(TestScenario(
            test_id=f"PS{self.test_counter:03d}",
            category="Psychrometric",
            description="Extreme winter: Very cold, very dry outdoor air",
            initial_state={
                'variables': {
                    1: 250,   # kamra_homerseklet = 25.0°C
                    2: 900,   # kamra_para = 90.0% RH (very humid chamber)
                    3: 200,   # kamra_cel_homerseklet = 20.0°C (target)
                    4: 600,   # kamra_cel_para = 60.0% RH (target)
                    5: -100,  # kulso_homerseklet = -10.0°C (extreme cold)
                    6: 500,   # kulso_para = 50.0% RH
                }
            },
            inputs={
                'outdoor_air_eval': True,
                'outdoor_mix_ratio': 0.30
            },
            expected_output={
                'outdoor_air_beneficial': True,
                'temp_improves': True,
                'ah_improves': True,
                'strong_dehumidification': True
            }
        ))
        self.test_counter += 1

        # Test Scenario 5: Same Conditions - No Benefit
        scenarios.append(TestScenario(
            test_id=f"PS{self.test_counter:03d}",
            category="Psychrometric",
            description="Outdoor air same as chamber - no benefit",
            initial_state={
                'variables': {
                    1: 200,   # kamra_homerseklet = 20.0°C
                    2: 600,   # kamra_para = 60.0% RH
                    3: 200,   # kamra_cel_homerseklet = 20.0°C (target)
                    4: 600,   # kamra_cel_para = 60.0% RH (target)
                    5: 200,   # kulso_homerseklet = 20.0°C (same)
                    6: 600,   # kulso_para = 60.0% RH (same)
                }
            },
            inputs={
                'outdoor_air_eval': True,
                'outdoor_mix_ratio': 0.30
            },
            expected_output={
                'outdoor_air_beneficial': False,  # No improvement
                'temp_improves': False,
                'ah_improves': False
            }
        ))
        self.test_counter += 1

        # Test different outdoor air mixing ratios
        for mix_ratio in [0.10, 0.20, 0.30, 0.40, 0.50]:
            scenarios.append(TestScenario(
                test_id=f"PS{self.test_counter:03d}",
                category="Psychrometric",
                description=f"Outdoor air mixing ratio {int(mix_ratio*100)}%",
                initial_state={
                    'variables': {
                        1: 120, 2: 850,  # Chamber: 12°C, 85% RH
                        3: 100, 4: 850,  # Target: 10°C, 85% RH
                        5: 0, 6: 600,    # Outdoor: 0°C, 60% RH
                    }
                },
                inputs={
                    'outdoor_air_eval': True,
                    'outdoor_mix_ratio': mix_ratio
                },
                expected_output={
                    'outdoor_air_beneficial': True,
                    'mixing_ratio': mix_ratio
                }
            ))
            self.test_counter += 1

        # Test RH tolerance boundary (±5%)
        rh_tolerance_cases = [
            (850, 800, True),   # 85% target, 80% projected = 5% diff (acceptable)
            (850, 850, True),   # 85% target, 85% projected = 0% diff (perfect)
            (850, 900, True),   # 85% target, 90% projected = 5% diff (acceptable)
            (850, 750, False),  # 85% target, 75% projected = 10% diff (not acceptable)
            (850, 920, False),  # 85% target, 92% projected = 7% diff (not acceptable)
        ]

        for target_rh, projected_rh, acceptable in rh_tolerance_cases:
            scenarios.append(TestScenario(
                test_id=f"PS{self.test_counter:03d}",
                category="Psychrometric",
                description=f"RH tolerance: target={target_rh/10}%, projected={projected_rh/10}%",
                initial_state={
                    'variables': {
                        1: 150, 2: 700,           # Chamber conditions
                        3: 150, 4: target_rh,     # Target
                        5: 100, 6: 650,           # Outdoor
                    }
                },
                inputs={
                    'outdoor_air_eval': True,
                    'outdoor_mix_ratio': 0.30,
                    'expected_projected_rh': projected_rh
                },
                expected_output={
                    'rh_acceptable': acceptable,
                    'within_tolerance': acceptable
                }
            ))
            self.test_counter += 1

        # Test temperature improvement detection
        temp_improvement_cases = [
            # (chamber_temp, target_temp, outdoor_temp, should_improve)
            (120, 100, 0, True),     # 12°C → 10°C, outdoor 0°C: improves
            (220, 200, 320, False),  # 22°C → 20°C, outdoor 32°C: worsens
            (200, 200, 150, False),  # Already at target, outdoor cooler: no improvement needed
            (180, 150, 100, True),   # 18°C → 15°C, outdoor 10°C: improves
            (100, 150, 200, False),  # 10°C → 15°C (need heat), outdoor 20°C: wrong direction
        ]

        for chamber_temp, target_temp, outdoor_temp, should_improve in temp_improvement_cases:
            scenarios.append(TestScenario(
                test_id=f"PS{self.test_counter:03d}",
                category="Psychrometric",
                description=f"Temp improvement: chamber={chamber_temp/10}°C, target={target_temp/10}°C, outdoor={outdoor_temp/10}°C",
                initial_state={
                    'variables': {
                        1: chamber_temp,
                        2: 600,
                        3: target_temp,
                        4: 600,
                        5: outdoor_temp,
                        6: 600,
                    }
                },
                inputs={
                    'outdoor_air_eval': True,
                    'outdoor_mix_ratio': 0.30
                },
                expected_output={
                    'temp_improves': should_improve
                }
            ))
            self.test_counter += 1

        # Test absolute humidity improvement
        ah_improvement_cases = [
            # (chamber_temp, chamber_rh, target_temp, target_rh, outdoor_temp, outdoor_rh, should_improve)
            (120, 850, 100, 850, 0, 600, True),     # Winter: dry outdoor air helps
            (220, 600, 200, 550, 320, 800, False),  # Summer: humid outdoor air hinders
            (200, 700, 200, 600, 200, 500, True),   # Same temp, drier outdoor: helps
            (180, 500, 180, 600, 180, 700, False),  # Need humidification, dry outdoor: hinders
        ]

        for chamber_temp, chamber_rh, target_temp, target_rh, outdoor_temp, outdoor_rh, should_improve in ah_improvement_cases:
            scenarios.append(TestScenario(
                test_id=f"PS{self.test_counter:03d}",
                category="Psychrometric",
                description=f"AH improvement: chamber={chamber_temp/10}°C/{chamber_rh/10}%, target={target_temp/10}°C/{target_rh/10}%, outdoor={outdoor_temp/10}°C/{outdoor_rh/10}%",
                initial_state={
                    'variables': {
                        1: chamber_temp, 2: chamber_rh,
                        3: target_temp, 4: target_rh,
                        5: outdoor_temp, 6: outdoor_rh,
                    }
                },
                inputs={
                    'outdoor_air_eval': True,
                    'outdoor_mix_ratio': 0.30
                },
                expected_output={
                    'ah_improves': should_improve
                }
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

        # === NEW: Integration with Outdoor Air Control ===

        # Test controlling() with outdoor air benefit evaluation - Winter scenario
        scenarios.append(TestScenario(
            test_id=f"IT{self.test_counter:03d}",
            category="Integration",
            description="controlling() winter: outdoor air beneficial, relay activated",
            initial_state={
                'variables': {
                    1: 120,   # kamra_homerseklet = 12.0°C
                    2: 850,   # kamra_para = 85.0% RH
                    3: 100,   # kamra_cel_homerseklet = 10.0°C
                    4: 850,   # kamra_cel_para = 85.0% RH
                    5: 0,     # kulso_homerseklet = 0.0°C
                    6: 600,   # kulso_para = 60.0% RH
                    34: {'humi_save': False, 'sum_wint_jel': False}
                },
                'relays': {61: 'off'}  # add_air_max relay
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'outdoor_air_beneficial': True,
                'relay_61_state': 'on',  # add_air_max should be ON
                'signal_add_air_max': True,
                'energy_savings': True
            }
        ))
        self.test_counter += 1

        # Test controlling() with outdoor air NOT beneficial - Summer scenario
        scenarios.append(TestScenario(
            test_id=f"IT{self.test_counter:03d}",
            category="Integration",
            description="controlling() summer: outdoor air NOT beneficial, relay OFF",
            initial_state={
                'variables': {
                    1: 220,   # kamra_homerseklet = 22.0°C
                    2: 600,   # kamra_para = 60.0% RH
                    3: 200,   # kamra_cel_homerseklet = 20.0°C
                    4: 550,   # kamra_cel_para = 55.0% RH
                    5: 320,   # kulso_homerseklet = 32.0°C
                    6: 800,   # kulso_para = 80.0% RH
                    34: {'humi_save': False, 'sum_wint_jel': False}
                },
                'relays': {61: 'on'}  # add_air_max relay currently ON
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'outdoor_air_beneficial': False,
                'relay_61_state': 'off',  # add_air_max should be OFF
                'signal_add_air_max': False
            }
        ))
        self.test_counter += 1

        # Test controlling() with humi_save mode (should block outdoor air)
        scenarios.append(TestScenario(
            test_id=f"IT{self.test_counter:03d}",
            category="Integration",
            description="controlling() humi_save mode: outdoor air blocked even if beneficial",
            initial_state={
                'variables': {
                    1: 120, 2: 850,   # Chamber: 12°C, 85% RH
                    3: 100, 4: 850,   # Target: 10°C, 85% RH
                    5: 0, 6: 600,     # Outdoor: 0°C, 60% RH (beneficial!)
                    34: {'humi_save': True, 'sum_wint_jel': False}  # humi_save ON
                },
                'relays': {61: 'off'}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'outdoor_air_evaluated': False,  # Should not even evaluate
                'relay_61_state': 'off',
                'signal_add_air_max': False  # Blocked by humi_save
            }
        ))
        self.test_counter += 1

        # Test controlling() with sum_wint_jel mode
        scenarios.append(TestScenario(
            test_id=f"IT{self.test_counter:03d}",
            category="Integration",
            description="controlling() sum_wint_jel mode: outdoor air blocked",
            initial_state={
                'variables': {
                    1: 120, 2: 850,
                    3: 100, 4: 850,
                    5: 0, 6: 600,
                    34: {'humi_save': False, 'sum_wint_jel': True}  # sum_wint ON
                },
                'relays': {61: 'off'}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'outdoor_air_beneficial': True,  # Would be beneficial, but...
                'relay_61_state': 'off',         # ...blocked by sum_wint_jel
                'signal_add_air_max': False
            }
        ))
        self.test_counter += 1

        return scenarios

    def _generate_cycle_time_tests(self) -> List[TestScenario]:
        """Test multi-round control cycles (5-second intervals)"""
        scenarios = []

        # === Multi-Round Outdoor Air Evaluation Tests ===

        # Test 1: 10-cycle winter scenario (50 seconds simulated)
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="10 cycles (50s): Winter cooling with outdoor air benefit",
            initial_state={
                'variables': {
                    1: 150, 2: 800,   # Start: 15°C, 80% RH
                    3: 100, 4: 700,   # Target: 10°C, 70% RH
                    5: -50, 6: 600,   # Outdoor: -5°C, 60% RH
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    # Each cycle represents 5 seconds
                    {'cycle': 1, 'sensor_readings': {'temp': 145, 'humidity': 785}},
                    {'cycle': 2, 'sensor_readings': {'temp': 140, 'humidity': 770}},
                    {'cycle': 3, 'sensor_readings': {'temp': 135, 'humidity': 755}},
                    {'cycle': 4, 'sensor_readings': {'temp': 130, 'humidity': 740}},
                    {'cycle': 5, 'sensor_readings': {'temp': 125, 'humidity': 730}},
                    {'cycle': 6, 'sensor_readings': {'temp': 120, 'humidity': 720}},
                    {'cycle': 7, 'sensor_readings': {'temp': 115, 'humidity': 715}},
                    {'cycle': 8, 'sensor_readings': {'temp': 110, 'humidity': 710}},
                    {'cycle': 9, 'sensor_readings': {'temp': 105, 'humidity': 705}},
                    {'cycle': 10, 'sensor_readings': {'temp': 100, 'humidity': 700}},
                ]
            },
            expected_output={
                'cycles_with_outdoor_air': 10,  # All cycles should use outdoor air
                'final_temp': 100,
                'final_humidity': 700,
                'target_reached': True,
                'total_energy_savings': 30000  # 3000W × 10 cycles
            }
        ))
        self.test_counter += 1

        # Test 2: 20-cycle transitional scenario (100 seconds)
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="20 cycles (100s): Transition from beneficial to non-beneficial",
            initial_state={
                'variables': {
                    1: 200, 2: 700,
                    3: 180, 4: 600,
                    5: 100, 6: 550,   # Outdoor initially beneficial
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    # Outdoor temp rises during test
                    {'cycle': i, 'sensor_readings': {
                        'temp': 200 - i,
                        'humidity': 700 - (i * 5)
                    }, 'outdoor_change': {
                        'temp': 100 + (i * 10),  # Outdoor warms up
                        'humidity': 550 + (i * 10)
                    }} for i in range(1, 21)
                ]
            },
            expected_output={
                'outdoor_air_switch_cycle': 10,  # Around cycle 10, outdoor becomes non-beneficial
                'cycles_with_outdoor_air': 10,   # First 10 cycles
                'cycles_without_outdoor_air': 10  # Last 10 cycles
            }
        ))
        self.test_counter += 1

        # Test 3: 50-cycle long-duration test (250 seconds = 4.17 minutes)
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="50 cycles (250s): Long-duration stability test",
            initial_state={
                'variables': {
                    1: 250, 2: 850,
                    3: 200, 4: 700,
                    5: 50, 6: 600,
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    {'cycle': i, 'sensor_readings': {
                        'temp': max(200, 250 - i),  # Gradually cool down
                        'humidity': max(700, 850 - (i * 3))  # Gradually dehumidify
                    }} for i in range(1, 51)
                ]
            },
            expected_output={
                'cycles_executed': 50,
                'target_reached_at_cycle': 50,
                'outdoor_air_usage_consistent': True,
                'no_relay_chatter': True  # Should not oscillate
            }
        ))
        self.test_counter += 1

        # Test 4: Rapid setpoint changes (stress test)
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="30 cycles (150s): Rapid setpoint changes",
            initial_state={
                'variables': {
                    1: 200, 2: 600,
                    3: 200, 4: 600,
                    5: 150, 6: 550,
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    # Setpoint changes every 10 cycles
                    {'cycle': i, 'setpoints': {
                        'temp': 200 + ((i // 10) * 20),
                        'humidity': 600 + ((i // 10) * 50)
                    }} for i in range(1, 31)
                ]
            },
            expected_output={
                'setpoint_changes_handled': 3,
                'outdoor_air_reevaluated': True,
                'propagation_on_setpoint_change': True
            }
        ))
        self.test_counter += 1

        # Test 5: Mode switching during cycles
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="25 cycles (125s): Mode switching (humi_save enabled mid-test)",
            initial_state={
                'variables': {
                    1: 120, 2: 850,
                    3: 100, 4: 800,
                    5: 0, 6: 600,
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    # Enable humi_save at cycle 15
                    {'cycle': i, 'mode_change': 'humi_save' if i == 15 else None,
                     'humi_save_value': True if i == 15 else None}
                    for i in range(1, 26)
                ]
            },
            expected_output={
                'outdoor_air_active_cycles_1_14': 14,
                'outdoor_air_blocked_cycles_15_25': 11,
                'mode_switch_detected': True,
                'relay_state_changed_at_cycle': 15
            }
        ))
        self.test_counter += 1

        # Test 6: Seasonal transition (100 cycles = 500s = 8.33 minutes)
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="100 cycles (500s): Seasonal transition winter→spring→summer",
            initial_state={
                'variables': {
                    1: 150, 2: 750,
                    3: 200, 4: 600,
                    5: -100, 6: 500,  # Start: winter
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    {'cycle': i,
                     'outdoor_change': {
                         'temp': -100 + (i * 5),  # Outdoor warms from -10°C to +40°C
                         'humidity': 500 + (i * 2)  # Outdoor humidity rises
                     }}
                    for i in range(1, 101)
                ]
            },
            expected_output={
                'outdoor_air_beneficial_winter': True,   # Cycles 1-20
                'outdoor_air_beneficial_spring': True,   # Cycles 21-50
                'outdoor_air_beneficial_summer': False,  # Cycles 51-100
                'transition_points_detected': 2
            }
        ))
        self.test_counter += 1

        # Test 7: Extreme conditions stability
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="40 cycles (200s): Extreme cold outdoor air (-30°C)",
            initial_state={
                'variables': {
                    1: 250, 2: 900,   # Chamber: 25°C, 90% RH (very humid)
                    3: 150, 4: 600,   # Target: 15°C, 60% RH
                    5: -300, 6: 400,  # Outdoor: -30°C, 40% RH (extreme)
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    {'cycle': i, 'sensor_readings': {
                        'temp': max(150, 250 - (i * 3)),
                        'humidity': max(600, 900 - (i * 8))
                    }} for i in range(1, 41)
                ]
            },
            expected_output={
                'outdoor_air_beneficial_all_cycles': True,
                'strong_cooling': True,
                'strong_dehumidification': True,
                'energy_savings_high': True
            }
        ))
        self.test_counter += 1

        # Test 8: Oscillating outdoor conditions
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="30 cycles (150s): Oscillating outdoor temp/humidity",
            initial_state={
                'variables': {
                    1: 200, 2: 700,
                    3: 180, 4: 650,
                    5: 150, 6: 600,
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    {'cycle': i, 'outdoor_change': {
                        'temp': 150 + (50 if i % 2 == 0 else -50),  # Oscillate ±5°C
                        'humidity': 600 + (100 if i % 2 == 0 else -100)  # Oscillate ±10%
                    }} for i in range(1, 31)
                ]
            },
            expected_output={
                'outdoor_air_decisions_oscillate': True,
                'relay_cycling_count': 15,  # ~Every other cycle
                'system_stable': True
            }
        ))
        self.test_counter += 1

        # Test 9: Constant conditions (steady state)
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="60 cycles (300s): Constant beneficial conditions",
            initial_state={
                'variables': {
                    1: 120, 2: 850,
                    3: 100, 4: 800,
                    5: 0, 6: 600,
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    {'cycle': i}  # No changes
                    for i in range(1, 61)
                ]
            },
            expected_output={
                'outdoor_air_decision_constant': True,
                'relay_state_stable': True,
                'no_unnecessary_switching': True
            }
        ))
        self.test_counter += 1

        # Test 10: Edge case - exactly at tolerance boundary
        scenarios.append(TestScenario(
            test_id=f"CT{self.test_counter:03d}",
            category="Cycle Time",
            description="20 cycles (100s): RH projection exactly at ±5% tolerance",
            initial_state={
                'variables': {
                    1: 180, 2: 750,
                    3: 150, 4: 700,   # Target: 70% RH
                    5: 100, 6: 650,   # Outdoor will project to 75% (exactly +5%)
                    34: {'humi_save': False, 'sum_wint_jel': False}
                }
            },
            inputs={
                'control_cycles': [
                    {'cycle': i} for i in range(1, 21)
                ]
            },
            expected_output={
                'rh_at_tolerance_boundary': True,
                'outdoor_air_accepted': True,  # Should accept ±5%
                'boundary_condition_handled': True
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
