"""
Mock Tech Sinum Device Environment for Testing
Simulates the Tech Sinum platform APIs and environment
"""

class MockVariable:
    """Simulates Tech Sinum variable object"""
    def __init__(self, value=0):
        self._value = value
        self._propagation_log = []

    def getValue(self, default=None):
        return self._value if self._value is not None else default

    def setValue(self, value, stop_propagation=False):
        """
        Sets value with propagation control
        stop_propagation=True blocks event propagation
        stop_propagation=False allows event propagation
        """
        old_value = self._value
        self._value = value
        self._propagation_log.append({
            'old': old_value,
            'new': value,
            'propagated': not stop_propagation
        })
        return value

    def setValueByPath(self, path, value, stop_propagation=False):
        """Sets nested value by path (e.g., 'ah_cel')"""
        if not isinstance(self._value, dict):
            self._value = {}
        self._value[path] = value
        self._propagation_log.append({
            'path': path,
            'old': self._value.get(path),
            'new': value,
            'propagated': not stop_propagation
        })

    def get_propagation_count(self):
        """Returns count of propagated events"""
        return sum(1 for log in self._propagation_log if log.get('propagated', False))

    def get_blocked_count(self):
        """Returns count of blocked events"""
        return sum(1 for log in self._propagation_log if not log.get('propagated', True))

    def reset_log(self):
        """Clears propagation log"""
        self._propagation_log = []


class MockRelay:
    """Simulates Tech Sinum relay/sbus object"""
    def __init__(self, initial_state='off'):
        self._state = initial_state
        self._call_log = []

    def getValue(self, param):
        if param == 'state':
            return self._state
        return None

    def call(self, method):
        """Simulates relay method calls"""
        self._call_log.append(method)
        if method == 'turn_on':
            self._state = 'on'
        elif method == 'turn_off':
            self._state = 'off'

    def get_state(self):
        return self._state

    def get_call_count(self, method=None):
        if method:
            return sum(1 for call in self._call_log if call == method)
        return len(self._call_log)


class MockComponent:
    """Simulates Tech Sinum component (e.g., modbus RTU)"""
    def __init__(self, comp_type='modbus_rtu_client'):
        self.type = comp_type
        self._config = {
            'baud_rate': 9600,
            'parity': 'none',
            'stop_bits': 'one',
            'slave_address': 5,
            'associations.transceiver': None
        }

    def getValue(self, key):
        return self._config.get(key)

    def setValue(self, key, value):
        self._config[key] = value


class MockElement:
    """Simulates UI element"""
    def __init__(self, name):
        self.name = name
        self._value = None

    def setValue(self, key, value, stop_propagation=False):
        self._value = value

    def getValue(self):
        return self._value


class MockCustomDevice:
    """Simulates the CustomDevice object"""
    def __init__(self):
        self._values = {}
        self._components = {'com': MockComponent()}
        self._elements = {}
        self._print_log = []

    def setValue(self, key, value):
        self._values[key] = value

    def getValue(self, key):
        return self._values.get(key)

    def getComponent(self, name):
        return self._components.get(name, MockComponent())

    def getElement(self, name):
        if name not in self._elements:
            self._elements[name] = MockElement(name)
        return self._elements[name]

    def poll(self):
        """Simulates device polling"""
        pass

    def log_print(self, *args):
        """Captures print statements"""
        self._print_log.append(' '.join(str(arg) for arg in args))


class MockTechSinumEnvironment:
    """
    Complete mock environment for Tech Sinum device
    Provides all variables, relays, and device context
    """
    def __init__(self):
        # Create 50 variables (more than enough for the code)
        self.variables = {i: MockVariable() for i in range(1, 51)}

        # Create relay/sbus objects (indices 50-70)
        self.sbus = {i: MockRelay() for i in range(50, 71)}

        # Custom device instance
        self.custom_device = MockCustomDevice()

        # Track all print statements
        self.print_log = []

    def reset(self):
        """Reset all state for new test"""
        for var in self.variables.values():
            var._value = 0
            var.reset_log()

        for relay in self.sbus.values():
            relay._state = 'off'
            relay._call_log = []

        self.print_log = []

    def set_initial_state(self, state):
        """
        Set initial state for test
        state = {
            'variables': {1: value1, 2: value2, ...},
            'relays': {60: 'on', 61: 'off', ...}
        }
        """
        if 'variables' in state:
            for var_id, value in state['variables'].items():
                self.variables[var_id]._value = value

        if 'relays' in state:
            for relay_id, relay_state in state['relays'].items():
                self.sbus[relay_id]._state = relay_state

    def get_state_snapshot(self):
        """Get current state of all variables and relays"""
        return {
            'variables': {i: var.getValue() for i, var in self.variables.items()},
            'relays': {i: relay.get_state() for i, relay in self.sbus.items()},
            'propagation_counts': {
                i: var.get_propagation_count()
                for i, var in self.variables.items()
            },
            'blocked_counts': {
                i: var.get_blocked_count()
                for i, var in self.variables.items()
            }
        }

    def get_lua_globals(self):
        """
        Returns dictionary of globals to inject into Lua environment
        This makes variables accessible to Lua code as 'variable[1]', etc.
        """
        return {
            'variable': self.variables,
            'sbus': self.sbus,
            'CustomDevice': self.custom_device,
            'print': self.log_print
        }

    def log_print(self, *args):
        """Capture print statements"""
        msg = ' '.join(str(arg) for arg in args)
        self.print_log.append(msg)
        self.custom_device.log_print(msg)
