#!/bin/bash

# TekTool - Comprehensive Test Runner
# Runs all tests and generates detailed reports

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  TekTool - Production Test Suite"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}✗ Flutter not found in PATH${NC}"
    echo "  Please install Flutter or add it to PATH:"
    echo "  export PATH=\"\$HOME/flutter/bin:\$PATH\""
    exit 1
fi

echo -e "${GREEN}✓ Flutter found: $(flutter --version | head -n 1)${NC}"
echo ""

# Create test results directory
mkdir -p test_results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="test_results/test_report_${TIMESTAMP}.txt"

# Function to log results
log_result() {
    echo "$1" | tee -a "$REPORT_FILE"
}

log_result "═══════════════════════════════════════════════════════════"
log_result "  Test Execution Report"
log_result "  Date: $(date)"
log_result "═══════════════════════════════════════════════════════════"
log_result ""

# ═══════════════════════════════════════════════════════════════════════
# 1. Code Analysis
# ═══════════════════════════════════════════════════════════════════════
echo "───────────────────────────────────────────────────────────"
echo "  1. Running Code Analysis"
echo "───────────────────────────────────────────────────────────"
log_result "───────────────────────────────────────────────────────────"
log_result "  1. Code Analysis"
log_result "───────────────────────────────────────────────────────────"

if flutter analyze > test_results/analyze_${TIMESTAMP}.log 2>&1; then
    echo -e "${GREEN}✓ Code analysis passed${NC}"
    log_result "✓ Code analysis passed"
else
    echo -e "${YELLOW}⚠ Code analysis found issues (see test_results/analyze_${TIMESTAMP}.log)${NC}"
    log_result "⚠ Code analysis found issues"
fi
echo ""
log_result ""

# ═══════════════════════════════════════════════════════════════════════
# 2. Unit Tests
# ═══════════════════════════════════════════════════════════════════════
echo "───────────────────────────────────────────────────────────"
echo "  2. Running Unit Tests"
echo "───────────────────────────────────────────────────────────"
log_result "───────────────────────────────────────────────────────────"
log_result "  2. Unit Tests"
log_result "───────────────────────────────────────────────────────────"

if flutter test --coverage --no-pub > test_results/unit_tests_${TIMESTAMP}.log 2>&1; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
    log_result "✓ Unit tests passed"
    
    # Extract test count
    TEST_COUNT=$(grep -o "[0-9]\+ tests passed" test_results/unit_tests_${TIMESTAMP}.log | head -n 1)
    if [ -n "$TEST_COUNT" ]; then
        echo "  $TEST_COUNT"
        log_result "  $TEST_COUNT"
    fi
else
    echo -e "${RED}✗ Unit tests failed (see test_results/unit_tests_${TIMESTAMP}.log)${NC}"
    log_result "✗ Unit tests failed"
fi
echo ""
log_result ""

# ═══════════════════════════════════════════════════════════════════════
# 3. Coverage Report
# ═══════════════════════════════════════════════════════════════════════
if [ -f "coverage/lcov.info" ]; then
    echo "───────────────────────────────────────────────────────────"
    echo "  3. Generating Coverage Report"
    echo "───────────────────────────────────────────────────────────"
    log_result "───────────────────────────────────────────────────────────"
    log_result "  3. Coverage Report"
    log_result "───────────────────────────────────────────────────────────"
    
    if command -v lcov &> /dev/null; then
        COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | awk '{print $2}')
        echo -e "${GREEN}✓ Test coverage: $COVERAGE${NC}"
        log_result "✓ Test coverage: $COVERAGE"
    else
        echo -e "${YELLOW}⚠ lcov not installed (cannot calculate coverage)${NC}"
        log_result "⚠ lcov not installed"
    fi
    echo ""
    log_result ""
fi

# ═══════════════════════════════════════════════════════════════════════
# 4. Integration Tests (Optional - requires device)
# ═══════════════════════════════════════════════════════════════════════
echo "───────────────────────────────────────────────────────────"
echo "  4. Integration Tests"
echo "───────────────────────────────────────────────────────────"
log_result "───────────────────────────────────────────────────────────"
log_result "  4. Integration Tests"
log_result "───────────────────────────────────────────────────────────"

# Check for connected devices
DEVICE_COUNT=$(flutter devices 2>/dev/null | grep -c "^[a-zA-Z]" || echo "0")

if [ "$DEVICE_COUNT" -gt "0" ]; then
    echo "Found $DEVICE_COUNT connected device(s)"
    echo ""
    echo "Run integration tests? (requires device interaction) [y/N]"
    read -t 10 -n 1 RUN_INTEGRATION || RUN_INTEGRATION="n"
    echo ""
    
    if [ "$RUN_INTEGRATION" = "y" ] || [ "$RUN_INTEGRATION" = "Y" ]; then
        DEVICE_ID=$(flutter devices | grep "^[a-zA-Z]" | head -n 1 | awk '{print $4}')
        echo "Running integration tests on device $DEVICE_ID..."
        
        if flutter test integration_test/app_test.dart --device-id="$DEVICE_ID" > test_results/integration_${TIMESTAMP}.log 2>&1; then
            echo -e "${GREEN}✓ Integration tests passed${NC}"
            log_result "✓ Integration tests passed on device $DEVICE_ID"
            
            # Copy integration test report if generated
            if [ -f "integration_test_report.txt" ]; then
                cp integration_test_report.txt test_results/integration_report_${TIMESTAMP}.txt
                echo "  Report saved to test_results/integration_report_${TIMESTAMP}.txt"
            fi
        else
            echo -e "${RED}✗ Integration tests failed${NC}"
            log_result "✗ Integration tests failed"
        fi
    else
        echo -e "${YELLOW}⏭️  Integration tests skipped${NC}"
        log_result "⏭️  Integration tests skipped (user declined)"
    fi
else
    echo -e "${YELLOW}⏭️  Integration tests skipped (no devices connected)${NC}"
    log_result "⏭️  Integration tests skipped (no devices connected)"
fi
echo ""
log_result ""

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════
log_result "═══════════════════════════════════════════════════════════"
log_result "  Test Summary"
log_result "═══════════════════════════════════════════════════════════"
log_result ""
log_result "Test artifacts saved to: test_results/"
log_result "  - analyze_${TIMESTAMP}.log"
log_result "  - unit_tests_${TIMESTAMP}.log"
if [ -f "test_results/integration_${TIMESTAMP}.log" ]; then
    log_result "  - integration_${TIMESTAMP}.log"
    log_result "  - integration_report_${TIMESTAMP}.txt"
fi
log_result ""
log_result "Full report: $REPORT_FILE"
log_result ""

echo "═══════════════════════════════════════════════════════════"
echo "  Test Suite Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Results saved to: $REPORT_FILE"
echo ""
echo "View detailed logs:"
echo "  cat test_results/analyze_${TIMESTAMP}.log"
echo "  cat test_results/unit_tests_${TIMESTAMP}.log"
if [ -f "test_results/integration_${TIMESTAMP}.log" ]; then
    echo "  cat test_results/integration_report_${TIMESTAMP}.txt"
fi
echo ""

# Return exit code based on critical failures
if grep -q "✗" "$REPORT_FILE"; then
    echo -e "${RED}⚠️  Some tests failed - review logs above${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
