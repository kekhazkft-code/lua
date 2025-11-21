"""
Comprehensive Test Scenario Generator
Covers all new features added in 2025-11-20:
- Humidification control (with/without humidifier)
- Bypass-outdoor air coordination
- Water cooling backup (3°C threshold)
- "Better cold than dry" strategy
- humi_save mode interactions
"""

from typing import List, Dict
from scenario_generator import TestScenario

class ComprehensiveScenarioGenerator:
    def __init__(self):
        self.test_counter = 2000  # Start from 2000 for new tests

    def generate_all_scenarios(self) -> List[TestScenario]:
        """Generate comprehensive test scenarios for new features"""
        scenarios = []

        scenarios.extend(self._generate_humidification_with_equipment_tests())
        scenarios.extend(self._generate_humidification_without_equipment_tests())
        scenarios.extend(self._generate_bypass_outdoor_air_coordination_tests())
        scenarios.extend(self._generate_water_cooling_backup_tests())
        scenarios.extend(self._generate_humi_save_mode_tests())
        scenarios.extend(self._generate_temperature_difference_threshold_tests())
        scenarios.extend(self._generate_better_cold_than_dry_tests())
        scenarios.extend(self._generate_combined_scenario_tests())

        return scenarios

    def _generate_humidification_with_equipment_tests(self) -> List[TestScenario]:
        """Test humidification when HAS_HUMIDIFIER = true"""
        scenarios = []

        # Test 1: Low humidity, should start humidifier
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"HUM{self.test_counter:04d}",
            category="Humidification_With_Equipment",
            description="Low humidity: Start humidifier (projected RH < target - 5%)",
            initial_state={
                'variables': {
                    1: 50,    # chamber 5°C
                    2: 500,   # chamber 50% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                },
                'config': {'HAS_HUMIDIFIER': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'humidification': True,
                'relay_humidifier': 'on'
            }
        ))

        # Test 2: Humidity approaching target
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"HUM{self.test_counter:04d}",
            category="Humidification_With_Equipment",
            description="Humidity approaching target: Continue humidification",
            initial_state={
                'variables': {
                    1: 50,    # chamber 5°C
                    2: 700,   # chamber 70% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                },
                'config': {'HAS_HUMIDIFIER': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'humidification': True,
                'relay_humidifier': 'on'
            }
        ))

        # Test 3: AH reached target, stop humidifier
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"HUM{self.test_counter:04d}",
            category="Humidification_With_Equipment",
            description="AH at target: Stop humidifier",
            initial_state={
                'variables': {
                    1: 100,   # chamber 10°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                },
                'config': {'HAS_HUMIDIFIER': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'humidification': False,
                'relay_humidifier': 'off'
            }
        ))

        return scenarios

    def _generate_humidification_without_equipment_tests(self) -> List[TestScenario]:
        """Test 'better cold than dry' strategy when HAS_HUMIDIFIER = false"""
        scenarios = []

        # Test 1: Low AH, block heating
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"BCD{self.test_counter:04d}",
            category="Better_Cold_Than_Dry",
            description="No humidifier, low AH: Block heating to prevent over-drying",
            initial_state={
                'variables': {
                    1: 80,    # chamber 8°C
                    2: 600,   # chamber 60% RH (low AH)
                    3: 120,   # target 12°C
                    4: 850,   # target 85% RH (higher AH)
                },
                'config': {'HAS_HUMIDIFIER': False}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'kamra_futes': False,
                'befujt_futes': False,
                'heating_blocked_by_humidity': True
            }
        ))

        # Test 2: At minimum temp (11°C), block cooling
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"BCD{self.test_counter:04d}",
            category="Better_Cold_Than_Dry",
            description="No humidifier, at min temp 11°C: Block cooling",
            initial_state={
                'variables': {
                    1: 110,   # chamber 11°C (minimum)
                    2: 700,   # chamber 70% RH
                    3: 120,   # target 12°C
                    4: 850,   # target 85% RH
                },
                'config': {'HAS_HUMIDIFIER': False, 'MIN_TEMP_WITHOUT_HUMIDIFIER': 110}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'kamra_hutes_tiltas': True,
                'cooling_blocked_at_minimum_temp': True
            }
        ))

        # Test 3: Safe to heat (AH won't drop below target)
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"BCD{self.test_counter:04d}",
            category="Better_Cold_Than_Dry",
            description="No humidifier, safe AH: Allow heating",
            initial_state={
                'variables': {
                    1: 100,   # chamber 10°C
                    2: 900,   # chamber 90% RH (high AH)
                    3: 120,   # target 12°C
                    4: 850,   # target 85% RH
                },
                'config': {'HAS_HUMIDIFIER': False}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'kamra_para_futes_tiltas': False,
                'heating_allowed': True
            }
        ))

        return scenarios

    def _generate_bypass_outdoor_air_coordination_tests(self) -> List[TestScenario]:
        """Test bypass-outdoor air priority coordination"""
        scenarios = []

        # Test 1: Outdoor air active, bypass doesn't matter
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"BYP{self.test_counter:04d}",
            category="Bypass_Outdoor_Air_Coordination",
            description="Outdoor air active: Bypass state irrelevant (not using water)",
            initial_state={
                'variables': {
                    1: 120,   # chamber 12°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 0,     # outdoor 0°C
                    6: 600,   # outdoor 60% RH
                },
                'signals': {'sum_wint_jel': False, 'humi_save': False}  # Winter mode
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'add_air_max': True,
                'cool_rel': False,  # Pump off when using outdoor air
                'bypass_open': False  # Doesn't matter, pump off
            }
        ))

        # Test 2: Cooling without dehumi, no outdoor air - bypass OPEN
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"BYP{self.test_counter:04d}",
            category="Bypass_Outdoor_Air_Coordination",
            description="Cooling without dehumi, no outdoor air: Bypass OPEN (8°C water)",
            initial_state={
                'variables': {
                    1: 130,   # chamber 13°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 120,   # outdoor 12°C (not beneficial)
                    6: 800,   # outdoor 80% RH
                },
                'signals': {'sum_wint_jel': True, 'humi_save': False}  # Summer mode
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool': True,
                'dehumi': False,
                'bypass_open': True,  # Open for cooling without condensation
                'cool_rel': True      # Water cooling in summer
            }
        ))

        # Test 3: Dehumidification needed - bypass CLOSED
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"BYP{self.test_counter:04d}",
            category="Bypass_Outdoor_Air_Coordination",
            description="Dehumidification needed: Bypass CLOSED (0°C water)",
            initial_state={
                'variables': {
                    1: 120,   # chamber 12°C
                    2: 900,   # chamber 90% RH (high)
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                },
                'signals': {'sum_wint_jel': True, 'humi_save': False}  # Summer mode
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool': True,
                'dehumi': True,
                'bypass_open': False,  # Closed for cold water (0°C)
                'cool_rel': True
            }
        ))

        # Test 4: humi_save mode - bypass always OPEN
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"BYP{self.test_counter:04d}",
            category="Bypass_Outdoor_Air_Coordination",
            description="humi_save mode: Bypass always OPEN to preserve humidity",
            initial_state={
                'variables': {
                    1: 130,   # chamber 13°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                },
                'signals': {'sum_wint_jel': False, 'humi_save': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'bypass_open': True,  # Always open in humi_save mode
                'add_air_max': False  # Outdoor air blocked by humi_save
            }
        ))

        return scenarios

    def _generate_water_cooling_backup_tests(self) -> List[TestScenario]:
        """Test water cooling backup when outdoor temp diff <= 3°C"""
        scenarios = []

        # Test 1: Winter, small temp diff (2°C) - use water backup
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"WCB{self.test_counter:04d}",
            category="Water_Cooling_Backup",
            description="Winter, outdoor diff 2°C: Water cooling backup active",
            initial_state={
                'variables': {
                    1: 120,   # chamber 12°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 100,   # outdoor 10°C (only 2°C diff)
                    6: 700,   # outdoor 70% RH
                },
                'signals': {'sum_wint_jel': False, 'humi_save': False}  # Winter mode
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool': True,
                'cool_rel': True,  # Water cooling active as backup
                'add_air_max': False,  # Outdoor air not beneficial (small diff)
                'outdoor_temp_diff': 20  # 2.0°C in int*10
            }
        ))

        # Test 2: Winter, exact 3°C diff - threshold boundary
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"WCB{self.test_counter:04d}",
            category="Water_Cooling_Backup",
            description="Winter, outdoor diff 3°C: At threshold, water backup active",
            initial_state={
                'variables': {
                    1: 120,   # chamber 12°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 90,    # outdoor 9°C (exactly 3°C diff)
                    6: 700,   # outdoor 70% RH
                },
                'signals': {'sum_wint_jel': False}  # Winter mode
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool_rel': True,  # Water cooling active (at threshold)
                'outdoor_temp_diff': 30  # 3.0°C in int*10
            }
        ))

        # Test 3: Winter, large temp diff (10°C) - outdoor air preferred
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"WCB{self.test_counter:04d}",
            category="Water_Cooling_Backup",
            description="Winter, outdoor diff 10°C: Outdoor air preferred, no water",
            initial_state={
                'variables': {
                    1: 120,   # chamber 12°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 20,    # outdoor 2°C (10°C diff)
                    6: 600,   # outdoor 60% RH
                },
                'signals': {'sum_wint_jel': False}  # Winter mode
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool_rel': False,  # Water cooling OFF (outdoor air used)
                'add_air_max': True,  # Outdoor air active
                'outdoor_temp_diff': 100  # 10.0°C in int*10
            }
        ))

        # Test 4: Summer mode - always use water cooling
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"WCB{self.test_counter:04d}",
            category="Water_Cooling_Backup",
            description="Summer mode: Always water cooling regardless of outdoor diff",
            initial_state={
                'variables': {
                    1: 250,   # chamber 25°C
                    2: 800,   # chamber 80% RH
                    3: 200,   # target 20°C
                    4: 600,   # target 60% RH
                    5: 230,   # outdoor 23°C (only 2°C diff)
                    6: 700,   # outdoor 70% RH
                },
                'signals': {'sum_wint_jel': True}  # Summer mode
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool_rel': True,  # Water cooling in summer
                'add_air_max': False  # No outdoor air in summer
            }
        ))

        return scenarios

    def _generate_humi_save_mode_tests(self) -> List[TestScenario]:
        """Test humi_save mode interactions"""
        scenarios = []

        # Test 1: humi_save blocks outdoor air evaluation
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"HSM{self.test_counter:04d}",
            category="Humi_Save_Mode",
            description="humi_save ON: Block outdoor air evaluation",
            initial_state={
                'variables': {
                    1: 120,   # chamber 12°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 0,     # outdoor 0°C (would be beneficial)
                    6: 600,   # outdoor 60% RH
                },
                'signals': {'sum_wint_jel': False, 'humi_save': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'add_air_max': False,  # Outdoor air blocked
                'bypass_open': True,   # Bypass open to preserve humidity
                'reventon': True,      # Reventon active
                'add_air_save': True   # Air save active
            }
        ))

        # Test 2: humi_save with cooling needed
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"HSM{self.test_counter:04d}",
            category="Humi_Save_Mode",
            description="humi_save ON with cooling: Use water with bypass open",
            initial_state={
                'variables': {
                    1: 150,   # chamber 15°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 130,   # outdoor 13°C (small diff)
                    6: 800,   # outdoor 80% RH
                },
                'signals': {'sum_wint_jel': False, 'humi_save': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool': True,
                'cool_rel': True,      # Water cooling (small outdoor diff)
                'bypass_open': True,   # Open to preserve humidity (8°C water)
                'add_air_max': False   # No outdoor air
            }
        ))

        return scenarios

    def _generate_temperature_difference_threshold_tests(self) -> List[TestScenario]:
        """Test various temperature difference scenarios"""
        scenarios = []

        # Test temperature differences: 0°C, 1°C, 2°C, 3°C, 4°C, 5°C, 10°C, 20°C
        temp_diffs = [0, 10, 20, 30, 40, 50, 100, 200]  # in int*10

        for i, diff in enumerate(temp_diffs):
            self.test_counter += 1
            outdoor_temp = 120 - diff  # Chamber at 12°C

            expect_water_backup = diff <= 30  # <= 3°C threshold

            scenarios.append(TestScenario(
                test_id=f"TDT{self.test_counter:04d}",
                category="Temperature_Difference_Threshold",
                description=f"Winter, outdoor diff {diff/10:.1f}°C: Water backup = {expect_water_backup}",
                initial_state={
                    'variables': {
                        1: 120,   # chamber 12°C
                        2: 850,   # chamber 85% RH
                        3: 100,   # target 10°C
                        4: 850,   # target 85% RH
                        5: outdoor_temp,  # outdoor varies
                        6: 700,   # outdoor 70% RH
                    },
                    'signals': {'sum_wint_jel': False}  # Winter mode
                },
                inputs={'controlling_cycle': True},
                expected_output={
                    'outdoor_temp_diff': diff,
                    'water_backup_active': expect_water_backup
                }
            ))

        return scenarios

    def _generate_better_cold_than_dry_tests(self) -> List[TestScenario]:
        """Additional 'better cold than dry' edge cases"""
        scenarios = []

        # Various AH scenarios without humidifier
        test_cases = [
            {
                'chamber_temp': 80, 'chamber_rh': 500,  # Low AH
                'target_temp': 120, 'target_rh': 850,    # High AH needed
                'expect_heating': False,  # Block heating
                'description': 'Very low AH, block heating'
            },
            {
                'chamber_temp': 100, 'chamber_rh': 900,  # High AH
                'target_temp': 120, 'target_rh': 700,    # Lower AH target
                'expect_heating': True,   # Allow heating
                'description': 'High AH, safe to heat'
            },
            {
                'chamber_temp': 110, 'chamber_rh': 600,  # At min temp, low RH
                'target_temp': 120, 'target_rh': 850,
                'expect_cooling_block': True,  # Block cooling at min temp
                'description': 'At 11°C minimum, block cooling'
            },
            {
                'chamber_temp': 130, 'chamber_rh': 700,  # Above min temp
                'target_temp': 120, 'target_rh': 850,
                'expect_cooling': True,  # Allow cooling to increase RH
                'description': 'Above min temp, allow cooling to increase RH'
            },
        ]

        for test_case in test_cases:
            self.test_counter += 1
            scenarios.append(TestScenario(
                test_id=f"BCD{self.test_counter:04d}",
                category="Better_Cold_Than_Dry",
                description=f"No humidifier: {test_case['description']}",
                initial_state={
                    'variables': {
                        1: test_case['chamber_temp'],
                        2: test_case['chamber_rh'],
                        3: test_case['target_temp'],
                        4: test_case['target_rh'],
                    },
                    'config': {'HAS_HUMIDIFIER': False}
                },
                inputs={'controlling_cycle': True},
                expected_output=test_case
            ))

        return scenarios

    def _generate_combined_scenario_tests(self) -> List[TestScenario]:
        """Complex combined scenarios testing multiple features"""
        scenarios = []

        # Scenario 1: Winter + humi_save + small outdoor diff + cooling needed
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"CMB{self.test_counter:04d}",
            category="Combined_Scenarios",
            description="Winter+humi_save+small_diff+cooling: Water with bypass",
            initial_state={
                'variables': {
                    1: 140,   # chamber 14°C
                    2: 850,   # chamber 85% RH
                    3: 100,   # target 10°C
                    4: 850,   # target 85% RH
                    5: 120,   # outdoor 12°C (only 2°C diff)
                    6: 700,   # outdoor 70% RH
                },
                'signals': {'sum_wint_jel': False, 'humi_save': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'cool': True,
                'cool_rel': True,      # Water backup (small diff)
                'bypass_open': True,   # Preserve humidity
                'add_air_max': False,  # Blocked by humi_save
                'dehumi': False
            }
        ))

        # Scenario 2: Winter + no humidifier + low AH + heating needed
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"CMB{self.test_counter:04d}",
            category="Combined_Scenarios",
            description="Winter+no_humidifier+low_AH+heating: Block heating",
            initial_state={
                'variables': {
                    1: 80,    # chamber 8°C
                    2: 600,   # chamber 60% RH (low AH)
                    3: 120,   # target 12°C
                    4: 850,   # target 85% RH (high AH)
                    5: 50,    # outdoor 5°C
                    6: 500,   # outdoor 50% RH
                },
                'signals': {'sum_wint_jel': False},
                'config': {'HAS_HUMIDIFIER': False}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'kamra_futes': False,  # Heating blocked
                'befujt_futes': False,
                'warm': False
            }
        ))

        # Scenario 3: Summer + dehumidification + humidification conflict
        self.test_counter += 1
        scenarios.append(TestScenario(
            test_id=f"CMB{self.test_counter:04d}",
            category="Combined_Scenarios",
            description="Summer+high_humidity: Dehumidify (no humidifier)",
            initial_state={
                'variables': {
                    1: 200,   # chamber 20°C
                    2: 900,   # chamber 90% RH (too high)
                    3: 200,   # target 20°C
                    4: 600,   # target 60% RH
                },
                'signals': {'sum_wint_jel': True},  # Summer mode
                'config': {'HAS_HUMIDIFIER': True}
            },
            inputs={'controlling_cycle': True},
            expected_output={
                'dehumi': True,
                'humidification': False,  # Can't humidify and dehumidify
                'bypass_open': False,     # Need cold water (0°C)
                'cool_rel': True
            }
        ))

        # Add 700+ more systematic test combinations
        scenarios.extend(self._generate_systematic_combinations())

        return scenarios

    def _generate_systematic_combinations(self) -> List[TestScenario]:
        """Generate systematic combinations of all parameters"""
        scenarios = []

        # Temperature ranges
        temps = [50, 80, 100, 120, 150, 200, 250]  # 5°C to 25°C

        # Humidity ranges
        humidities = [400, 600, 700, 850, 900]  # 40% to 90%

        # Modes
        modes = [
            {'sum_wint_jel': False, 'humi_save': False, 'name': 'winter'},
            {'sum_wint_jel': True, 'humi_save': False, 'name': 'summer'},
            {'sum_wint_jel': False, 'humi_save': True, 'name': 'winter_humi_save'},
        ]

        # Outdoor conditions
        outdoor_conditions = [
            {'temp': 0, 'rh': 600, 'name': 'cold_dry'},
            {'temp': 100, 'rh': 700, 'name': 'mild'},
            {'temp': 200, 'rh': 800, 'name': 'warm_humid'},
        ]

        # Configuration
        configs = [
            {'HAS_HUMIDIFIER': True, 'name': 'with_humidifier'},
            {'HAS_HUMIDIFIER': False, 'name': 'no_humidifier'},
        ]

        # Generate combinations
        for chamber_temp in temps:
            for chamber_rh in humidities:
                for target_temp in temps:
                    for target_rh in humidities:
                        for mode in modes:
                            for outdoor in outdoor_conditions:
                                for config in configs:
                                    # Skip some redundant combinations
                                    if abs(chamber_temp - target_temp) < 20 and chamber_rh == target_rh:
                                        continue  # Skip near-equilibrium states

                                    if len(scenarios) >= 2000:  # Limit to ~2000 systematic tests
                                        return scenarios

                                    self.test_counter += 1
                                    scenarios.append(TestScenario(
                                        test_id=f"SYS{self.test_counter:04d}",
                                        category="Systematic_Combinations",
                                        description=f"{mode['name']}_{outdoor['name']}_{config['name']}_c{chamber_temp}_{chamber_rh}_t{target_temp}_{target_rh}",
                                        initial_state={
                                            'variables': {
                                                1: chamber_temp,
                                                2: chamber_rh,
                                                3: target_temp,
                                                4: target_rh,
                                                5: outdoor['temp'],
                                                6: outdoor['rh'],
                                            },
                                            'signals': mode,
                                            'config': config
                                        },
                                        inputs={'controlling_cycle': True},
                                        expected_output={
                                            'test_completes': True
                                        }
                                    ))

        return scenarios

if __name__ == '__main__':
    gen = ComprehensiveScenarioGenerator()
    scenarios = gen.generate_all_scenarios()
    print(f"Generated {len(scenarios)} comprehensive test scenarios")
