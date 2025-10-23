#!/bin/bash

# InfiniteEdge Orchestrator Test Script
# Build and run the all-in-one orchestrator container

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
ICON_BUILD="🔨"
ICON_TEST="🧪"
ICON_RUN="🚀"
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_INFO="ℹ️"

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

# Configuration
CONTAINER_NAME="infiniteedge-orchestrator"
IMAGE_NAME="infiniteedge/orchestrator"
DOCKERFILE="orchestrator/Dockerfile.working"
COMPOSE_FILE="docker-compose.orchestrator.yml"
TEST_TIMEOUT=180  # 3 minutes

# Help function
show_help() {
    cat << EOF
InfiniteEdge Orchestrator Test Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  build       Build the orchestrator container
  run         Run the orchestrator container
  test        Build and test the orchestrator container
  stop        Stop the orchestrator container
  clean       Clean up containers and images
  logs        Show container logs
  status      Show container status
  health      Check container health
  help        Show this help

Options:
  --no-cache      Build without Docker cache
  --detach        Run container in background
  --rebuild       Stop, clean, and rebuild container
  --follow-logs   Follow logs after starting

Examples:
  $0 build                    # Build the container
  $0 run --detach            # Run in background
  $0 test                    # Build and test
  $0 logs                    # Show logs
  $0 clean                   # Clean up

Port Mappings:
  - Health Dashboard: http://localhost:8888/health.html
  - AegisEdgeAI: http://localhost:8080
  - SPEAR: http://localhost:8081
  - YoMo: http://localhost:8082
  - Shifu: http://localhost:8083
  - All services: ports 8080-8089

EOF
}

# Check prerequisites
check_prerequisites() {
    log_section "${ICON_INFO} CHECKING PREREQUISITES"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [[ ! -f "$DOCKERFILE" ]]; then
        log_error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi
    
    log_info "Docker version: $(docker --version)"
    log_info "Docker Compose version: $(docker-compose --version 2>/dev/null || docker compose version)"
    log_info "Architecture: $(uname -m)"
    log_success "Prerequisites check passed"
}

# Build container
build_container() {
    local no_cache=${1:-false}
    
    log_section "${ICON_BUILD} BUILDING ORCHESTRATOR CONTAINER"
    
    local build_args=(
        "--file" "$DOCKERFILE"
        "--tag" "$IMAGE_NAME:latest"
        "--tag" "$IMAGE_NAME:$(date +%Y%m%d-%H%M%S)"
    )
    
    if [[ "$no_cache" == "true" ]]; then
        build_args+=("--no-cache")
        log_info "Building without cache..."
    fi
    
    build_args+=(".")
    
    log_info "Building image: $IMAGE_NAME"
    log_info "Using Dockerfile: $DOCKERFILE"
    log_info "Build command: docker build ${build_args[*]}"
    
    if docker build "${build_args[@]}"; then
        log_success "Container built successfully"
        
        # Show image info
        local image_size
        image_size=$(docker images --format "table {{.Size}}" "$IMAGE_NAME:latest" | tail -n +2)
        log_info "Image size: $image_size"
        
        return 0
    else
        log_error "Container build failed"
        return 1
    fi
}

# Run container
run_container() {
    local detach=${1:-false}
    local follow_logs=${2:-false}
    
    log_section "${ICON_RUN} RUNNING ORCHESTRATOR CONTAINER"
    
    # Stop existing container if running
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        log_info "Stopping existing container..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Remove existing container
    if docker ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
        log_info "Removing existing container..."
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Run with Docker Compose
    if [[ -f "$COMPOSE_FILE" ]]; then
        log_info "Using Docker Compose: $COMPOSE_FILE"
        
        if [[ "$detach" == "true" ]]; then
            docker-compose -f "$COMPOSE_FILE" up -d
        else
            docker-compose -f "$COMPOSE_FILE" up
        fi
    else
        # Fallback to direct docker run
        log_info "Running container directly..."
        
        local run_args=(
            "--name" "$CONTAINER_NAME"
            "--hostname" "$CONTAINER_NAME"
            "--restart" "unless-stopped"
        )
        
        # Port mappings
        local ports=(
            "8888:80"   # Health dashboard
            "8080:8080" "8081:8081" "8082:8082" "8083:8083" "8084:8084"
            "8085:8085" "8086:8086" "8087:8087" "8088:8088" "8089:8089"
            "9000:9000" "9001:9001"
        )
        
        for port in "${ports[@]}"; do
            run_args+=("-p" "$port")
        done
        
        if [[ "$detach" == "true" ]]; then
            run_args+=("-d")
        fi
        
        run_args+=("$IMAGE_NAME:latest")
        
        docker run "${run_args[@]}"
    fi
    
    if [[ "$detach" == "true" ]]; then
        log_success "Container started in background"
        log_info "Health Dashboard: http://localhost:8888/health.html"
        log_info "Container name: $CONTAINER_NAME"
        
        if [[ "$follow_logs" == "true" ]]; then
            log_info "Following logs..."
            sleep 2
            docker logs -f "$CONTAINER_NAME"
        fi
    fi
}

# Test container
test_container() {
    log_section "${ICON_TEST} TESTING ORCHESTRATOR CONTAINER"
    
    # Build first
    if ! build_container; then
        log_error "Build failed, cannot test"
        return 1
    fi
    
    # Run in background
    if ! run_container true; then
        log_error "Failed to start container for testing"
        return 1
    fi
    
    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    local retries=0
    local max_retries=$((TEST_TIMEOUT / 5))
    
    while [ $retries -lt $max_retries ]; do
        if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then
            log_success "Container is running"
            break
        fi
        
        retries=$((retries + 1))
        log_info "Waiting... ($retries/$max_retries)"
        sleep 5
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "Container failed to start within $TEST_TIMEOUT seconds"
        show_container_logs
        return 1
    fi
    
    # Test health endpoint
    log_info "Testing health endpoints..."
    sleep 10  # Give services time to start
    
    local health_tests=(
        "http://localhost:8888/health.html:Health Dashboard"
        "http://localhost:8888/health.json:Health API"
    )
    
    for test in "${health_tests[@]}"; do
        IFS=':' read -r url description <<< "$test"
        
        if curl -s -f "$url" >/dev/null 2>&1; then
            log_success "$description is accessible"
        else
            log_warning "$description is not accessible (may be starting up)"
        fi
    done
    
    # Test individual service ports
    log_info "Testing service ports..."
    local service_ports=(8080 8081 8082 8083 8084 8085 8086 8087 8088 8089)
    local accessible_services=0
    
    for port in "${service_ports[@]}"; do
        if nc -z localhost "$port" 2>/dev/null; then
            log_success "Service on port $port is accessible"
            accessible_services=$((accessible_services + 1))
        else
            log_warning "Service on port $port is not accessible"
        fi
    done
    
    log_info "Services accessible: $accessible_services/${#service_ports[@]}"
    
    # Show container status
    show_container_status
    
    log_success "Container testing completed"
    log_info "Use '$0 logs' to see detailed logs"
    log_info "Use '$0 health' for continuous health monitoring"
    
    return 0
}

# Show container logs
show_container_logs() {
    if docker ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
        log_info "Container logs:"
        docker logs "$CONTAINER_NAME" --tail 50
    else
        log_warning "Container $CONTAINER_NAME not found"
    fi
}

# Show container status
show_container_status() {
    log_section "📊 CONTAINER STATUS"
    
    if docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        echo "Container Status:"
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo
        echo "Resource Usage:"
        docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
        echo
        echo "Health Check:"
        docker inspect "$CONTAINER_NAME" --format="{{.State.Health.Status}}" 2>/dev/null || echo "No health check configured"
    else
        log_warning "Container $CONTAINER_NAME is not running"
    fi
}

# Health monitoring
monitor_health() {
    log_section "🔍 HEALTH MONITORING"
    
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        log_error "Container $CONTAINER_NAME is not running"
        return 1
    fi
    
    log_info "Monitoring health endpoints... (Press Ctrl+C to stop)"
    log_info "Health Dashboard: http://localhost:8888/health.html"
    
    while true; do
        echo -n "$(date '+%H:%M:%S'): "
        
        if curl -s -f "http://localhost:8888/health.json" >/dev/null 2>&1; then
            local health_data
            health_data=$(curl -s "http://localhost:8888/health.json" 2>/dev/null || echo '{}')
            local healthy_count
            healthy_count=$(echo "$health_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('healthy_count', 0))" 2>/dev/null || echo "0")
            local total_count
            total_count=$(echo "$health_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('total_count', 10))" 2>/dev/null || echo "10")
            
            echo -e "${GREEN}✅ Health API OK${NC} - Services: $healthy_count/$total_count"
        else
            echo -e "${RED}❌ Health API Failed${NC}"
        fi
        
        sleep 10
    done
}

# Stop container
stop_container() {
    log_section "🛑 STOPPING ORCHESTRATOR CONTAINER"
    
    if [[ -f "$COMPOSE_FILE" ]]; then
        log_info "Stopping with Docker Compose..."
        docker-compose -f "$COMPOSE_FILE" down
    else
        if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
            log_info "Stopping container: $CONTAINER_NAME"
            docker stop "$CONTAINER_NAME"
        else
            log_warning "Container $CONTAINER_NAME is not running"
        fi
    fi
    
    log_success "Container stopped"
}

# Clean up
clean_up() {
    log_section "🧹 CLEANING UP"
    
    # Stop and remove container
    if docker ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
        log_info "Removing container: $CONTAINER_NAME"
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Remove Docker Compose resources
    if [[ -f "$COMPOSE_FILE" ]]; then
        log_info "Cleaning up Docker Compose resources..."
        docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans >/dev/null 2>&1 || true
    fi
    
    # Remove images
    if docker images -q "$IMAGE_NAME" | grep -q .; then
        log_info "Removing images: $IMAGE_NAME"
        docker rmi $(docker images -q "$IMAGE_NAME") >/dev/null 2>&1 || true
    fi
    
    # Clean up dangling images
    log_info "Cleaning up dangling images..."
    docker image prune -f >/dev/null 2>&1 || true
    
    log_success "Cleanup completed"
}

# Main execution
main() {
    local command=${1:-help}
    local options=()
    
    # Parse options
    for arg in "${@:2}"; do
        case $arg in
            --no-cache)
                options+=("no_cache")
                ;;
            --detach)
                options+=("detach")
                ;;
            --rebuild)
                options+=("rebuild")
                ;;
            --follow-logs)
                options+=("follow_logs")
                ;;
        esac
    done
    
    # Handle rebuild option
    if [[ " ${options[*]} " =~ " rebuild " ]]; then
        stop_container
        clean_up
    fi
    
    case $command in
        build)
            check_prerequisites
            local no_cache=false
            [[ " ${options[*]} " =~ " no_cache " ]] && no_cache=true
            build_container $no_cache
            ;;
        run)
            check_prerequisites
            local detach=false
            local follow_logs=false
            [[ " ${options[*]} " =~ " detach " ]] && detach=true
            [[ " ${options[*]} " =~ " follow_logs " ]] && follow_logs=true
            run_container $detach $follow_logs
            ;;
        test)
            check_prerequisites
            test_container
            ;;
        stop)
            stop_container
            ;;
        clean)
            clean_up
            ;;
        logs)
            show_container_logs
            ;;
        status)
            show_container_status
            ;;
        health)
            monitor_health
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Error handling
trap 'log_error "Script failed at line $LINENO"' ERR

# Execute main function
main "$@"