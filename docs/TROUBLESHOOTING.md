# Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting information for the InfiniteEdge platform, covering common issues, diagnostic procedures, and resolution strategies.

## Quick Diagnostics

### System Health Check

```bash
# Check overall system status
./manage-external.sh status

# Verify all services are running
docker exec infiniedge-all-services supervisorctl status

# Test gateway connectivity
curl -s http://localhost:8888/health

# Check resource usage
docker stats infiniedge-all-services
```

### Service Status Matrix

| Service | Port | Status Check | Expected Response |
|---------|------|--------------|-------------------|
| Gateway | 8888 | `curl localhost:8888/health` | "HTTP Gateway Fallback - Healthy" |
| AegisEdgeAI | 9080 | `curl localhost:9080/health` | `{"status": "healthy"}` |
| SPEAR | 9081 | `curl localhost:9081/health` | `{"status": "healthy"}` |
| YoMo | 9082 | `curl localhost:9082/health` | `{"status": "healthy"}` |
| Shifu | 9083 | `curl localhost:9083/health` | `{"status": "healthy"}` |
| AIOps | 9084 | `curl localhost:9084/health` | `{"status": "healthy"}` |
| EDA | 9085 | `curl localhost:9085/health` | `{"status": "healthy"}` |
| Edge Whisper | 9086 | `curl localhost:9086/health` | `{"status": "healthy"}` |
| Whisper Finetune | 9087 | `curl localhost:9087/health` | `{"status": "healthy"}` |
| Megatron-LM | 9088 | `curl localhost:9088/health` | `{"status": "healthy"}` |
| Transformers | 9089 | `curl localhost:9089/health` | `{"status": "healthy"}` |
| Health Monitor | 9090 | `curl localhost:9090/health` | `{"status": "healthy"}` |

## Common Issues

### 1. Container Startup Issues

#### Issue: Container fails to start

**Symptoms:**
```bash
Error response from daemon: container failed to start
```

**Diagnosis:**
```bash
# Check container logs
docker logs infiniedge-all-services

# Check Docker daemon status
sudo systemctl status docker

# Verify Docker resources
docker system df
```

**Resolution:**
```bash
# Clean up Docker resources
docker system prune -f

# Restart Docker daemon
sudo systemctl restart docker

# Rebuild container
./manage-external.sh rebuild
```

#### Issue: Port conflicts

**Symptoms:**
```bash
Error: bind: address already in use
```

**Diagnosis:**
```bash
# Check what's using the ports
sudo netstat -tulpn | grep -E ':(8888|9080|9081|9082|9083|9084|9085|9086|9087|9088|9089|9090)'
sudo lsof -i :8888
```

**Resolution:**
```bash
# Stop conflicting services
sudo systemctl stop apache2  # If Apache is running on port 80
sudo systemctl stop nginx    # If nginx is running

# Kill specific processes
sudo kill $(sudo lsof -t -i:8888)

# Change port mapping (if needed)
# Edit docker-compose.external.yml port mappings
```

### 2. Service Startup Failures

#### Issue: Services show FATAL in supervisor

**Symptoms:**
```bash
docker exec infiniedge-all-services supervisorctl status
# Shows: service-name    FATAL    Exited too quickly
```

**Diagnosis:**
```bash
# Check service logs
docker exec infiniedge-all-services cat /app/logs/service-name.log

# Check supervisor logs  
docker exec infiniedge-all-services cat /var/log/supervisor/supervisord.log

# Check service script permissions
docker exec infiniedge-all-services ls -la /app/scripts/
```

**Resolution:**
```bash
# Restart individual service
docker exec infiniedge-all-services supervisorctl restart service-name

# Check startup script syntax
docker exec infiniedge-all-services bash -n /app/scripts/start-service-name.sh

# Fix permissions if needed
docker exec infiniedge-all-services chmod +x /app/scripts/start-service-name.sh
```

#### Issue: Node.js services failing (Edge Whisper)

**Symptoms:**
```bash
/usr/bin/env: 'node': No such file or directory
npm: command not found
```

**Diagnosis:**
```bash
# Check Node.js installation
docker exec infiniedge-all-services which node
docker exec infiniedge-all-services node --version
docker exec infiniedge-all-services npm --version
```

**Resolution:**
```bash
# Verify Node.js 18.x is installed
docker exec infiniedge-all-services curl -sL https://deb.nodesource.com/setup_18.x | bash -
docker exec infiniedge-all-services apt-get install -y nodejs

# Check PATH environment
docker exec infiniedge-all-services echo $PATH
```

#### Issue: Go services build failures (YoMo, Shifu, SPEAR)

**Symptoms:**
```bash
go: no Go files in directory
build failed: permission denied
```

**Diagnosis:**
```bash
# Check Go installation
docker exec infiniedge-all-services go version
docker exec infiniedge-all-services echo $GOPATH
docker exec infiniedge-all-services echo $GOROOT

# Check filesystem permissions
docker exec infiniedge-all-services mount | grep "read-only"
```

**Resolution:**
The platform uses HTTP fallback services for Go applications that cannot build due to filesystem constraints. This is expected behavior:

```bash
# Verify fallback services are running
curl localhost:9082/  # YoMo fallback
curl localhost:9083/  # Shifu fallback  
curl localhost:9081/  # SPEAR fallback

# Check fallback service logs
docker exec infiniedge-all-services cat /app/logs/yomo.log
```

### 3. Network Connectivity Issues

#### Issue: Services cannot communicate

**Symptoms:**
```bash
curl: (7) Failed to connect to localhost port 8080: Connection refused
```

**Diagnosis:**
```bash
# Test internal connectivity
docker exec infiniedge-all-services curl -s localhost:8080
docker exec infiniedge-all-services netstat -tulpn | grep LISTEN

# Check port bindings
docker port infiniedge-all-services

# Verify network configuration
docker network ls
docker network inspect infiniedge_demo_infiniedge_external
```

**Resolution:**
```bash
# Restart networking in container
docker exec infiniedge-all-services supervisorctl restart all

# Restart entire container
./manage-external.sh restart

# Check firewall rules (if applicable)
sudo ufw status
sudo iptables -L
```

#### Issue: Gateway routing failures

**Symptoms:**
```bash
curl localhost:8888/aegis/
# Returns: 502 Bad Gateway
```

**Diagnosis:**
```bash
# Check gateway logs
docker exec infiniedge-all-services cat /app/logs/gateway.log

# Test direct service access
curl localhost:9080/health  # Direct AegisEdgeAI access

# Check gateway process
docker exec infiniedge-all-services ps aux | grep python
```

**Resolution:**
```bash
# Restart gateway service
docker exec infiniedge-all-services supervisorctl restart gateway

# Check gateway configuration
docker exec infiniedge-all-services cat /app/scripts/start-gateway.sh

# Test gateway functionality
curl -v localhost:8888/aegis/
```

### 4. Performance Issues

#### Issue: High memory usage

**Symptoms:**
```bash
docker stats infiniedge-all-services
# Shows: high memory percentage (>80%)
```

**Diagnosis:**
```bash
# Check memory usage per process
docker exec infiniedge-all-services ps aux --sort=-%mem | head -10

# Check system memory
docker exec infiniedge-all-services free -h

# Check for memory leaks
docker exec infiniedge-all-services cat /proc/meminfo
```

**Resolution:**
```bash
# Increase container memory limit
docker compose -f docker-compose.external.yml up -d --memory=6g

# Restart memory-intensive services
docker exec infiniedge-all-services supervisorctl restart transformers
docker exec infiniedge-all-services supervisorctl restart megatron-lm

# Enable swap if needed (host system)
sudo swapon --show
```

#### Issue: High CPU usage

**Symptoms:**
```bash
docker stats infiniedge-all-services  
# Shows: high CPU percentage (>90%)
```

**Diagnosis:**
```bash
# Check CPU usage per process
docker exec infiniedge-all-services top

# Check for CPU-intensive processes
docker exec infiniedge-all-services ps aux --sort=-%cpu | head -10

# Monitor CPU over time
docker exec infiniedge-all-services vmstat 5
```

**Resolution:**
```bash
# Limit CPU usage
docker compose -f docker-compose.external.yml up -d --cpus="2.0"

# Optimize service configuration
# Edit service environment variables to reduce CPU usage

# Restart CPU-intensive services
docker exec infiniedge-all-services supervisorctl restart edge-whisper
```

#### Issue: Slow response times

**Symptoms:**
```bash
curl -w "@curl-format.txt" -s -o /dev/null localhost:8888/health
# Shows: time_total > 5 seconds
```

**Diagnosis:**
```bash
# Test individual services
for port in {9080..9090}; do
  echo "Testing port $port:"
  curl -w "Time: %{time_total}s\n" -s -o /dev/null localhost:$port/health
done

# Check system load
docker exec infiniedge-all-services uptime
docker exec infiniedge-all-services iostat 1 5
```

**Resolution:**
```bash
# Optimize service startup order
# Edit /etc/supervisor/conf.d/infiniedge.conf priority values

# Increase connection limits
# Edit gateway configuration to handle more concurrent connections

# Add connection pooling
# Configure services to use connection pooling where applicable
```

### 5. Security Issues

#### Issue: SSL/TLS errors

**Symptoms:**
```bash
curl: (60) SSL certificate problem: self signed certificate
```

**Resolution:**
```bash
# For development, accept self-signed certificates
curl -k https://localhost:8443/health

# For production, install proper certificates
./setup-production.sh --enable-ssl
```

#### Issue: Authentication failures

**Symptoms:**
```bash
HTTP/1.1 401 Unauthorized
{"error": "Authentication required"}
```

**Resolution:**
```bash
# Check authentication configuration
# Verify API keys or tokens are correctly configured

# Test with authentication
curl -H "Authorization: Bearer your-token" localhost:8888/api/endpoint
```

## Logging and Debugging

### Log Locations

```bash
# Container logs
docker logs infiniedge-all-services

# Service logs
docker exec infiniedge-all-services ls -la /app/logs/

# Supervisor logs
docker exec infiniedge-all-services cat /var/log/supervisor/supervisord.log

# System logs (host)
journalctl -u docker.service
```

### Log Analysis

#### View real-time logs
```bash
# All services
docker exec infiniedge-all-services tail -f /app/logs/*.log

# Specific service
docker exec infiniedge-all-services tail -f /app/logs/aegis.log

# Supervisor events
docker exec infiniedge-all-services supervisorctl tail -f gateway
```

#### Search for errors
```bash
# Search all logs for errors
docker exec infiniedge-all-services grep -r "ERROR\|FATAL\|CRITICAL" /app/logs/

# Search for specific patterns
docker exec infiniedge-all-services grep -r "connection refused" /app/logs/
docker exec infiniedge-all-services grep -r "timeout" /app/logs/

# Check startup errors
docker exec infiniedge-all-services grep -r "failed to start" /app/logs/
```

#### Log rotation setup
```bash
# Setup log rotation to prevent disk space issues
cat > /etc/logrotate.d/infiniedge << EOF
/app/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
```

### Debug Mode

#### Enable debug logging
```bash
# Set debug environment variables
export LOG_LEVEL=DEBUG
export PYTHONPATH=/app

# Restart services with debug mode
docker exec infiniedge-all-services supervisorctl restart all
```

#### Interactive debugging
```bash
# Access container shell
docker exec -it infiniedge-all-services bash

# Check process status
ps aux | grep python
ps aux | grep node
ps aux | grep go

# Test service startup manually
cd /app/services/aegis-edge-ai
/app/scripts/start-aegis.sh
```

## Recovery Procedures

### Service Recovery

#### Restart individual services
```bash
# Restart specific service
docker exec infiniedge-all-services supervisorctl restart aegis-edge-ai

# Restart all services
docker exec infiniedge-all-services supervisorctl restart all

# Stop and start service
docker exec infiniedge-all-services supervisorctl stop gateway
docker exec infiniedge-all-services supervisorctl start gateway
```

#### Container recovery
```bash
# Soft restart (preserves data)
./manage-external.sh restart

# Hard restart (full rebuild)
./manage-external.sh rebuild

# Factory reset (clean slate)
docker compose -f docker-compose.external.yml down -v
./manage-external.sh build
./manage-external.sh start
```

### Data Recovery

#### Configuration backup and restore
```bash
# Backup configuration
docker exec infiniedge-all-services tar -czf /tmp/config-backup.tar.gz /app/scripts/ /etc/supervisor/

# Restore configuration
docker cp infiniedge-all-services:/tmp/config-backup.tar.gz ./
tar -xzf config-backup.tar.gz
```

#### Service data recovery
```bash
# Backup service data (if applicable)
docker exec infiniedge-all-services tar -czf /tmp/data-backup.tar.gz /app/data/

# Restore service data
docker cp ./data-backup.tar.gz infiniedge-all-services:/tmp/
docker exec infiniedge-all-services tar -xzf /tmp/data-backup.tar.gz -C /
```

## Monitoring and Alerting

### Health Monitoring Script

```bash
#!/bin/bash
# health-check.sh - Comprehensive health monitoring

SERVICES=("gateway:8888" "aegis-edge-ai:9080" "spear:9081" "yomo:9082" "shifu:9083" 
          "aiops:9084" "eda:9085" "edge-whisper:9086" "whisper-finetune:9087" 
          "megatron-lm:9088" "transformers:9089" "health-monitor:9090")

echo "InfiniteEdge Health Check - $(date)"
echo "=================================="

FAILED_SERVICES=()
TOTAL_SERVICES=${#SERVICES[@]}
HEALTHY_SERVICES=0

for service in "${SERVICES[@]}"; do
    name=${service%:*}
    port=${service#*:}
    
    if curl -s -f "http://localhost:$port/health" > /dev/null; then
        echo "✅ $name ($port): Healthy"
        ((HEALTHY_SERVICES++))
    else
        echo "❌ $name ($port): Failed"
        FAILED_SERVICES+=("$name")
    fi
done

echo ""
echo "Summary: $HEALTHY_SERVICES/$TOTAL_SERVICES services healthy"

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo "Failed services: ${FAILED_SERVICES[*]}"
    exit 1
else
    echo "All services operational! 🚀"
    exit 0
fi
```

### Alerting Setup

```bash
# Setup email alerting (example)
#!/bin/bash
# alert.sh - Send alerts for service failures

if ! ./health-check.sh; then
    echo "Service failure detected!" | mail -s "InfiniteEdge Alert" admin@company.com
fi

# Add to crontab for regular monitoring
# crontab -e
# */5 * * * * /path/to/alert.sh
```

### Performance Monitoring

```bash
#!/bin/bash
# performance-monitor.sh - Monitor system performance

echo "Performance Metrics - $(date)"
echo "============================"

# Container stats
echo "Container Resource Usage:"
docker stats --no-stream infiniedge-all-services

# Individual service CPU/Memory
echo -e "\nTop Processes by Memory:"
docker exec infiniedge-all-services ps aux --sort=-%mem | head -5

echo -e "\nTop Processes by CPU:"  
docker exec infiniedge-all-services ps aux --sort=-%cpu | head -5

# Network connections
echo -e "\nNetwork Connections:"
docker exec infiniedge-all-services netstat -tlpn | grep LISTEN | wc -l

# Disk usage
echo -e "\nDisk Usage:"
docker exec infiniedge-all-services df -h /
```

## Getting Help

### Support Resources

1. **Documentation**: Check the [main documentation](./README.md)
2. **API Reference**: See [API.md](./API.md) for endpoint details
3. **External Orchestrator**: See [EXTERNAL-ORCHESTRATOR.md](./EXTERNAL-ORCHESTRATOR.md)

### Collecting Debug Information

When reporting issues, collect the following information:

```bash
#!/bin/bash
# collect-debug-info.sh - Gather debug information

echo "Collecting InfiniteEdge debug information..."
mkdir -p debug-info/$(date +%Y%m%d_%H%M%S)
cd debug-info/$(date +%Y%m%d_%H%M%S)

# System information
echo "System Information" > system-info.txt
uname -a >> system-info.txt
docker version >> system-info.txt
docker compose version >> system-info.txt

# Container status
docker ps -a > container-status.txt
docker logs infiniedge-all-services > container-logs.txt

# Service status
docker exec infiniedge-all-services supervisorctl status > service-status.txt

# Service logs
mkdir -p service-logs
docker exec infiniedge-all-services cp -r /app/logs/ ./service-logs/ 2>/dev/null || true

# Network information  
docker network ls > network-info.txt
docker port infiniedge-all-services >> network-info.txt

# Resource usage
docker stats --no-stream infiniedge-all-services > resource-usage.txt

echo "Debug information collected in: $(pwd)"
echo "Please include this directory when reporting issues."
```

### Community Support

- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Submit documentation improvements
- **Community Forum**: Ask questions and share solutions

---

**Need immediate help? Run `./health-check.sh` for quick diagnostics or `./collect-debug-info.sh` to gather troubleshooting data.**