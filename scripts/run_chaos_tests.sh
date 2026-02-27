#!/bin/bash

# ============================================================================
# KORUBENI CHAOS TEST RUNNER
# ============================================================================
# Runs the comprehensive chaos engineering test suite and generates report.
# Usage: ./scripts/run_chaos_tests.sh [options]
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  KORUBENI CHAOS TEST RUNNER                                    ║"
echo "║  Testing Zero-Fault Guarantees Under Extreme Conditions       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Parse options
VERBOSE=false
INDIVIDUAL=false
REPORT_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -i|--individual)
      INDIVIDUAL=true
      shift
      ;;
    -r|--report)
      REPORT_ONLY=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  -v, --verbose     Show detailed test output"
      echo "  -i, --individual  Run tests individually (slower but more detailed)"
      echo "  -r, --report      Only show the report (don't run tests)"
      echo "  -h, --help        Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found. Please install Flutter first.${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ pubspec.yaml not found. Please run from project root.${NC}"
    exit 1
fi

# Show report only
if [ "$REPORT_ONLY" = true ]; then
    if [ -f "test/chaos/CHAOS_REPORT.md" ]; then
        echo -e "${BLUE}📄 Chaos Test Report:${NC}"
        echo ""
        cat test/chaos/CHAOS_REPORT.md
        exit 0
    else
        echo -e "${YELLOW}⚠️  No report found. Run tests first.${NC}"
        exit 1
    fi
fi

# Ensure dependencies are installed
echo -e "${BLUE}📦 Checking dependencies...${NC}"
flutter pub get > /dev/null 2>&1

# Run tests
START_TIME=$(date +%s)

if [ "$INDIVIDUAL" = true ]; then
    echo -e "${BLUE}🧪 Running tests individually...${NC}"
    echo ""
    
    TESTS=(
        "test/chaos/network_blackout_test.dart"
        "test/chaos/gps_loss_test.dart"
        "test/chaos/resource_exhaustion_test.dart"
        "test/chaos/system_kill_test.dart"
        "test/chaos/database_corruption_test.dart"
    )
    
    PASSED=0
    FAILED=0
    
    for test in "${TESTS[@]}"; do
        echo -e "${YELLOW}Running: $test${NC}"
        
        if [ "$VERBOSE" = true ]; then
            if flutter test "$test"; then
                ((PASSED++))
                echo -e "${GREEN}✅ PASSED${NC}"
            else
                ((FAILED++))
                echo -e "${RED}❌ FAILED${NC}"
            fi
        else
            if flutter test "$test" > /dev/null 2>&1; then
                ((PASSED++))
                echo -e "${GREEN}✅ PASSED${NC}"
            else
                ((FAILED++))
                echo -e "${RED}❌ FAILED${NC}"
            fi
        fi
        
        echo ""
    done
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  INDIVIDUAL TEST RESULTS                                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    echo ""
    
else
    echo -e "${BLUE}🧪 Running chaos test suite...${NC}"
    echo ""
    
    if [ "$VERBOSE" = true ]; then
        flutter test test/chaos/chaos_test_suite.dart
    else
        flutter test test/chaos/chaos_test_suite.dart 2>&1 | grep -E "(PASSED|FAILED|✅|❌|Running:|Test Suite)"
    fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${BLUE}⏱️  Total Duration: ${DURATION}s${NC}"
echo ""

# Show report if it exists
if [ -f "test/chaos/CHAOS_REPORT.md" ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  CHAOS TEST REPORT                                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    cat test/chaos/CHAOS_REPORT.md
    echo ""
    echo -e "${GREEN}📄 Full report saved to: test/chaos/CHAOS_REPORT.md${NC}"
fi

# Check if any tests failed
if grep -q "Failed: 0" test/chaos/CHAOS_REPORT.md 2>/dev/null; then
    echo ""
    echo -e "${GREEN}✅ ALL CHAOS TESTS PASSED - Zero-Fault Guarantees Verified!${NC}"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}❌ SOME CHAOS TESTS FAILED - Fix issues before release!${NC}"
    echo ""
    exit 1
fi
