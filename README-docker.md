# InfinieEdge Demo - Comprehensive Docker Platform

This repository contains a complete Docker-based deployment of all LF Edge AI repositories, configured to work together as an integrated edge computing platform.

## 🚀 Quick Start

### Prerequisites
- Docker 20.10+
- Docker Compose 2.0+
- At least 8GB RAM available for Docker
- 20GB free disk space

### 1. Build and Start All Services

```bash
# Build all Docker images
./manage-demo.sh build

# Start all services
./manage-demo.sh start
```

### 2. Access the Platform

Once all services are running, access the unified dashboard at:
**http://localhost**

## 📋 Included Services

| Service | Port | Description | Technology |
|---------|------|-------------|------------|
| **AegisEdgeAI** | 5000-5002 | Security and trust framework for edge AI | Python, TPM |
| **SPEAR** | 8100-8150, 9090 | Distributed AI agent platform | Go, Rust |
| **YoMo** | 9000-9001 | Serverless framework for edge AI | Go |
| **Shifu** | 8080-8081 | Kubernetes-native IoT gateway | Go |
| **Edge Whisper** | 3000-3001 | Real-time speech recognition | TypeScript, Node.js |
| **EDA** | 8000 | Data analysis platform | Python |
| **AIOps** | 8001-8002 | AI operations and anomaly detection | Python |
| **Transformers** | 7000 | ML model inference service | Python, PyTorch |
| **Megatron-LM** | 6000 | Large model training | Python |
| **Whisper Finetune** | 4000 | Speech model training | C, Python |
| **Redis** | 6379 | Shared caching and messaging | Redis |
| **PostgreSQL** | 5432 | Shared database | PostgreSQL |
| **Nginx Gateway** | 80, 443 | Reverse proxy and load balancer | Nginx |

## 🛠 Management Commands

Use the `manage-demo.sh` script to control the platform:

```bash
# Build all images
./manage-demo.sh build

# Start all services
./manage-demo.sh start

# Stop all services
./manage-demo.sh stop

# Restart all services
./manage-demo.sh restart

# Check service status
./manage-demo.sh status

# View logs (all services or specific service)
./manage-demo.sh logs
./manage-demo.sh logs yomo

# Check health of all services
./manage-demo.sh health

# Open shell in a service
./manage-demo.sh shell spear

# Clean up everything
./manage-demo.sh clean
```

## 🔗 Service Communication

The services are configured to communicate with each other through:

### Shared Infrastructure
- **Redis**: Used for caching, pub/sub messaging, and job queues
- **PostgreSQL**: Shared database for persistent data
- **Docker Network**: Private network for secure inter-service communication

### Service Integration Examples

1. **AegisEdgeAI ↔ SPEAR**: Security verification for AI agents
2. **YoMo ↔ Edge Whisper**: Real-time audio processing pipeline  
3. **SPEAR ↔ Shifu**: IoT device management through AI agents
4. **AIOps ↔ EDA**: Data analysis for anomaly detection
5. **Transformers ↔ Megatron-LM**: Model serving and training coordination
6. **Edge Whisper ↔ Whisper Finetune**: Speech recognition and model improvement

## 📊 Monitoring and Access

### Web Interfaces
- **Main Dashboard**: http://localhost
- **AegisEdgeAI**: http://localhost/aegis/
- **SPEAR Management**: http://localhost/spear/
- **YoMo Dashboard**: http://localhost/yomo/
- **Shifu Gateway**: http://localhost/shifu/
- **Edge Whisper**: http://localhost/whisper/
- **EDA Platform**: http://localhost/eda/
- **AIOps Dashboard**: http://localhost/aiops/

### API Endpoints
All services expose REST APIs accessible through the gateway at `/[service]/api`.

## 🔧 Configuration

### Environment Variables
Key environment variables are configured in `docker-compose.yml`:
- `REDIS_HOST=shared-redis`
- `DATABASE_URL=postgresql://postgres:postgres@shared-postgres:5432/infiniedge`
- Service-specific endpoints for inter-service communication

### Volumes
Persistent data is stored in Docker volumes:
- Service data: `[service-name]-data`
- Shared infrastructure: `redis-data`, `postgres-data`
- Model caches: `transformers-cache`, `megatron-checkpoints`

### Resource Limits
Services are configured with appropriate resource limits for edge deployment while allowing scaling up for development.

## 🚦 Health Checks

All services include health checks:
```bash
# Check all services
./manage-demo.sh health

# Check individual service logs
./manage-demo.sh logs [service-name]

# View Docker stats
docker stats
```

## 🔒 Security Features

- **Network isolation**: Services communicate through private Docker network
- **TPM integration**: Hardware security module support via AegisEdgeAI
- **Reverse proxy**: All external access goes through Nginx gateway
- **Non-root containers**: All services run with dedicated users

## 🧪 Development and Testing

### Adding New Services
1. Create a `Dockerfile.infiniedge` in the service directory
2. Add service configuration to `docker-compose.yml`
3. Update `nginx.conf` for web access
4. Add routes to the main dashboard HTML

### Custom Configurations
- Modify `docker-compose.yml` for different port mappings
- Update `nginx.conf` for custom routing
- Edit service-specific Dockerfiles for additional dependencies

## 📝 Logs and Debugging

### View Logs
```bash
# All services
./manage-demo.sh logs

# Specific service
./manage-demo.sh logs aegis-edge-ai

# Follow logs in real-time
docker compose logs -f [service-name]
```

### Debug Container Issues
```bash
# Check container status
docker compose ps

# Inspect a service
docker compose exec [service-name] /bin/bash

# Check resource usage
docker stats

# View service configuration
docker compose config
```

## 🚨 Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure no other services are using the required ports
2. **Memory Issues**: Increase Docker memory limit to at least 8GB
3. **Build Failures**: Check Docker logs and ensure all submodules are properly initialized
4. **Service Not Starting**: Check logs with `./manage-demo.sh logs [service]`

### Recovery Commands
```bash
# Stop and clean everything
./manage-demo.sh clean

# Rebuild from scratch
./manage-demo.sh build
./manage-demo.sh start

# Reset specific service
docker compose stop [service]
docker compose rm [service]
docker compose up -d [service]
```

## 🤝 Contributing

To add new features or services:
1. Fork the repository
2. Create a feature branch
3. Add your service following the established patterns
4. Test the integration
5. Submit a pull request

## 📄 License

This project integrates multiple open-source repositories, each with their own licenses. Please refer to individual submodule licenses for specific terms.

## 🙋 Support

- Check service logs: `./manage-demo.sh logs [service]`
- Verify health: `./manage-demo.sh health`
- Report issues on GitHub with full log output
- Include Docker version and system specifications