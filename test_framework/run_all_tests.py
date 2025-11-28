#!/usr/bin/env python3
"""
Main Test Runner Script
Executes all test scenarios and generates comprehensive reports
"""

import sys
import argparse
from pathlib import Path

from scenario_generator import ScenarioGenerator
from advanced_scenario_generator import AdvancedScenarioGenerator
from test_runner import LuaTestRunner
from report_generator import ReportGenerator


def main():
    """Main entry point for test execution"""
    parser = argparse.ArgumentParser(
        description='Run comprehensive tests on Aging Chamber Lua code'
    )
    parser.add_argument(
        '--lua-file',
        type=str,
        default='../aging_chamber_Apar2_0_REFACTORED.lua',
        help='Path to Lua code file to test'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        default='../test_reports',
        help='Directory for test reports'
    )
    parser.add_argument(
        '--format',
        type=str,
        choices=['csv', 'excel', 'json', 'all'],
        default='all',
        help='Output format for reports'
    )
    parser.add_argument(
        '--max-scenarios',
        type=int,
        default=None,
        help='Maximum number of scenarios to run (for testing)'
    )

    args = parser.parse_args()

    print("=" * 80)
    print("AGING CHAMBER CONTROL SYSTEM - COMPREHENSIVE TEST SUITE")
    print("=" * 80)

    # Step 1: Generate test scenarios
    print("\n[1/3] Generating test scenarios...")
    print("-" * 80)

    # Generate basic scenarios
    print("Generating basic test scenarios...")
    basic_gen = ScenarioGenerator()
    basic_scenarios = basic_gen.generate_all_scenarios()

    # Generate advanced scenarios
    print("Generating advanced test scenarios...")
    advanced_gen = AdvancedScenarioGenerator()
    advanced_scenarios = advanced_gen.generate_all_scenarios()

    # Combine all scenarios
    scenarios = basic_scenarios + advanced_scenarios

    print(f"\n✓ Generated {len(scenarios)} test scenarios")

    # Show category breakdown
    categories = {}
    for scenario in scenarios:
        cat = scenario.category
        categories[cat] = categories.get(cat, 0) + 1

    print("\nTest scenarios by category:")
    for category, count in sorted(categories.items()):
        print(f"  • {category:30s}: {count:4d} tests")

    # Limit scenarios if requested
    if args.max_scenarios:
        scenarios = scenarios[:args.max_scenarios]
        print(f"\n⚠ Limited to {args.max_scenarios} scenarios for testing")

    # Step 2: Run tests
    print(f"\n[2/3] Running {len(scenarios)} test scenarios...")
    print("-" * 80)

    try:
        runner = LuaTestRunner(args.lua_file)
        results = runner.run_all_tests(scenarios)
    except FileNotFoundError:
        print(f"\n✗ Error: Lua file not found: {args.lua_file}")
        print("  Please provide correct path with --lua-file argument")
        return 1
    except Exception as e:
        print(f"\n✗ Error running tests: {e}")
        import traceback
        traceback.print_exc()
        return 1

    # Step 3: Generate reports
    print(f"\n[3/3] Generating test reports...")
    print("-" * 80)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    report_gen = ReportGenerator(results)

    generated_files = []

    try:
        if args.format in ['csv', 'all']:
            csv_file = output_dir / 'test_results.csv'
            report_gen.generate_csv(str(csv_file))
            generated_files.append(csv_file)

        if args.format in ['excel', 'all']:
            excel_file = output_dir / 'test_results.xlsx'
            report_gen.generate_excel(str(excel_file))
            generated_files.append(excel_file)

        if args.format in ['json', 'all']:
            json_file = output_dir / 'test_results.json'
            report_gen.generate_json(str(json_file))
            generated_files.append(json_file)

    except Exception as e:
        print(f"\n✗ Error generating reports: {e}")
        import traceback
        traceback.print_exc()
        return 1

    # Final summary
    print("\n" + "=" * 80)
    print("TEST EXECUTION COMPLETE")
    print("=" * 80)

    passed = sum(1 for r in results if r.passed)
    failed = len(results) - passed

    print(f"\nResults Summary:")
    print(f"  Total Tests:  {len(results)}")
    print(f"  ✓ Passed:     {passed} ({passed/len(results)*100:.1f}%)")
    print(f"  ✗ Failed:     {failed} ({failed/len(results)*100:.1f}%)")

    if failed > 0:
        print(f"\n⚠ WARNING: {failed} tests failed!")
        print("\nFailed tests:")
        for result in results:
            if not result.passed:
                print(f"  • {result.test_id}: {result.description}")
                if result.error_message:
                    print(f"    Error: {result.error_message}")

    print(f"\nGenerated Reports:")
    for file in generated_files:
        print(f"  • {file}")

    print("\n" + "=" * 80)

    # Return exit code
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
