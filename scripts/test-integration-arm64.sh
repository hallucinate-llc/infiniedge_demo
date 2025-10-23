#!/bin/bash

# InfiniteEdge Integration Tests - ARM64 Architecture
# Tests all services and their integration points on ARM64

set -euo pipefail

# Test configuration (ARM64 specific adjustments)
TEST_TIMEOUT=600  # Longer timeout for ARM64
HEALTH_CHECK_RETRIES=60  # More retries for ARM64
HEALTH_CHECK_DELAY=15    # Longer delay for ARM64
BASE_URL="http://localhost:8888"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Test results
TEST_RESULTS=()
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# ARM64-specific configurations
ARM64_SERVICES=(
    "aegis-edge-ai:9080"
    "spear:9081"
    "yomo:9082"
    "shifu:9083"
    "aiops:9084"
    "eda:9085"
    "edge-whisper:9086"
    "whisper-finetune:9087"
    "megatron-lm:9088"
    "transformers:9089"
    "health-monitor:9090"
)

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_arm64() {
    echo -e "${PURPLE}[ARM64]${NC} $1"
}

log_test_start() {
    echo -e "\n${YELLOW}▶ Running ARM64 test: $1${NC}"
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

log_test_skip() {
    echo -e "${YELLOW}⚠ SKIP: $1${NC}"
    TEST_RESULTS+=("SKIP: $1")
    ((SKIPPED_COUNT++))
}

# Increment test counter
start_test() {
    ((TEST_COUNT++))
    log_test_start "$1"
}

# Check if running on ARM64
check_arm64() {
    local arch=$(uname -m)
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        log_arm64 "Running on native ARM64 architecture: $arch"
        return 0
    else
        log_warning "Running on non-ARM64 architecture: $arch (using emulation)"
        return 1
    fi
}

# Wait for service with ARM64 considerations
wait_for_health_arm64() {
    local service_url="$1"
    local service_name="$2"
    local retries=${3:-$HEALTH_CHECK_RETRIES}
    
    log_arm64 "Waiting for $service_name to be healthy (ARM64 mode)..."
    
    for ((i=1; i<=retries; i++)); do
        local start_time=$(date +%s%N)
        
        if timeout 30 curl -sf "$service_url" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local response_time=$(( (end_time - start_time) / 1000000 ))
            log_success "$service_name is healthy (response time: ${response_time}ms)"
            return 0
        fi
        
        if [[ $i -eq $retries ]]; then
            log_error "$service_name failed health check after $retries attempts"
            return 1
        fi
        
        log_info "ARM64 health check $i/$retries failed, retrying in ${HEALTH_CHECK_DELAY}s..."
        sleep $HEALTH_CHECK_DELAY
    done
}

# Test ARM64 specific performance characteristics
test_arm64_performance() {
    local url="$1"
    local description="$2"
    local max_response_time="${3:-5000}"  # 5 seconds max for ARM64
    
    start_test "$description"
    
    local total_time=0
    local iterations=3
    
    for ((i=1; i<=iterations; i++)); do
        local start_time=$(date +%s%N)
        
        if curl -sf "$url" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local response_time=$(( (end_time - start_time) / 1000000 ))
            total_time=$((total_time + response_time))
        else
            log_test_fail "$description (request $i failed)"
            return 1
        fi
    done
    
    local avg_time=$((total_time / iterations))
    
    if [[ $avg_time -lt $max_response_time ]]; then
        log_test_pass "$description (avg: ${avg_time}ms)"
        return 0
    else
        log_test_fail "$description (avg: ${avg_time}ms, expected <${max_response_time}ms)"
        return 1
    fi
}

# Test ARM64 container architecture
test_container_architecture() {
    start_test "Container Architecture Verification"
    
    if docker ps --format "{{.Names}}" | grep -q "infiniedge"; then
        local container_name=$(docker ps --format "{{.Names}}" | grep "infiniedge" | head -1)
        
        # Check container platform
        local platform=$(docker inspect "$container_name" --format '{{.Platform}}' 2>/dev/null || echo "unknown")
        
        # Check process architecture inside container
        local container_arch=$(docker exec "$container_name" uname -m 2>/dev/null || echo "unknown")
        
        if [[ "$container_arch" == "aarch64" || "$container_arch" == "arm64" ]]; then
            log_test_pass "Container Architecture Verification (platform: $platform, arch: $container_arch)"
            return 0
        else
            log_test_fail "Container Architecture Verification (expected ARM64, got: $container_arch)"
            return 1
        fi
    else
        log_test_fail "Container Architecture Verification (container not found)"
        return 1
    fi
}

# Test ARM64 specific libraries and dependencies
test_arm64_dependencies() {
    start_test "ARM64 Dependencies Check"
    
    if docker ps --format "{{.Names}}" | grep -q "infiniedge"; then
        local container_name=$(docker ps --format "{{.Names}}" | grep "infiniedge" | head -1)
        
        # Check for ARM64 specific libraries
        local lib_check=$(docker exec "$container_name" bash -c '
            libs_ok=0
            total_libs=0
            
            # Check for common ARM64 libraries
            for lib in libc.so.6 libpthread.so.0 libm.so.6; do
                ((total_libs++))
                if ldconfig -p | grep -q "$lib.*aarch64"; then
                    ((libs_ok++))
                fi
            done
            
            echo "$libs_ok/$total_libs"
        ' 2>/dev/null || echo "0/0")
        
        local libs_ok=$(echo "$lib_check" | cut -d'/' -f1)
        local total_libs=$(echo "$lib_check" | cut -d'/' -f2)
        
        if [[ $total_libs -gt 0 && $libs_ok -eq $total_libs ]]; then
            log_test_pass "ARM64 Dependencies Check ($lib_check ARM64 libraries found)"
            return 0
        else
            log_test_fail "ARM64 Dependencies Check ($lib_check ARM64 libraries found)"
            return 1
        fi
    else
        log_test_fail "ARM64 Dependencies Check (container not found)"
        return 1
    fi
}

# Test memory efficiency on ARM64
test_arm64_memory_efficiency() {
    start_test "ARM64 Memory Efficiency"
    
    if docker ps --format "{{.Names}}" | grep -q "infiniedge"; then
        local container_name=$(docker ps --format "{{.Names}}" | grep "infiniedge" | head -1)
        
        # Get detailed memory stats
        local memory_stats=$(docker stats --no-stream --format "json" "$container_name" 2>/dev/null || echo '{}')
        
        if [[ "$memory_stats" != "{}" ]]; then
            local memory_usage=$(echo "$memory_stats" | jq -r '.MemUsage' | cut -d'/' -f1 | sed 's/MiB//' | tr -d ' ')
            local memory_limit=$(echo "$memory_stats" | jq -r '.MemUsage' | cut -d'/' -f2 | sed 's/MiB//' | tr -d ' ')
            
            # ARM64 typically has good memory efficiency
            local memory_percent=$(echo "scale=2; $memory_usage * 100 / $memory_limit" | bc -l 2>/dev/null || echo "0")
            
            if (( $(echo "$memory_percent < 75" | bc -l) )); then
                log_test_pass "ARM64 Memory Efficiency (${memory_percent}% usage)"
                return 0
            else
                log_test_fail "ARM64 Memory Efficiency (${memory_percent}% usage, expected <75%)"
                return 1
            fi
        else
            log_test_fail "ARM64 Memory Efficiency (stats unavailable)"
            return 1
        fi
    else
        log_test_fail "ARM64 Memory Efficiency (container not found)"
        return 1
    fi
}

# Main ARM64 test execution
run_arm64_integration_tests() {
    log_arm64 "Starting InfiniteEdge ARM64 Integration Tests"
    log_info "Architecture: ARM64/aarch64"
    log_info "Base URL: $BASE_URL"
    log_info "Extended timeouts for ARM64 performance characteristics"
    echo
    
    # Check architecture
    check_arm64
    echo
    
    # Wait for main gateway with extended timeout
    wait_for_health_arm64 "$BASE_URL/health" "HTTP Gateway" || {
        log_error "Gateway failed to start, checking Docker logs..."
        if docker ps --format "{{.Names}}" | grep -q "infiniedge"; then
            local container_name=$(docker ps --format "{{.Names}}" | grep "infiniedge" | head -1)
            docker logs "$container_name" --tail 20
        fi
        exit 1
    }
    
    echo "="*80
    echo "ARM64 ARCHITECTURE VERIFICATION"
    echo "="*80
    
    test_container_architecture
    test_arm64_dependencies
    
    echo "\n="*80
    echo "ARM64 PERFORMANCE CHARACTERISTICS"
    echo "="*80
    
    test_arm64_performance "$BASE_URL/health" "Gateway Response Time (ARM64)" 3000
    test_arm64_memory_efficiency
    
    echo "\n="*80
    echo "ARM64 SERVICE CONNECTIVITY"
    echo "="*80
    
    # Test individual services with ARM64 considerations
    for service_info in "${ARM64_SERVICES[@]}"; do
        local service_name=$(echo "$service_info" | cut -d':' -f1)
        local service_port=$(echo "$service_info" | cut -d':' -f2)
        
        test_arm64_performance "http://localhost:$service_port/health" \
            "${service_name^} Service (ARM64)" 5000
    done
    
    echo "\n="*80
    echo "ARM64 API FUNCTIONALITY"
    echo "="*80
    
    # Test APIs with ARM64 performance expectations
    start_test "Platform Status API (ARM64)"
    local api_start=$(date +%s%N)
    local api_response=$(curl -s "$BASE_URL/api/v1/status" 2>/dev/null || echo '{"error": "api_failed"}')
    local api_end=$(date +%s%N)
    local api_time=$(( (api_end - api_start) / 1000000 ))
    
    if echo "$api_response" | jq -e '.status' >/dev/null 2>&1 && [[ $api_time -lt 8000 ]]; then
        log_test_pass "Platform Status API (ARM64) (${api_time}ms)"
    else
        log_test_fail "Platform Status API (ARM64) (${api_time}ms or invalid response)"
    fi
    
    echo "\n="*80
    echo "ARM64 STRESS TESTING"
    echo "="*80
    
    # ARM64 stress test with lower expectations
    start_test "ARM64 Concurrent Load Test"
    local concurrent_requests=5  # Lower for ARM64
    local success_count=0
    local pids=()
    
    for ((i=1; i<=concurrent_requests; i++)); do
        (
            if curl -sf "$BASE_URL/health" >/dev/null 2>&1; then
                echo "success" > "/tmp/arm64-test-$i.result"
            else
                echo "failure" > "/tmp/arm64-test-$i.result"
            fi
        ) &
        pids+=($!)
    done
    
    # Wait for all requests with timeout
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            ((success_count++))
        fi
    done
    
    # Count successful results
    local actual_success=0
    for ((i=1; i<=concurrent_requests; i++)); do
        if [[ -f "/tmp/arm64-test-$i.result" ]] && grep -q "success" "/tmp/arm64-test-$i.result"; then
            ((actual_success++))
        fi
        rm -f "/tmp/arm64-test-$i.result"
    done
    
    if [[ $actual_success -ge $((concurrent_requests * 4 / 5)) ]]; then  # 80% success rate for ARM64
        log_test_pass "ARM64 Concurrent Load Test ($actual_success/$concurrent_requests successful)"
    else
        log_test_fail "ARM64 Concurrent Load Test ($actual_success/$concurrent_requests successful)"
    fi
    
    echo "\n="*80
    echo "ARM64 STABILITY TEST"
    echo "="*80
    
    # Extended stability test for ARM64
    start_test "ARM64 Extended Stability Test"
    local stability_iterations=10
    local stability_success=0
    
    for ((i=1; i<=stability_iterations; i++)); do
        if curl -sf "$BASE_URL/health" >/dev/null 2>&1; then
            ((stability_success++))
        fi
        sleep 2  # Brief pause between requests
    done
    
    if [[ $stability_success -ge $((stability_iterations * 9 / 10)) ]]; then  # 90% success rate
        log_test_pass "ARM64 Extended Stability Test ($stability_success/$stability_iterations successful)"
    else
        log_test_fail "ARM64 Extended Stability Test ($stability_success/$stability_iterations successful)"
    fi
    
    echo "\n="*80
    echo "ARM64 RESOURCE MONITORING"
    echo "="*80
    
    # Monitor ARM64 specific resource patterns
    start_test "ARM64 Resource Pattern Analysis"
    if docker ps --format "{{.Names}}" | grep -q "infiniedge"; then
        local container_name=$(docker ps --format "{{.Names}}" | grep "infiniedge" | head -1)
        
        # Sample resources over time
        local samples=5
        local total_cpu=0
        local total_memory=0
        
        for ((i=1; i<=samples; i++)); do
            local stats=$(docker stats --no-stream --format "{{.CPUPerc}} {{.MemUsage}}" "$container_name" 2>/dev/null || echo "0% 0MiB/0MiB")
            local cpu_percent=$(echo "$stats" | awk '{print $1}' | sed 's/%//')
            local memory_mb=$(echo "$stats" | awk '{print $2}' | cut -d'/' -f1 | sed 's/MiB//')
            
            total_cpu=$(echo "$total_cpu + $cpu_percent" | bc -l 2>/dev/null || echo "0")
            total_memory=$(echo "$total_memory + $memory_mb" | bc -l 2>/dev/null || echo "0")
            
            sleep 3
        done
        
        local avg_cpu=$(echo "scale=2; $total_cpu / $samples" | bc -l 2>/dev/null || echo "0")
        local avg_memory=$(echo "scale=2; $total_memory / $samples" | bc -l 2>/dev/null || echo "0")
        
        # ARM64 typically shows different resource patterns
        if (( $(echo "$avg_cpu < 60" | bc -l) )) && (( $(echo "$avg_memory < 800" | bc -l) )); then
            log_test_pass "ARM64 Resource Pattern Analysis (CPU: ${avg_cpu}%, Memory: ${avg_memory}MB)"
        else
            log_test_fail "ARM64 Resource Pattern Analysis (CPU: ${avg_cpu}%, Memory: ${avg_memory}MB)"
        fi
    else
        log_test_fail "ARM64 Resource Pattern Analysis (container not found)"
    fi
}

# Generate ARM64-specific test report
generate_arm64_report() {
    echo "\n\n"
    echo "="*80
    echo "ARM64 INTEGRATION TEST REPORT"
    echo "="*80
    echo "Total Tests: $TEST_COUNT"
    echo "Passed: $PASSED_COUNT"
    echo "Failed: $FAILED_COUNT"
    echo "Skipped: $SKIPPED_COUNT"
    
    local success_rate=0
    if [[ $TEST_COUNT -gt 0 ]]; then
        success_rate=$(( PASSED_COUNT * 100 / TEST_COUNT ))
    fi
    
    echo "Success Rate: ${success_rate}%"
    echo "Test Date: $(date)"
    echo "Architecture: ARM64/aarch64"
    echo "Host Architecture: $(uname -m)"
    
    # Check if running on native ARM64
    if check_arm64; then
        echo "Execution Mode: Native ARM64"
    else
        echo "Execution Mode: Emulated ARM64"
    fi
    
    echo
    
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL ARM64 TESTS PASSED!${NC}"
    else
        echo -e "${RED}⚠️  SOME ARM64 TESTS FAILED${NC}"
        echo
        echo "Failed Tests:"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ $result == FAIL* ]]; then
                echo -e "${RED}  - ${result#FAIL: }${NC}"
            fi
        done
    fi
    
    echo "="*80
    
    # Save ARM64-specific report
    local report_file="/tmp/integration-test-arm64-$(date +%s).json"
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "architecture": "arm64",
  "host_architecture": "$(uname -m)",
  "execution_mode": "$(check_arm64 && echo 'native' || echo 'emulated')",
  "test_results": {
    "total": $TEST_COUNT,
    "passed": $PASSED_COUNT,
    "failed": $FAILED_COUNT,
    "skipped": $SKIPPED_COUNT,
    "success_rate": $success_rate
  },
  "arm64_specific": {
    "extended_timeouts": true,
    "performance_adjusted": true,
    "resource_optimized": true
  }
}
EOF
    
    echo "ARM64 test report saved to: $report_file"
    
    # Return appropriate exit code
    if [[ $FAILED_COUNT -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Cleanup function
cleanup_arm64() {
    log_info "Cleaning up ARM64 test artifacts..."
    rm -f /tmp/arm64-test-*.result /tmp/response.body
}

# Signal handlers
trap cleanup_arm64 EXIT
trap 'log_error "ARM64 test interrupted"; cleanup_arm64; exit 1' INT TERM

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_arm64_integration_tests
    generate_arm64_report
fi
