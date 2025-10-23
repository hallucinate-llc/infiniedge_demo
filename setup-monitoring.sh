#!/bin/bash

# Comprehensive Monitoring and Logging Setup for InfinieEdge Demo Platform

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

echo "📊 InfinieEdge Demo Platform - Monitoring & Logging Setup"
echo "========================================================="

# Create monitoring directory structure
create_monitoring_structure() {
    print_header "Creating Monitoring Directory Structure"
    
    mkdir -p monitoring/{prometheus,grafana,alertmanager,loki,fluentd}
    mkdir -p monitoring/grafana/{dashboards,provisioning/{datasources,dashboards}}
    mkdir -p monitoring/prometheus/rules
    mkdir -p logs/{nginx,services,security,audit}
    
    print_success "Directory structure created"
}

# Prometheus configuration
setup_prometheus() {
    print_header "Setting up Prometheus Configuration"
    
    cat > monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'infiniedge-demo'

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter for system metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # Docker daemon metrics
  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']

  # Nginx metrics
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-gateway:9113']
    metrics_path: '/metrics'

  # Redis metrics
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  # PostgreSQL metrics
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Application services
  - job_name: 'aegis-edge-ai'
    static_configs:
      - targets: ['aegis-edge-ai:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'spear-platform'
    static_configs:
      - targets: ['spear-platform:8081']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'yomo-serverless'
    static_configs:
      - targets: ['yomo-serverless:8082']
    metrics_path: '/metrics'
    scrape_interval: 30s

  # cAdvisor for container metrics
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # BlackBox Exporter for endpoint monitoring
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://localhost/
        - https://localhost/aegis/
        - https://localhost/spear/
        - https://localhost/yomo/
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
EOF

    print_success "Prometheus configuration created"
}

# Prometheus alerting rules
setup_alerting_rules() {
    print_header "Setting up Alerting Rules"
    
    cat > monitoring/prometheus/rules/alerts.yml << 'EOF'
groups:
  - name: infiniedge.rules
    rules:
    # High CPU usage
    - alert: HighCPUUsage
      expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage detected"
        description: "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}"

    # High memory usage
    - alert: HighMemoryUsage
      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Memory usage is above 85% on {{ $labels.instance }}"

    # Service down
    - alert: ServiceDown
      expr: up == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Service is down"
        description: "Service {{ $labels.job }} on {{ $labels.instance }} is down"

    # High response time
    - alert: HighResponseTime
      expr: probe_duration_seconds > 5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High response time detected"
        description: "Response time for {{ $labels.instance }} is above 5 seconds"

    # Container restart
    - alert: ContainerRestart
      expr: increase(container_start_time_seconds[1h]) > 0
      labels:
        severity: warning
      annotations:
        summary: "Container has been restarted"
        description: "Container {{ $labels.name }} has been restarted"

    # Disk space usage
    - alert: HighDiskUsage
      expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 90
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High disk usage detected"
        description: "Disk usage is above 90% on {{ $labels.instance }} for mount {{ $labels.mountpoint }}"

    # Redis connection issues
    - alert: RedisConnectionsHigh
      expr: redis_connected_clients / redis_config_maxclients * 100 > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High Redis connections"
        description: "Redis connections are above 80% of maximum"

    # PostgreSQL connection issues
    - alert: PostgreSQLConnectionsHigh
      expr: pg_stat_database_numbackends / pg_settings_max_connections * 100 > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High PostgreSQL connections"
        description: "PostgreSQL connections are above 80% of maximum"
EOF

    print_success "Alerting rules created"
}

# Grafana datasources
setup_grafana_datasources() {
    print_header "Setting up Grafana Datasources"
    
    cat > monitoring/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
EOF

    print_success "Grafana datasources configured"
}

# Grafana dashboard provisioning
setup_grafana_dashboards() {
    print_header "Setting up Grafana Dashboard Provisioning"
    
    cat > monitoring/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

    # Create main platform dashboard
    cat > monitoring/grafana/dashboards/infiniedge-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "InfinieEdge Demo Platform Overview",
    "tags": ["infiniedge"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Overview",
        "type": "stat",
        "targets": [
          {
            "expr": "up",
            "legendFormat": "Services Up"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{ instance }}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{ instance }}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Response Times",
        "type": "graph",
        "targets": [
          {
            "expr": "probe_duration_seconds",
            "legendFormat": "{{ instance }}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "5s"
  }
}
EOF

    print_success "Grafana dashboards created"
}

# Loki configuration for log aggregation
setup_loki() {
    print_header "Setting up Loki Configuration"
    
    cat > monitoring/loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  max_transfer_retries: 0

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index

  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
EOF

    print_success "Loki configuration created"
}

# Fluentd configuration for log collection
setup_fluentd() {
    print_header "Setting up Fluentd Configuration"
    
    cat > monitoring/fluentd/fluent.conf << 'EOF'
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<source>
  @type tail
  path /var/log/containers/*.log
  pos_file /var/log/fluentd-containers.log.pos
  tag docker.*
  format json
  read_from_head true
</source>

<filter docker.**>
  @type parser
  key_name log
  reserve_data true
  <parse>
    @type json
  </parse>
</filter>

<match docker.**>
  @type loki
  url http://loki:3100
  username ""
  password ""
  
  <label>
    container_name
    job $.kubernetes.container_name
  </label>
  
  <buffer>
    flush_interval 10s
    flush_at_shutdown true
  </buffer>
</match>

<match **>
  @type loki
  url http://loki:3100
  
  <label>
    job fluentd
  </label>
  
  <buffer>
    flush_interval 10s
  </buffer>
</match>
EOF

    print_success "Fluentd configuration created"
}

# Log rotation setup
setup_log_rotation() {
    print_header "Setting up Log Rotation"
    
    cat > monitoring/logrotate.conf << 'EOF'
/home/barberb/infiniedge_demo/logs/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        docker compose -f docker-compose.hardened.yml kill -s USR1 nginx-gateway 2>/dev/null || true
        docker compose -f docker-compose.hardened.yml restart fluentd 2>/dev/null || true
    endscript
}

/home/barberb/infiniedge_demo/logs/security/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
}

/home/barberb/infiniedge_demo/logs/audit/*.log {
    daily
    rotate 365
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
}
EOF

    # Create cron job for log rotation
    cat > monitoring/setup-logrotate.sh << 'EOF'
#!/bin/bash
# Setup log rotation cron job

# Copy logrotate config
sudo cp monitoring/logrotate.conf /etc/logrotate.d/infiniedge-demo

# Add cron job for hourly log rotation check
echo "0 * * * * root /usr/sbin/logrotate /etc/logrotate.d/infiniedge-demo" | sudo tee -a /etc/crontab

# Test logrotate configuration
sudo logrotate -d /etc/logrotate.d/infiniedge-demo
EOF

    chmod +x monitoring/setup-logrotate.sh
    print_success "Log rotation configured"
}

# Alertmanager configuration
setup_alertmanager() {
    print_header "Setting up Alertmanager Configuration"
    
    cat > monitoring/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@infiniedge.local'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
  - match:
      severity: critical
    receiver: critical-alerts
  - match:
      severity: warning
    receiver: warning-alerts

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'

- name: 'critical-alerts'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/critical'
    send_resolved: true

- name: 'warning-alerts'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/warning'
    send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

    print_success "Alertmanager configuration created"
}

# Update docker-compose with monitoring services
update_docker_compose_monitoring() {
    print_header "Updating Docker Compose with Monitoring Services"
    
    cat >> docker-compose.hardened.yml << 'EOF'

  # Monitoring Services
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - infiniedge_network
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "65534:65534"
    read_only: true
    tmpfs:
      - /tmp

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SECURITY_DISABLE_GRAVATAR=true
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_SECURITY_COOKIE_SECURE=true
      - GF_SECURITY_COOKIE_SAMESITE=strict
    networks:
      - infiniedge_network
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "472:472"

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager:/etc/alertmanager:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
    networks:
      - infiniedge_network
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "65534:65534"

  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./monitoring/loki:/etc/loki:ro
      - loki_data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    networks:
      - infiniedge_network
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "10001:10001"

  fluentd:
    image: fluent/fluentd:v1.16-debian-1
    container_name: fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"
    volumes:
      - ./monitoring/fluentd:/fluentd/etc:ro
      - ./logs:/var/log:ro
    networks:
      - infiniedge_network
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - infiniedge_network
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "65534:65534"
    read_only: true

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg
    networks:
      - infiniedge_network
    restart: unless-stopped

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox-exporter
    ports:
      - "9115:9115"
    volumes:
      - ./monitoring/blackbox:/etc/blackbox_exporter:ro
    networks:
      - infiniedge_network
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "65534:65534"
    read_only: true

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
  alertmanager_data:
    driver: local
  loki_data:
    driver: local
EOF

    print_success "Docker Compose updated with monitoring services"
}

# Create blackbox exporter config
setup_blackbox_exporter() {
    print_header "Setting up BlackBox Exporter"
    
    mkdir -p monitoring/blackbox
    
    cat > monitoring/blackbox/config.yml << 'EOF'
modules:
  http_2xx:
    prober: http
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: []
      method: GET
      headers:
        Host: localhost
        Accept-Language: en-US
      no_follow_redirects: false
      fail_if_ssl: false
      fail_if_not_ssl: true
      tls_config:
        insecure_skip_verify: true

  http_post_2xx:
    prober: http
    http:
      method: POST
      headers:
        Content-Type: application/json
      body: '{}'

  tcp_connect:
    prober: tcp

  pop3s_banner:
    prober: tcp
    tcp:
      query_response:
      - expect: "^+OK"
      tls: true
      tls_config:
        insecure_skip_verify: false

  grpc:
    prober: grpc
    grpc:
      tls: true
      preferred_ip_protocol: "ip4"

  grpc_plain:
    prober: grpc
    grpc:
      tls: false
      service: "service1"

  ssh_banner:
    prober: tcp
    tcp:
      query_response:
      - expect: "^SSH-2.0-"

  irc_banner:
    prober: tcp
    tcp:
      query_response:
      - send: "NICK prober"
      - send: "USER prober prober prober :prober"
      - expect: "PING :([^ ]+)"
        send: "PONG :${1}"
      - expect: "^:[^ ]+ 001"

  icmp:
    prober: icmp
EOF

    print_success "BlackBox Exporter configured"
}

# Create monitoring dashboard
create_monitoring_dashboard() {
    print_header "Creating Monitoring Dashboard Script"
    
    cat > monitoring-dashboard.sh << 'EOF'
#!/bin/bash

# Quick Monitoring Dashboard

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}📊 InfinieEdge Demo Platform - Monitoring Dashboard${NC}"
echo "==========================================================="

# System status
echo -e "\n${YELLOW}System Status:${NC}"
docker compose -f docker-compose.hardened.yml ps --format "table {{.Service}}\t{{.State}}\t{{.Status}}"

# Quick metrics
echo -e "\n${YELLOW}Quick Metrics:${NC}"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%\n", ($3/$2) * 100.0)}')"
echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"

# Service endpoints
echo -e "\n${YELLOW}Service Endpoints:${NC}"
echo "Dashboard: https://localhost/"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000"
echo "AlertManager: http://localhost:9093"

# Recent alerts
echo -e "\n${YELLOW}System Health:${NC}"
if docker compose -f docker-compose.hardened.yml exec -T prometheus wget -qO- "http://localhost:9090/api/v1/alerts" 2>/dev/null | grep -q '"state":"firing"'; then
    echo -e "${RED}⚠️  Active Alerts Detected${NC}"
else
    echo -e "${GREEN}✅ All Systems Normal${NC}"
fi

echo -e "\nPress Ctrl+C to exit monitoring..."
EOF

    chmod +x monitoring-dashboard.sh
    print_success "Monitoring dashboard script created"
}

# Main setup function
main() {
    create_monitoring_structure
    setup_prometheus
    setup_alerting_rules
    setup_grafana_datasources
    setup_grafana_dashboards
    setup_loki
    setup_fluentd
    setup_log_rotation
    setup_alertmanager
    setup_blackbox_exporter
    update_docker_compose_monitoring
    create_monitoring_dashboard
    
    print_success "🎉 Monitoring and logging setup completed!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Run: docker compose -f docker-compose.hardened.yml up -d"
    print_info "2. Access Grafana: http://localhost:3000 (admin/admin123)"
    print_info "3. Access Prometheus: http://localhost:9090"
    print_info "4. Monitor with: ./monitoring-dashboard.sh"
    print_info "5. Setup log rotation: ./monitoring/setup-logrotate.sh"
}

# Execute main function
main "$@"