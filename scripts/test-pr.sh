#!/bin/bash

# InfiniteEdge PR Testing Script
# Specialized testing for GitHub Pull Requests with Copilot integration

set -euo pipefail

# Configuration
PR_TEST_TIMEOUT=180
BASE_URL="http://localhost:8888"
TEST_ENV="pr-test"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Test tracking
TEST_RESULTS=()
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Logging with GitHub Actions format
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "::notice::$1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "::notice::✅ $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "::error::❌ $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "::warning::⚠️ $1"
}

log_group_start() {
    echo "::group::$1"
    echo -e "${PURPLE}┌─ $1${NC}"
}

log_group_end() {
    echo -e "${PURPLE}└─ Complete${NC}"
    echo "::endgroup::"
}

# Test functions
start_test() {
    ((TEST_COUNT++))
    echo -e "\n${YELLOW}▶ PR Test $TEST_COUNT: $1${NC}"
}

pass_test() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    TEST_RESULTS+=("PASS: $1")
    ((PASSED_COUNT++))
}

fail_test() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    TEST_RESULTS+=("FAIL: $1")
    ((FAILED_COUNT++))
}

# Quick health check for PR environment
quick_health_check() {
    log_group_start "Quick Health Check"
    
    start_test "Gateway Connectivity"
    if timeout 30 curl -sf "$BASE_URL/health" >/dev/null 2>&1; then
        pass_test "Gateway Connectivity"
    else
        fail_test "Gateway Connectivity"
        log_error "Gateway is not responding"
        log_group_end
        return 1
    fi
    
    start_test "Basic API Response"
    local response=$(curl -s "$BASE_URL/api/v1/status" 2>/dev/null || echo '{}')
    if echo "$response" | jq . >/dev/null 2>&1; then
        pass_test "Basic API Response"
    else
        fail_test "Basic API Response"
    fi
    
    log_group_end
    return 0
}

# Test critical services for PR
test_critical_services() {
    log_group_start "Critical Services Test"
    
    local critical_services=(
        "9080:AegisEdgeAI"
        "9081:SPEAR"
        "9082:YoMo"
        "9083:Shifu"
    )
    
    for service_info in "${critical_services[@]}"; do
        local port=$(echo "$service_info" | cut -d':' -f1)
        local name=$(echo "$service_info" | cut -d':' -f2)
        
        start_test "$name Service Health"
        
        if timeout 20 curl -sf "http://localhost:$port/health" >/dev/null 2>&1; then
            pass_test "$name Service Health"
        else
            fail_test "$name Service Health"
        fi
    done
    
    log_group_end
}

# Test API endpoints critical for PR
test_pr_critical_apis() {
    log_group_start "Critical API Tests"
    
    local apis=(
        "/api/v1/status:Platform Status"
        "/api/v1/services:Services List"
        "/health:Health Check"
    )
    
    for api_info in "${apis[@]}"; do
        local endpoint=$(echo "$api_info" | cut -d':' -f1)
        local name=$(echo "$api_info" | cut -d':' -f2)
        
        start_test "$name API"
        
        local response=$(curl -s -w "%{http_code}" "$BASE_URL$endpoint" || echo "000")
        local status_code=${response: -3}
        
        if [[ "$status_code" == "200" ]]; then
            pass_test "$name API (HTTP $status_code)"
        else
            fail_test "$name API (HTTP $status_code)"
        fi
    done
    
    log_group_end
}

# Test performance for PR
test_pr_performance() {
    log_group_start "Performance Tests"
    
    start_test "Response Time Check"
    local start_time=$(date +%s%N)
    curl -s "$BASE_URL/health" >/dev/null
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $response_time -lt 2000 ]]; then  # 2 seconds for PR
        pass_test "Response Time Check (${response_time}ms)"
    else
        fail_test "Response Time Check (${response_time}ms, expected <2000ms)"
    fi
    
    start_test "Concurrent Request Handling"
    local concurrent=3  # Light load for PR testing
    local success=0
    
    for ((i=1; i<=concurrent; i++)); do
        if curl -sf "$BASE_URL/health" >/dev/null 2>&1 & then
            ((success++))
        fi
    done
    
    wait
    
    if [[ $success -eq $concurrent ]]; then
        pass_test "Concurrent Request Handling ($success/$concurrent)"
    else
        fail_test "Concurrent Request Handling ($success/$concurrent)"
    fi
    
    log_group_end
}

# Test security basics for PR
test_pr_security() {
    log_group_start "Security Tests"
    
    start_test "Security Headers"
    local headers=$(curl -s -I "$BASE_URL/" | tr -d '\r')
    local security_headers=0
    
    if echo "$headers" | grep -qi "x-frame-options"; then
        ((security_headers++))
    fi
    
    if echo "$headers" | grep -qi "x-content-type-options"; then
        ((security_headers++))
    fi
    
    if [[ $security_headers -ge 1 ]]; then
        pass_test "Security Headers ($security_headers headers found)"
    else
        fail_test "Security Headers (no security headers found)"
    fi
    
    start_test "Unauthorized Access Prevention"
    local admin_response=$(curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/admin/" || echo "404")
    
    if [[ "$admin_response" == "404" || "$admin_response" == "403" ]]; then
        pass_test "Unauthorized Access Prevention"
    else
        fail_test "Unauthorized Access Prevention (got HTTP $admin_response)"
    fi
    
    log_group_end
}

# Generate PR test summary
generate_pr_summary() {
    local success_rate=0
    if [[ $TEST_COUNT -gt 0 ]]; then
        success_rate=$(( PASSED_COUNT * 100 / TEST_COUNT ))
    fi
    
    echo
    echo "==========================================="
    echo "PR TEST SUMMARY"
    echo "==========================================="
    echo "Total Tests: $TEST_COUNT"
    echo "Passed: $PASSED_COUNT"
    echo "Failed: $FAILED_COUNT"
    echo "Success Rate: ${success_rate}%"
    echo "Environment: $TEST_ENV"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    
    # GitHub Actions output
    echo "::set-output name=total-tests::$TEST_COUNT"
    echo "::set-output name=passed-tests::$PASSED_COUNT"
    echo "::set-output name=failed-tests::$FAILED_COUNT"
    echo "::set-output name=success-rate::$success_rate"
    
    # Create summary for GitHub
    local summary_file="/tmp/pr-test-summary.md"
    cat > "$summary_file" << EOF
## 🔍 PR Test Results

| Metric | Value |
|--------|-------|
| Total Tests | $TEST_COUNT |
| Passed | $PASSED_COUNT |
| Failed | $FAILED_COUNT |
| Success Rate | ${success_rate}% |

### Test Details

EOF
    
    for result in "${TEST_RESULTS[@]}"; do
        if [[ $result == PASS* ]]; then
            echo "- ✅ ${result#PASS: }" >> "$summary_file"
        else
            echo "- ❌ ${result#FAIL: }" >> "$summary_file"
        fi
    done
    
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 ALL PR TESTS PASSED - READY FOR REVIEW!${NC}"
        cat >> "$summary_file" << EOF

### ✅ Status: PASSED

All tests passed successfully! This PR is ready for review and merge.
EOF
        echo "::set-output name=pr-status::passed"
        return 0
    else
        echo -e "\n${RED}⚠️  SOME PR TESTS FAILED - REQUIRES ATTENTION${NC}"
        echo
        echo "Failed tests:"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ $result == FAIL* ]]; then
                echo -e "${RED}  - ${result#FAIL: }${NC}"
            fi
        done
        
        cat >> "$summary_file" << EOF

### ❌ Status: FAILED

Some tests failed. Please review the failures above and fix the issues before merging.
EOF
        echo "::set-output name=pr-status::failed"
        return 1
    fi
}

# Main PR test execution
run_pr_tests() {
    echo "🚀 Starting InfiniteEdge PR Tests"
    echo "Environment: $TEST_ENV"
    echo "Base URL: $BASE_URL"
    echo "Timeout: ${PR_TEST_TIMEOUT}s"
    echo
    
    # Set GitHub Actions job summary
    echo "# InfiniteEdge PR Tests" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**Environment:** $TEST_ENV" >> $GITHUB_STEP_SUMMARY
    echo "**Started:** $(date)" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    
    # Run test suites
    quick_health_check || {
        log_error "Quick health check failed - aborting PR tests"
        generate_pr_summary
        exit 1
    }
    
    test_critical_services
    test_pr_critical_apis
    test_pr_performance
    test_pr_security
    
    # Generate final summary
    generate_pr_summary
}

# Cleanup
cleanup() {
    log_info "Cleaning up PR test artifacts..."
    rm -f /tmp/pr-*.tmp
}

# Signal handlers
trap cleanup EXIT
trap 'log_error "PR test interrupted"; cleanup; exit 1' INT TERM

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_pr_tests
fi
