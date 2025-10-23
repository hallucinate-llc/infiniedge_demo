# 🚀 InfinieEdge Demo Platform - External Orchestrator

## Overview

This is the **External Orchestration Container** that runs ALL InfinieEdge Demo Platform services simultaneously in a single Docker container. Unlike the previous multi-container approach, this creates one unified container that orchestrates all 10+ LF Edge AI submodules.

## 🎯 What This Provides

### **Single Container, All Services**
- **All 10+ services** running simultaneously in one container
- **Unified gateway** routing through Nginx
- **Beautiful dashboard** accessible at http://localhost/
- **Supervisor-managed processes** with automatic restart
- **Health monitoring** for all services
- **Resource optimization** with shared dependencies

### **Services Included**
1. **AegisEdgeAI** (Port 8080) - AI compliance & security analysis
2. **SPEAR** (Port 8081) - Secure edge analytics platform  
3. **YoMo** (Port 8082) - Serverless edge computing framework
4. **Shifu** (Port 8083) - Kubernetes IoT device management
5. **AIOps** (Port 8084) - AI operations platform
6. **EDA** (Port 8085) - Event-driven architecture
7. **Edge Whisper** (Port 8086) - Edge speech recognition
8. **Whisper Finetune** (Port 8087) - Model fine-tuning platform
9. **Megatron-LM** (Port 8088) - Large language model training
10. **Transformers** (Port 8089) - Hugging Face transformers library

## 🚦 Quick Start

### **1. Build the External Container**
```bash
# Build the orchestrator container
./manage-external.sh build

# Or using docker-compose directly
docker-compose -f docker-compose.external.yml build
```

### **2. Start All Services**
```bash
# Start all services in one container
./manage-external.sh start

# Or using docker-compose directly  
docker-compose -f docker-compose.external.yml up -d
```

### **3. Access the Platform**
```bash
# Open the main dashboard
open http://localhost/

# Or access individual services
open http://localhost/aegis/     # AegisEdgeAI
open http://localhost/spear/     # SPEAR
open http://localhost/yomo/      # YoMo
# ... and 7 more services
```

## 🛠️ Management Commands

The `manage-external.sh` script provides comprehensive management:

```bash
./manage-external.sh build      # Build container
./manage-external.sh start      # Start all services
./manage-external.sh stop       # Stop container
./manage-external.sh restart    # Restart container
./manage-external.sh status     # Show status
./manage-external.sh logs       # View logs
./manage-external.sh shell      # Open shell
./manage-external.sh health     # Health check
./manage-external.sh clean      # Clean up
./manage-external.sh rebuild    # Rebuild container
```

## 🌐 Service Access

### **Main Dashboard**
- **URL**: http://localhost/
- **Features**: Service overview, health status, quick access links

### **Individual Services**
| Service | URL | Port | Description |
|---------|-----|------|-------------|
| AegisEdgeAI | http://localhost/aegis/ | 8080 | AI compliance & security |
| SPEAR | http://localhost/spear/ | 8081 | Edge analytics platform |
| YoMo | http://localhost/yomo/ | 8082 | Serverless framework |
| Shifu | http://localhost/shifu/ | 8083 | IoT device management |
| AIOps | http://localhost/aiops/ | 8084 | AI operations |
| EDA | http://localhost/eda/ | 8085 | Event-driven architecture |
| Edge Whisper | http://localhost/edge-whisper/ | 8086 | Speech recognition |
| Whisper Finetune | http://localhost/whisper-finetune/ | 8087 | Model fine-tuning |
| Megatron-LM | http://localhost/megatron/ | 8088 | LLM training |
| Transformers | http://localhost/transformers/ | 8089 | NLP models |

### **Health Endpoints**
Every service provides a health check at `/health`:
```bash
curl http://localhost/aegis/health
curl http://localhost/spear/health
# ... etc
```

## 📁 Architecture

### **Container Structure**
```
/app/
├── services/           # All service source code
│   ├── aegis-edge-ai/
│   ├── spear/
│   ├── yomo/
│   └── ...
├── scripts/           # Startup scripts for each service  
├── configs/           # Configuration files
├── logs/             # Service logs
└── data/             # Persistent data
```

### **Process Management**
- **Supervisor** manages all service processes
- **Automatic restart** on failure
- **Centralized logging** for all services
- **Health monitoring** with alerts

### **Network Architecture**
```
Internet → Nginx (Port 80) → Internal Services (8080-8089)
              ↓
         Dashboard UI
```

## 🔧 Configuration

### **Environment Variables**
The container supports various environment variables:
- `NODE_ENV=production` - Node.js environment
- `PYTHONPATH=/app/services` - Python path
- `GOPATH=/go` - Go workspace

### **Resource Limits**
- **Memory**: 8GB limit, 2GB reserved
- **CPU**: 4 cores limit, 1 core reserved  
- **Ports**: 80, 443, 8080-8089, 9000-9003

### **Security Features**
- Non-privileged container execution
- Capability dropping (`cap_drop: ALL`)
- No new privileges (`no-new-privileges:true`)
- Minimal bind service capability

## 🍴 Fork All Repositories

To fork all submodules to your GitHub userspace and commit changes:

```bash
# Fork all repos and commit Docker configurations
./fork-and-commit.sh

# Follow the prompts to:
# 1. Enter your GitHub username
# 2. Provide GitHub token (optional)
# 3. Confirm forking process
```

This will:
- Fork all 10+ submodule repositories to your GitHub account
- Update submodule remotes to point to your forks
- Commit all Docker configurations and orchestrator code
- Create a summary of all forked repositories

## 🔍 Troubleshooting

### **Container Won't Start**
```bash
# Check container logs
./manage-external.sh logs

# Check individual service status
./manage-external.sh shell
supervisorctl status
```

### **Service Not Responding**
```bash
# Health check all services
./manage-external.sh health

# Check specific service logs
./manage-external.sh shell
tail -f /app/logs/aegis.log
```

### **Performance Issues**
```bash
# Check resource usage
./manage-external.sh status

# Monitor in real-time
docker stats infiniedge-all-services
```

### **Rebuild After Changes**
```bash
# Clean rebuild
./manage-external.sh rebuild

# Or manual process
./manage-external.sh clean
./manage-external.sh build
./manage-external.sh start
```

## 📊 Monitoring

### **Built-in Health Checks**
- Container-level health check every 30s
- Individual service health endpoints
- Supervisor process monitoring
- Automatic service restart on failure

### **Logs**
- Centralized logging in `/app/logs/`
- Service-specific log files
- Nginx access and error logs
- Supervisor management logs

### **Status Monitoring**
```bash
# Overall status
./manage-external.sh status

# Health check
./manage-external.sh health

# Live logs
./manage-external.sh logs
```

## 🎉 Benefits of External Orchestrator

### **Simplified Deployment**
- **One container** instead of 10+ containers
- **Single build** and deploy process
- **Unified management** through one interface
- **Shared dependencies** reduce overhead

### **Better Resource Utilization**
- **Shared base image** reduces disk usage
- **Optimized process management** with supervisor
- **Centralized logging** and monitoring
- **Single network namespace** for all services

### **Easier Development**
- **One container to manage** instead of complex docker-compose
- **Faster startup** with shared initialization
- **Simplified networking** with internal routing
- **Single dashboard** for all services

### **Production Ready**
- **Health monitoring** for all services
- **Automatic restart** policies
- **Resource limits** and security
- **Easy scaling** and deployment

---

**🎯 This external orchestrator approach gives you exactly what you requested: a single Docker container that runs all submodules simultaneously with full inter-service communication!**