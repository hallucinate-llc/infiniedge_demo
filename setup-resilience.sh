#!/bin/bash

# Health Checks and Resilience Setup for InfinieEdge Demo Platform

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

echo "🔄 InfinieEdge Demo Platform - Health Checks & Resilience Setup"
echo "=============================================================="

# Create health check scripts directory
create_healthcheck_structure() {
    print_header "Creating Health Check Structure"
    
    mkdir -p healthchecks/{services,database,network}
    mkdir -p backup/{configs,data,scripts}
    mkdir -p recovery/{procedures,templates}
    
    print_success "Health check structure created"
}

# Generic health check script template
create_generic_healthcheck() {
    print_header "Creating Generic Health Check Template"
    
    cat > healthchecks/generic-healthcheck.sh << 'EOF'
#!/bin/bash

# Generic Health Check Script Template
# Usage: ./generic-healthcheck.sh <service_name> <health_endpoint> [timeout]

SERVICE_NAME=${1:-"unknown"}
HEALTH_ENDPOINT=${2:-"/health"}
TIMEOUT=${3:-10}
MAX_RETRIES=${4:-3}

check_service_health() {
    local retry_count=0
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if curl -f -s --max-time $TIMEOUT "$HEALTH_ENDPOINT" >/dev/null 2>&1; then
            echo "✅ $SERVICE_NAME is healthy"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            echo "⚠️ $SERVICE_NAME health check failed, retrying ($retry_count/$MAX_RETRIES)..."
            sleep 2
        fi
    done
    
    echo "❌ $SERVICE_NAME is unhealthy after $MAX_RETRIES attempts"
    return 1
}

check_service_health
EOF

    chmod +x healthchecks/generic-healthcheck.sh
    print_success "Generic health check template created"
}

# Service-specific health checks
create_service_healthchecks() {
    print_header "Creating Service-Specific Health Checks"
    
    # AegisEdgeAI health check
    cat > healthchecks/services/aegis-healthcheck.sh << 'EOF'
#!/bin/bash

SERVICE="AegisEdgeAI"
HEALTH_URL="http://localhost:8080/health"
METRICS_URL="http://localhost:8080/metrics"

echo "🔍 Checking $SERVICE health..."

# Basic connectivity
if ! curl -f -s --max-time 5 "$HEALTH_URL" >/dev/null; then
    echo "❌ $SERVICE health endpoint unreachable"
    exit 1
fi

# Check if metrics are being generated
if ! curl -f -s --max-time 5 "$METRICS_URL" | grep -q "aegis_"; then
    echo "⚠️ $SERVICE metrics not found"
fi

# Check memory usage
memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" aegis-edge-ai 2>/dev/null | cut -d'/' -f1 | sed 's/[^0-9.]//g')
if [ "$(echo "$memory_usage > 1000" | bc -l 2>/dev/null)" ]; then
    echo "⚠️ $SERVICE high memory usage: ${memory_usage}MB"
fi

echo "✅ $SERVICE is healthy"
EOF

    # SPEAR health check
    cat > healthchecks/services/spear-healthcheck.sh << 'EOF'
#!/bin/bash

SERVICE="SPEAR"
HEALTH_URL="http://localhost:8081/health"
API_URL="http://localhost:8081/api/v1/status"

echo "🔍 Checking $SERVICE health..."

# Basic connectivity
if ! curl -f -s --max-time 5 "$HEALTH_URL" >/dev/null; then
    echo "❌ $SERVICE health endpoint unreachable"
    exit 1
fi

# Check API responsiveness
if ! curl -f -s --max-time 5 "$API_URL" | grep -q "status"; then
    echo "⚠️ $SERVICE API not responding properly"
fi

# Check container resource usage
cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" spear-platform 2>/dev/null | sed 's/%//')
if [ "$(echo "$cpu_usage > 80" | bc -l 2>/dev/null)" ]; then
    echo "⚠️ $SERVICE high CPU usage: ${cpu_usage}%"
fi

echo "✅ $SERVICE is healthy"
EOF

    # YoMo health check
    cat > healthchecks/services/yomo-healthcheck.sh << 'EOF'
#!/bin/bash

SERVICE="YoMo"
HEALTH_URL="http://localhost:8082/health"
ZIPPER_URL="http://localhost:9000/v1/health"

echo "🔍 Checking $SERVICE health..."

# Basic connectivity
if ! curl -f -s --max-time 5 "$HEALTH_URL" >/dev/null; then
    echo "❌ $SERVICE health endpoint unreachable"
    exit 1
fi

# Check zipper service if available
if curl -f -s --max-time 3 "$ZIPPER_URL" >/dev/null 2>&1; then
    echo "✅ $SERVICE zipper is healthy"
else
    echo "⚠️ $SERVICE zipper not responding"
fi

echo "✅ $SERVICE is healthy"
EOF

    chmod +x healthchecks/services/*.sh
    print_success "Service health checks created"
}

# Database health checks
create_database_healthchecks() {
    print_header "Creating Database Health Checks"
    
    # Redis health check
    cat > healthchecks/database/redis-healthcheck.sh << 'EOF'
#!/bin/bash

SERVICE="Redis"
CONTAINER="shared-redis"

echo "🔍 Checking $SERVICE health..."

# Check container status
if ! docker compose -f docker-compose.hardened.yml ps -q "$CONTAINER" | xargs docker inspect --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; then
    echo "❌ $SERVICE container is not healthy"
    exit 1
fi

# Check Redis connectivity
if ! docker compose -f docker-compose.hardened.yml exec -T "$CONTAINER" redis-cli ping | grep -q PONG; then
    echo "❌ $SERVICE is not responding to ping"
    exit 1
fi

# Check memory usage
memory_info=$(docker compose -f docker-compose.hardened.yml exec -T "$CONTAINER" redis-cli info memory | grep used_memory_human)
echo "📊 $SERVICE $memory_info"

# Check connected clients
clients=$(docker compose -f docker-compose.hardened.yml exec -T "$CONTAINER" redis-cli info clients | grep connected_clients | cut -d: -f2)
echo "👥 $SERVICE connected clients: $clients"

echo "✅ $SERVICE is healthy"
EOF

    # PostgreSQL health check
    cat > healthchecks/database/postgres-healthcheck.sh << 'EOF'
#!/bin/bash

SERVICE="PostgreSQL"
CONTAINER="shared-postgres"

echo "🔍 Checking $SERVICE health..."

# Check container status
if ! docker compose -f docker-compose.hardened.yml ps -q "$CONTAINER" >/dev/null 2>&1; then
    echo "❌ $SERVICE container is not running"
    exit 1
fi

# Check PostgreSQL connectivity
if ! docker compose -f docker-compose.hardened.yml exec -T "$CONTAINER" pg_isready -U infiniedge >/dev/null 2>&1; then
    echo "❌ $SERVICE is not ready"
    exit 1
fi

# Check database connections
connections=$(docker compose -f docker-compose.hardened.yml exec -T "$CONTAINER" psql -U infiniedge -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ')
echo "🔗 $SERVICE active connections: $connections"

# Check database size
db_size=$(docker compose -f docker-compose.hardened.yml exec -T "$CONTAINER" psql -U infiniedge -t -c "SELECT pg_size_pretty(pg_database_size('infiniedge'));" 2>/dev/null | tr -d ' ')
echo "💾 $SERVICE database size: $db_size"

echo "✅ $SERVICE is healthy"
EOF

    chmod +x healthchecks/database/*.sh
    print_success "Database health checks created"
}

# Network health checks
create_network_healthchecks() {
    print_header "Creating Network Health Checks"
    
    cat > healthchecks/network/connectivity-check.sh << 'EOF'
#!/bin/bash

echo "🔍 Checking network connectivity..."

# Check internal network connectivity
SERVICES=("aegis-edge-ai:8080" "spear-platform:8081" "yomo-serverless:8082" "shared-redis:6379" "shared-postgres:5432")

for service in "${SERVICES[@]}"; do
    service_name=$(echo "$service" | cut -d: -f1)
    service_port=$(echo "$service" | cut -d: -f2)
    
    if docker compose -f docker-compose.hardened.yml exec -T nginx-gateway nc -z "$service_name" "$service_port" >/dev/null 2>&1; then
        echo "✅ $service_name:$service_port reachable"
    else
        echo "❌ $service_name:$service_port unreachable"
    fi
done

# Check external connectivity (if needed)
echo "🌐 Checking external connectivity..."
if curl -s --max-time 5 https://www.google.com >/dev/null; then
    echo "✅ External connectivity available"
else
    echo "⚠️ External connectivity limited"
fi

echo "✅ Network connectivity check completed"
EOF

    chmod +x healthchecks/network/connectivity-check.sh
    print_success "Network health checks created"
}

# Comprehensive health check orchestrator
create_health_orchestrator() {
    print_header "Creating Health Check Orchestrator"
    
    cat > healthchecks/health-monitor.sh << 'EOF'
#!/bin/bash

# Comprehensive Health Monitoring Orchestrator

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HEALTH_LOG="logs/health-monitor.log"
ALERT_THRESHOLD=3
FAILED_CHECKS=0

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$HEALTH_LOG"
}

run_health_check() {
    local check_script="$1"
    local check_name="$2"
    
    log_message "Running $check_name health check..."
    
    if timeout 30s bash "$check_script"; then
        log_message "✅ $check_name - PASSED"
        return 0
    else
        log_message "❌ $check_name - FAILED"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# Main health check sequence
main() {
    log_message "🏥 Starting comprehensive health check..."
    
    # Service health checks
    run_health_check "healthchecks/services/aegis-healthcheck.sh" "AegisEdgeAI"
    run_health_check "healthchecks/services/spear-healthcheck.sh" "SPEAR"
    run_health_check "healthchecks/services/yomo-healthcheck.sh" "YoMo"
    
    # Database health checks
    run_health_check "healthchecks/database/redis-healthcheck.sh" "Redis"
    run_health_check "healthchecks/database/postgres-healthcheck.sh" "PostgreSQL"
    
    # Network health checks
    run_health_check "healthchecks/network/connectivity-check.sh" "Network"
    
    # System resource check
    log_message "📊 System Resources:"
    log_message "  CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | sed 's/%us,//')"
    log_message "  Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
    log_message "  Disk: $(df -h / | awk 'NR==2{print $5}')"
    
    # Overall health assessment
    if [ $FAILED_CHECKS -eq 0 ]; then
        log_message "🎉 All health checks PASSED"
        exit 0
    elif [ $FAILED_CHECKS -lt $ALERT_THRESHOLD ]; then
        log_message "⚠️ $FAILED_CHECKS health check(s) failed - monitoring"
        exit 1
    else
        log_message "🚨 CRITICAL: $FAILED_CHECKS health checks failed - intervention required"
        exit 2
    fi
}

main "$@"
EOF

    chmod +x healthchecks/health-monitor.sh
    print_success "Health check orchestrator created"
}

# Backup and recovery scripts
create_backup_scripts() {
    print_header "Creating Backup and Recovery Scripts"
    
    # Configuration backup
    cat > backup/backup-configs.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="backup/configs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Backing up configurations..."

# Docker configurations
cp docker-compose*.yml "$BACKUP_DIR/"
cp -r monitoring/ "$BACKUP_DIR/"
cp -r healthchecks/ "$BACKUP_DIR/"
cp *.sh "$BACKUP_DIR/"

# Environment files
cp .env* "$BACKUP_DIR/" 2>/dev/null || true

# Certificates and secrets
if [ -d "certs" ]; then
    cp -r certs/ "$BACKUP_DIR/"
fi

# Create archive
tar -czf "backup/configs-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$BACKUP_DIR/.." "$(basename "$BACKUP_DIR")"

echo "✅ Configuration backup completed: $BACKUP_DIR"
EOF

    # Data backup
    cat > backup/backup-data.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="backup/data/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "💾 Backing up persistent data..."

# Redis backup
echo "Backing up Redis data..."
docker compose -f docker-compose.hardened.yml exec -T shared-redis redis-cli BGSAVE
docker compose -f docker-compose.hardened.yml exec -T shared-redis sh -c "while [ \$(redis-cli LASTSAVE) -eq \$(redis-cli LASTSAVE) ]; do sleep 1; done"
docker cp "$(docker compose -f docker-compose.hardened.yml ps -q shared-redis):/data/dump.rdb" "$BACKUP_DIR/redis-dump.rdb"

# PostgreSQL backup
echo "Backing up PostgreSQL data..."
docker compose -f docker-compose.hardened.yml exec -T shared-postgres pg_dump -U infiniedge infiniedge > "$BACKUP_DIR/postgres-backup.sql"

# Application data volumes
echo "Backing up application volumes..."
docker run --rm -v "$(pwd):/backup" -v infiniedge_demo_shared_postgres_data:/data alpine tar -czf /backup/"$BACKUP_DIR"/postgres-volume.tar.gz -C /data .
docker run --rm -v "$(pwd):/backup" -v infiniedge_demo_shared_redis_data:/data alpine tar -czf /backup/"$BACKUP_DIR"/redis-volume.tar.gz -C /data .

# Logs backup
if [ -d "logs" ]; then
    tar -czf "$BACKUP_DIR/logs-backup.tar.gz" logs/
fi

echo "✅ Data backup completed: $BACKUP_DIR"
EOF

    # Recovery script
    cat > recovery/restore-system.sh << 'EOF'
#!/bin/bash

# System Recovery Script

BACKUP_DATE=${1:-"latest"}

if [ "$BACKUP_DATE" = "latest" ]; then
    CONFIG_BACKUP=$(find backup/configs -name "configs-*.tar.gz" | sort | tail -1)
    DATA_BACKUP=$(find backup/data -maxdepth 1 -type d -name "20*" | sort | tail -1)
else
    CONFIG_BACKUP="backup/configs/configs-${BACKUP_DATE}.tar.gz"
    DATA_BACKUP="backup/data/${BACKUP_DATE}"
fi

echo "🔄 Starting system recovery..."
echo "Config backup: $CONFIG_BACKUP"
echo "Data backup: $DATA_BACKUP"

# Stop services
docker compose -f docker-compose.hardened.yml down

# Restore configurations
if [ -f "$CONFIG_BACKUP" ]; then
    echo "📋 Restoring configurations..."
    tar -xzf "$CONFIG_BACKUP" -C /tmp/
    cp -r /tmp/*/docker-compose*.yml .
    cp -r /tmp/*/monitoring/ .
    cp -r /tmp/*/healthchecks/ .
fi

# Restore data
if [ -d "$DATA_BACKUP" ]; then
    echo "💾 Restoring data..."
    
    # Restore PostgreSQL
    if [ -f "$DATA_BACKUP/postgres-backup.sql" ]; then
        docker compose -f docker-compose.hardened.yml up -d shared-postgres
        sleep 10
        docker compose -f docker-compose.hardened.yml exec -T shared-postgres psql -U infiniedge -c "DROP DATABASE IF EXISTS infiniedge;"
        docker compose -f docker-compose.hardened.yml exec -T shared-postgres psql -U infiniedge -c "CREATE DATABASE infiniedge;"
        docker compose -f docker-compose.hardened.yml exec -T shared-postgres psql -U infiniedge infiniedge < "$DATA_BACKUP/postgres-backup.sql"
    fi
    
    # Restore Redis
    if [ -f "$DATA_BACKUP/redis-dump.rdb" ]; then
        docker compose -f docker-compose.hardened.yml up -d shared-redis
        sleep 5
        docker cp "$DATA_BACKUP/redis-dump.rdb" "$(docker compose -f docker-compose.hardened.yml ps -q shared-redis):/data/dump.rdb"
        docker compose -f docker-compose.hardened.yml restart shared-redis
    fi
fi

# Start all services
docker compose -f docker-compose.hardened.yml up -d

echo "✅ System recovery completed"
echo "🔍 Running health checks..."
bash healthchecks/health-monitor.sh
EOF

    chmod +x backup/*.sh recovery/*.sh
    print_success "Backup and recovery scripts created"
}

# Auto-restart and resilience policies
create_resilience_policies() {
    print_header "Creating Resilience Policies"
    
    # Watchdog script for automatic service recovery
    cat > recovery/service-watchdog.sh << 'EOF'
#!/bin/bash

# Service Watchdog - Automatic Recovery System

LOG_FILE="logs/watchdog.log"
CHECK_INTERVAL=30
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=300  # 5 minutes

declare -A restart_counts
declare -A last_restart_time

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_and_restart_service() {
    local service="$1"
    local current_time=$(date +%s)
    
    # Check if service is running
    if ! docker compose -f docker-compose.hardened.yml ps -q "$service" | xargs docker inspect --format '{{.State.Status}}' 2>/dev/null | grep -q running; then
        log_message "🚨 Service $service is not running"
        
        # Check restart limits
        local restart_count=${restart_counts[$service]:-0}
        local last_restart=${last_restart_time[$service]:-0}
        local time_since_restart=$((current_time - last_restart))
        
        if [ $time_since_restart -gt $RESTART_COOLDOWN ]; then
            restart_counts[$service]=0
            restart_count=0
        fi
        
        if [ $restart_count -lt $MAX_RESTART_ATTEMPTS ]; then
            log_message "🔄 Attempting to restart $service (attempt $((restart_count + 1))/$MAX_RESTART_ATTEMPTS)"
            
            if docker compose -f docker-compose.hardened.yml up -d "$service"; then
                log_message "✅ Service $service restarted successfully"
                restart_counts[$service]=$((restart_count + 1))
                last_restart_time[$service]=$current_time
            else
                log_message "❌ Failed to restart $service"
            fi
        else
            log_message "⚠️ Service $service has exceeded maximum restart attempts"
        fi
    fi
}

# Main monitoring loop
main() {
    log_message "🐕 Service watchdog started"
    
    # Services to monitor
    SERVICES=("aegis-edge-ai" "spear-platform" "yomo-serverless" "shared-redis" "shared-postgres" "nginx-gateway")
    
    while true; do
        for service in "${SERVICES[@]}"; do
            check_and_restart_service "$service"
        done
        
        sleep $CHECK_INTERVAL
    done
}

# Handle script termination
cleanup() {
    log_message "🛑 Service watchdog stopping"
}

trap cleanup EXIT

main "$@"
EOF

    # Graceful shutdown script
    cat > recovery/graceful-shutdown.sh << 'EOF'
#!/bin/bash

# Graceful System Shutdown

echo "🛑 Initiating graceful shutdown..."

# Stop monitoring first
if pgrep -f "service-watchdog.sh" > /dev/null; then
    echo "Stopping service watchdog..."
    pkill -f "service-watchdog.sh"
fi

# Backup critical data before shutdown
echo "📦 Creating emergency backup..."
bash backup/backup-data.sh

# Gracefully stop services in reverse dependency order
echo "🔄 Stopping services gracefully..."

# Stop application services first
docker compose -f docker-compose.hardened.yml stop aegis-edge-ai spear-platform yomo-serverless

# Stop shared services
docker compose -f docker-compose.hardened.yml stop nginx-gateway

# Stop databases last
docker compose -f docker-compose.hardened.yml stop shared-redis shared-postgres

# Stop monitoring services
docker compose -f docker-compose.hardened.yml stop prometheus grafana alertmanager

echo "✅ Graceful shutdown completed"
EOF

    chmod +x recovery/*.sh
    print_success "Resilience policies created"
}

# System startup script with health validation
create_startup_script() {
    print_header "Creating System Startup Script"
    
    cat > startup-system.sh << 'EOF'
#!/bin/bash

# System Startup with Health Validation

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 InfinieEdge Demo Platform - System Startup"
echo "=============================================="

# Pre-startup checks
print_info "Running pre-startup checks..."

# Check Docker and Docker Compose
if ! docker --version >/dev/null 2>&1; then
    print_error "Docker is not available"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    print_error "Docker Compose is not available"
    exit 1
fi

# Check required files
REQUIRED_FILES=("docker-compose.hardened.yml" ".env.security")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file not found: $file"
        exit 1
    fi
done

print_success "Pre-startup checks passed"

# Start services in dependency order
print_info "Starting infrastructure services..."
docker compose -f docker-compose.hardened.yml up -d shared-postgres shared-redis

# Wait for databases to be ready
print_info "Waiting for databases to be ready..."
timeout 60s bash -c 'until docker compose -f docker-compose.hardened.yml exec -T shared-postgres pg_isready -U infiniedge; do sleep 2; done'
timeout 60s bash -c 'until docker compose -f docker-compose.hardened.yml exec -T shared-redis redis-cli ping | grep -q PONG; do sleep 2; done'

print_success "Databases are ready"

# Start application services
print_info "Starting application services..."
docker compose -f docker-compose.hardened.yml up -d aegis-edge-ai spear-platform yomo-serverless

# Start gateway
print_info "Starting gateway..."
docker compose -f docker-compose.hardened.yml up -d nginx-gateway

# Start monitoring (if available)
if grep -q "prometheus:" docker-compose.hardened.yml; then
    print_info "Starting monitoring services..."
    docker compose -f docker-compose.hardened.yml up -d prometheus grafana alertmanager loki
fi

# Wait for services to be ready
print_info "Waiting for services to be ready..."
sleep 30

# Run comprehensive health checks
print_info "Running health validation..."
if bash healthchecks/health-monitor.sh; then
    print_success "🎉 System startup completed successfully!"
    print_info ""
    print_info "Service URLs:"
    print_info "  Main Dashboard: https://localhost/"
    print_info "  AegisEdgeAI: https://localhost/aegis/"
    print_info "  SPEAR: https://localhost/spear/"
    print_info "  YoMo: https://localhost/yomo/"
    if grep -q "grafana:" docker-compose.hardened.yml; then
        print_info "  Grafana: http://localhost:3000"
        print_info "  Prometheus: http://localhost:9090"
    fi
    
    # Start watchdog if requested
    if [ "${START_WATCHDOG:-false}" = "true" ]; then
        print_info "Starting service watchdog..."
        nohup bash recovery/service-watchdog.sh > /dev/null 2>&1 &
        print_success "Service watchdog started (PID: $!)"
    fi
else
    print_error "Health validation failed - system may not be fully operational"
    exit 1
fi
EOF

    chmod +x startup-system.sh
    print_success "System startup script created"
}

# Main execution
main() {
    create_healthcheck_structure
    create_generic_healthcheck
    create_service_healthchecks
    create_database_healthchecks
    create_network_healthchecks
    create_health_orchestrator
    create_backup_scripts
    create_resilience_policies
    create_startup_script
    
    print_success "🎉 Health checks and resilience setup completed!"
    print_info ""
    print_info "Available commands:"
    print_info "  ./startup-system.sh                    - Start system with health validation"
    print_info "  ./healthchecks/health-monitor.sh       - Run comprehensive health check"
    print_info "  ./backup/backup-configs.sh             - Backup configurations"
    print_info "  ./backup/backup-data.sh                - Backup persistent data"
    print_info "  ./recovery/restore-system.sh [date]    - Restore system from backup"
    print_info "  ./recovery/service-watchdog.sh         - Start automatic service recovery"
    print_info "  ./recovery/graceful-shutdown.sh        - Graceful system shutdown"
}

# Execute main function
main "$@"