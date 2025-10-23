#!/bin/bash

# Comprehensive Load Testing Script for InfinieEdge Demo Platform

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "⚡ InfinieEdge Demo Platform - Load Testing Suite"
echo "================================================"

# Configuration
LOAD_TEST_DURATION=${LOAD_TEST_DURATION:-60}
CONCURRENT_USERS=${CONCURRENT_USERS:-10}
RAMP_UP_TIME=${RAMP_UP_TIME:-30}
BASE_URL=${BASE_URL:-"https://localhost"}

# Results tracking
RESULTS_DIR="./test-results/load-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

print_info "Load test configuration:"
print_info "  Duration: ${LOAD_TEST_DURATION}s"
print_info "  Concurrent users: $CONCURRENT_USERS"
print_info "  Ramp-up time: ${RAMP_UP_TIME}s"
print_info "  Base URL: $BASE_URL"
print_info "  Results: $RESULTS_DIR"

# Install dependencies if needed
install_dependencies() {
    print_info "Checking dependencies..."
    
    # Check for Apache Bench (ab)
    if ! command -v ab >/dev/null 2>&1; then
        print_info "Installing Apache Bench..."
        sudo apt-get update && sudo apt-get install -y apache2-utils
    fi
    
    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    # Check for wrk if available
    if command -v wrk >/dev/null 2>&1; then
        USE_WRK=true
        print_info "Using wrk for advanced load testing"
    else
        USE_WRK=false
        print_info "Using ab for basic load testing"
    fi
}

# Basic connectivity test
test_connectivity() {
    print_header "Connectivity Test"
    
    local endpoints=(
        "$BASE_URL/"
        "$BASE_URL/aegis/"
        "$BASE_URL/spear/"
        "$BASE_URL/yomo/"
    )
    
    for endpoint in "${endpoints[@]}"; do
        print_info "Testing $endpoint..."
        
        if curl -k -s --max-time 10 "$endpoint" >/dev/null; then
            print_success "  ✓ $endpoint reachable"
        else
            print_error "  ✗ $endpoint unreachable"
            return 1
        fi
    done
    
    print_success "All endpoints reachable"
}

# Load test individual endpoints
load_test_endpoints() {
    print_header "Endpoint Load Testing"
    
    local endpoints=(
        "/:Main Dashboard"
        "/aegis/:AegisEdgeAI"
        "/spear/:SPEAR Platform"
        "/yomo/:YoMo Framework"
    )
    
    for endpoint_desc in "${endpoints[@]}"; do
        local endpoint=$(echo "$endpoint_desc" | cut -d: -f1)
        local name=$(echo "$endpoint_desc" | cut -d: -f2)
        
        print_info "Load testing $name ($endpoint)..."
        
        if $USE_WRK && command -v wrk >/dev/null 2>&1; then
            # Using wrk for more advanced testing
            wrk -t4 -c"$CONCURRENT_USERS" -d"${LOAD_TEST_DURATION}s" \
                --timeout 30s \
                "$BASE_URL$endpoint" \
                > "$RESULTS_DIR/load-test-${name//[^a-zA-Z0-9]/-}.txt" 2>&1
        else
            # Using Apache Bench
            ab -n $((CONCURRENT_USERS * 10)) \
               -c "$CONCURRENT_USERS" \
               -t "$LOAD_TEST_DURATION" \
               -k \
               -g "$RESULTS_DIR/ab-${name//[^a-zA-Z0-9]/-}.gnuplot" \
               "$BASE_URL$endpoint" \
               > "$RESULTS_DIR/ab-${name//[^a-zA-Z0-9]/-}.txt" 2>&1 || true
        fi
        
        print_success "  ✓ Load test completed for $name"
    done
}

# Stress test with increasing load
stress_test() {
    print_header "Stress Testing - Progressive Load"
    
    local max_users=50
    local step=10
    local test_duration=30
    
    print_info "Progressive load test: 1 to $max_users users, step $step"
    
    echo "users,response_time,requests_per_sec,errors" > "$RESULTS_DIR/stress-test-results.csv"
    
    for users in $(seq $step $step $max_users); do
        print_info "Testing with $users concurrent users..."
        
        local start_time=$(date +%s)
        local success_count=0
        local total_requests=0
        local total_time=0
        
        # Run concurrent requests
        for i in $(seq 1 "$users"); do
            {
                local request_start=$(date +%s.%N)
                if curl -k -s --max-time 10 "$BASE_URL/" >/dev/null 2>&1; then
                    local request_end=$(date +%s.%N)
                    local request_time=$(echo "$request_end - $request_start" | bc -l)
                    echo "$request_time" >> "$RESULTS_DIR/stress-${users}-times.tmp"
                    ((success_count++))
                fi
                ((total_requests++))
            } &
        done
        
        # Wait for all requests to complete
        wait
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Calculate metrics
        local rps=0
        if [ "$duration" -gt 0 ]; then
            rps=$((success_count / duration))
        fi
        
        local avg_response_time=0
        if [ -f "$RESULTS_DIR/stress-${users}-times.tmp" ]; then
            avg_response_time=$(awk '{sum+=$1} END {print sum/NR}' "$RESULTS_DIR/stress-${users}-times.tmp" 2>/dev/null || echo "0")
            rm -f "$RESULTS_DIR/stress-${users}-times.tmp"
        fi
        
        local error_rate=$(( (total_requests - success_count) * 100 / total_requests ))
        
        echo "$users,$avg_response_time,$rps,$error_rate" >> "$RESULTS_DIR/stress-test-results.csv"
        
        print_info "  Users: $users, RPS: $rps, Avg Response: ${avg_response_time}s, Errors: ${error_rate}%"
        
        # Brief pause between tests
        sleep 5
    done
    
    print_success "Stress testing completed"
}

# Spike test - sudden load increase
spike_test() {
    print_header "Spike Testing - Sudden Load Spikes"
    
    local normal_load=5
    local spike_load=25
    local spike_duration=30
    
    print_info "Spike test: $normal_load users -> $spike_load users for ${spike_duration}s"
    
    # Normal load phase
    print_info "Phase 1: Normal load ($normal_load users)..."
    for i in $(seq 1 $normal_load); do
        {
            while true; do
                curl -k -s --max-time 5 "$BASE_URL/" >/dev/null 2>&1 || true
                sleep 1
            done
        } &
    done
    
    local normal_pids=()
    for i in $(seq 1 $normal_load); do
        normal_pids+=($!)
    done
    
    sleep 10
    
    # Spike phase
    print_info "Phase 2: Spike load ($spike_load users)..."
    local spike_start=$(date +%s)
    
    for i in $(seq 1 $((spike_load - normal_load))); do
        {
            local end_time=$((spike_start + spike_duration))
            while [ "$(date +%s)" -lt "$end_time" ]; do
                curl -k -s --max-time 5 "$BASE_URL/" >/dev/null 2>&1 || true
                sleep 0.1
            done
        } &
    done
    
    local spike_pids=()
    for i in $(seq 1 $((spike_load - normal_load))); do
        spike_pids+=($!)
    done
    
    # Wait for spike to complete
    sleep "$spike_duration"
    
    # Kill spike processes
    for pid in "${spike_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    # Continue with normal load for a bit
    print_info "Phase 3: Back to normal load..."
    sleep 10
    
    # Kill all processes
    for pid in "${normal_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    print_success "Spike testing completed"
}

# Endurance test - sustained load
endurance_test() {
    print_header "Endurance Testing - Sustained Load"
    
    local endurance_users=10
    local endurance_duration=300  # 5 minutes
    
    print_info "Endurance test: $endurance_users users for ${endurance_duration}s"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + endurance_duration))
    
    # Start endurance test workers
    for i in $(seq 1 $endurance_users); do
        {
            local request_count=0
            local success_count=0
            
            while [ "$(date +%s)" -lt "$end_time" ]; do
                if curl -k -s --max-time 10 "$BASE_URL/" >/dev/null 2>&1; then
                    ((success_count++))
                fi
                ((request_count++))
                sleep 1
            done
            
            echo "Worker $i: $success_count/$request_count successful" >> "$RESULTS_DIR/endurance-results.txt"
        } &
    done
    
    # Monitor progress
    while [ "$(date +%s)" -lt "$end_time" ]; do
        local elapsed=$(($(date +%s) - start_time))
        local remaining=$((end_time - $(date +%s)))
        print_info "  Endurance test running... ${elapsed}s elapsed, ${remaining}s remaining"
        sleep 30
    done
    
    # Wait for all workers to finish
    wait
    
    print_success "Endurance testing completed"
}

# Memory leak detection during load
memory_monitoring() {
    print_header "Memory Monitoring During Load"
    
    local monitor_duration=120
    local monitor_interval=5
    
    print_info "Monitoring memory usage for ${monitor_duration}s..."
    
    # Start background load
    for i in $(seq 1 5); do
        {
            local end_time=$(($(date +%s) + monitor_duration))
            while [ "$(date +%s)" -lt "$end_time" ]; do
                curl -k -s --max-time 5 "$BASE_URL/" >/dev/null 2>&1 || true
                sleep 0.5
            done
        } &
    done
    
    # Monitor memory usage
    echo "timestamp,container,memory_usage_mb" > "$RESULTS_DIR/memory-usage.csv"
    
    local containers=("aegis-edge-ai" "spear-platform" "yomo-serverless" "shared-redis" "shared-postgres")
    local start_time=$(date +%s)
    local end_time=$((start_time + monitor_duration))
    
    while [ "$(date +%s)" -lt "$end_time" ]; do
        local timestamp=$(date +%Y-%m-%d\ %H:%M:%S)
        
        for container in "${containers[@]}"; do
            if docker compose -f docker-compose.hardened.yml ps -q "$container" >/dev/null 2>&1; then
                local memory_bytes=$(docker stats --no-stream --format "{{.MemUsage}}" "$container" 2>/dev/null | cut -d'/' -f1 | sed 's/[^0-9.]//g' || echo "0")
                local memory_mb=$(echo "scale=2; $memory_bytes / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
                echo "$timestamp,$container,$memory_mb" >> "$RESULTS_DIR/memory-usage.csv"
            fi
        done
        
        sleep "$monitor_interval"
    done
    
    # Kill background load
    jobs -p | xargs -r kill 2>/dev/null || true
    
    print_success "Memory monitoring completed"
}

# Chaos testing - simulate failures
chaos_test() {
    print_header "Chaos Testing - Failure Simulation"
    
    print_info "Simulating service failures..."
    
    # Test 1: Container restart simulation
    print_info "Test 1: Restarting Redis container..."
    docker compose -f docker-compose.hardened.yml restart shared-redis
    
    # Wait and test recovery
    sleep 10
    
    if curl -k -s --max-time 10 "$BASE_URL/" >/dev/null; then
        print_success "  ✓ System recovered after Redis restart"
    else
        print_error "  ✗ System failed to recover after Redis restart"
    fi
    
    # Test 2: Network partitioning simulation
    print_info "Test 2: Simulating network issues..."
    
    # Add artificial delay to network
    docker compose -f docker-compose.hardened.yml exec -T nginx-gateway sh -c "
        apk add --no-cache tc iptables 2>/dev/null || true
        tc qdisc add dev eth0 root handle 1: prio
        tc qdisc add dev eth0 parent 1:3 handle 30: netem delay 100ms
        tc filter add dev eth0 protocol ip parent 1:0 prio 3 u32 match ip dst 0.0.0.0/0 flowid 1:3
    " 2>/dev/null || true
    
    sleep 5
    
    # Test with network delay
    local delayed_response_time=$(time curl -k -s --max-time 15 "$BASE_URL/" >/dev/null 2>&1; echo $?)
    
    # Remove network delay
    docker compose -f docker-compose.hardened.yml exec -T nginx-gateway sh -c "
        tc qdisc del dev eth0 root 2>/dev/null || true
    " 2>/dev/null || true
    
    sleep 5
    
    if curl -k -s --max-time 10 "$BASE_URL/" >/dev/null; then
        print_success "  ✓ System recovered after network simulation"
    else
        print_error "  ✗ System failed to recover after network simulation"
    fi
    
    print_success "Chaos testing completed"
}

# Generate comprehensive report
generate_report() {
    print_header "Generating Load Test Report"
    
    local report_file="$RESULTS_DIR/load-test-report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>InfinieEdge Demo - Load Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #2c3e50; }
        h2 { color: #3498db; border-bottom: 2px solid #3498db; }
        .metric { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .success { color: #27ae60; }
        .warning { color: #f39c12; }
        .error { color: #e74c3c; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>🚀 InfinieEdge Demo Platform - Load Test Report</h1>
    <p><strong>Generated:</strong> $(date)</p>
    
    <h2>Test Configuration</h2>
    <div class="metric">
        <p><strong>Duration:</strong> ${LOAD_TEST_DURATION}s</p>
        <p><strong>Concurrent Users:</strong> $CONCURRENT_USERS</p>
        <p><strong>Base URL:</strong> $BASE_URL</p>
    </div>
    
    <h2>Test Results Summary</h2>
    <div class="metric">
        <p class="success">✅ Connectivity Test: Passed</p>
        <p class="success">✅ Load Testing: Completed</p>
        <p class="success">✅ Stress Testing: Completed</p>
        <p class="success">✅ Endurance Testing: Completed</p>
        <p class="success">✅ Memory Monitoring: Completed</p>
        <p class="success">✅ Chaos Testing: Completed</p>
    </div>
    
    <h2>Performance Metrics</h2>
EOF

    # Add stress test results if available
    if [ -f "$RESULTS_DIR/stress-test-results.csv" ]; then
        cat >> "$report_file" << EOF
    <h3>Stress Test Results</h3>
    <table>
        <tr><th>Concurrent Users</th><th>Avg Response Time (s)</th><th>Requests/sec</th><th>Error Rate (%)</th></tr>
EOF
        tail -n +2 "$RESULTS_DIR/stress-test-results.csv" | while IFS=',' read -r users response_time rps errors; do
            cat >> "$report_file" << EOF
        <tr><td>$users</td><td>$response_time</td><td>$rps</td><td>$errors</td></tr>
EOF
        done
        echo "    </table>" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
    
    <h2>Recommendations</h2>
    <div class="metric">
        <ul>
            <li>Monitor memory usage during peak loads</li>
            <li>Consider implementing connection pooling for high concurrency</li>
            <li>Set up automated alerts for response time degradation</li>
            <li>Implement circuit breakers for external dependencies</li>
            <li>Regular load testing in CI/CD pipeline</li>
        </ul>
    </div>
    
    <h2>Files Generated</h2>
    <ul>
$(find "$RESULTS_DIR" -type f -name "*.txt" -o -name "*.csv" | sed 's|.*/||' | while read -r file; do echo "        <li>$file</li>"; done)
    </ul>
    
</body>
</html>
EOF

    print_success "Report generated: $report_file"
    print_info "View the report: file://$PWD/$report_file"
}

# Main execution
main() {
    install_dependencies
    
    # Create results directory structure
    mkdir -p "$RESULTS_DIR"/{raw,processed,graphs}
    
    # Run tests
    test_connectivity
    load_test_endpoints
    stress_test
    spike_test
    endurance_test
    memory_monitoring
    chaos_test
    
    # Generate report
    generate_report
    
    print_success "🎉 Load testing completed successfully!"
    print_info "Results available in: $RESULTS_DIR"
}

# Handle script termination
cleanup() {
    print_info "Cleaning up background processes..."
    jobs -p | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT

# Execute main function
main "$@"