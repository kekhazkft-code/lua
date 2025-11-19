# Aging Chamber Test Framework

Comprehensive automated testing framework for Tech Sinum aging chamber control system Lua code.

## Features

- **350+ Test Scenarios** covering all aspects of the control system
- **Mock Tech Sinum Environment** - Simulates device variables, relays, and components
- **Intelligent Test Generation** - Automatically creates test scenarios
- **Multiple Output Formats** - Excel, CSV, and JSON reports
- **Detailed Results** - Tracks propagation events, relay states, and execution time
- **Category-Based Organization** - Tests grouped by functionality

## Test Categories

| Category | Tests | Description |
|----------|-------|-------------|
| Event Propagation | 50+ | Tests intelligent event propagation logic |
| Temperature Control | 50+ | Tests heating/cooling control algorithms |
| Humidity Control | 50+ | Tests humidification/dehumidification |
| Mode Switching | 50+ | Tests sleep mode, summer/winter, etc. |
| Relay Control | 50+ | Tests relay activation and logic |
| Psychrometric | 50+ | Tests humidity/temperature calculations |
| Edge Cases | 50+ | Tests fault handling and edge conditions |
| Integration | 50+ | Tests system integration |

## Installation

### Prerequisites

- Python 3.7 or higher
- pip (Python package installer)

### Install Dependencies

```bash
cd test_framework
pip install -r requirements.txt
```

If you don't have openpyxl and only want CSV output:

```bash
# Skip openpyxl installation
# Tests will automatically fallback to CSV
```

## Usage

### Basic Usage

Run all tests with default settings:

```bash
python run_all_tests.py
```

This will:
1. Generate 350+ test scenarios
2. Execute all tests
3. Generate reports in `../test_reports/`

### Command Line Options

```bash
# Specify Lua file to test
python run_all_tests.py --lua-file path/to/your_code.lua

# Specify output directory
python run_all_tests.py --output-dir ./my_reports

# Choose output format
python run_all_tests.py --format excel    # Excel only
python run_all_tests.py --format csv      # CSV only
python run_all_tests.py --format json     # JSON only
python run_all_tests.py --format all      # All formats (default)

# Run limited number of scenarios (for testing)
python run_all_tests.py --max-scenarios 50
```

### Full Example

```bash
python run_all_tests.py \
    --lua-file ../erlelo_1119_REFACTORED.json \
    --output-dir ./reports_2025 \
    --format excel
```

## Output Files

### Excel Report (`test_results.xlsx`)

Contains multiple sheets:

1. **Summary** - Overview statistics, pass/fail rates, category breakdown
2. **Detailed Results** - Complete test data for all scenarios
3. **Category Sheets** - Separate sheet for each test category

Features:
- Color-coded pass/fail (green/red)
- Formatted headers
- Frozen header rows
- Auto-sized columns
- Summary statistics

### CSV Report (`test_results.csv`)

Plain CSV file with all test data. Useful for:
- Importing into other tools
- Custom analysis
- Version control tracking

### JSON Report (`test_results.json`)

Structured JSON with:
- Timestamp
- Summary statistics
- Complete test results

Perfect for:
- Programmatic analysis
- CI/CD integration
- Custom reporting tools

## Test Result Columns

Each test result includes:

| Column | Description |
|--------|-------------|
| Test ID | Unique identifier (e.g., EP001, TC045) |
| Category | Test category |
| Description | Human-readable test description |
| Initial State | Starting conditions |
| Inputs | Test inputs |
| Expected Output | Expected behavior |
| Actual Output | Actual behavior |
| Status | PASS or FAIL |
| Error Message | Error details (if any) |
| Execution Time | Test duration in milliseconds |
| Propagation Count | Number of events propagated |
| Blocked Count | Number of events blocked |
| Relay States | Final state of all relays |
| Notes | Additional information |

## Understanding Results

### Event Propagation Tests

Tests verify intelligent propagation:

- **Small changes** (< threshold) → Events BLOCKED ✓
- **Large changes** (≥ threshold) → Events PROPAGATED ✓
- **User changes** → ALWAYS propagated ✓

Example:
```
Test ID: EP001
Description: Small temp change (0.1°C) should block propagation
Expected: propagated=False, blocked=True
Actual: propagated=False, blocked=True
Status: PASS ✓
```

### Temperature Control Tests

Tests verify heating/cooling logic:

```
Test ID: TC012
Description: Temp=20.0°C, Setpoint=25.0°C
Expected: heating_active=True, cooling_active=False
Status: PASS ✓
```

### Relay Control Tests

Tests verify relay switching:

```
Test ID: RC005
Description: Relay warm set to on
Expected: relay_state=on
Actual: relay_state=on
Status: PASS ✓
```

## Customization

### Adding Custom Test Scenarios

Edit `scenario_generator.py`:

```python
def _generate_custom_tests(self) -> List[TestScenario]:
    scenarios = []

    scenarios.append(TestScenario(
        test_id=f"CUSTOM{self.test_counter:03d}",
        category="Custom Tests",
        description="My custom test",
        initial_state={'variables': {1: 250}},
        inputs={'my_input': 'value'},
        expected_output={'my_expected': True}
    ))

    return scenarios
```

Then add to `generate_all_scenarios()`:

```python
self.scenarios.extend(self._generate_custom_tests())
```

### Modifying Mock Environment

Edit `mock_techsinum.py` to add custom behavior:

```python
class MockVariable:
    def custom_method(self):
        # Your custom logic
        pass
```

## Troubleshooting

### "Module not found" errors

Install dependencies:
```bash
pip install -r requirements.txt
```

### "openpyxl not available" warning

Either:
1. Install openpyxl: `pip install openpyxl`
2. Use CSV format: `python run_all_tests.py --format csv`

### Tests failing unexpectedly

1. Check Lua code syntax
2. Verify mock environment matches real environment
3. Review test expectations in `scenario_generator.py`

### Slow test execution

Run subset of tests:
```bash
python run_all_tests.py --max-scenarios 100
```

## Architecture

```
test_framework/
├── run_all_tests.py          # Main entry point
├── scenario_generator.py     # Generates test scenarios
├── test_runner.py            # Executes tests
├── report_generator.py       # Creates reports
├── mock_techsinum.py         # Mock environment
├── requirements.txt          # Dependencies
└── README.md                 # This file
```

## Example Output

```
================================================================================
AGING CHAMBER CONTROL SYSTEM - COMPREHENSIVE TEST SUITE
================================================================================

[1/3] Generating test scenarios...
--------------------------------------------------------------------------------

✓ Generated 352 test scenarios

Test scenarios by category:
  • Event Propagation               :   24 tests
  • Temperature Control              :   45 tests
  • Humidity Control                 :   24 tests
  • Mode Switching                   :    6 tests
  • Relay Control                    :   12 tests
  • Psychrometric                    :   12 tests
  • Edge Cases                       :   21 tests
  • Integration                      :    2 tests

[2/3] Running 352 test scenarios...
--------------------------------------------------------------------------------
  Progress: 10/352
  Progress: 20/352
  ...
  Progress: 352/352

Test Results:
  Total: 352
  Passed: 348
  Failed: 4
  Pass Rate: 98.9%

[3/3] Generating test reports...
--------------------------------------------------------------------------------
CSV report generated: ../test_reports/test_results.csv
Excel report generated: ../test_reports/test_results.xlsx
JSON report generated: ../test_reports/test_results.json

================================================================================
TEST EXECUTION COMPLETE
================================================================================

Results Summary:
  Total Tests:  352
  ✓ Passed:     348 (98.9%)
  ✗ Failed:     4 (1.1%)

Generated Reports:
  • ../test_reports/test_results.csv
  • ../test_reports/test_results.xlsx
  • ../test_reports/test_results.json

================================================================================
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Lua Code Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: |
          cd test_framework
          pip install -r requirements.txt
      - name: Run tests
        run: |
          cd test_framework
          python run_all_tests.py --format json
      - name: Upload results
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: test_reports/
```

## Contributing

To add new test scenarios:

1. Edit `scenario_generator.py`
2. Add your test generation method
3. Call it from `generate_all_scenarios()`
4. Run tests to verify

## License

MIT License - Feel free to use and modify

## Support

For issues or questions:
1. Check this README
2. Review example outputs
3. Examine test framework code
4. Check Lua code syntax

## Version History

- **v1.0** (2025-11-19) - Initial release
  - 350+ test scenarios
  - Excel/CSV/JSON output
  - 8 test categories
  - Mock Tech Sinum environment

---

**Happy Testing! 🚀**
