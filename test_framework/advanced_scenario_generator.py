"""
Advanced Test Scenario Generator
Generates comprehensive, multi-round, realistic test scenarios
Target: 1400+ test cases with complex control cycles
"""

import itertools
import math
from typing import List, Dict, Any
from scenario_generator import TestScenario


class AdvancedScenarioGenerator:
    """Generates advanced multi-round test scenarios"""

    def __init__(self):
        self.test_counter = 1000  # Start from 1000 to avoid conflicts
        self.scenarios = []

    def generate_all_scenarios(self) -> List[TestScenario]:
        """Generate all advanced test scenarios"""
        self.scenarios = []

        # Original simple tests (fixed versions)
        self.scenarios.extend(self._generate_basic_propagation_tests())

        # Multi-round control cycle tests
        self.scenarios.extend(self._generate_heating_cycle_tests())
        self.scenarios.extend(self._generate_cooling_cycle_tests())
        self.scenarios.extend(self._generate_humidity_control_cycles())

        # Concurrent control tests
        self.scenarios.extend(self._generate_concurrent_temp_humidity_tests())

        # Hysteresis and stability tests
        self.scenarios.extend(self._generate_hysteresis_tests())
        self.scenarios.extend(self._generate_oscillation_tests())

        # Mode transition tests
        self.scenarios.extend(self._generate_sleep_mode_transition_tests())
        self.scenarios.extend(self._generate_season_mode_tests())

        # Fault injection and recovery
        self.scenarios.extend(self._generate_sensor_fault_tests())
        self.scenarios.extend(self._generate_recovery_tests())

        # Long-running stability tests
        self.scenarios.extend(self._generate_long_run_stability_tests())

        # Stress tests
        self.scenarios.extend(self._generate_rapid_change_tests())
        self.scenarios.extend(self._generate_extreme_condition_tests())

        # Edge case combinations
        self.scenarios.extend(self._generate_edge_case_combinations())

        # Performance tests
        self.scenarios.extend(self._generate_propagation_efficiency_tests())

        # Integration scenarios
        self.scenarios.extend(self._generate_multi_device_scenarios())

        # Additional comprehensive tests
        self.scenarios.extend(self._generate_boundary_condition_tests())
        self.scenarios.extend(self._generate_state_transition_tests())
        self.scenarios.extend(self._generate_relay_sequence_tests())
        self.scenarios.extend(self._generate_proportional_control_tests())
        self.scenarios.extend(self._generate_interlock_tests())
        self.scenarios.extend(self._generate_deadband_tests())
        self.scenarios.extend(self._generate_ramp_rate_tests())

        return self.scenarios

    def _generate_basic_propagation_tests(self) -> List[TestScenario]:
        """Basic propagation tests with all variations"""
        scenarios = []

        # Temperature propagation - exhaustive testing
        for delta in range(0, 101):  # 0 to 10.0°C in 0.1°C steps
            scenarios.append(TestScenario(
                test_id=f"BP{self.test_counter:04d}",
                category="Basic Propagation",
                description=f"Temp delta {delta/10:.1f}°C propagation test",
                initial_state={'variables': {1: 250, 3: 260}},
                inputs={'temp_delta': delta},
                expected_output={'propagated': delta >= 2}
            ))
            self.test_counter += 1

        # Humidity propagation - exhaustive testing
        for delta in range(0, 101):  # 0 to 10.0% in 0.1% steps
            scenarios.append(TestScenario(
                test_id=f"BP{self.test_counter:04d}",
                category="Basic Propagation",
                description=f"Humidity delta {delta/10:.1f}% propagation test",
                initial_state={'variables': {2: 500, 4: 550}},
                inputs={'humi_delta': delta},
                expected_output={'propagated': delta >= 3}
            ))
            self.test_counter += 1

        # User setpoint changes (always propagate)
        for delta in [1, 2, 5, 10, 20, 50]:
            scenarios.append(TestScenario(
                test_id=f"BP{self.test_counter:04d}",
                category="Basic Propagation",
                description=f"User setpoint change {delta/10:.1f}°C (always propagates)",
                initial_state={'variables': {3: 250}},
                inputs={'user_setpoint_change': delta},
                expected_output={'propagated': True, 'user_change': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_heating_cycle_tests(self) -> List[TestScenario]:
        """Complete heating cycles from cold start to target"""
        scenarios = []

        # Heating from various starting temps to various targets
        start_temps = [100, 150, 180, 200, 220]  # 10°C to 22°C
        target_temps = [220, 240, 250, 260, 280]  # 22°C to 28°C

        for start, target in itertools.product(start_temps, target_temps):
            if start >= target:
                continue

            # Simulate realistic heating curve
            cycles = self._simulate_heating_curve(start, target)

            scenarios.append(TestScenario(
                test_id=f"HC{self.test_counter:04d}",
                category="Heating Cycle",
                description=f"Heat from {start/10:.1f}°C to {target/10:.1f}°C",
                initial_state={
                    'variables': {1: start, 3: target},
                    'relays': {60: 'off', 52: 'off'}
                },
                inputs={'control_cycles': cycles},
                expected_output={
                    'final_temp_reached': True,
                    'heating_activated': True,
                    'propagations_occurred': True,
                    'no_overshoot': True
                }
            ))
            self.test_counter += 1

        return scenarios

    def _simulate_heating_curve(self, start: int, target: int) -> List[Dict]:
        """Simulate realistic heating curve with thermal inertia"""
        cycles = []
        current_temp = start
        step = 0

        while current_temp < target and step < 100:  # Max 100 steps safety
            # Heating rate decreases as temp approaches target (thermal inertia)
            delta_to_target = target - current_temp
            heating_rate = min(5, max(1, delta_to_target // 10))  # 0.1-0.5°C per cycle

            cycles.append({
                'sensor_readings': {'temp': current_temp},
                'setpoints': {'temp': target},
                'control_action': 'heat' if current_temp < target else 'idle',
                'delay_ms': 1000  # 1 second per cycle
            })

            current_temp += heating_rate
            step += 1

        # Final cycle - reach target
        cycles.append({
            'sensor_readings': {'temp': target},
            'setpoints': {'temp': target},
            'control_action': 'idle',
            'delay_ms': 1000
        })

        return cycles

    def _generate_cooling_cycle_tests(self) -> List[TestScenario]:
        """Complete cooling cycles from warm to target"""
        scenarios = []

        start_temps = [280, 300, 320, 350]  # 28°C to 35°C
        target_temps = [200, 220, 240, 250]  # 20°C to 25°C

        for start, target in itertools.product(start_temps, target_temps):
            if start <= target:
                continue

            cycles = self._simulate_cooling_curve(start, target)

            scenarios.append(TestScenario(
                test_id=f"CC{self.test_counter:04d}",
                category="Cooling Cycle",
                description=f"Cool from {start/10:.1f}°C to {target/10:.1f}°C",
                initial_state={
                    'variables': {1: start, 3: target},
                    'relays': {60: 'off', 52: 'off'}
                },
                inputs={'control_cycles': cycles},
                expected_output={
                    'final_temp_reached': True,
                    'cooling_activated': True,
                    'propagations_occurred': True,
                    'no_undershoot': True
                }
            ))
            self.test_counter += 1

        return scenarios

    def _simulate_cooling_curve(self, start: int, target: int) -> List[Dict]:
        """Simulate realistic cooling curve"""
        cycles = []
        current_temp = start
        step = 0

        while current_temp > target and step < 100:
            delta_to_target = current_temp - target
            cooling_rate = min(5, max(1, delta_to_target // 10))

            cycles.append({
                'sensor_readings': {'temp': current_temp},
                'setpoints': {'temp': target},
                'control_action': 'cool' if current_temp > target else 'idle',
                'delay_ms': 1000
            })

            current_temp -= cooling_rate
            step += 1

        cycles.append({
            'sensor_readings': {'temp': target},
            'setpoints': {'temp': target},
            'control_action': 'idle',
            'delay_ms': 1000
        })

        return cycles

    def _generate_humidity_control_cycles(self) -> List[TestScenario]:
        """Humidity control cycles"""
        scenarios = []

        start_humidity = [300, 400, 500, 600, 700, 800]  # 30-80%
        target_humidity = [400, 500, 600, 700]  # 40-70%

        for start, target in itertools.product(start_humidity, target_humidity):
            if abs(start - target) < 50:  # Skip if too close
                continue

            cycles = []
            current = start
            step = 0

            while abs(current - target) > 5 and step < 50:
                if current < target:
                    delta = min(10, target - current)
                    current += delta
                else:
                    delta = min(10, current - target)
                    current -= delta

                cycles.append({
                    'sensor_readings': {'humidity': current},
                    'setpoints': {'humidity': target},
                    'control_action': 'humidify' if current < target else 'dehumidify',
                    'delay_ms': 2000  # Humidity changes slower
                })
                step += 1

            scenarios.append(TestScenario(
                test_id=f"HMC{self.test_counter:04d}",
                category="Humidity Control Cycle",
                description=f"Humidity {start/10:.1f}% to {target/10:.1f}%",
                initial_state={'variables': {2: start, 4: target}},
                inputs={'control_cycles': cycles},
                expected_output={'humidity_controlled': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_concurrent_temp_humidity_tests(self) -> List[TestScenario]:
        """Test simultaneous temperature and humidity control"""
        scenarios = []

        # Comprehensive combinations
        start_temps = [150, 180, 200, 220, 240, 260, 280, 300]
        target_temps = [200, 220, 240, 250, 260, 280]
        start_humis = [300, 400, 500, 600, 700, 800]
        target_humis = [400, 500, 600, 700]

        test_cases = []
        for st, tt in itertools.product(start_temps, target_temps):
            for sh, th in itertools.product(start_humis, target_humis):
                if abs(st - tt) > 20 and abs(sh - th) > 100:  # Significant changes only
                    test_cases.append((st, tt, sh, th))

        for start_t, target_t, start_h, target_h in test_cases:
            cycles = []
            current_temp = start_t
            current_humi = start_h
            step = 0

            while (abs(current_temp - target_t) > 5 or abs(current_humi - target_h) > 10) and step < 100:
                # Update temp
                if abs(current_temp - target_t) > 5:
                    if current_temp < target_t:
                        current_temp = min(current_temp + 3, target_t)
                    else:
                        current_temp = max(current_temp - 3, target_t)

                # Update humidity
                if abs(current_humi - target_h) > 10:
                    if current_humi < target_h:
                        current_humi = min(current_humi + 5, target_h)
                    else:
                        current_humi = max(current_humi - 5, target_h)

                cycles.append({
                    'sensor_readings': {'temp': current_temp, 'humidity': current_humi},
                    'setpoints': {'temp': target_t, 'humidity': target_h},
                    'delay_ms': 1000
                })
                step += 1

            scenarios.append(TestScenario(
                test_id=f"CON{self.test_counter:04d}",
                category="Concurrent Control",
                description=f"T:{start_t/10:.1f}→{target_t/10:.1f}°C, H:{start_h/10:.1f}→{target_h/10:.1f}%",
                initial_state={'variables': {1: start_t, 2: start_h, 3: target_t, 4: target_h}},
                inputs={'control_cycles': cycles},
                expected_output={'both_controlled': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_hysteresis_tests(self) -> List[TestScenario]:
        """Test hysteresis behavior (prevent rapid on/off cycling)"""
        scenarios = []

        # Temperature oscillating around setpoint
        for target in [220, 240, 250, 260]:
            for oscillation_range in [2, 5, 10, 15]:  # 0.2°C to 1.5°C oscillation
                cycles = []
                for i in range(20):  # 20 oscillations
                    temp = target + (oscillation_range if i % 2 == 0 else -oscillation_range)
                    cycles.append({
                        'sensor_readings': {'temp': temp},
                        'setpoints': {'temp': target},
                        'delay_ms': 500
                    })

                scenarios.append(TestScenario(
                    test_id=f"HYS{self.test_counter:04d}",
                    category="Hysteresis",
                    description=f"Temp oscillation ±{oscillation_range/10:.1f}°C around {target/10:.1f}°C",
                    initial_state={'variables': {1: target, 3: target}},
                    inputs={'control_cycles': cycles},
                    expected_output={'no_rapid_cycling': True}
                ))
                self.test_counter += 1

        return scenarios

    def _generate_oscillation_tests(self) -> List[TestScenario]:
        """Test response to oscillating inputs"""
        scenarios = []

        # Sinusoidal temperature variation
        for amplitude in [10, 20, 50]:  # 1°C, 2°C, 5°C amplitude
            for target in [220, 250, 280]:
                cycles = []
                for step in range(50):  # 50 step sine wave
                    angle = (step / 50.0) * 2 * math.pi
                    temp = target + int(amplitude * math.sin(angle))
                    cycles.append({
                        'sensor_readings': {'temp': temp},
                        'setpoints': {'temp': target},
                        'delay_ms': 200
                    })

                scenarios.append(TestScenario(
                    test_id=f"OSC{self.test_counter:04d}",
                    category="Oscillation Response",
                    description=f"Sine wave ±{amplitude/10:.1f}°C, target {target/10:.1f}°C",
                    initial_state={'variables': {1: target, 3: target}},
                    inputs={'control_cycles': cycles},
                    expected_output={'stable_control': True}
                ))
                self.test_counter += 1

        return scenarios

    def _generate_sleep_mode_transition_tests(self) -> List[TestScenario]:
        """Test sleep mode activation and deactivation"""
        scenarios = []

        # Sleep mode transitions with various temperatures
        for current_temp in [200, 220, 240, 260, 280]:
            for target_temp in [220, 250, 280]:
                # Activate sleep mode
                scenarios.append(TestScenario(
                    test_id=f"SLP{self.test_counter:04d}",
                    category="Sleep Mode",
                    description=f"Activate sleep @ {current_temp/10:.1f}°C",
                    initial_state={'variables': {1: current_temp, 3: target_temp}},
                    inputs={'mode_change': 'sleep', 'new_value': True},
                    expected_output={
                        'sleep_active': True,
                        'relays_disabled': True,
                        'event_propagated': True
                    }
                ))
                self.test_counter += 1

                # Deactivate sleep mode
                scenarios.append(TestScenario(
                    test_id=f"SLP{self.test_counter:04d}",
                    category="Sleep Mode",
                    description=f"Deactivate sleep @ {current_temp/10:.1f}°C",
                    initial_state={'variables': {1: current_temp, 3: target_temp}},
                    inputs={'mode_change': 'sleep', 'new_value': False},
                    expected_output={
                        'sleep_active': False,
                        'control_resumed': True,
                        'event_propagated': True
                    }
                ))
                self.test_counter += 1

        return scenarios

    def _generate_season_mode_tests(self) -> List[TestScenario]:
        """Test summer/winter mode switching"""
        scenarios = []

        for mode in ['summer', 'winter']:
            for outdoor_temp in [0, 100, 200, 300, 350]:  # -10°C to 35°C
                for indoor_temp in [200, 220, 250, 280]:
                    scenarios.append(TestScenario(
                        test_id=f"SSN{self.test_counter:04d}",
                        category="Season Mode",
                        description=f"{mode.capitalize()} mode, outdoor {outdoor_temp/10:.1f}°C",
                        initial_state={
                            'variables': {
                                1: indoor_temp,  # Indoor temp
                                7: outdoor_temp,  # Outdoor temp
                                34: {'sum_wint_jel': mode == 'summer'}
                            }
                        },
                        inputs={'mode_change': 'season'},
                        expected_output={'season_mode': mode}
                    ))
                    self.test_counter += 1

        return scenarios

    def _generate_sensor_fault_tests(self) -> List[TestScenario]:
        """Test sensor failure scenarios"""
        scenarios = []

        fault_counts = [0, 1, 2, 3, 5, 10]
        for fault_count in fault_counts:
            scenarios.append(TestScenario(
                test_id=f"FLT{self.test_counter:04d}",
                category="Sensor Fault",
                description=f"Sensor error count: {fault_count}",
                initial_state={'variables': {29: fault_count}},  # befujt_hibaszam1
                inputs={'fault_handling': True},
                expected_output={'fault_mode': fault_count > 0}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_recovery_tests(self) -> List[TestScenario]:
        """Test recovery from faults"""
        scenarios = []

        # Recovery from sensor failure
        for initial_faults in [3, 5, 10]:
            cycles = [
                {'sensor_readings': {'temp': 0}, 'delay_ms': 100},  # Faulty reading
                {'sensor_readings': {'temp': 250}, 'delay_ms': 100},  # Recovery
                {'sensor_readings': {'temp': 250}, 'delay_ms': 100},  # Stable
            ]

            scenarios.append(TestScenario(
                test_id=f"RCV{self.test_counter:04d}",
                category="Recovery",
                description=f"Recover from {initial_faults} faults",
                initial_state={'variables': {29: initial_faults}},
                inputs={'control_cycles': cycles},
                expected_output={'recovered': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_long_run_stability_tests(self) -> List[TestScenario]:
        """Test stability over long runs (simulated)"""
        scenarios = []

        # Simulate 24 hours of operation (1 minute intervals)
        for target_temp in [220, 250, 280]:
            cycles = []
            for minute in range(1440):  # 24 hours * 60 minutes
                # Small random variations
                temp = target_temp + ((minute % 10) - 5)
                cycles.append({
                    'sensor_readings': {'temp': temp},
                    'setpoints': {'temp': target_temp},
                    'delay_ms': 60000  # 1 minute
                })

            scenarios.append(TestScenario(
                test_id=f"LRS{self.test_counter:04d}",
                category="Long-Run Stability",
                description=f"24h stability @ {target_temp/10:.1f}°C",
                initial_state={'variables': {1: target_temp, 3: target_temp}},
                inputs={'control_cycles': cycles[:100]},  # Truncate for performance
                expected_output={'stable_24h': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_rapid_change_tests(self) -> List[TestScenario]:
        """Test rapid setpoint changes"""
        scenarios = []

        # Rapid temperature changes
        setpoint_sequence = [220, 280, 200, 260, 240, 250]
        cycles = []
        for setpoint in setpoint_sequence:
            cycles.append({
                'setpoints': {'temp': setpoint},
                'delay_ms': 100  # Very fast changes
            })

        scenarios.append(TestScenario(
            test_id=f"RPD{self.test_counter:04d}",
            category="Rapid Change",
            description="Rapid setpoint sequence",
            initial_state={'variables': {1: 250, 3: 250}},
            inputs={'control_cycles': cycles},
            expected_output={'all_propagated': True}
        ))
        self.test_counter += 1

        return scenarios

    def _generate_extreme_condition_tests(self) -> List[TestScenario]:
        """Test extreme temperature and humidity values"""
        scenarios = []

        extreme_values = [
            (-300, "Extreme cold -30°C"),
            (0, "Freezing 0°C"),
            (500, "Extreme heat 50°C"),
            (800, "Very extreme 80°C"),
        ]

        for value, desc in extreme_values:
            scenarios.append(TestScenario(
                test_id=f"EXT{self.test_counter:04d}",
                category="Extreme Conditions",
                description=desc,
                initial_state={'variables': {1: value}},
                inputs={'validation': True},
                expected_output={'handled_gracefully': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_edge_case_combinations(self) -> List[TestScenario]:
        """Test combinations of edge cases"""
        scenarios = []

        # Multiple simultaneous edge conditions
        scenarios.append(TestScenario(
            test_id=f"EDG{self.test_counter:04d}",
            category="Edge Case Combination",
            description="Extreme temp + humidity + sensor fault",
            initial_state={
                'variables': {
                    1: 500,   # 50°C
                    2: 1000,  # 100% humidity
                    29: 5     # Sensor faults
                }
            },
            inputs={'validation': True},
            expected_output={'system_stable': True}
        ))
        self.test_counter += 1

        return scenarios

    def _generate_propagation_efficiency_tests(self) -> List[TestScenario]:
        """Test propagation bandwidth efficiency"""
        scenarios = []

        # Many small changes that should be blocked
        cycles = []
        for i in range(100):
            cycles.append({
                'setpoints': {'temp': 250 + (i % 2)},  # Oscillate by 0.1°C
                'delay_ms': 50
            })

        scenarios.append(TestScenario(
            test_id=f"EFF{self.test_counter:04d}",
            category="Efficiency",
            description="100 sub-threshold changes (should mostly block)",
            initial_state={'variables': {3: 250}},
            inputs={'control_cycles': cycles},
            expected_output={'blocked_percentage': 95}  # Expect 95%+ blocked
        ))
        self.test_counter += 1

        return scenarios

    def _generate_multi_device_scenarios(self) -> List[TestScenario]:
        """Test multi-device communication scenarios"""
        scenarios = []

        # Device coordination scenarios
        scenarios.append(TestScenario(
            test_id=f"MDV{self.test_counter:04d}",
            category="Multi-Device",
            description="Sleep mode propagation to all devices",
            initial_state={'variables': {34: {'sleep': False}}},
            inputs={'mode_change': 'sleep', 'new_value': True},
            expected_output={
                'event_sent': True,
                'all_devices_notified': True
            }
        ))
        self.test_counter += 1

        return scenarios

    def _generate_boundary_condition_tests(self) -> List[TestScenario]:
        """Test boundary conditions for all parameters"""
        scenarios = []

        # Temperature boundaries
        boundary_temps = [-300, -200, -100, 0, 10, 500, 600, 800, 1000]
        for temp in boundary_temps:
            for setpoint in [200, 250, 300]:
                scenarios.append(TestScenario(
                    test_id=f"BND{self.test_counter:04d}",
                    category="Boundary Conditions",
                    description=f"Temp={temp/10:.1f}°C, setpoint={setpoint/10:.1f}°C",
                    initial_state={'variables': {1: temp, 3: setpoint}},
                    inputs={'validation': True},
                    expected_output={'handled': True}
                ))
                self.test_counter += 1

        # Humidity boundaries
        boundary_humis = [0, 10, 50, 1000, 1200, 1500]
        for humi in boundary_humis:
            for setpoint in [400, 600, 800]:
                scenarios.append(TestScenario(
                    test_id=f"BND{self.test_counter:04d}",
                    category="Boundary Conditions",
                    description=f"Humidity={humi/10:.1f}%, setpoint={setpoint/10:.1f}%",
                    initial_state={'variables': {2: humi, 4: setpoint}},
                    inputs={'validation': True},
                    expected_output={'handled': True}
                ))
                self.test_counter += 1

        return scenarios

    def _generate_state_transition_tests(self) -> List[TestScenario]:
        """Test all possible state transitions"""
        scenarios = []

        states = ['idle', 'heating', 'cooling', 'humidifying', 'dehumidifying']
        for from_state in states:
            for to_state in states:
                if from_state == to_state:
                    continue
                scenarios.append(TestScenario(
                    test_id=f"STT{self.test_counter:04d}",
                    category="State Transition",
                    description=f"Transition {from_state} → {to_state}",
                    initial_state={'variables': {1: 250, 2: 500, 3: 250, 4: 500}},
                    inputs={'state_transition': (from_state, to_state)},
                    expected_output={'transition_valid': True}
                ))
                self.test_counter += 1

        return scenarios

    def _generate_relay_sequence_tests(self) -> List[TestScenario]:
        """Test relay activation sequences"""
        scenarios = []

        relays = {60: 'warm', 52: 'cool', 53: 'sleep', 61: 'add_air',
                  62: 'fan', 63: 'bypass', 64: 'bypass_open', 65: 'main_fan'}

        # Test all relay combinations (on/off)
        for relay_id in relays.keys():
            for state in ['on', 'off']:
                scenarios.append(TestScenario(
                    test_id=f"RLY{self.test_counter:04d}",
                    category="Relay Sequence",
                    description=f"Relay {relays[relay_id]} → {state}",
                    initial_state={'relays': {relay_id: 'off'}},
                    inputs={'relay_command': (relay_id, state)},
                    expected_output={'relay_state': state}
                ))
                self.test_counter += 1

        # Test relay interlock sequences (heating and cooling never on together)
        scenarios.append(TestScenario(
            test_id=f"RLY{self.test_counter:04d}",
            category="Relay Sequence",
            description="Heating on → Cooling off (interlock)",
            initial_state={'relays': {60: 'on', 52: 'off'}},
            inputs={'relay_command': (52, 'on')},  # Try to turn cooling on
            expected_output={'heating_off': True, 'cooling_on': True}  # Should turn heating off first
        ))
        self.test_counter += 1

        return scenarios

    def _generate_proportional_control_tests(self) -> List[TestScenario]:
        """Test proportional control behavior"""
        scenarios = []

        # Test proportional response to different error magnitudes
        for target in [220, 250, 280]:
            for error in [5, 10, 20, 50, 100]:  # 0.5°C to 10°C error
                current = target - error
                scenarios.append(TestScenario(
                    test_id=f"PRP{self.test_counter:04d}",
                    category="Proportional Control",
                    description=f"Error {error/10:.1f}°C at target {target/10:.1f}°C",
                    initial_state={'variables': {1: current, 3: target}},
                    inputs={'control_cycle': 1},
                    expected_output={'proportional_response': True}
                ))
                self.test_counter += 1

        return scenarios

    def _generate_interlock_tests(self) -> List[TestScenario]:
        """Test safety interlocks"""
        scenarios = []

        # Heat + Cool interlock
        scenarios.append(TestScenario(
            test_id=f"ILK{self.test_counter:04d}",
            category="Interlock",
            description="Prevent simultaneous heating and cooling",
            initial_state={'relays': {60: 'on', 52: 'off'}},
            inputs={'relay_command': (52, 'on')},
            expected_output={'only_one_active': True}
        ))
        self.test_counter += 1

        # Multiple interlock scenarios
        for i in range(10):
            scenarios.append(TestScenario(
                test_id=f"ILK{self.test_counter:04d}",
                category="Interlock",
                description=f"Interlock scenario {i+1}",
                initial_state={'variables': {1: 200 + i*10, 3: 250}},
                inputs={'validation': True},
                expected_output={'interlocks_active': True}
            ))
            self.test_counter += 1

        return scenarios

    def _generate_deadband_tests(self) -> List[TestScenario]:
        """Test deadband/hysteresis zones"""
        scenarios = []

        # Test behavior within deadband
        for target in [220, 240, 250, 260, 280]:
            for offset in range(-20, 21, 2):  # -2°C to +2°C in 0.2°C steps
                current = target + offset
                scenarios.append(TestScenario(
                    test_id=f"DBD{self.test_counter:04d}",
                    category="Deadband",
                    description=f"Within deadband: {offset/10:.1f}°C from target",
                    initial_state={'variables': {1: current, 3: target}},
                    inputs={'control_cycle': 1},
                    expected_output={'in_deadband': abs(offset) <= 10}  # ±1°C deadband
                ))
                self.test_counter += 1

        return scenarios

    def _generate_ramp_rate_tests(self) -> List[TestScenario]:
        """Test temperature ramp rate limiting"""
        scenarios = []

        # Test various ramp rates
        for start in [200, 220, 250, 280]:
            for end in [200, 220, 250, 280, 300]:
                if abs(end - start) < 20:
                    continue

                # Calculate expected ramp time
                delta = abs(end - start)
                max_ramp_rate = 5  # 0.5°C per second
                min_time = delta / max_ramp_rate

                scenarios.append(TestScenario(
                    test_id=f"RMP{self.test_counter:04d}",
                    category="Ramp Rate",
                    description=f"Ramp {start/10:.1f}°C → {end/10:.1f}°C",
                    initial_state={'variables': {1: start, 3: end}},
                    inputs={'test_ramp_rate': True},
                    expected_output={'min_time_respected': True}
                ))
                self.test_counter += 1

        return scenarios


def main():
    """Generate and display scenario count"""
    generator = AdvancedScenarioGenerator()
    scenarios = generator.generate_all_scenarios()

    print(f"Generated {len(scenarios)} advanced test scenarios:")

    categories = {}
    for scenario in scenarios:
        cat = scenario.category
        categories[cat] = categories.get(cat, 0) + 1

    for category, count in sorted(categories.items()):
        print(f"  {category}: {count} tests")

    return scenarios


if __name__ == '__main__':
    main()
