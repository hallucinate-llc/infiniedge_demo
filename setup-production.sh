#!/bin/bash

# Production Configuration and Deployment Automation for InfinieEdge Demo Platform

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

echo "🏭 InfinieEdge Demo Platform - Production Configuration"
echo "====================================================="

# Environment validation
validate_environment() {
    print_header "Environment Validation"
    
    local errors=0
    
    # Check system requirements
    print_info "Checking system requirements..."
    
    # Check available memory
    local memory_gb=$(free -g | awk 'NR==2{print $2}')
    if [ "$memory_gb" -lt 8 ]; then
        print_error "Insufficient memory: ${memory_gb}GB (minimum 8GB required)"
        ((errors++))
    else
        print_success "Memory: ${memory_gb}GB ✓"
    fi
    
    # Check available disk space
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$disk_gb" -lt 20 ]; then
        print_error "Insufficient disk space: ${disk_gb}GB (minimum 20GB required)"
        ((errors++))
    else
        print_success "Disk space: ${disk_gb}GB ✓"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 4 ]; then
        print_warning "Low CPU cores: $cpu_cores (recommended: 4+)"
    else
        print_success "CPU cores: $cpu_cores ✓"
    fi
    
    # Check Docker version
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local docker_major=$(echo "$docker_version" | cut -d. -f1)
    if [ "$docker_major" -lt 20 ]; then
        print_error "Docker version too old: $docker_version (minimum 20.0 required)"
        ((errors++))
    else
        print_success "Docker version: $docker_version ✓"
    fi
    
    # Check Docker Compose version
    if ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose v2 not available (docker compose command)"
        ((errors++))
    else
        print_success "Docker Compose v2 ✓"
    fi
    
    # Check required ports
    local required_ports=(80 443 3000 9090 9093 5432 6379)
    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is already in use"
        fi
    done
    
    if [ $errors -gt 0 ]; then
        print_error "$errors critical error(s) found. Please resolve before proceeding."
        return 1
    fi
    
    print_success "Environment validation passed"
    return 0
}

# Production environment setup
setup_production_environment() {
    print_header "Production Environment Setup"
    
    # Create production directory structure
    print_info "Creating production directory structure..."
    mkdir -p production/{configs,secrets,backups,logs,monitoring,scripts}
    mkdir -p production/configs/{nginx,prometheus,grafana,alertmanager}
    
    # Generate production environment file
    cat > production/.env.production << EOF
# InfinieEdge Demo Platform - Production Environment Configuration
# Generated on: $(date)

# Environment
NODE_ENV=production
ENVIRONMENT=production
DEBUG=false

# Security
SECURE_COOKIES=true
HTTPS_ONLY=true
HSTS_ENABLED=true
CSP_ENABLED=true

# Database Configuration
POSTGRES_DB=infiniedge_prod
POSTGRES_USER=infiniedge_prod
POSTGRES_PASSWORD=$(openssl rand -base64 32)
POSTGRES_HOST=shared-postgres
POSTGRES_PORT=5432

# Redis Configuration
REDIS_HOST=shared-redis
REDIS_PORT=6379
REDIS_PASSWORD=$(openssl rand -base64 32)

# Application Ports
AEGIS_PORT=8080
SPEAR_PORT=8081
YOMO_PORT=8082

# Monitoring
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)
ALERTMANAGER_PORT=9093

# SSL/TLS Configuration
SSL_CERT_PATH=/etc/ssl/certs/infiniedge.crt
SSL_KEY_PATH=/etc/ssl/private/infiniedge.key

# Logging
LOG_LEVEL=info
LOG_FORMAT=json
LOG_MAX_SIZE=100MB
LOG_MAX_FILES=10

# Resource Limits
MAX_MEMORY_AEGIS=2g
MAX_MEMORY_SPEAR=1g
MAX_MEMORY_YOMO=1g
MAX_MEMORY_POSTGRES=2g
MAX_MEMORY_REDIS=512m

# Backup Configuration
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM

# Health Check Configuration
HEALTH_CHECK_INTERVAL=30s
HEALTH_CHECK_TIMEOUT=10s
HEALTH_CHECK_RETRIES=3
HEALTH_CHECK_START_PERIOD=60s

# Performance Tuning
POSTGRES_MAX_CONNECTIONS=100
POSTGRES_SHARED_BUFFERS=256MB
REDIS_MAXMEMORY=400mb
NGINX_WORKER_PROCESSES=auto
NGINX_WORKER_CONNECTIONS=1024
EOF

    print_success "Production environment configuration created"
}

# Production Docker Compose
create_production_compose() {
    print_header "Creating Production Docker Compose"
    
    cat > production/docker-compose.production.yml << 'EOF'
version: '3.8'

networks:
  infiniedge_prod:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  postgres_prod_data:
    driver: local
  redis_prod_data:
    driver: local
  prometheus_prod_data:
    driver: local
  grafana_prod_data:
    driver: local
  nginx_prod_logs:
    driver: local

services:
  # Database Services
  shared-postgres:
    image: postgres:15-alpine
    container_name: postgres-prod
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--auth-host=md5"
    volumes:
      - postgres_prod_data:/var/lib/postgresql/data
      - ./production/configs/postgres:/docker-entrypoint-initdb.d:ro
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.10
    ports:
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
      start_period: ${HEALTH_CHECK_START_PERIOD}
    deploy:
      resources:
        limits:
          memory: ${MAX_MEMORY_POSTGRES}
        reservations:
          memory: 512m
    security_opt:
      - no-new-privileges:true
    user: "999:999"
    read_only: true
    tmpfs:
      - /tmp
      - /var/run/postgresql

  shared-redis:
    image: redis:7-alpine
    container_name: redis-prod
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory ${REDIS_MAXMEMORY} --maxmemory-policy allkeys-lru
    volumes:
      - redis_prod_data:/data
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.11
    ports:
      - "127.0.0.1:6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
    deploy:
      resources:
        limits:
          memory: ${MAX_MEMORY_REDIS}
        reservations:
          memory: 128m
    security_opt:
      - no-new-privileges:true
    user: "999:999"
    read_only: true
    tmpfs:
      - /tmp

  # Application Services
  aegis-edge-ai:
    build:
      context: ../AegisEdgeAI
      dockerfile: Dockerfile
    container_name: aegis-prod
    restart: unless-stopped
    environment:
      NODE_ENV: ${NODE_ENV}
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@shared-postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://:${REDIS_PASSWORD}@shared-redis:6379
    depends_on:
      shared-postgres:
        condition: service_healthy
      shared-redis:
        condition: service_healthy
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.20
    ports:
      - "127.0.0.1:${AEGIS_PORT}:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
      start_period: ${HEALTH_CHECK_START_PERIOD}
    deploy:
      resources:
        limits:
          memory: ${MAX_MEMORY_AEGIS}
          cpus: '2.0'
        reservations:
          memory: 512m
          cpus: '0.5'
    security_opt:
      - no-new-privileges:true
    user: "1001:1001"
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE

  spear-platform:
    build:
      context: ../SPEAR
      dockerfile: Dockerfile
    container_name: spear-prod
    restart: unless-stopped
    environment:
      ENVIRONMENT: ${ENVIRONMENT}
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@shared-postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://:${REDIS_PASSWORD}@shared-redis:6379
    depends_on:
      shared-postgres:
        condition: service_healthy
      shared-redis:
        condition: service_healthy
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.21
    ports:
      - "127.0.0.1:${SPEAR_PORT}:8081"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/health"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
      start_period: ${HEALTH_CHECK_START_PERIOD}
    deploy:
      resources:
        limits:
          memory: ${MAX_MEMORY_SPEAR}
          cpus: '1.0'
        reservations:
          memory: 256m
          cpus: '0.25'
    security_opt:
      - no-new-privileges:true
    user: "1001:1001"
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE

  yomo-serverless:
    build:
      context: ../yomo
      dockerfile: Dockerfile
    container_name: yomo-prod
    restart: unless-stopped
    environment:
      ENVIRONMENT: ${ENVIRONMENT}
      REDIS_URL: redis://:${REDIS_PASSWORD}@shared-redis:6379
    depends_on:
      shared-redis:
        condition: service_healthy
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.22
    ports:
      - "127.0.0.1:${YOMO_PORT}:8082"
      - "127.0.0.1:9000:9000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8082/health"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
      start_period: ${HEALTH_CHECK_START_PERIOD}
    deploy:
      resources:
        limits:
          memory: ${MAX_MEMORY_YOMO}
          cpus: '1.0'
        reservations:
          memory: 256m
          cpus: '0.25'
    security_opt:
      - no-new-privileges:true
    user: "1001:1001"
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE

  # Gateway Service
  nginx-gateway:
    image: nginx:alpine
    container_name: nginx-prod
    restart: unless-stopped
    volumes:
      - ./production/configs/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./production/configs/nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certs:/etc/ssl/certs:ro
      - nginx_prod_logs:/var/log/nginx
    depends_on:
      - aegis-edge-ai
      - spear-platform
      - yomo-serverless
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.30
    ports:
      - "80:80"
      - "443:443"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
    deploy:
      resources:
        limits:
          memory: 256m
          cpus: '0.5'
    security_opt:
      - no-new-privileges:true
    user: "101:101"
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /var/run

  # Monitoring Services
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus-prod
    restart: unless-stopped
    volumes:
      - ./monitoring/prometheus:/etc/prometheus:ro
      - prometheus_prod_data:/prometheus
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.40
    ports:
      - "127.0.0.1:${PROMETHEUS_PORT}:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
    deploy:
      resources:
        limits:
          memory: 1g
          cpus: '0.5'
    security_opt:
      - no-new-privileges:true
    user: "65534:65534"
    read_only: true
    tmpfs:
      - /tmp

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-prod
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SECURITY_DISABLE_GRAVATAR: "true"
      GF_ANALYTICS_REPORTING_ENABLED: "false"
      GF_ANALYTICS_CHECK_FOR_UPDATES: "false"
      GF_SECURITY_COOKIE_SECURE: "true"
      GF_SECURITY_COOKIE_SAMESITE: "strict"
      GF_SERVER_ROOT_URL: "https://localhost/grafana"
    volumes:
      - grafana_prod_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      infiniedge_prod:
        ipv4_address: 172.20.0.41
    ports:
      - "127.0.0.1:${GRAFANA_PORT}:3000"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: ${HEALTH_CHECK_INTERVAL}
      timeout: ${HEALTH_CHECK_TIMEOUT}
      retries: ${HEALTH_CHECK_RETRIES}
    deploy:
      resources:
        limits:
          memory: 512m
          cpus: '0.5'
    security_opt:
      - no-new-privileges:true
    user: "472:472"
EOF

    print_success "Production Docker Compose created"
}

# Deployment automation scripts
create_deployment_scripts() {
    print_header "Creating Deployment Automation Scripts"
    
    # Production deployment script
    cat > production/deploy-production.sh << 'EOF'
#!/bin/bash

# Production Deployment Script

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

DEPLOYMENT_LOG="logs/deployment-$(date +%Y%m%d-%H%M%S).log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$DEPLOYMENT_LOG"
}

# Pre-deployment validation
pre_deployment_checks() {
    print_info "Running pre-deployment checks..."
    
    # Check environment file
    if [ ! -f ".env.production" ]; then
        print_error "Production environment file not found"
        exit 1
    fi
    
    # Source environment
    set -a
    source .env.production
    set +a
    
    # Check required secrets
    local required_vars=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "GRAFANA_ADMIN_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            print_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Check SSL certificates
    if [ ! -f "../certs/infiniedge.crt" ] || [ ! -f "../certs/infiniedge.key" ]; then
        print_warning "SSL certificates not found, generating self-signed certificates..."
        ../harden-security.sh
    fi
    
    print_success "Pre-deployment checks passed"
}

# Build services
build_services() {
    print_info "Building services..."
    log_message "Starting service build"
    
    # Pull base images
    docker compose -f docker-compose.production.yml pull postgres redis nginx prometheus grafana
    
    # Build application images
    docker compose -f docker-compose.production.yml build --no-cache
    
    log_message "Service build completed"
    print_success "Services built successfully"
}

# Deploy services
deploy_services() {
    print_info "Deploying services..."
    log_message "Starting service deployment"
    
    # Start infrastructure services first
    docker compose -f docker-compose.production.yml up -d shared-postgres shared-redis
    
    # Wait for databases
    print_info "Waiting for databases..."
    sleep 30
    
    # Start application services
    docker compose -f docker-compose.production.yml up -d aegis-edge-ai spear-platform yomo-serverless
    
    # Wait for applications
    print_info "Waiting for applications..."
    sleep 30
    
    # Start gateway
    docker compose -f docker-compose.production.yml up -d nginx-gateway
    
    # Start monitoring
    docker compose -f docker-compose.production.yml up -d prometheus grafana
    
    log_message "Service deployment completed"
    print_success "Services deployed successfully"
}

# Post-deployment validation
post_deployment_validation() {
    print_info "Running post-deployment validation..."
    log_message "Starting post-deployment validation"
    
    # Wait for services to stabilize
    sleep 60
    
    # Run health checks
    if ! ../healthchecks/health-monitor.sh; then
        print_error "Health checks failed"
        return 1
    fi
    
    # Test endpoints
    local endpoints=("https://localhost/" "https://localhost/aegis/" "https://localhost/spear/" "https://localhost/yomo/")
    for endpoint in "${endpoints[@]}"; do
        if curl -k -f -s --max-time 10 "$endpoint" >/dev/null; then
            print_success "  ✓ $endpoint"
        else
            print_error "  ✗ $endpoint"
            return 1
        fi
    done
    
    log_message "Post-deployment validation completed successfully"
    print_success "Deployment validation passed"
}

# Main deployment function
main() {
    log_message "Starting production deployment"
    
    pre_deployment_checks
    build_services
    deploy_services
    post_deployment_validation
    
    print_success "🎉 Production deployment completed successfully!"
    print_info ""
    print_info "Access URLs:"
    print_info "  Main Dashboard: https://localhost/"
    print_info "  Grafana: http://localhost:3000"
    print_info "  Prometheus: http://localhost:9090"
    print_info ""
    print_info "Logs: $DEPLOYMENT_LOG"
}

# Cleanup on failure
cleanup_on_failure() {
    print_error "Deployment failed, cleaning up..."
    docker compose -f docker-compose.production.yml down
}

trap cleanup_on_failure ERR

main "$@"
EOF

    # Rolling update script
    cat > production/rolling-update.sh << 'EOF'
#!/bin/bash

# Rolling Update Script for Production Services

set -euo pipefail

SERVICE=${1:-"all"}
VERSION=${2:-"latest"}

print_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }

rolling_update_service() {
    local service="$1"
    
    print_info "Performing rolling update for $service..."
    
    # Build new image
    docker compose -f docker-compose.production.yml build "$service"
    
    # Create new container
    docker compose -f docker-compose.production.yml up -d --no-deps "$service"
    
    # Wait for health check
    local retries=0
    while [ $retries -lt 30 ]; do
        if docker compose -f docker-compose.production.yml ps "$service" | grep -q "healthy\|Up"; then
            print_success "$service updated successfully"
            return 0
        fi
        sleep 10
        ((retries++))
    done
    
    print_error "$service update failed"
    return 1
}

if [ "$SERVICE" = "all" ]; then
    for service in aegis-edge-ai spear-platform yomo-serverless; do
        rolling_update_service "$service"
    done
else
    rolling_update_service "$SERVICE"
fi
EOF

    chmod +x production/*.sh
    print_success "Deployment scripts created"
}

# CI/CD pipeline configuration
create_cicd_config() {
    print_header "Creating CI/CD Configuration"
    
    # GitHub Actions workflow
    mkdir -p .github/workflows
    cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy InfinieEdge Demo

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y apache2-utils bc
    
    - name: Setup security and monitoring
      run: |
        ./harden-security.sh
        ./setup-monitoring.sh
        ./setup-resilience.sh
    
    - name: Run security tests
      run: ./test-security.sh
    
    - name: Run load tests
      run: |
        ./manage-demo.sh start
        sleep 60
        ./test-load.sh
        ./manage-demo.sh stop

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Deploy to production
      run: |
        cd production
        ./deploy-production.sh
    
    - name: Run post-deployment tests
      run: |
        sleep 120
        ./healthchecks/health-monitor.sh
        ./test-load.sh
EOF

    # Makefile for common operations
    cat > Makefile << 'EOF'
.PHONY: setup build start stop test deploy clean

# Setup development environment
setup:
	@echo "Setting up InfinieEdge Demo Platform..."
	./harden-security.sh
	./setup-monitoring.sh
	./setup-resilience.sh

# Build all services
build:
	docker compose -f docker-compose.hardened.yml build

# Start development environment
start:
	./startup-system.sh

# Stop all services
stop:
	docker compose -f docker-compose.hardened.yml down

# Run comprehensive tests
test:
	./test-security.sh
	./test-load.sh
	./healthchecks/health-monitor.sh

# Deploy to production
deploy:
	cd production && ./deploy-production.sh

# Clean up all resources
clean:
	docker compose -f docker-compose.hardened.yml down -v
	docker system prune -f

# Show status
status:
	./status.sh

# Show logs
logs:
	docker compose -f docker-compose.hardened.yml logs -f

# Backup data
backup:
	./backup/backup-configs.sh
	./backup/backup-data.sh

# Monitor services
monitor:
	./monitoring-dashboard.sh
EOF

    print_success "CI/CD configuration created"
}

# Documentation generation
create_documentation() {
    print_header "Creating Production Documentation"
    
    cat > production/PRODUCTION-GUIDE.md << 'EOF'
# InfinieEdge Demo Platform - Production Deployment Guide

## Overview

This guide covers the production deployment of the InfinieEdge Demo Platform with all necessary security hardening, monitoring, and resilience features.

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or CentOS 8+
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: Minimum 20GB free space (50GB recommended)
- **CPU**: Minimum 4 cores (8 cores recommended)
- **Network**: Internet connectivity for image downloads

### Software Requirements
- Docker 20.0+
- Docker Compose v2
- OpenSSL
- curl, wget, netstat
- bc (for calculations)

## Quick Start

1. **Environment Setup**
   ```bash
   # Clone repository with submodules
   git clone --recursive <repository-url>
   cd infiniedge_demo
   
   # Validate environment
   ./setup-production.sh
   ```

2. **Security Hardening**
   ```bash
   # Generate certificates and secrets
   ./harden-security.sh
   ```

3. **Production Deployment**
   ```bash
   # Deploy production environment
   cd production
   ./deploy-production.sh
   ```

## Architecture

### Services Overview
- **AegisEdgeAI**: AI-powered compliance and security analysis
- **SPEAR**: Secure platform for edge analytics and runtime
- **YoMo**: Serverless framework for edge computing
- **PostgreSQL**: Primary database for structured data
- **Redis**: Cache and session storage
- **Nginx**: Reverse proxy and load balancer
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and dashboards

### Network Architecture
```
Internet → Nginx (443/80) → Services (Internal Network)
                ↓
    Prometheus ← Services → PostgreSQL/Redis
        ↓
    Grafana
```

## Security Features

### Container Security
- Non-root user execution
- Read-only filesystems
- Capability dropping
- Seccomp profiles
- Resource limitations

### Network Security
- TLS 1.3 encryption
- Internal network isolation
- Secure service communication
- Rate limiting
- HSTS headers

### Data Security
- Encrypted passwords and secrets
- Certificate-based authentication
- Secure database connections
- Audit logging

## Monitoring & Alerting

### Metrics Collection
- System metrics (CPU, memory, disk)
- Application metrics
- Database performance
- Network statistics

### Alerting Rules
- High resource usage
- Service downtime
- Response time degradation
- Security incidents

### Dashboards
- System overview
- Service health
- Performance metrics
- Security monitoring

## Operations

### Daily Operations
```bash
# Check system status
./status.sh

# View health status
./healthchecks/health-monitor.sh

# Monitor dashboard
./monitoring-dashboard.sh
```

### Backup Operations
```bash
# Backup configurations
./backup/backup-configs.sh

# Backup data
./backup/backup-data.sh

# Automated backup (cron)
0 2 * * * /path/to/backup/backup-data.sh
```

### Update Operations
```bash
# Rolling update specific service
./production/rolling-update.sh aegis-edge-ai

# Full system update
./production/rolling-update.sh all
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   ```bash
   # Check logs
   docker compose -f docker-compose.production.yml logs <service>
   
   # Check health
   docker compose -f docker-compose.production.yml ps
   ```

2. **Performance Issues**
   ```bash
   # Check resource usage
   docker stats
   
   # Monitor metrics
   open http://localhost:3000
   ```

3. **SSL Certificate Issues**
   ```bash
   # Regenerate certificates
   ./harden-security.sh
   
   # Verify certificates
   openssl x509 -in certs/infiniedge.crt -text -noout
   ```

### Emergency Procedures

1. **Service Recovery**
   ```bash
   # Automatic recovery
   ./recovery/service-watchdog.sh &
   
   # Manual recovery
   ./startup-system.sh
   ```

2. **System Restore**
   ```bash
   # Restore from backup
   ./recovery/restore-system.sh [backup-date]
   ```

3. **Graceful Shutdown**
   ```bash
   ./recovery/graceful-shutdown.sh
   ```

## Security Compliance

### Regular Security Tasks
- [ ] Update base images monthly
- [ ] Rotate secrets quarterly
- [ ] Review access logs weekly
- [ ] Update SSL certificates annually
- [ ] Vulnerability scanning monthly

### Audit Checklist
- [ ] All services running as non-root
- [ ] TLS encryption enabled
- [ ] Secrets properly managed
- [ ] Logging configured
- [ ] Monitoring active
- [ ] Backups tested

## Support

For issues and support:
1. Check logs: `./logs/`
2. Run diagnostics: `./test-security.sh`
3. Monitor status: `./monitoring-dashboard.sh`
4. Review documentation: `./docs/`

## License

[Include appropriate license information]
EOF

    print_success "Production documentation created"
}

# Main execution
main() {
    validate_environment
    setup_production_environment
    create_production_compose
    create_deployment_scripts
    create_cicd_config
    create_documentation
    
    print_success "🏭 Production configuration completed!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Review production/.env.production"
    print_info "2. Deploy: cd production && ./deploy-production.sh"
    print_info "3. Monitor: ./monitoring-dashboard.sh"
    print_info "4. Read: production/PRODUCTION-GUIDE.md"
}

# Execute main function
main "$@"