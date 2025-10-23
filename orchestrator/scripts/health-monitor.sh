#!/bin/bash

# InfiniteEdge Orchestrator - Health Monitor
# Monitors all services and provides health endpoints

set -euo pipefail

# Configuration
HEALTH_PORT=${HEALTH_PORT:-80}
HEALTH_INTERVAL=${HEALTH_INTERVAL:-30}
SERVICE_PORTS=(8080 8081 8082 8083 8084 8085 8086 8087 8088 8089)
SERVICE_NAMES=("AegisEdgeAI" "SPEAR" "YoMo" "Shifu" "AIOps" "EDA" "EdgeWhisper" "WhisperFinetune" "MegatronLM" "Transformers")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH]${NC} $1"; }
log_error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH]${NC} $1"; }

# Check if a service is healthy
check_service_health() {
    local port=$1
    local name=$2
    
    if nc -z localhost "$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Create simple HTTP health endpoint
create_health_endpoint() {
    local health_file="/tmp/health.html"
    local health_json="/tmp/health.json"
    
    while true; do
        local healthy_count=0
        local total_count=${#SERVICE_PORTS[@]}
        local services_json="[]"
        local html_content=""
        
        html_content="<!DOCTYPE html><html><head><title>InfiniteEdge Health</title></head><body>"
        html_content+="<h1>InfiniteEdge Health Dashboard</h1>"
        html_content+="<p>Generated: $(date)</p>"
        html_content+="<h2>Service Status</h2><ul>"
        
        # Build JSON array
        services_json="["
        
        for i in "${!SERVICE_PORTS[@]}"; do
            local port=${SERVICE_PORTS[$i]}
            local name=${SERVICE_NAMES[$i]}
            
            if check_service_health "$port" "$name"; then
                html_content+="<li style='color: green'>✅ $name (Port $port): HEALTHY</li>"
                services_json+="{\"name\":\"$name\",\"port\":$port,\"status\":\"healthy\"},"
                healthy_count=$((healthy_count + 1))
            else
                html_content+="<li style='color: red'>❌ $name (Port $port): UNHEALTHY</li>"
                services_json+="{\"name\":\"$name\",\"port\":$port,\"status\":\"unhealthy\"},"
            fi
        done
        
        # Remove trailing comma and close array
        services_json="${services_json%,}]"
        
        html_content+="</ul><h2>Summary</h2>"
        html_content+="<p>Healthy Services: $healthy_count/$total_count</p>"
        
        if [ "$healthy_count" -eq "$total_count" ]; then
            html_content+="<p style='color: green; font-weight: bold'>✅ ALL SERVICES HEALTHY</p>"
            overall_status="healthy"
        elif [ "$healthy_count" -gt 0 ]; then
            html_content+="<p style='color: orange; font-weight: bold'>⚠️ PARTIAL SERVICES HEALTHY</p>"
            overall_status="partial"
        else
            html_content+="<p style='color: red; font-weight: bold'>❌ ALL SERVICES UNHEALTHY</p>"
            overall_status="unhealthy"
        fi
        
        html_content+="</body></html>"
        
        # Write HTML health page
        echo "$html_content" > "$health_file"
        
        # Write JSON health data
        cat > "$health_json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overall_status": "$overall_status",
  "healthy_count": $healthy_count,
  "total_count": $total_count,
  "services": $services_json
}
EOF
        
        log_info "Health check: $healthy_count/$total_count services healthy"
        sleep "$HEALTH_INTERVAL"
    done
}

# Start simple HTTP server for health endpoint
start_health_server() {
    log_info "Starting health monitor on port $HEALTH_PORT"
    
    # Create health endpoint in background
    create_health_endpoint &
    
    # Start simple HTTP server
    cd /tmp
    python3 -m http.server "$HEALTH_PORT" --bind 0.0.0.0 &
    local server_pid=$!
    
    log_success "Health server started (PID: $server_pid)"
    
    # Wait for server to be ready
    sleep 2
    
    # Keep the script running
    wait
}

# Signal handlers
cleanup() {
    log_info "Shutting down health monitor..."
    jobs -p | xargs -r kill
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main execution
main() {
    log_info "InfiniteEdge Health Monitor starting..."
    log_info "Monitoring ${#SERVICE_PORTS[@]} services"
    log_info "Health endpoint: http://localhost:$HEALTH_PORT/health.html"
    log_info "Health API: http://localhost:$HEALTH_PORT/health.json"
    
    # Initial health check
    log_info "Running initial health check..."
    
    # Start health server
    start_health_server
}

# Execute main function
main "$@"
