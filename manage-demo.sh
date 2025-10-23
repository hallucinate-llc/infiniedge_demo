#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    echo "InfinieEdge Demo Docker Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build     Build all Docker images"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  status    Show status of all services"
    echo "  logs      Show logs from all services"
    echo "  clean     Clean up containers, images, and volumes"
    echo "  health    Check health of all services"
    echo "  shell     Open shell in a specific service"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build         # Build all images"
    echo "  $0 start         # Start all services"
    echo "  $0 logs yomo     # Show logs for YoMo service"
    echo "  $0 shell spear   # Open shell in SPEAR container"
    echo ""
}

# Check if Docker and Docker Compose are installed
check_requirements() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
}

# Build all images
build_images() {
    print_status "Building all Docker images..."
    
    # Build images in dependency order
    local services=(
        "shared-redis"
        "shared-postgres"
        "aegis-edge-ai"
        "spear"
        "yomo"
        "shifu"
        "edge-whisper"
        "eda"
        "aiops"
        "transformers"
        "megatron-lm"
        "whisper-finetune"
        "nginx-gateway"
    )
    
    for service in "${services[@]}"; do
        print_status "Building $service..."
        if docker compose build "$service"; then
            print_success "$service built successfully"
        else
            print_error "Failed to build $service"
            return 1
        fi
    done
    
    print_success "All images built successfully!"
}

# Start all services
start_services() {
    print_status "Starting InfinieEdge Demo Platform..."
    
    # Create external network if it doesn't exist
    if ! docker network ls | grep -q "infiniedge-network"; then
        print_status "Creating Docker network..."
        docker network create infiniedge-network
    fi
    
    # Start services in dependency order
    print_status "Starting infrastructure services..."
    docker compose up -d shared-redis shared-postgres
    
    sleep 10
    
    print_status "Starting core services..."
    docker compose up -d aegis-edge-ai spear yomo shifu
    
    sleep 15
    
    print_status "Starting application services..."
    docker compose up -d edge-whisper eda aiops transformers megatron-lm whisper-finetune
    
    sleep 10
    
    print_status "Starting gateway..."
    docker compose up -d nginx-gateway
    
    print_success "All services started!"
    print_status "Access the dashboard at: http://localhost"
    print_status "Use '$0 status' to check service health"
}

# Stop all services
stop_services() {
    print_status "Stopping all services..."
    docker compose down
    print_success "All services stopped!"
}

# Restart all services
restart_services() {
    print_status "Restarting all services..."
    stop_services
    sleep 5
    start_services
}

# Show service status
show_status() {
    print_status "Service Status:"
    docker compose ps
    echo ""
    print_status "Resource Usage:"
    docker stats --no-stream
}

# Show logs
show_logs() {
    local service=${1:-}
    
    if [ -z "$service" ]; then
        print_status "Showing logs for all services..."
        docker compose logs -f --tail=50
    else
        print_status "Showing logs for $service..."
        docker compose logs -f --tail=50 "$service"
    fi
}

# Clean up everything
clean_up() {
    print_warning "This will remove all containers, images, and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Stopping services..."
        docker compose down -v
        
        print_status "Removing images..."
        docker compose down --rmi all
        
        print_status "Cleaning up Docker system..."
        docker system prune -f
        
        print_success "Cleanup complete!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Health check
health_check() {
    print_status "Checking service health..."
    
    local services=(
        "aegis-edge-ai:5000"
        "spear-platform:9090"
        "yomo-serverless:9000"
        "shifu-gateway:8080"
        "edge-whisper:3000"
        "eda-platform:8000"
        "aiops-platform:8001"
        "transformers-service:7000"
        "megatron-lm:6000"
        "whisper-finetune:4000"
        "shared-redis:6379"
        "shared-postgres:5432"
    )
    
    for service in "${services[@]}"; do
        local name=$(echo "$service" | cut -d: -f1)
        local port=$(echo "$service" | cut -d: -f2)
        
        if docker compose exec -T "$name" nc -z localhost "$port" 2>/dev/null; then
            print_success "$name is healthy"
        else
            print_error "$name is not responding"
        fi
    done
    
    print_status "Gateway check..."
    if curl -s http://localhost >/dev/null 2>&1; then
        print_success "Gateway is accessible at http://localhost"
    else
        print_error "Gateway is not accessible"
    fi
}

# Open shell in container
open_shell() {
    local service=${1:-}
    
    if [ -z "$service" ]; then
        print_error "Please specify a service name"
        print_status "Available services:"
        docker compose ps --services
        return 1
    fi
    
    print_status "Opening shell in $service..."
    docker compose exec "$service" /bin/bash || docker compose exec "$service" /bin/sh
}

# Main execution
main() {
    local command=${1:-help}
    
    case $command in
        "build")
            check_requirements
            build_images
            ;;
        "start")
            check_requirements
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
            show_logs "$2"
            ;;
        "clean")
            clean_up
            ;;
        "health")
            health_check
            ;;
        "shell")
            open_shell "$2"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Execute main function with all arguments
main "$@"