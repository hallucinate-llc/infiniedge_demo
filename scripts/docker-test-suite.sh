#!/bin/bash

# InfiniteEdge Docker Testing Script
# Tests all Docker containers locally before pushing to Docker Hub

set -euo pipefail

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results/docker"
LOG_DIR="$PROJECT_ROOT/logs/docker-tests"

# Colors and icons
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

ICON_TEST="🧪"
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_BUILD="🔨"
ICON_RUN="🚀"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_section() {
    echo
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# Setup test environment
setup_test_environment() {
    log_section "${ICON_TEST} SETTING UP TEST ENVIRONMENT"
    
    # Create directories
    mkdir -p "$TEST_RESULTS_DIR" "$LOG_DIR"
    
    # Clean up any existing test containers
    log_info "Cleaning up existing test containers..."
    docker ps -a --filter "name=infiniteedge-test-" --format "table {{.Names}}" | tail -n +2 | xargs -r docker rm -f
    
    # Clean up test networks
    docker network ls --filter "name=infiniteedge-test-" --format "table {{.Name}}" | tail -n +2 | xargs -r docker network rm
    
    log_success "Test environment setup complete"
}

# Test container definitions
declare -A CONTAINERS=(
    ["orchestrator"]="orchestrator/Dockerfile"
    ["aegis-edge-ai"]="AegisEdgeAI/Dockerfile.simple"
    ["compliance-agent"]="AegisEdgeAI/compliance_agent/Dockerfile"
    ["spear"]="SPEAR/Dockerfile"
    ["shifu"]="shifu/dockerfiles/shifu/Dockerfile"
    ["yomo"]="yomo/Dockerfile"
)

# Test individual container
test_container() {
    local name=$1
    local dockerfile=$2
    local timestamp=$(date +%s)
    local test_name="infiniteedge-test-${name}-${timestamp}"
    local log_file="$LOG_DIR/${name}-test.log"
    
    log_section "${ICON_BUILD} TESTING $name CONTAINER"
    
    echo "Container: $name" > "$log_file"
    echo "Dockerfile: $dockerfile" >> "$log_file"
    echo "Test started: $(date)" >> "$log_file"
    echo "=========================" >> "$log_file"
    
    # Check if Dockerfile exists
    if [[ ! -f "$PROJECT_ROOT/$dockerfile" ]]; then
        log_warning "Dockerfile not found: $dockerfile"
        echo "SKIPPED: Dockerfile not found" >> "$log_file"
        return 0
    fi
    
    # Build container
    log_info "Building $name container..."
    local build_context
    build_context=$(dirname "$PROJECT_ROOT/$dockerfile")
    
    if docker build -t "$test_name" -f "$PROJECT_ROOT/$dockerfile" "$build_context" >> "$log_file" 2>&1; then
        log_success "$name container built successfully"
        echo "BUILD: SUCCESS" >> "$log_file"
    else
        log_error "$name container build failed"
        echo "BUILD: FAILED" >> "$log_file"
        return 1
    fi
    
    # Test container startup
    log_info "Testing $name container startup..."
    local container_id
    if container_id=$(docker run -d --name "$test_name" "$test_name" 2>> "$log_file"); then
        log_success "$name container started successfully"
        echo "STARTUP: SUCCESS" >> "$log_file"
        echo "CONTAINER_ID: $container_id" >> "$log_file"
        
        # Wait a moment for startup
        sleep 5
        
        # Check if container is still running
        if docker ps --filter "id=$container_id" --format "{{.ID}}" | grep -q .; then
            log_success "$name container is running"
            echo "RUNNING: SUCCESS" >> "$log_file"
            
            # Get container logs
            log_info "Collecting $name container logs..."
            docker logs "$container_id" >> "$log_file" 2>&1
            
        else
            log_warning "$name container stopped unexpectedly"
            echo "RUNNING: STOPPED" >> "$log_file"
            docker logs "$container_id" >> "$log_file" 2>&1
        fi
        
        # Cleanup
        docker stop "$container_id" >> "$log_file" 2>&1 || true
        docker rm "$container_id" >> "$log_file" 2>&1 || true
        
    else
        log_error "$name container startup failed"
        echo "STARTUP: FAILED" >> "$log_file"
        return 1
    fi
    
    # Cleanup image
    docker rmi "$test_name" >> "$log_file" 2>&1 || true
    
    echo "Test completed: $(date)" >> "$log_file"
    log_success "$name container test completed"
    return 0
}

# Test docker-compose configurations
test_docker_compose() {
    log_section "${ICON_TEST} TESTING DOCKER-COMPOSE CONFIGURATIONS"
    
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.hardened.yml"
        "docker-compose.external.yml"
    )
    
    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$compose_file" ]]; then
            log_info "Testing $compose_file..."
            local log_file="$LOG_DIR/compose-${compose_file%.*}-test.log"
            
            echo "Compose file: $compose_file" > "$log_file"
            echo "Test started: $(date)" >> "$log_file"
            echo "=========================" >> "$log_file"
            
            # Validate compose file
            if docker-compose -f "$PROJECT_ROOT/$compose_file" config >> "$log_file" 2>&1; then
                log_success "$compose_file is valid"
                echo "VALIDATION: SUCCESS" >> "$log_file"
                
                # Test build (dry-run)
                log_info "Testing build for $compose_file..."
                if docker-compose -f "$PROJECT_ROOT/$compose_file" build --dry-run >> "$log_file" 2>&1; then
                    log_success "$compose_file build test passed"
                    echo "BUILD_TEST: SUCCESS" >> "$log_file"
                else
                    log_warning "$compose_file build test failed"
                    echo "BUILD_TEST: FAILED" >> "$log_file"
                fi
            else
                log_error "$compose_file validation failed"
                echo "VALIDATION: FAILED" >> "$log_file"
            fi
            
            echo "Test completed: $(date)" >> "$log_file"
        else
            log_warning "$compose_file not found"
        fi
    done
}

# Test orchestrator with docker-compose
test_orchestrator_compose() {
    log_section "${ICON_RUN} TESTING ORCHESTRATOR WITH DOCKER-COMPOSE"
    
    local compose_file="docker-compose.yml"
    local project_name="infiniteedge-test-$(date +%s)"
    local log_file="$LOG_DIR/orchestrator-compose-test.log"
    
    echo "Orchestrator compose test" > "$log_file"
    echo "Project: $project_name" >> "$log_file"
    echo "Compose file: $compose_file" >> "$log_file"
    echo "Test started: $(date)" >> "$log_file"
    echo "=========================" >> "$log_file"
    
    if [[ ! -f "$PROJECT_ROOT/$compose_file" ]]; then
        log_warning "Docker compose file not found: $compose_file"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Start services
    log_info "Starting orchestrator services..."
    if docker-compose -p "$project_name" up -d >> "$log_file" 2>&1; then
        log_success "Orchestrator services started"
        echo "STARTUP: SUCCESS" >> "$log_file"
        
        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 30
        
        # Check service health
        log_info "Checking service health..."
        local services
        services=$(docker-compose -p "$project_name" ps --services)
        
        for service in $services; do
            if docker-compose -p "$project_name" ps "$service" | grep -q "Up"; then
                log_success "Service $service is running"
                echo "SERVICE_$service: RUNNING" >> "$log_file"
            else
                log_warning "Service $service is not running"
                echo "SERVICE_$service: NOT_RUNNING" >> "$log_file"
            fi
        done
        
        # Collect logs
        log_info "Collecting service logs..."
        docker-compose -p "$project_name" logs >> "$log_file" 2>&1
        
        # Cleanup
        log_info "Cleaning up orchestrator services..."
        docker-compose -p "$project_name" down -v >> "$log_file" 2>&1
        
    else
        log_error "Failed to start orchestrator services"
        echo "STARTUP: FAILED" >> "$log_file"
        return 1
    fi
    
    echo "Test completed: $(date)" >> "$log_file"
    log_success "Orchestrator compose test completed"
}

# Generate test report
generate_test_report() {
    log_section "📊 GENERATING TEST REPORT"
    
    local report_file="$TEST_RESULTS_DIR/docker-test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# InfiniteEdge Docker Test Report

**Generated:** $(date)
**Test Environment:** $(uname -a)
**Docker Version:** $(docker --version)

## Test Summary

EOF
    
    # Count test results
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    for log_file in "$LOG_DIR"/*.log; do
        if [[ -f "$log_file" ]]; then
            total_tests=$((total_tests + 1))
            
            if grep -q "SUCCESS" "$log_file"; then
                passed_tests=$((passed_tests + 1))
            elif grep -q "FAILED" "$log_file"; then
                failed_tests=$((failed_tests + 1))
            else
                skipped_tests=$((skipped_tests + 1))
            fi
        fi
    done
    
    cat >> "$report_file" << EOF
- **Total Tests:** $total_tests
- **Passed:** $passed_tests ✅
- **Failed:** $failed_tests ❌
- **Skipped:** $skipped_tests ⚠️

## Individual Test Results

EOF
    
    # Add individual test results
    for log_file in "$LOG_DIR"/*.log; do
        if [[ -f "$log_file" ]]; then
            local test_name
            test_name=$(basename "$log_file" .log)
            
            echo "### $test_name" >> "$report_file"
            echo >> "$report_file"
            
            if grep -q "SUCCESS" "$log_file"; then
                echo "**Status:** ✅ PASSED" >> "$report_file"
            elif grep -q "FAILED" "$log_file"; then
                echo "**Status:** ❌ FAILED" >> "$report_file"
            else
                echo "**Status:** ⚠️ SKIPPED" >> "$report_file"
            fi
            
            echo >> "$report_file"
            echo "**Log File:** \`$log_file\`" >> "$report_file"
            echo >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Next Steps

### If Tests Passed:
1. Run the Docker Hub deployment script:
   \`\`\`bash
   ./scripts/docker-hub-deploy.sh v1.0.0 amd64
   \`\`\`

2. For multi-architecture build:
   \`\`\`bash
   ./scripts/docker-hub-deploy.sh v1.0.0 multi
   \`\`\`

### If Tests Failed:
1. Review the log files in \`$LOG_DIR\`
2. Fix any identified issues
3. Re-run the tests

## Docker Hub Deployment Commands

\`\`\`bash
# Set Docker Hub credentials
export DOCKER_HUB_USERNAME="your-username"
export DOCKER_HUB_PASSWORD="your-password"

# Test and push single architecture
./scripts/docker-hub-deploy.sh v1.0.0 amd64

# Test and push ARM64
./scripts/docker-hub-deploy.sh v1.0.0 arm64

# Multi-architecture build and push
./scripts/docker-hub-deploy.sh v1.0.0 multi

# Test only (no push)
./scripts/docker-hub-deploy.sh v1.0.0 amd64 --test-only
\`\`\`

EOF
    
    log_success "Test report generated: $report_file"
    echo "View the report with: cat $report_file"
}

# Main execution
main() {
    log_section "${ICON_TEST} INFINITEEDGE DOCKER TESTING SUITE"
    
    setup_test_environment
    
    # Test individual containers
    local container_test_results=()
    for container_name in "${!CONTAINERS[@]}"; do
        dockerfile="${CONTAINERS[$container_name]}"
        if test_container "$container_name" "$dockerfile"; then
            container_test_results+=("$container_name:PASSED")
        else
            container_test_results+=("$container_name:FAILED")
        fi
    done
    
    # Test docker-compose configurations
    test_docker_compose
    
    # Test orchestrator with docker-compose
    test_orchestrator_compose
    
    # Generate report
    generate_test_report
    
    # Summary
    log_section "📋 TEST EXECUTION SUMMARY"
    
    echo -e "${CYAN}Container Test Results:${NC}"
    for result in "${container_test_results[@]}"; do
        IFS=':' read -r name status <<< "$result"
        if [[ "$status" == "PASSED" ]]; then
            echo "  ${ICON_SUCCESS} $name"
        else
            echo "  ${ICON_ERROR} $name"
        fi
    done
    
    echo
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Review test logs in: $LOG_DIR"
    echo "2. Check test report: $TEST_RESULTS_DIR"
    echo "3. If tests passed, run Docker Hub deployment:"
    echo "   ./scripts/docker-hub-deploy.sh v1.0.0 amd64"
    
    log_success "Docker testing suite completed"
}

# Error handling
trap 'log_error "Script failed at line $LINENO"' ERR

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi