#!/bin/bash

# Simple nginx startup as root with minimal configuration
# This runs nginx in the foreground for supervisor

echo "Starting nginx as root with minimal setup..."

# Create minimal directories
mkdir -p /tmp/nginx /run

# Create a minimal nginx.conf just for the gateway
cat > /tmp/nginx-simple.conf << 'EOF'
daemon off;
worker_processes 1;
error_log /dev/stderr;

events {
    worker_connections 1024;
}

http {
    access_log /dev/stdout;
    
    upstream health_backend {
        server localhost:8090;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location /health {
            return 200 "nginx gateway healthy\n";
            add_header Content-Type text/plain;
        }
        
        location /aegis/ {
            proxy_pass http://localhost:8080/;
        }
        
        location /yomo/ {
            proxy_pass http://localhost:8082/;
        }
        
        location /shifu/ {
            proxy_pass http://localhost:8083/;
        }
        
        location / {
            return 200 "InfiniteEdge Orchestrator Gateway\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Start nginx with simple config
exec nginx -c /tmp/nginx-simple.conf -g "pid /tmp/nginx.pid;"