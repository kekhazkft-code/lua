# Aging Chamber Test Framework

## Overview
Comprehensive testing framework for the Tech Sinum aging chamber control system.

## Architecture

### Components:
1. **Mock Tech Sinum Environment** - Simulates device variables, relays, and components
2. **Lua Test Harness** - Loads and executes Lua code in controlled environment
3. **Scenario Generator** - Creates hundreds of test scenarios
4. **Test Runner** - Executes tests and collects results
5. **Report Generator** - Outputs results to Excel/CSV

### Test Categories:

#### 1. Event Propagation Tests (~50 scenarios)
- Test intelligent propagation (only on meaningful changes)
- Test threshold detection (0.2°C, 0.3% RH)
- Test propagation blocking on minor changes
- Test user setpoint propagation (always propagate)

#### 2. Temperature Control Tests (~50 scenarios)
- Heating activation/deactivation
- Cooling activation/deactivation
- Temperature tracking accuracy
- Gradient calculations
- Supply air temperature limits

#### 3. Humidity Control Tests (~50 scenarios)
- Humidification
- Dehumidification
- Humidity tracking
- Absolute humidity calculations
- Dew point calculations

#### 4. Mode Switching Tests (~50 scenarios)
- Sleep mode transitions
- Summer/Winter mode
- Humidity save mode
- Mode coordination between devices

#### 5. Relay Control Tests (~50 scenarios)
- Relay state transitions
- Relay logic correctness
- Multiple relay coordination
- Safety interlocks

#### 6. Psychrometric Calculations Tests (~50 scenarios)
- Absolute humidity calculation
- Relative humidity calculation
- Dew point calculation
- Temperature from AH/RH calculation

#### 7. Edge Cases & Fault Scenarios (~50 scenarios)
- Sensor failures
- Out-of-range values
- Rapid setpoint changes
- Concurrent events

#### 8. Integration Tests (~50 scenarios)
- Device-to-device communication
- Event propagation chains
- System stability over time
- Performance under load

## Test Execution

Tests run in isolated environments with:
- Controlled initial state
- Predetermined inputs
- Expected outputs
- Actual vs expected comparison

## Output Format

Excel spreadsheet with columns:
- Test ID
- Category
- Scenario Description
- Initial State
- Inputs
- Expected Output
- Actual Output
- Pass/Fail
- Notes/Errors
- Execution Time
