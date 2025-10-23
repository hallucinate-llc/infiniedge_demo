#!/bin/bash

# API Test Script for InfinieEdge Demo Platform
# Tests basic connectivity and API endpoints of all services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[TEST]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "🧪 InfinieEdge Demo Platform - API Tests"
echo "========================================"

# Test function
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    print_status "Testing $name at $url"
    
    if response=$(curl -s -w "%{http_code}" -o /tmp/response "$url" 2>/dev/null); then
        if [ "$response" = "$expected_status" ]; then
            print_success "$name is responding correctly"
            return 0
        else
            print_error "$name returned status $response (expected $expected_status)"
            return 1
        fi
    else
        print_error "$name is not reachable"
        return 1
    fi
}

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 10

# Test main dashboard
test_endpoint "Main Dashboard" "http://localhost"

# Test individual services
echo ""
print_status "Testing individual services..."

# Services that should have health endpoints
test_endpoint "AegisEdgeAI" "http://localhost:5000" "200"
test_endpoint "SPEAR Platform" "http://localhost:9090" "200"
test_endpoint "YoMo Framework" "http://localhost:9000" "200"
test_endpoint "Shifu Gateway" "http://localhost:8080" "200"
test_endpoint "Edge Whisper" "http://localhost:3000" "200"
test_endpoint "EDA Platform" "http://localhost:8000" "200"
test_endpoint "AIOps Platform" "http://localhost:8001" "200"
test_endpoint "Transformers Service" "http://localhost:7000" "200"
test_endpoint "Megatron-LM" "http://localhost:6000" "200"
test_endpoint "Whisper Fine-tune" "http://localhost:4000" "200"

# Test infrastructure services
echo ""
print_status "Testing infrastructure services..."

test_endpoint "Redis" "http://localhost:6379" "200"
test_endpoint "PostgreSQL" "http://localhost:5432" "200"

# Test through gateway
echo ""
print_status "Testing gateway routing..."

test_endpoint "Gateway -> AegisEdgeAI" "http://localhost/aegis/"
test_endpoint "Gateway -> SPEAR" "http://localhost/spear/"
test_endpoint "Gateway -> YoMo" "http://localhost/yomo/"
test_endpoint "Gateway -> Shifu" "http://localhost/shifu/"
test_endpoint "Gateway -> Edge Whisper" "http://localhost/whisper/"
test_endpoint "Gateway -> EDA" "http://localhost/eda/"
test_endpoint "Gateway -> AIOps" "http://localhost/aiops/"

# Test inter-service communication
echo ""
print_status "Testing inter-service communication..."

# Test Redis connectivity from services
if docker compose exec -T shared-redis redis-cli ping | grep -q "PONG"; then
    print_success "Redis is accessible"
else
    print_error "Redis is not accessible"
fi

# Test PostgreSQL connectivity
if docker compose exec -T shared-postgres pg_isready | grep -q "accepting connections"; then
    print_success "PostgreSQL is accessible"
else
    print_error "PostgreSQL is not accessible"
fi

echo ""
print_status "API test summary complete!"
echo ""
print_status "🌐 Access the dashboard at: http://localhost"
print_status "📋 Check service status with: ./status.sh"
print_status "📊 View logs with: ./manage-demo.sh logs"