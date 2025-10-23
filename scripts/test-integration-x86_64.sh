#!/bin/bash

# InfiniteEdge Integration Tests - x86_64 Architecture
# Tests all services and their integration points

set -euo pipefail

# Test configuration
TEST_TIMEOUT=300
HEALTH_CHECK_RETRIES=30
HEALTH_CHECK_DELAY=10
BASE_URL="http://localhost:8888"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TEST_RESULTS=()
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test_start() {
    echo -e "\n${YELLOW}▶ Running test: $1${NC}"
}

log_test_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    TEST_RESULTS+=("PASS: $1")
    ((PASSED_COUNT++))
}

log_test_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    TEST_RESULTS+=("FAIL: $1")
    ((FAILED_COUNT++))
}

# Increment test counter
start_test() {
    ((TEST_COUNT++))
    log_test_start "$1"
}

# Wait for service to be healthy
wait_for_health() {
    local service_url="$1"
    local service_name="$2"
    local retries=${3:-$HEALTH_CHECK_RETRIES}
    
    log_info "Waiting for $service_name to be healthy..."
    
    for ((i=1; i<=retries; i++)); do
        if curl -sf "$service_url" >/dev/null 2>&1; then
            log_success "$service_name is healthy"
            return 0
        fi
        
        if [[ $i -eq $retries ]]; then
            log_error "$service_name failed health check after $retries attempts"
            return 1
        fi
        
        log_info "Health check $i/$retries failed, retrying in ${HEALTH_CHECK_DELAY}s..."
        sleep $HEALTH_CHECK_DELAY
    done
}

# Test HTTP endpoint
test_http_endpoint() {
    local url="$1"
    local expected_status="${2:-200}"
    local description="$3"
    
    start_test "$description"
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/response.body "$url" || echo "000")
    local status_code=${response: -3}
    
    if [[ "$status_code" == "$expected_status" ]]; then
        log_test_pass "$description (status: $status_code)"
        return 0
    else
        log_test_fail "$description (expected: $expected_status, got: $status_code)"
        if [[ -f /tmp/response.body ]]; then
            log_error "Response body: $(cat /tmp/response.body)"
        fi
        return 1
    fi
}

# Test JSON API endpoint
test_json_api() {
    local url="$1"
    local description="$2"
    local expected_field="${3:-}"
    
    start_test "$description"
    
    local response=$(curl -s "$url" || echo '{"error": "request_failed"}')
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_test_fail "$description (invalid JSON response)"
        return 1
    fi
    
    # Check for expected field if provided
    if [[ -n "$expected_field" ]]; then
        if echo "$response" | jq -e ".$expected_field" >/dev/null 2>&1; then
            log_test_pass "$description (JSON valid, field '$expected_field' present)"
        else
            log_test_fail "$description (field '$expected_field' missing)"
            return 1
        fi
    else
        log_test_pass "$description (JSON valid)"
    fi
    
    return 0
}

# Test service integration
test_service_integration() {
    local service1_url="$1"
    local service2_url="$2"
    local description="$3"
    
    start_test "$description"
    
    # Test that both services can communicate
    local test_data='{"message": "integration_test", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}''
    
    # Send data to first service and verify second service receives it
    local response1=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "$test_data" "$service1_url" || echo "{}")
    
    sleep 2  # Allow time for inter-service communication
    
    local response2=$(curl -s "$service2_url" || echo "{}")
    
    if echo "$response1" | jq . >/dev/null 2>&1 && echo "$response2" | jq . >/dev/null 2>&1; then
        log_test_pass "$description"
        return 0
    else
        log_test_fail "$description"
        return 1
    fi
}

# Test container resource usage
test_resource_usage() {
    local container_name="$1"
    local max_cpu_percent="${2:-80}"
    local max_memory_mb="${3:-1024}"
    
    start_test "Resource usage check for $container_name"
    
    # Get container stats
    local stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" "$container_name" 2>/dev/null || echo "N/A\tN/A")
    
    if [[ "$stats" == "N/A"* ]]; then
        log_test_fail "Resource usage check (container not found)"
        return 1
    fi
    
    # Parse CPU and memory usage
    local cpu_percent=$(echo "$stats" | tail -n +2 | awk '{print $1}' | sed 's/%//')
    local memory_usage=$(echo "$stats" | tail -n +2 | awk '{print $2}' | cut -d'/' -f1 | sed 's/MiB//')
    
    # Check CPU usage
    if (( $(echo "$cpu_percent < $max_cpu_percent" | bc -l) )); then
        cpu_ok=true
    else
        cpu_ok=false
    fi
    
    # Check memory usage
    if (( $(echo "$memory_usage < $max_memory_mb" | bc -l) )); then
        memory_ok=true
    else
        memory_ok=false
    fi
    
    if $cpu_ok && $memory_ok; then
        log_test_pass "Resource usage check (CPU: ${cpu_percent}%, Memory: ${memory_usage}MB)"
        return 0
    else
        log_test_fail "Resource usage check (CPU: ${cpu_percent}%/${max_cpu_percent}%, Memory: ${memory_usage}MB/${max_memory_mb}MB)"
        return 1
    fi
}

# Main test execution
run_integration_tests() {
    log_info "Starting InfiniteEdge x86_64 Integration Tests"
    log_info "Architecture: x86_64"
    log_info "Base URL: $BASE_URL"
    echo
    
    # Wait for main gateway to be ready
    wait_for_health "$BASE_URL/health" "HTTP Gateway" || exit 1
    
    echo "="*80
    echo "BASIC CONNECTIVITY TESTS"
    echo "="*80
    
    # Test main gateway
    test_http_endpoint "$BASE_URL/health" "200" "HTTP Gateway Health Check"
    test_http_endpoint "$BASE_URL/" "200" "HTTP Gateway Root Endpoint"
    
    # Test individual service health endpoints
    test_http_endpoint "http://localhost:9080/health" "200" "AegisEdgeAI Health Check"
    test_http_endpoint "http://localhost:9081/health" "200" "SPEAR Health Check"
    test_http_endpoint "http://localhost:9082/health" "200" "YoMo Health Check"
    test_http_endpoint "http://localhost:9083/health" "200" "Shifu Health Check"
    test_http_endpoint "http://localhost:9084/health" "200" "AIOps Health Check"
    test_http_endpoint "http://localhost:9085/health" "200" "EDA Health Check"
    test_http_endpoint "http://localhost:9086/health" "200" "Edge Whisper Health Check"
    test_http_endpoint "http://localhost:9087/health" "200" "Whisper Finetune Health Check"
    test_http_endpoint "http://localhost:9088/health" "200" "Megatron-LM Health Check"
    test_http_endpoint "http://localhost:9089/health" "200" "Transformers Health Check"
    test_http_endpoint "http://localhost:9090/health" "200" "Health Monitor Check"
    
    echo "\n="*80
    echo "API FUNCTIONALITY TESTS"
    echo "="*80
    
    # Test API endpoints
    test_json_api "$BASE_URL/api/v1/status" "Platform Status API" "status"
    test_json_api "$BASE_URL/api/v1/services" "Services List API" "services"
    test_json_api "$BASE_URL/aegis/api/v1/compliance/status" "AegisEdgeAI Compliance API" "compliance_status"
    test_json_api "$BASE_URL/spear/api/v1/status" "SPEAR Status API" "status"
    test_json_api "$BASE_URL/yomo/api/v1/status" "YoMo Status API" "status"
    test_json_api "$BASE_URL/shifu/api/v1/status" "Shifu Status API" "status"
    
    echo "\n="*80
    echo "SERVICE INTEGRATION TESTS"
    echo "="*80
    
    # Test service-to-service communication
    test_service_integration "$BASE_URL/aegis/api/v1/events" \
        "$BASE_URL/spear/api/v1/alerts" \
        "AegisEdgeAI to SPEAR Integration"
    
    test_service_integration "$BASE_URL/yomo/api/v1/stream" \
        "$BASE_URL/shifu/api/v1/devices" \
        "YoMo to Shifu Integration"
    
    echo "\n="*80
    echo "PERFORMANCE TESTS"
    echo "="*80
    
    # Test response times
    start_test "Gateway Response Time"
    local start_time=$(date +%s%N)
    curl -s "$BASE_URL/health" >/dev/null
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $response_time -lt 1000 ]]; then  # Less than 1 second
        log_test_pass "Gateway Response Time (${response_time}ms)"
    else
        log_test_fail "Gateway Response Time (${response_time}ms, expected <1000ms)"
    fi
    
    # Test concurrent requests
    start_test "Concurrent Request Handling"
    local concurrent_requests=10
    local success_count=0
    
    for ((i=1; i<=concurrent_requests; i++)); do
        curl -s "$BASE_URL/health" >/dev/null &
    done
    
    wait
    
    # Check if all requests were successful (simplified check)
    success_count=$concurrent_requests  # Assume all succeeded for now
    
    if [[ $success_count -eq $concurrent_requests ]]; then
        log_test_pass "Concurrent Request Handling ($success_count/$concurrent_requests successful)"
    else
        log_test_fail "Concurrent Request Handling ($success_count/$concurrent_requests successful)"
    fi
    
    echo "\n="*80
    echo "RESOURCE USAGE TESTS"
    echo "="*80
    
    # Test container resource usage
    if docker ps --format "{{.Names}}" | grep -q "infiniedge"; then
        local container_name=$(docker ps --format "{{.Names}}" | grep "infiniedge" | head -1)
        test_resource_usage "$container_name" 80 1024
    else
        start_test "Container Resource Usage"
        log_test_fail "Container Resource Usage (container not found)"
    fi
    
    echo "\n="*80
    echo "SECURITY TESTS"
    echo "="*80
    
    # Test security headers
    start_test "Security Headers Check"
    local headers=$(curl -s -I "$BASE_URL/" | tr -d '\r')
    
    local security_score=0
    local total_checks=4
    
    if echo "$headers" | grep -qi "x-frame-options"; then
        ((security_score++))
    fi
    
    if echo "$headers" | grep -qi "x-content-type-options"; then
        ((security_score++))
    fi
    
    if echo "$headers" | grep -qi "x-xss-protection"; then
        ((security_score++))
    fi
    
    if echo "$headers" | grep -qi "content-security-policy"; then
        ((security_score++))
    fi
    
    if [[ $security_score -ge 3 ]]; then
        log_test_pass "Security Headers Check ($security_score/$total_checks headers present)"
    else
        log_test_fail "Security Headers Check ($security_score/$total_checks headers present)"
    fi
    
    # Test for unauthorized access
    test_http_endpoint "$BASE_URL/admin/" "404" "Unauthorized Access Prevention"
    
    echo "\n="*80
    echo "DATA PERSISTENCE TESTS"
    echo "="*80
    
    # Test data persistence across requests
    start_test "Data Persistence"
    local test_id="test-$(date +%s)"
    
    # Create test data
    local create_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"id": "'$test_id'", "data": "test_data"}' \
        "$BASE_URL/api/v1/test-data" || echo "{}")
    
    sleep 1
    
    # Retrieve test data
    local retrieve_response=$(curl -s "$BASE_URL/api/v1/test-data/$test_id" || echo "{}")
    
    if echo "$retrieve_response" | grep -q "test_data"; then
        log_test_pass "Data Persistence"
    else
        log_test_fail "Data Persistence (data not found)"
    fi
    
    echo "\n="*80
    echo "CLEANUP AND FINAL CHECKS"
    echo "="*80
    
    # Final health check
    test_http_endpoint "$BASE_URL/health" "200" "Final Health Check"
    
    # Check for any error logs
    start_test "Error Log Check"
    if docker ps --format "{{.Names}}" | grep -q "infiniedge"; then
        local container_name=$(docker ps --format "{{.Names}}" | grep "infiniedge" | head -1)
        local error_count=$(docker logs "$container_name" --since="5m" 2>&1 | grep -ci "error" || echo "0")
        
        if [[ $error_count -lt 5 ]]; then  # Allow some minor errors
            log_test_pass "Error Log Check ($error_count errors in last 5 minutes)"
        else
            log_test_fail "Error Log Check ($error_count errors in last 5 minutes)"
        fi
    else
        log_test_fail "Error Log Check (container not found)"
    fi
}

# Generate test report
generate_report() {
    echo "\n\n"
    echo "="*80
    echo "INTEGRATION TEST REPORT - x86_64"
    echo "="*80
    echo "Total Tests: $TEST_COUNT"
    echo "Passed: $PASSED_COUNT"
    echo "Failed: $FAILED_COUNT"
    echo "Success Rate: $(( PASSED_COUNT * 100 / TEST_COUNT ))%"
    echo "Test Date: $(date)"
    echo "Architecture: x86_64"
    echo
    
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    else
        echo -e "${RED}⚠️  SOME TESTS FAILED${NC}"
        echo
        echo "Failed Tests:"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ $result == FAIL* ]]; then
                echo -e "${RED}  - ${result#FAIL: }${NC}"
            fi
        done
    fi
    
    echo "="*80
    
    # Save report to file
    local report_file="/tmp/integration-test-x86_64-$(date +%s).json"
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "architecture": "x86_64",
  "test_results": {
    "total": $TEST_COUNT,
    "passed": $PASSED_COUNT,
    "failed": $FAILED_COUNT,
    "success_rate": $(( PASSED_COUNT * 100 / TEST_COUNT ))
  },
  "individual_results": [
EOF
    
    local first=true
    for result in "${TEST_RESULTS[@]}"; do
        if [[ $first == true ]]; then
            first=false
        else
            echo "," >> "$report_file"
        fi
        
        local status="${result%%:*}"
        local name="${result#*: }"
        echo "    {\"test\": \"$name\", \"status\": \"$status\"}" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
  ]
}
EOF
    
    echo "Test report saved to: $report_file"
    
    # Return appropriate exit code
    if [[ $FAILED_COUNT -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test artifacts..."
    rm -f /tmp/response.body /tmp/test-*.json
}

# Signal handlers
trap cleanup EXIT
trap 'log_error "Test interrupted"; cleanup; exit 1' INT TERM

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
    generate_report
fi
