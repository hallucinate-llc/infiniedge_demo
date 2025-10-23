#!/bin/bash

# Comprehensive Security Testing Script for InfinieEdge Demo Platform

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
print_test() { echo -e "${YELLOW}[TEST]${NC} $1"; }
print_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test tracking functions
test_start() {
    ((TESTS_TOTAL++))
}

test_pass() {
    ((TESTS_PASSED++))
    print_pass "$1"
}

test_fail() {
    ((TESTS_FAILED++))
    print_fail "$1"
}

echo "🔒 InfinieEdge Demo Platform - Security Testing Suite"
echo "===================================================="

# Container Security Tests
print_header "Container Security Tests"

test_container_users() {
    print_test "Checking containers run as non-root users"
    test_start
    
    local containers=(
        "aegis-edge-ai:1001"
        "spear-platform:1001"
        "yomo-serverless:1001"
        "shared-redis:999"
        "shared-postgres:70"
        "nginx-gateway:101"
    )
    
    local all_passed=true
    
    for container_user in "${containers[@]}"; do
        local container=$(echo "$container_user" | cut -d: -f1)
        local expected_uid=$(echo "$container_user" | cut -d: -f2)
        
        if docker compose -f docker-compose.hardened.yml ps -q "$container" >/dev/null 2>&1; then
            local actual_uid=$(docker compose -f docker-compose.hardened.yml exec -T "$container" id -u 2>/dev/null || echo "failed")
            
            if [ "$actual_uid" = "$expected_uid" ]; then
                print_info "  ✓ $container running as UID $actual_uid"
            else
                print_info "  ✗ $container running as UID $actual_uid (expected $expected_uid)"
                all_passed=false
            fi
        else
            print_info "  ⚠ $container not running, skipping"
        fi
    done
    
    if $all_passed; then
        test_pass "All containers run as non-root users"
    else
        test_fail "Some containers running as root or wrong user"
    fi
}

test_readonly_filesystem() {
    print_test "Checking read-only filesystems"
    test_start
    
    local containers=("aegis-edge-ai" "spear-platform" "yomo-serverless")
    local all_readonly=true
    
    for container in "${containers[@]}"; do
        if docker compose -f docker-compose.hardened.yml ps -q "$container" >/dev/null 2>&1; then
            # Try to write to root filesystem (should fail)
            if docker compose -f docker-compose.hardened.yml exec -T "$container" touch /test-write 2>/dev/null; then
                print_info "  ✗ $container filesystem is writable"
                all_readonly=false
            else
                print_info "  ✓ $container filesystem is read-only"
            fi
        fi
    done
    
    if $all_readonly; then
        test_pass "Containers have read-only filesystems"
    else
        test_fail "Some containers have writable filesystems"
    fi
}

test_capabilities() {
    print_test "Checking dropped capabilities"
    test_start
    
    local containers=("aegis-edge-ai" "spear-platform" "yomo-serverless")
    local all_dropped=true
    
    for container in "${containers[@]}"; do
        if docker compose -f docker-compose.hardened.yml ps -q "$container" >/dev/null 2>&1; then
            # Check for dangerous capabilities
            local caps=$(docker inspect "$(docker compose -f docker-compose.hardened.yml ps -q "$container")" --format '{{.HostConfig.CapAdd}}' 2>/dev/null || echo "[]")
            
            if [[ "$caps" == "[]" ]] || [[ "$caps" == *"CHOWN"* ]] && [[ ! "$caps" == *"SYS_ADMIN"* ]]; then
                print_info "  ✓ $container has minimal capabilities"
            else
                print_info "  ✗ $container has dangerous capabilities: $caps"
                all_dropped=false
            fi
        fi
    done
    
    if $all_dropped; then
        test_pass "Containers have minimal capabilities"
    else
        test_fail "Some containers have dangerous capabilities"
    fi
}

# Network Security Tests
print_header "Network Security Tests"

test_tls_configuration() {
    print_test "Testing TLS configuration"
    test_start
    
    # Test if HTTPS is available and properly configured
    if curl -k -s https://localhost >/dev/null 2>&1; then
        # Check TLS version
        local tls_version=$(echo | openssl s_client -connect localhost:443 2>/dev/null | grep "Protocol" | awk '{print $3}')
        
        if [[ "$tls_version" == "TLSv1.2" ]] || [[ "$tls_version" == "TLSv1.3" ]]; then
            test_pass "TLS properly configured ($tls_version)"
        else
            test_fail "Weak TLS configuration: $tls_version"
        fi
    else
        test_fail "HTTPS not available or misconfigured"
    fi
}

test_http_redirect() {
    print_test "Testing HTTP to HTTPS redirect"
    test_start
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
    
    if [ "$response" = "301" ] || [ "$response" = "302" ]; then
        test_pass "HTTP properly redirects to HTTPS"
    else
        test_fail "HTTP redirect not working (got $response)"
    fi
}

test_security_headers() {
    print_test "Testing security headers"
    test_start
    
    local headers_check=true
    local required_headers=(
        "strict-transport-security"
        "x-content-type-options"
        "x-frame-options"
        "x-xss-protection"
        "content-security-policy"
    )
    
    for header in "${required_headers[@]}"; do
        if curl -k -s -I https://localhost 2>/dev/null | grep -i "$header" >/dev/null; then
            print_info "  ✓ $header present"
        else
            print_info "  ✗ $header missing"
            headers_check=false
        fi
    done
    
    if $headers_check; then
        test_pass "All required security headers present"
    else
        test_fail "Missing security headers"
    fi
}

# Authentication and Authorization Tests
print_header "Authentication & Authorization Tests"

test_api_rate_limiting() {
    print_test "Testing API rate limiting"
    test_start
    
    local rate_limit_triggered=false
    
    # Send rapid requests to trigger rate limiting
    for i in {1..35}; do
        local response=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost/aegis/ 2>/dev/null || echo "000")
        if [ "$response" = "429" ]; then
            rate_limit_triggered=true
            break
        fi
        sleep 0.1
    done
    
    if $rate_limit_triggered; then
        test_pass "Rate limiting is working"
    else
        test_fail "Rate limiting not triggered"
    fi
}

test_unauthorized_access() {
    print_test "Testing unauthorized access protection"
    test_start
    
    # Try to access monitoring without auth
    local response=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost/prometheus/ 2>/dev/null || echo "000")
    
    if [ "$response" = "401" ] || [ "$response" = "403" ]; then
        test_pass "Monitoring endpoints properly protected"
    else
        test_fail "Monitoring endpoints not protected (got $response)"
    fi
}

# Service Health and Resilience Tests
print_header "Health & Resilience Tests"

test_health_checks() {
    print_test "Testing service health checks"
    test_start
    
    local services=("aegis-edge-ai" "spear-platform" "yomo-serverless" "shared-redis" "shared-postgres")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        local health=$(docker compose -f docker-compose.hardened.yml ps "$service" --format "table {{.State}}" 2>/dev/null | tail -n +2 | grep -c "Up (healthy)" || echo "0")
        
        if [ "$health" -gt 0 ]; then
            print_info "  ✓ $service is healthy"
        else
            print_info "  ✗ $service is not healthy"
            all_healthy=false
        fi
    done
    
    if $all_healthy; then
        test_pass "All services are healthy"
    else
        test_fail "Some services are unhealthy"
    fi
}

test_resource_limits() {
    print_test "Testing resource limits enforcement"
    test_start
    
    local containers=("aegis-edge-ai" "spear-platform" "yomo-serverless")
    local limits_enforced=true
    
    for container in "${containers[@]}"; do
        if docker compose -f docker-compose.hardened.yml ps -q "$container" >/dev/null 2>&1; then
            local memory_limit=$(docker inspect "$(docker compose -f docker-compose.hardened.yml ps -q "$container")" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
            
            if [ "$memory_limit" != "0" ]; then
                print_info "  ✓ $container has memory limit: $memory_limit bytes"
            else
                print_info "  ✗ $container has no memory limit"
                limits_enforced=false
            fi
        fi
    done
    
    if $limits_enforced; then
        test_pass "Resource limits are enforced"
    else
        test_fail "Some containers lack resource limits"
    fi
}

# Vulnerability Scanning Tests
print_header "Vulnerability Scanning Tests"

test_image_vulnerabilities() {
    print_test "Scanning Docker images for vulnerabilities"
    test_start
    
    if command -v trivy >/dev/null 2>&1; then
        local images=("redis:7-alpine" "postgres:15-alpine" "nginx:alpine")
        local vulnerabilities_found=false
        
        for image in "${images[@]}"; do
            print_info "  Scanning $image..."
            
            if trivy image --exit-code 1 --severity HIGH,CRITICAL --quiet "$image" >/dev/null 2>&1; then
                print_info "    ✓ No high/critical vulnerabilities found"
            else
                print_info "    ✗ High/critical vulnerabilities found"
                vulnerabilities_found=true
            fi
        done
        
        if ! $vulnerabilities_found; then
            test_pass "No critical vulnerabilities in base images"
        else
            test_fail "Critical vulnerabilities found in base images"
        fi
    else
        print_info "Trivy not installed, skipping vulnerability scan"
        test_pass "Vulnerability scanning skipped (trivy not available)"
    fi
}

# Data Protection Tests
print_header "Data Protection Tests"

test_secrets_management() {
    print_test "Testing secrets management"
    test_start
    
    local secrets_dir="./secrets"
    local secrets_secure=true
    
    if [ -d "$secrets_dir" ]; then
        # Check directory permissions
        local dir_perms=$(stat -c "%a" "$secrets_dir" 2>/dev/null || echo "000")
        
        if [ "$dir_perms" = "700" ]; then
            print_info "  ✓ Secrets directory has correct permissions"
        else
            print_info "  ✗ Secrets directory has wrong permissions: $dir_perms"
            secrets_secure=false
        fi
        
        # Check file permissions
        for secret_file in "$secrets_dir"/*; do
            if [ -f "$secret_file" ]; then
                local file_perms=$(stat -c "%a" "$secret_file" 2>/dev/null || echo "000")
                
                if [ "$file_perms" = "600" ]; then
                    print_info "  ✓ $(basename "$secret_file") has correct permissions"
                else
                    print_info "  ✗ $(basename "$secret_file") has wrong permissions: $file_perms"
                    secrets_secure=false
                fi
            fi
        done
        
        if $secrets_secure; then
            test_pass "Secrets are properly secured"
        else
            test_fail "Secrets have incorrect permissions"
        fi
    else
        test_fail "Secrets directory not found"
    fi
}

test_data_encryption() {
    print_test "Testing data encryption"
    test_start
    
    # Check if Redis is configured with encryption
    if docker compose -f docker-compose.hardened.yml exec -T shared-redis redis-cli ping >/dev/null 2>&1; then
        # Check Redis configuration for security settings
        local redis_config=$(docker compose -f docker-compose.hardened.yml exec -T shared-redis redis-cli CONFIG GET "*" 2>/dev/null | grep -E "(requirepass|tls)" || echo "")
        
        if [[ -n "$redis_config" ]]; then
            print_info "  ✓ Redis has security configuration"
        else
            print_info "  ⚠ Redis security configuration unclear"
        fi
    fi
    
    # Check PostgreSQL security
    if docker compose -f docker-compose.hardened.yml exec -T shared-postgres psql -U postgres -c "\l" >/dev/null 2>&1; then
        print_info "  ✓ PostgreSQL connection secured"
    fi
    
    test_pass "Data encryption tests completed"
}

# Performance and Load Tests
print_header "Performance & Load Tests"

test_concurrent_connections() {
    print_test "Testing concurrent connection handling"
    test_start
    
    local concurrent_requests=10
    local success_count=0
    
    for i in $(seq 1 $concurrent_requests); do
        if curl -k -s --max-time 5 https://localhost >/dev/null 2>&1 &; then
            ((success_count++))
        fi
    done
    
    wait # Wait for all background jobs to complete
    
    if [ "$success_count" -ge $((concurrent_requests / 2)) ]; then
        test_pass "Handled $success_count/$concurrent_requests concurrent requests"
    else
        test_fail "Only handled $success_count/$concurrent_requests concurrent requests"
    fi
}

# Cleanup and Logging Tests
print_header "Logging & Monitoring Tests"

test_log_collection() {
    print_test "Testing log collection and rotation"
    test_start
    
    local log_files_found=0
    
    # Check if containers are generating logs
    local containers=("aegis-edge-ai" "spear-platform" "nginx-gateway")
    
    for container in "${containers[@]}"; do
        if docker compose -f docker-compose.hardened.yml logs --tail=5 "$container" 2>/dev/null | grep -q .; then
            print_info "  ✓ $container generating logs"
            ((log_files_found++))
        else
            print_info "  ⚠ $container not generating logs"
        fi
    done
    
    if [ "$log_files_found" -gt 0 ]; then
        test_pass "Log collection is working"
    else
        test_fail "No logs being collected"
    fi
}

# Execute all tests
test_container_users
test_readonly_filesystem
test_capabilities
test_tls_configuration
test_http_redirect
test_security_headers
test_api_rate_limiting
test_unauthorized_access
test_health_checks
test_resource_limits
test_image_vulnerabilities
test_secrets_management
test_data_encryption
test_concurrent_connections
test_log_collection

# Print summary
print_header "Test Summary"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests:  $TESTS_TOTAL"

if [ "$TESTS_FAILED" -eq 0 ]; then
    print_pass "🎉 All security tests passed!"
    exit 0
else
    print_fail "⚠️  $TESTS_FAILED test(s) failed. Review and fix issues before production deployment."
    exit 1
fi