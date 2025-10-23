#!/bin/bash

# External Orchestrator Management Script

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

DOCKER_COMPOSE_FILE="docker-compose.external.yml"
CONTAINER_NAME="infiniedge-all-services"

# Show usage
show_usage() {
    echo "🚀 InfinieEdge External Orchestrator Management"
    echo "=============================================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  build       Build the external orchestrator container"
    echo "  start       Start all services in external container"
    echo "  stop        Stop the external container"
    echo "  restart     Restart the external container"
    echo "  status      Show container and service status"
    echo "  logs        Show container logs"
    echo "  shell       Open shell in running container"
    echo "  health      Check health of all services"
    echo "  clean       Remove container and clean up"
    echo "  rebuild     Clean rebuild of container"
    echo ""
    echo "Examples:"
    echo "  $0 build                # Build container"
    echo "  $0 start                # Start all services"
    echo "  $0 logs                 # View logs"
    echo "  $0 shell                # Interactive shell"
}

# Build the external container
build_container() {
    print_header "Building External Orchestrator Container"
    
    print_info "Building container with all services..."
    if docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache; then
        print_success "Container built successfully"
        
        # Show container size
        local image_size=$(docker images infiniedge_demo_infiniedge-orchestrator --format "table {{.Size}}" | tail -1)
        print_info "Container size: $image_size"
    else
        print_error "Failed to build container"
        exit 1
    fi
}

# Start all services
start_services() {
    print_header "Starting External Orchestrator"
    
    print_info "Starting container with all services..."
    if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d; then
        print_success "Container started successfully"
        
        # Wait for services to be ready
        print_info "Waiting for services to initialize..."
        sleep 15
        
        # Show access URLs
        print_success "🎉 All services are running!"
        print_info ""
        print_info "🌐 Access URLs:"
        print_info "  Main Dashboard:    http://localhost/"
        print_info "  AegisEdgeAI:      http://localhost/aegis/"
        print_info "  SPEAR:            http://localhost/spear/"
        print_info "  YoMo:             http://localhost/yomo/"
        print_info "  Shifu:            http://localhost/shifu/"
        print_info "  AIOps:            http://localhost/aiops/"
        print_info "  EDA:              http://localhost/eda/"
        print_info "  Edge Whisper:     http://localhost/edge-whisper/"
        print_info "  Whisper Finetune: http://localhost/whisper-finetune/"
        print_info "  Megatron-LM:      http://localhost/megatron/"
        print_info "  Transformers:     http://localhost/transformers/"
        print_info ""
        print_info "🔍 Direct service ports: 8080-8089"
        print_info "📊 Health check: http://localhost/health"
    else
        print_error "Failed to start container"
        exit 1
    fi
}

# Stop services
stop_services() {
    print_header "Stopping External Orchestrator"
    
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down; then
        print_success "Container stopped successfully"
    else
        print_error "Failed to stop container"
        exit 1
    fi
}

# Restart services
restart_services() {
    print_header "Restarting External Orchestrator"
    
    stop_services
    start_services
}

# Show status
show_status() {
    print_header "External Orchestrator Status"
    
    # Container status
    if docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        print_success "Container is running"
        echo ""
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # Service status inside container
        print_info ""
        print_info "Service status inside container:"
        docker exec -t "$CONTAINER_NAME" supervisorctl status 2>/dev/null || print_warning "Could not get service status"
        
        # Resource usage
        print_info ""
        print_info "Resource usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" "$CONTAINER_NAME" 2>/dev/null || true
        
    else
        print_warning "Container is not running"
        
        # Check if container exists but stopped
        if docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
            print_info "Container exists but is stopped"
            docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}"
        else
            print_info "Container does not exist"
        fi
    fi
}

# Show logs
show_logs() {
    print_header "External Orchestrator Logs"
    
    if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        print_info "Showing container logs (press Ctrl+C to exit)..."
        docker logs -f "$CONTAINER_NAME"
    else
        print_error "Container is not running"
        exit 1
    fi
}

# Open shell
open_shell() {
    print_header "Opening Shell in External Orchestrator"
    
    if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        print_info "Opening interactive shell in container..."
        docker exec -it "$CONTAINER_NAME" /bin/bash
    else
        print_error "Container is not running"
        exit 1
    fi
}

# Health check
health_check() {
    print_header "Health Check - All Services"
    
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        print_error "Container is not running"
        exit 1
    fi
    
    # Check container health
    local container_health=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    print_info "Container health: $container_health"
    
    # Check individual services
    local services=(
        "8080:AegisEdgeAI"
        "8081:SPEAR"
        "8082:YoMo"
        "8083:Shifu"
        "8084:AIOps"
        "8085:EDA"
        "8086:EdgeWhisper"
        "8087:WhisperFinetune"
        "8088:MegatronLM"
        "8089:Transformers"
    )
    
    print_info ""
    print_info "Individual service health checks:"
    
    local healthy_count=0
    local total_count=${#services[@]}
    
    for service in "${services[@]}"; do
        local port=$(echo "$service" | cut -d: -f1)
        local name=$(echo "$service" | cut -d: -f2)
        
        if curl -s -f "http://localhost:$port/health" >/dev/null 2>&1; then
            print_success "  ✅ $name (port $port)"
            ((healthy_count++))
        else
            print_error "  ❌ $name (port $port)"
        fi
    done
    
    print_info ""
    print_info "Health Summary: $healthy_count/$total_count services healthy"
    
    if [ $healthy_count -eq $total_count ]; then
        print_success "🎉 All services are healthy!"
    else
        print_warning "⚠️ Some services are not responding"
    fi
}

# Clean up
clean_up() {
    print_header "Cleaning Up External Orchestrator"
    
    print_warning "This will remove the container and all associated volumes."
    print_info "Continue? (y/N)"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Stopping and removing container..."
        docker-compose -f "$DOCKER_COMPOSE_FILE" down -v --remove-orphans
        
        print_info "Removing container image..."
        docker rmi "infiniedge_demo_infiniedge-orchestrator" 2>/dev/null || true
        
        print_success "Cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Rebuild container
rebuild_container() {
    print_header "Rebuilding External Orchestrator"
    
    print_info "Stopping container..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" down
    
    print_info "Removing old image..."
    docker rmi "infiniedge_demo_infiniedge-orchestrator" 2>/dev/null || true
    
    print_info "Building new container..."
    build_container
    
    print_info "Starting services..."
    start_services
}

# Main command handler
main() {
    local command=${1:-""}
    
    case "$command" in
        "build")
            build_container
            ;;
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "shell")
            open_shell
            ;;
        "health")
            health_check
            ;;
        "clean")
            clean_up
            ;;
        "rebuild")
            rebuild_container
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"