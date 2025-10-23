#!/bin/bash

# InfiniteEdge Deployment Script
# Handles deployment to different environments

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-test}"
IMAGE_TAG="${2:-latest}"
REGISTRY="ghcr.io"
REPO_NAME="${GITHUB_REPOSITORY:-hallucinate-llc/edge-whisper}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validate environment
validate_environment() {
    case "$ENVIRONMENT" in
        test|staging|production)
            log_info "Deploying to $ENVIRONMENT environment"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            log_info "Valid environments: test, staging, production"
            exit 1
            ;;
    esac
}

# Deploy to test environment
deploy_test() {
    log_info "Deploying to test environment with tag: $IMAGE_TAG"
    
    # Create test deployment configuration
    cat > docker-compose.test.yml << EOF
version: '3.8'

services:
  infiniedge-test:
    image: ${REGISTRY}/${REPO_NAME}/orchestrator:${IMAGE_TAG}
    ports:
      - "8888:80"
      - "9080-9090:8080-8090"
    environment:
      - ENVIRONMENT=test
      - IMAGE_TAG=${IMAGE_TAG}
      - DEPLOY_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    restart: unless-stopped
    
  # Test monitoring
  test-monitor:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./test-monitor.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - infiniedge-test
EOF
    
    # Create monitoring configuration
    cat > test-monitor.conf << EOF
events {
    worker_connections 1024;
}

http {
    upstream infiniedge {
        server infiniedge-test:80;
    }
    
    server {
        listen 80;
        location /monitor {
            return 200 "InfiniteEdge Test Environment\nImage: ${IMAGE_TAG}\nDeployed: $(date)\n";
            add_header Content-Type text/plain;
        }
        
        location / {
            proxy_pass http://infiniedge;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOF
    
    # Deploy
    docker-compose -f docker-compose.test.yml up -d
    
    # Wait for deployment
    log_info "Waiting for test deployment to be ready..."
    timeout 180 bash -c 'while ! docker-compose -f docker-compose.test.yml ps | grep -q "Up (healthy)"; do sleep 10; done'
    
    log_success "Test deployment completed successfully!"
    log_info "Access test environment at: http://localhost:8888"
    log_info "Monitor at: http://localhost:8080/monitor"
}

# Deploy to staging environment
deploy_staging() {
    log_info "Deploying to staging environment with tag: $IMAGE_TAG"
    
    # Create staging deployment with additional services
    cat > docker-compose.staging.yml << EOF
version: '3.8'

networks:
  infiniedge_staging:
    driver: bridge

volumes:
  staging_data:
  staging_logs:

services:
  infiniedge-staging:
    image: ${REGISTRY}/${REPO_NAME}/orchestrator:${IMAGE_TAG}
    networks:
      - infiniedge_staging
    ports:
      - "8888:80"
      - "9080-9090:8080-8090"
    environment:
      - ENVIRONMENT=staging
      - IMAGE_TAG=${IMAGE_TAG}
      - DEPLOY_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      - LOG_LEVEL=info
    volumes:
      - staging_data:/app/data
      - staging_logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
    
  # Staging load balancer
  staging-lb:
    image: nginx:alpine
    networks:
      - infiniedge_staging
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./staging-nginx.conf:/etc/nginx/nginx.conf:ro
      - staging_logs:/var/log/nginx
    depends_on:
      - infiniedge-staging
    restart: unless-stopped
    
  # Staging monitoring
  staging-monitor:
    image: prom/prometheus:latest
    networks:
      - infiniedge_staging
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    depends_on:
      - infiniedge-staging
EOF
    
    # Create staging nginx configuration
    cat > staging-nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    upstream infiniedge_backend {
        server infiniedge-staging:80 max_fails=3 fail_timeout=30s;
    }
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    
    server {
        listen 80;
        server_name _;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        
        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        # API rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://infiniedge_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
        
        # Default proxy
        location / {
            proxy_pass http://infiniedge_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF
    
    # Create Prometheus configuration
    cat > prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'infiniedge-staging'
    static_configs:
      - targets: ['infiniedge-staging:80']
    metrics_path: '/metrics'
    scrape_interval: 30s
EOF
    
    # Deploy staging
    docker-compose -f docker-compose.staging.yml up -d
    
    # Wait for staging deployment
    log_info "Waiting for staging deployment to be ready..."
    timeout 300 bash -c 'while ! docker-compose -f docker-compose.staging.yml ps | grep -q "Up (healthy)"; do sleep 15; done'
    
    log_success "Staging deployment completed successfully!"
    log_info "Access staging environment at: http://localhost"
    log_info "Monitoring at: http://localhost:9090"
}

# Deploy to production environment
deploy_production() {
    log_warning "Deploying to PRODUCTION environment with tag: $IMAGE_TAG"
    
    # Production safety check
    if [[ "$IMAGE_TAG" == "latest" ]]; then
        log_error "Cannot deploy 'latest' tag to production"
        log_info "Use a specific version tag for production deployments"
        exit 1
    fi
    
    # Confirm production deployment
    if [[ "${FORCE_PRODUCTION:-false}" != "true" ]]; then
        echo -n "Are you sure you want to deploy to PRODUCTION? (yes/no): "
        read -r confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Production deployment cancelled"
            exit 0
        fi
    fi
    
    log_info "Proceeding with production deployment..."
    
    # Create production deployment configuration
    cat > docker-compose.production.yml << EOF
version: '3.8'

networks:
  infiniedge_prod:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  prod_data:
    driver: local
  prod_logs:
    driver: local
  prod_backups:
    driver: local

services:
  infiniedge-production:
    image: ${REGISTRY}/${REPO_NAME}/orchestrator:${IMAGE_TAG}
    networks:
      - infiniedge_prod
    ports:
      - "8888:80"
      - "9080-9090:8080-8090"
    environment:
      - ENVIRONMENT=production
      - IMAGE_TAG=${IMAGE_TAG}
      - DEPLOY_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      - LOG_LEVEL=warn
      - ENABLE_METRICS=true
      - BACKUP_ENABLED=true
    volumes:
      - prod_data:/app/data
      - prod_logs:/app/logs
      - prod_backups:/app/backups
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 8G
        reservations:
          cpus: '2.0'
          memory: 4G
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
  # Production load balancer with SSL
  production-lb:
    image: nginx:alpine
    networks:
      - infiniedge_prod
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./production-nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - prod_logs:/var/log/nginx
    depends_on:
      - infiniedge-production
    restart: unless-stopped
    
  # Production monitoring stack
  prometheus:
    image: prom/prometheus:latest
    networks:
      - infiniedge_prod
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus-prod.yml:/etc/prometheus/prometheus.yml:ro
      - prod_data:/prometheus
    depends_on:
      - infiniedge-production
    restart: unless-stopped
    
  grafana:
    image: grafana/grafana:latest
    networks:
      - infiniedge_prod
    ports:
      - "3000:3000"
    volumes:
      - prod_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD:-admin}
    depends_on:
      - prometheus
    restart: unless-stopped
EOF
    
    # Create production nginx configuration with SSL
    cat > production-nginx.conf << EOF
events {
    worker_connections 2048;
}

http {
    upstream infiniedge_prod {
        server infiniedge-production:80 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }
    
    # Security and rate limiting
    limit_req_zone \$binary_remote_addr zone=prod_api:10m rate=20r/s;
    limit_req_zone \$binary_remote_addr zone=prod_global:10m rate=50r/s;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://\$host\$request_uri;
    }
    
    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name _;
        
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_private_key /etc/nginx/ssl/key.pem;
        
        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        
        # Rate limiting
        limit_req zone=prod_global burst=100 nodelay;
        
        # Health check (no rate limit)
        location = /health {
            access_log off;
            proxy_pass http://infiniedge_prod;
        }
        
        # API endpoints with stricter rate limiting
        location /api/ {
            limit_req zone=prod_api burst=40 nodelay;
            proxy_pass http://infiniedge_prod;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }
        
        # Default location
        location / {
            proxy_pass http://infiniedge_prod;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }
    }
}
EOF
    
    # Deploy production
    log_info "Starting production deployment..."
    docker-compose -f docker-compose.production.yml up -d
    
    # Wait for production deployment
    log_info "Waiting for production deployment to be ready..."
    timeout 600 bash -c 'while ! docker-compose -f docker-compose.production.yml ps | grep -q "Up (healthy)"; do sleep 20; done'
    
    # Verify deployment
    log_info "Verifying production deployment..."
    if curl -sf https://localhost/health >/dev/null 2>&1; then
        log_success "Production deployment completed successfully!"
        log_info "Access production environment at: https://localhost"
        log_info "Monitoring at: https://localhost:3000 (Grafana)"
        log_info "Metrics at: https://localhost:9090 (Prometheus)"
    else
        log_error "Production deployment verification failed!"
        log_info "Check logs: docker-compose -f docker-compose.production.yml logs"
        exit 1
    fi
}

# Rollback function
rollback() {
    local previous_tag="$1"
    log_warning "Rolling back to previous version: $previous_tag"
    
    case "$ENVIRONMENT" in
        test)
            docker-compose -f docker-compose.test.yml down
            IMAGE_TAG="$previous_tag"
            deploy_test
            ;;
        staging)
            docker-compose -f docker-compose.staging.yml down
            IMAGE_TAG="$previous_tag"
            deploy_staging
            ;;
        production)
            docker-compose -f docker-compose.production.yml down
            IMAGE_TAG="$previous_tag"
            deploy_production
            ;;
    esac
}

# Health check function
health_check() {
    local environment="$1"
    local port
    
    case "$environment" in
        test) port="8888" ;;
        staging) port="80" ;;
        production) port="443" ;;
    esac
    
    log_info "Checking health of $environment environment..."
    
    if curl -sf "http://localhost:$port/health" >/dev/null 2>&1; then
        log_success "$environment environment is healthy"
        return 0
    else
        log_error "$environment environment is not responding"
        return 1
    fi
}

# Main execution
case "$ENVIRONMENT" in
    test)
        validate_environment
        deploy_test
        ;;
    staging)
        validate_environment
        deploy_staging
        ;;
    production)
        validate_environment
        deploy_production
        ;;
    rollback)
        PREVIOUS_TAG="$IMAGE_TAG"
        ENVIRONMENT="${3:-test}"
        rollback "$PREVIOUS_TAG"
        ;;
    health)
        TARGET_ENV="${IMAGE_TAG:-test}"
        health_check "$TARGET_ENV"
        ;;
    *)
        log_error "Unknown deployment target: $ENVIRONMENT"
        log_info "Usage: $0 {test|staging|production|rollback|health} [image_tag] [environment]"
        exit 1
        ;;
esac
