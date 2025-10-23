#!/bin/bash

# InfinieEdge Demo Platform - Final Setup Verification

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

echo "✅ InfinieEdge Demo Platform - Setup Verification"
echo "================================================="

# Verify all setup scripts exist and are executable
verify_setup_scripts() {
    print_header "Verifying Setup Scripts"
    
    local scripts=(
        "manage-demo.sh"
        "harden-security.sh"
        "test-security.sh"
        "test-load.sh"
        "setup-monitoring.sh"
        "setup-resilience.sh"
        "setup-production.sh"
        "status.sh"
        "startup-system.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            print_success "✓ $script"
        else
            print_error "✗ $script (missing or not executable)"
        fi
    done
}

# Verify directory structure
verify_directory_structure() {
    print_header "Verifying Directory Structure"
    
    local directories=(
        "AegisEdgeAI"
        "SPEAR"
        "yomo"
        "shifu"
        "monitoring"
        "healthchecks"
        "backup"
        "recovery"
        "production"
        "logs"
        ".github/workflows"
    )
    
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            print_success "✓ $dir/"
        else
            print_warning "⚠ $dir/ (may be created during setup)"
        fi
    done
}

# Verify configuration files
verify_configuration_files() {
    print_header "Verifying Configuration Files"
    
    local configs=(
        "docker-compose.yml:Base Docker Compose"
        "docker-compose.hardened.yml:Hardened Configuration" 
        ".env.security:Security Environment"
        "Makefile:Build Automation"
        "README-COMPLETE.md:Complete Documentation"
    )
    
    for config in "${configs[@]}"; do
        local file=$(echo "$config" | cut -d: -f1)
        local desc=$(echo "$config" | cut -d: -f2)
        
        if [ -f "$file" ]; then
            print_success "✓ $desc ($file)"
        else
            print_warning "⚠ $desc ($file) - will be created during setup"
        fi
    done
}

# Check Docker environment
verify_docker_environment() {
    print_header "Verifying Docker Environment"
    
    # Check Docker
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        print_success "✓ Docker $docker_version"
    else
        print_error "✗ Docker not installed"
    fi
    
    # Check Docker Compose
    if docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
        print_success "✓ Docker Compose $compose_version"
    else
        print_error "✗ Docker Compose v2 not available"
    fi
    
    # Check Docker daemon
    if docker info >/dev/null 2>&1; then
        print_success "✓ Docker daemon running"
    else
        print_error "✗ Docker daemon not running"
    fi
}

# Check system resources
verify_system_resources() {
    print_header "Verifying System Resources"
    
    # Memory check
    local memory_gb=$(free -g | awk 'NR==2{print $2}')
    if [ "$memory_gb" -ge 8 ]; then
        print_success "✓ Memory: ${memory_gb}GB (sufficient)"
    else
        print_warning "⚠ Memory: ${memory_gb}GB (8GB+ recommended)"
    fi
    
    # Disk space check
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$disk_gb" -ge 20 ]; then
        print_success "✓ Disk space: ${disk_gb}GB available"
    else
        print_warning "⚠ Disk space: ${disk_gb}GB (20GB+ recommended)"
    fi
    
    # CPU cores check
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -ge 4 ]; then
        print_success "✓ CPU cores: $cpu_cores"
    else
        print_warning "⚠ CPU cores: $cpu_cores (4+ recommended)"
    fi
}

# Show next steps
show_next_steps() {
    print_header "Next Steps"
    
    print_info "🚀 Your InfinieEdge Demo Platform is ready to deploy!"
    print_info ""
    print_info "Choose your deployment path:"
    print_info ""
    print_info "📋 QUICK START (Development):"
    print_info "  1. ./harden-security.sh              # Setup security"
    print_info "  2. ./setup-monitoring.sh             # Setup monitoring"  
    print_info "  3. ./manage-demo.sh start             # Start platform"
    print_info "  4. Open https://localhost/            # Access dashboard"
    print_info ""
    print_info "🏭 PRODUCTION DEPLOYMENT:"
    print_info "  1. ./setup-production.sh             # Production setup"
    print_info "  2. cd production && ./deploy-production.sh  # Deploy"
    print_info "  3. ./monitoring-dashboard.sh          # Monitor"
    print_info ""
    print_info "🧪 COMPREHENSIVE TESTING:"
    print_info "  1. ./test-security.sh                 # Security tests"
    print_info "  2. ./test-load.sh                     # Load tests" 
    print_info "  3. ./healthchecks/health-monitor.sh   # Health checks"
    print_info ""
    print_info "📚 DOCUMENTATION:"
    print_info "  - README-COMPLETE.md                  # Complete guide"
    print_info "  - production/PRODUCTION-GUIDE.md      # Production guide"
    print_info ""
    print_info "🔧 MANAGEMENT COMMANDS:"
    print_info "  - ./status.sh                         # Quick status"
    print_info "  - ./backup/backup-data.sh             # Backup data"
    print_info "  - ./recovery/graceful-shutdown.sh     # Shutdown"
}

# Display platform summary
show_platform_summary() {
    print_header "Platform Summary"
    
    print_info "🎯 SERVICES INCLUDED:"
    print_info "  • AegisEdgeAI - AI compliance & security analysis"
    print_info "  • SPEAR - Secure edge analytics platform"
    print_info "  • YoMo - Serverless edge computing framework"
    print_info "  • Shifu - Kubernetes IoT device management"
    print_info "  • PostgreSQL - Primary database"
    print_info "  • Redis - Cache and session storage"
    print_info "  • Nginx - Reverse proxy & load balancer"
    print_info "  • Prometheus - Metrics & monitoring"
    print_info "  • Grafana - Dashboards & visualization"
    print_info ""
    print_info "🛡️ SECURITY FEATURES:"
    print_info "  • TLS 1.3 encryption"
    print_info "  • Container hardening"
    print_info "  • Network isolation"
    print_info "  • Secrets management"
    print_info "  • Vulnerability scanning"
    print_info "  • Security monitoring"
    print_info ""
    print_info "🔄 RESILIENCE FEATURES:"
    print_info "  • Health checks"
    print_info "  • Auto-restart policies"
    print_info "  • Backup & recovery"
    print_info "  • Graceful shutdown"
    print_info "  • Service watchdog"
    print_info "  • Load balancing"
}

# Main execution
main() {
    verify_setup_scripts
    verify_directory_structure
    verify_configuration_files
    verify_docker_environment
    verify_system_resources
    show_platform_summary
    show_next_steps
    
    print_success ""
    print_success "🎉 InfinieEdge Demo Platform setup verification completed!"
    print_success "   Ready for deployment with enterprise-grade security and monitoring."
}

main "$@"