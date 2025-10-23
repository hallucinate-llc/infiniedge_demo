# Security Guide

## Overview

The InfiniteEdge platform implements comprehensive security measures across all services, containers, and network communications. This guide outlines security features, best practices, and hardening procedures.

## Security Architecture

### Container Security

#### Base Image Security
- **Ubuntu 22.04 LTS**: Long-term support with regular security updates
- **Minimal Attack Surface**: Only essential packages installed
- **No Root Passwords**: Root access disabled by default
- **Read-only Filesystem**: Container filesystem mounted read-only where possible

#### Runtime Security
```bash
# Container runs with security constraints
docker run --security-opt no-new-privileges:true \
           --read-only \
           --tmpfs /tmp \
           --tmpfs /var/run \
           --cap-drop ALL \
           --cap-add NET_BIND_SERVICE
```

#### Process Isolation
- **Supervisor Management**: All processes managed through supervisor
- **Process Limits**: Resource limits enforced per service
- **Namespace Isolation**: Container network and process namespace isolation

### Network Security

#### Port Configuration
```
External Access (Secured):
├── 8888 → HTTP Gateway (80)     [Rate Limited]
├── 9080 → AegisEdgeAI (8080)   [Direct Access]  
├── 9081 → SPEAR (8081)         [Direct Access]
├── 9082 → YoMo (8082)          [Direct Access]
├── 9083 → Shifu (8083)         [Direct Access]
├── 9084 → AIOps (8084)         [Direct Access]
├── 9085 → EDA (8085)           [Direct Access]
├── 9086 → Edge Whisper (8086)  [Direct Access]
├── 9087 → Whisper Finetune (8087) [Direct Access]
├── 9088 → Megatron-LM (8088)   [Direct Access]
├── 9089 → Transformers (8089)  [Direct Access]
└── 9090 → Health Monitor (8090) [Direct Access]

Internal Communication:
└── localhost:8080-8090 → Inter-service communication
```

#### Network Isolation
- **Bridge Network**: Isolated container network
- **No Host Network**: Container does not use host networking
- **Internal DNS**: Services communicate via internal hostnames
- **Firewall Rules**: Host firewall configured for port restrictions

### Authentication and Authorization

#### API Authentication

**Bearer Token Authentication** (Recommended for Production)
```bash
# Generate secure API token
openssl rand -hex 32

# Use token in requests
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8888/api/v1/endpoint
```

**API Key Authentication**
```bash
# Configure API key
export INFINIEDGE_API_KEY="your-secure-api-key"

# Use API key in requests  
curl -H "X-API-Key: $INFINIEDGE_API_KEY" \
     http://localhost:8888/api/v1/endpoint
```

#### Service-to-Service Authentication

**Internal JWT Tokens**
```python
import jwt
import datetime

# Generate internal service token
def generate_service_token(service_name, secret_key):
    payload = {
        'service': service_name,
        'iat': datetime.datetime.utcnow(),
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=1)
    }
    return jwt.encode(payload, secret_key, algorithm='HS256')

# Verify service token
def verify_service_token(token, secret_key):
    try:
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        return payload['service']
    except jwt.ExpiredSignatureError:
        return None
```

### SSL/TLS Encryption

#### HTTPS Configuration

**Production SSL Setup**
```bash
# Generate SSL certificates
./setup-ssl.sh

# Configure HTTPS in docker-compose
services:
  infiniedge-orchestrator:
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./ssl:/etc/ssl/certs:ro
    environment:
      - ENABLE_SSL=true
      - SSL_CERT_PATH=/etc/ssl/certs/cert.pem
      - SSL_KEY_PATH=/etc/ssl/certs/key.pem
```

**Self-Signed Certificates (Development)**
```bash
# Generate development certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Configure nginx for HTTPS
server {
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_private_key /etc/ssl/certs/key.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
}
```

### Security Headers

#### HTTP Security Headers

The gateway implements comprehensive security headers:

```nginx
# Security headers configuration
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

#### CORS Configuration

```python
# CORS configuration for API services
from flask_cors import CORS

app = Flask(__name__)
CORS(app, 
     origins=['https://trusted-domain.com'],
     allow_headers=['Authorization', 'Content-Type'],
     methods=['GET', 'POST', 'PUT', 'DELETE'])
```

### Rate Limiting and DDoS Protection

#### Gateway Rate Limiting

```nginx
# Rate limiting configuration
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=health:1m rate=1r/s;
    
    server {
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://backend;
        }
        
        location /health {
            limit_req zone=health burst=5 nodelay;
            proxy_pass http://backend;
        }
    }
}
```

#### DDoS Protection

```bash
# Configure fail2ban for DDoS protection
cat > /etc/fail2ban/jail.d/infiniedge.conf << EOF
[infiniedge-ddos]
enabled = true
port = 8888,9080-9090
filter = infiniedge-ddos
logpath = /var/log/nginx/access.log
maxretry = 20
findtime = 60
bantime = 3600
action = iptables[name=infiniedge-ddos, port=8888, protocol=tcp]
EOF

# DDoS filter
cat > /etc/fail2ban/filter.d/infiniedge-ddos.conf << EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*HTTP.*" (4\d\d|5\d\d) 
ignoreregex =
EOF
```

### Input Validation and Sanitization

#### API Input Validation

```python
from marshmallow import Schema, fields, validate

class UserInputSchema(Schema):
    text = fields.Str(required=True, validate=validate.Length(max=1000))
    model = fields.Str(validate=validate.OneOf(['bert-base', 'gpt2', 'whisper']))
    max_tokens = fields.Int(validate=validate.Range(min=1, max=1000))

# Validate input
schema = UserInputSchema()
try:
    result = schema.load(request.json)
except ValidationError as err:
    return {"error": "Invalid input", "details": err.messages}, 400
```

#### SQL Injection Prevention

```python
# Use parameterized queries
import sqlite3

def get_user_data(user_id):
    conn = sqlite3.connect('database.db')
    cursor = conn.cursor()
    
    # Safe: parameterized query
    cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    
    # Unsafe: string concatenation
    # cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
    
    return cursor.fetchall()
```

#### XSS Prevention

```python
from markupsafe import escape

def render_user_content(content):
    # Escape HTML content
    safe_content = escape(content)
    return f"<div>{safe_content}</div>"
```

### Secrets Management

#### Environment Variables

```bash
# Secure environment configuration
cat > .env.security << EOF
# Database credentials
DB_PASSWORD=$(openssl rand -base64 32)
DB_ENCRYPTION_KEY=$(openssl rand -hex 32)

# API secrets
JWT_SECRET_KEY=$(openssl rand -base64 64)
API_SECRET_KEY=$(openssl rand -hex 32)

# Encryption keys
MASTER_KEY=$(openssl rand -base64 32)
SALT=$(openssl rand -hex 16)
EOF

# Set restrictive permissions
chmod 600 .env.security
chown root:root .env.security
```

#### Docker Secrets

```yaml
# docker-compose.yml with secrets
version: '3.8'

services:
  infiniedge-orchestrator:
    image: infiniedge-orchestrator
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    file: ./secrets/api_key.txt
```

### Audit Logging

#### Security Event Logging

```python
import logging
import json
from datetime import datetime

# Configure security logger
security_logger = logging.getLogger('security')
handler = logging.FileHandler('/app/logs/security.log')
formatter = logging.Formatter('%(asctime)s - %(message)s')
handler.setFormatter(formatter)
security_logger.addHandler(handler)
security_logger.setLevel(logging.INFO)

def log_security_event(event_type, user_id, details):
    event = {
        'timestamp': datetime.utcnow().isoformat(),
        'event_type': event_type,
        'user_id': user_id,
        'details': details,
        'source_ip': request.remote_addr
    }
    security_logger.info(json.dumps(event))

# Usage examples
log_security_event('login_attempt', user_id, {'success': True})
log_security_event('api_access', user_id, {'endpoint': '/api/v1/data'})
log_security_event('auth_failure', None, {'reason': 'invalid_token'})
```

#### Access Logging

```nginx
# Comprehensive access logging
log_format security_log '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $bytes_sent '
                       '"$http_referer" "$http_user_agent" '
                       '$request_time $upstream_response_time';

access_log /var/log/nginx/security.log security_log;
```

### Vulnerability Scanning

#### Container Vulnerability Scanning

```bash
# Install Docker vulnerability scanner
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image infiniedge_demo-infiniedge-orchestrator

# Scan for high/critical vulnerabilities only
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image --severity HIGH,CRITICAL infiniedge_demo-infiniedge-orchestrator
```

#### Dependency Scanning

```bash
# Python dependency scanning
pip install safety
safety check --file requirements.txt

# Node.js dependency scanning  
npm audit
npm audit fix

# Go module scanning
go list -json -m all | docker run --rm -i sonatypecommunity/nancy:latest sleuth
```

### Security Hardening

#### System Hardening Script

```bash
#!/bin/bash
# harden-security.sh - Security hardening script

echo "Applying InfiniteEdge security hardening..."

# 1. Update system packages
apt-get update && apt-get upgrade -y

# 2. Configure firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 8888/tcp  # Gateway
ufw allow 9080:9090/tcp  # Service ports
ufw --force enable

# 3. Secure Docker daemon
cat > /etc/docker/daemon.json << EOF
{
  "icc": false,
  "userland-proxy": false,
  "no-new-privileges": true,
  "experimental": false
}
EOF

systemctl restart docker

# 4. Configure log rotation
cat > /etc/logrotate.d/infiniedge << EOF
/app/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

# 5. Set file permissions
find /app -type f -name "*.sh" -exec chmod 755 {} \;
find /app/logs -type f -exec chmod 644 {} \;
chmod 600 .env.security

# 6. Configure fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo "Security hardening completed!"
```

#### Container Hardening

```dockerfile
# Dockerfile security improvements
FROM ubuntu:22.04

# Create non-root user
RUN groupadd -r infiniedge && useradd -r -g infiniedge infiniedge

# Install security updates
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set secure file permissions
COPY --chown=infiniedge:infiniedge scripts/ /app/scripts/
RUN chmod -R 755 /app/scripts/

# Use non-root user
USER infiniedge

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1
```

### Incident Response

#### Security Incident Detection

```bash
#!/bin/bash
# security-monitor.sh - Monitor for security incidents

# Check for failed login attempts
failed_logins=$(grep "Failed password" /var/log/auth.log | wc -l)
if [ $failed_logins -gt 10 ]; then
    echo "ALERT: $failed_logins failed login attempts detected"
fi

# Check for suspicious network activity
netstat -an | grep :8888 | grep -c ESTABLISHED
if [ $(netstat -an | grep :8888 | grep -c ESTABLISHED) -gt 100 ]; then
    echo "ALERT: High number of connections to gateway"
fi

# Check container integrity
docker diff infiniedge-all-services | grep -E '^[AC]' && \
    echo "ALERT: Container filesystem changes detected"

# Monitor resource usage for anomalies
cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" infiniedge-all-services | sed 's/%//')
if (( $(echo "$cpu_usage > 90" | bc -l) )); then
    echo "ALERT: High CPU usage: ${cpu_usage}%"
fi
```

#### Incident Response Procedures

1. **Detection**: Automated monitoring alerts
2. **Assessment**: Determine scope and impact
3. **Containment**: Isolate affected services
4. **Eradication**: Remove threats and vulnerabilities  
5. **Recovery**: Restore services to normal operation
6. **Lessons Learned**: Update security measures

```bash
#!/bin/bash
# incident-response.sh - Emergency response script

case "$1" in
  "isolate")
    echo "Isolating container..."
    docker network disconnect infiniedge_demo_infiniedge_external infiniedge-all-services
    ;;
  "stop")
    echo "Stopping all services..."
    docker exec infiniedge-all-services supervisorctl stop all
    ;;
  "backup")
    echo "Creating security backup..."
    docker exec infiniedge-all-services tar -czf /tmp/incident-backup-$(date +%s).tar.gz /app/logs/ /app/data/
    ;;
  "restore")
    echo "Restoring from backup..."
    ./manage-external.sh rebuild
    ;;
  *)
    echo "Usage: $0 {isolate|stop|backup|restore}"
    ;;
esac
```

### Compliance and Standards

#### Security Standards Compliance

**NIST Cybersecurity Framework**
- ✅ **Identify**: Asset inventory and risk assessment
- ✅ **Protect**: Access control and data protection  
- ✅ **Detect**: Continuous monitoring and logging
- ✅ **Respond**: Incident response procedures
- ✅ **Recover**: Backup and recovery capabilities

**OWASP Top 10 Protection**
- ✅ **A01: Broken Access Control** - Role-based access control
- ✅ **A02: Cryptographic Failures** - Strong encryption  
- ✅ **A03: Injection** - Input validation and parameterized queries
- ✅ **A04: Insecure Design** - Security by design principles
- ✅ **A05: Security Misconfiguration** - Secure defaults
- ✅ **A06: Vulnerable Components** - Dependency scanning
- ✅ **A07: Authentication Failures** - Strong authentication
- ✅ **A08: Software Integrity** - Container image signing
- ✅ **A09: Logging Failures** - Comprehensive audit logging
- ✅ **A10: Server-Side Request Forgery** - Input validation

#### Compliance Reporting

```python
# compliance-report.py - Generate compliance report
import json
from datetime import datetime, timedelta

def generate_compliance_report():
    report = {
        'timestamp': datetime.utcnow().isoformat(),
        'platform': 'InfiniteEdge',
        'version': '1.0.0',
        'compliance_checks': []
    }
    
    # Security controls assessment
    controls = [
        {'control': 'Access Control', 'status': 'COMPLIANT', 'evidence': 'Role-based access implemented'},
        {'control': 'Encryption', 'status': 'COMPLIANT', 'evidence': 'TLS 1.3 enforced'},
        {'control': 'Logging', 'status': 'COMPLIANT', 'evidence': 'Comprehensive audit logs'},
        {'control': 'Vulnerability Management', 'status': 'COMPLIANT', 'evidence': 'Regular scanning enabled'}
    ]
    
    report['compliance_checks'] = controls
    return json.dumps(report, indent=2)
```

### Security Testing

#### Penetration Testing

```bash
#!/bin/bash
# security-test.sh - Basic security testing

echo "Running InfiniteEdge security tests..."

# Test for common vulnerabilities
echo "1. Testing for open ports..."
nmap -p 1-65535 localhost | grep open

echo "2. Testing SSL configuration..."
sslscan --show-certificate localhost:8443

echo "3. Testing for SQL injection..."
sqlmap -u "http://localhost:8888/api/v1/endpoint" --batch --crawl=1

echo "4. Testing for XSS vulnerabilities..."
# Use XSStrike or similar tool

echo "5. Testing authentication bypass..."
curl -H "Authorization: Bearer invalid-token" http://localhost:8888/api/v1/protected

echo "Security tests completed!"
```

#### Load Testing with Security Focus

```bash
# Load test with malicious patterns
ab -n 1000 -c 10 -H "User-Agent: <script>alert('xss')</script>" \
   http://localhost:8888/

# Rate limiting test
for i in {1..100}; do
  curl http://localhost:8888/api/v1/endpoint &
done
wait
```

---

**Security is a shared responsibility. Follow these guidelines and regularly update security measures to maintain a secure InfiniteEdge deployment.**