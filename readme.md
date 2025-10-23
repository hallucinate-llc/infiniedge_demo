# InfinieEdge Demo Platform

🚀 **Complete Docker-based deployment of all LF Edge AI repositories**

This repository provides a unified platform that integrates all the major LF Edge AI projects into a single, cohesive edge computing environment.

## 🎯 What's Included

- **AegisEdgeAI** - Security and trust framework for edge AI
- **SPEAR** - Distributed AI agent platform  
- **YoMo** - Serverless framework for edge AI infrastructure
- **Shifu** - Kubernetes-native IoT gateway
- **Edge Whisper** - Real-time speech recognition
- **EDA** - Data analysis platform
- **AIOps** - AI operations and anomaly detection
- **Transformers** - ML model inference service
- **Megatron-LM** - Large model training
- **Whisper Fine-tune** - Speech model training

## 🚀 Quick Start

```bash
# Clone the repository (if not already done)
git clone https://github.com/hallucinate-llc/infiniedge_demo.git
cd infiniedge_demo

# Initialize submodules (if not already done)
git submodule update --init --recursive

# Build and start all services
./manage-demo.sh build
./manage-demo.sh start

# Access the unified dashboard
open http://localhost
```

## 📖 Full Documentation

See [README-docker.md](./README-docker.md) for complete setup instructions, service details, and management commands.

## 🔧 Management

```bash
# Check status
./status.sh

# View logs
./manage-demo.sh logs

# Stop services
./manage-demo.sh stop

# Get help
./manage-demo.sh help
```

## 🌟 Features

✅ **Unified Dashboard** - Single web interface for all services  
✅ **Inter-service Communication** - Services can communicate with each other  
✅ **Shared Infrastructure** - Redis and PostgreSQL for data sharing  
✅ **Health Monitoring** - Built-in health checks and monitoring  
✅ **Easy Management** - Simple scripts for common operations  
✅ **Production Ready** - Resource limits and security configured  

## 🏗️ Architecture

All services run in isolated Docker containers connected through a private network, with a reverse proxy providing unified access. Services share Redis for messaging and PostgreSQL for persistent data.

## 📋 Requirements

- Docker 20.10+
- Docker Compose 2.0+
- 8GB+ RAM available for Docker
- 20GB+ free disk space

---

**Ready to explore edge AI? Start with `./manage-demo.sh build && ./manage-demo.sh start`** 🚀