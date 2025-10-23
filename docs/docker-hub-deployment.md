# InfiniteEdge Docker Hub Deployment Guide

## Overview

This guide covers building, testing, and deploying InfiniteEdge containers to Docker Hub. The deployment system focuses on containers that successfully build and provides streamlined workflows for multi-architecture deployment.

## Quick Start

### Prerequisites

1. **Docker installed and running**
   ```bash
   docker --version
   docker info
   ```

2. **Docker Hub account and credentials**
   - Username/Organization: `hallucinate`
   - Access token with push permissions

3. **Environment setup**
   ```bash
   export DOCKER_HUB_USERNAME="your-username"
   export DOCKER_HUB_PASSWORD="your-access-token"
   ```

### Simple Deployment

```bash
# Run the interactive demo
./scripts/docker-hub-demo.sh

# Or deploy directly
./scripts/docker-hub-deploy-streamlined.sh v1.0.0 amd64
```

## Available Containers

### Working Containers ✅

| Container | Description | Dockerfile | Status |
|-----------|-------------|------------|---------|
| `aegis-edge-ai` | Zero-trust edge AI platform with TPM support | `AegisEdgeAI/Dockerfile.simple` | ✅ Tested |
| `yomo` | Real-time edge computing framework | `yomo/Dockerfile.infiniedge` | ✅ Available |
| `transformers` | Hugging Face transformers for edge AI | `transformers/Dockerfile.infiniedge` | ✅ Available |
| `whisper-finetune` | Fine-tuned Whisper models for edge | `Whisper-Finetune/Dockerfile.infiniedge` | ✅ Available |

### Docker Hub Images

All images are published to: `https://hub.docker.com/u/hallucinate`

```bash
# Pull images
docker pull hallucinate/infiniteedge-aegis-edge-ai:v1.0.0-amd64
docker pull hallucinate/infiniteedge-yomo:v1.0.0-amd64
docker pull hallucinate/infiniteedge-transformers:v1.0.0-amd64
docker pull hallucinate/infiniteedge-whisper-finetune:v1.0.0-amd64

# Latest tags
docker pull hallucinate/infiniteedge-aegis-edge-ai:latest-amd64
```

## Deployment Scripts

### 1. Streamlined Deployment (`docker-hub-deploy-streamlined.sh`)

**Purpose**: Build and push working containers efficiently

**Usage**:
```bash
./scripts/docker-hub-deploy-streamlined.sh [VERSION] [ARCHITECTURE]

# Examples
./scripts/docker-hub-deploy-streamlined.sh v1.0.0 amd64
./scripts/docker-hub-deploy-streamlined.sh v1.1.0 arm64
./scripts/docker-hub-deploy-streamlined.sh latest amd64
```

**Features**:
- ✅ Pre-flight checks
- ✅ Docker Hub authentication
- ✅ Quick container testing
- ✅ Automated push to registry
- ✅ Build summary report
- ✅ Error handling and cleanup

### 2. Interactive Demo (`docker-hub-demo.sh`)

**Purpose**: Guided deployment with interactive prompts

**Usage**:
```bash
./scripts/docker-hub-demo.sh
```

**Options**:
1. Quick Deploy (v1.0.0 amd64)
2. ARM64 Deploy (v1.0.0 arm64)
3. Custom Deploy
4. Multi-Arch Deploy
5. Show Help

### 3. Full Test Suite (`docker-test-suite.sh`)

**Purpose**: Comprehensive testing before deployment

**Usage**:
```bash
./scripts/docker-test-suite.sh
```

**Features**:
- ✅ Build validation
- ✅ Container startup testing
- ✅ Health checks
- ✅ Docker Compose validation
- ✅ Detailed reporting

## Architecture Support

### AMD64 (x86_64)
```bash
./scripts/docker-hub-deploy-streamlined.sh v1.0.0 amd64
```

### ARM64 (aarch64)
```bash
./scripts/docker-hub-deploy-streamlined.sh v1.0.0 arm64
```

### Multi-Architecture
```bash
# Build both architectures
./scripts/docker-hub-deploy-streamlined.sh v1.0.0 amd64
./scripts/docker-hub-deploy-streamlined.sh v1.0.0 arm64
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DOCKER_HUB_USERNAME` | Docker Hub username | ✅ Yes |
| `DOCKER_HUB_PASSWORD` | Docker Hub access token | ✅ Yes |

### Docker Hub Configuration

**File**: `config/docker-hub.conf`

```bash
# Organization settings
DOCKER_HUB_ORG=hallucinate
IMAGE_BASE_NAME=infiniteedge

# Supported architectures
SUPPORTED_ARCHITECTURES=(amd64 arm64)

# Default tags
DEFAULT_TAGS=(latest v1.0.0 stable)
```

## Container Details

### AegisEdgeAI Container

**Image**: `hallucinate/infiniteedge-aegis-edge-ai`

**Features**:
- Zero-trust security with TPM support
- ARM64 native compilation
- Software TPM emulation
- OpenTelemetry monitoring
- Health checks and metrics

**Usage**:
```bash
# Run with port mapping
docker run -d -p 8080:8080 \
  --name aegis-edge-ai \
  hallucinate/infiniteedge-aegis-edge-ai:v1.0.0-amd64

# Check health
curl http://localhost:8080/health
```

**Environment Variables**:
- `TPM_ENABLED=true` - Enable TPM functionality
- `LOG_LEVEL=info` - Set logging level
- `METRICS_ENABLED=true` - Enable metrics collection

### YoMo Container

**Image**: `hallucinate/infiniteedge-yomo`

**Features**:
- Real-time edge computing
- Stream processing
- Low-latency communication
- Go-based implementation

### Transformers Container

**Image**: `hallucinate/infiniteedge-transformers`

**Features**:
- Hugging Face transformers
- Edge-optimized models
- GPU support (when available)
- Python-based ML pipeline

### Whisper Fine-tune Container

**Image**: `hallucinate/infiniteedge-whisper-finetune`

**Features**:
- Fine-tuned Whisper models
- Edge speech recognition
- Custom model training
- Audio processing pipeline

## Troubleshooting

### Common Issues

#### 1. Docker Hub Authentication Failed
```bash
# Check credentials
echo $DOCKER_HUB_USERNAME
echo $DOCKER_HUB_PASSWORD | head -c 10

# Re-authenticate
docker logout
docker login --username $DOCKER_HUB_USERNAME
```

#### 2. Build Failures
```bash
# Check Docker daemon
docker info

# Clean up space
docker system prune -f

# Check build logs
./scripts/docker-test-suite.sh
cat logs/docker-tests/*.log
```

#### 3. Architecture Issues
```bash
# Check current architecture
uname -m

# For ARM64 builds on AMD64
docker buildx create --use
docker buildx inspect --bootstrap
```

### Debug Mode

```bash
# Enable verbose output
export DOCKER_BUILDKIT_DEBUG=1

# Check build progress
./scripts/docker-hub-deploy-streamlined.sh v1.0.0 amd64 2>&1 | tee build.log
```

## CI/CD Integration

### GitHub Actions

The project includes comprehensive CI/CD workflows:

```yaml
# .github/workflows/ci-cd-multi-arch.yml
name: Multi-Architecture CI/CD
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [amd64, arm64]
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Docker Hub
        run: ./scripts/docker-hub-deploy-streamlined.sh v1.0.0 ${{ matrix.arch }}
```

### Manual Triggering

```bash
# Trigger CI/CD workflow
./scripts/trigger-workflow.sh docker-deploy

# Monitor progress
./scripts/monitor-workflow.sh
```

## Production Usage

### Docker Compose

```yaml
version: '3.8'
services:
  aegis-edge-ai:
    image: hallucinate/infiniteedge-aegis-edge-ai:v1.0.0-amd64
    ports:
      - "8080:8080"
    environment:
      - TPM_ENABLED=true
      - LOG_LEVEL=info
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  yomo:
    image: hallucinate/infiniteedge-yomo:v1.0.0-amd64
    ports:
      - "8081:8081"
    depends_on:
      - aegis-edge-ai
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: infiniteedge-aegis
spec:
  replicas: 3
  selector:
    matchLabels:
      app: infiniteedge-aegis
  template:
    metadata:
      labels:
        app: infiniteedge-aegis
    spec:
      containers:
      - name: aegis-edge-ai
        image: hallucinate/infiniteedge-aegis-edge-ai:v1.0.0-amd64
        ports:
        - containerPort: 8080
        env:
        - name: TPM_ENABLED
          value: "true"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
```

## Monitoring and Metrics

### Container Health

```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"

# View logs
docker logs hallucinate/infiniteedge-aegis-edge-ai:v1.0.0-amd64

# Metrics endpoint
curl http://localhost:8080/metrics
```

### Build Metrics

All deployments generate detailed metrics:

- Build time and success rate
- Image sizes and layers
- Push success and timing
- Test results and coverage

**Reports Location**: `test-results/docker/`

## Security Considerations

### Image Scanning

```bash
# Scan for vulnerabilities
docker scout cves hallucinate/infiniteedge-aegis-edge-ai:v1.0.0-amd64

# Security best practices
- Use specific version tags
- Regularly update base images
- Scan for vulnerabilities
- Use minimal base images
- Run as non-root user
```

### Access Control

- Docker Hub access tokens with minimal permissions
- Repository-specific push access
- Automated security scanning
- Signed images (future enhancement)

## Performance Optimization

### Build Optimization

- Multi-stage builds to reduce image size
- Layer caching for faster builds
- Buildx for multi-architecture support
- Concurrent builds where possible

### Runtime Optimization

- Resource limits and requests
- Health checks and readiness probes
- Horizontal scaling support
- Efficient networking

## Future Enhancements

### Planned Features

1. **Multi-arch manifests** - Single tag for all architectures
2. **Image signing** - Cosign integration for security
3. **Automated scanning** - Continuous vulnerability assessment
4. **Performance monitoring** - Runtime metrics and alerting
5. **Rollback support** - Easy version rollback capability

### Contributing

To add new containers to the deployment pipeline:

1. Create Dockerfile in appropriate directory
2. Add to `WORKING_CONTAINERS` in deployment script
3. Test with `docker-test-suite.sh`
4. Submit PR with documentation updates

## Support

### Resources

- **GitHub Repository**: https://github.com/hallucinate-llc/infiniteedge
- **Docker Hub Organization**: https://hub.docker.com/u/hallucinate
- **Documentation**: `docs/` directory
- **Issue Tracker**: GitHub Issues

### Getting Help

1. Check this documentation
2. Run test suite for diagnostics
3. Review build logs
4. Create GitHub issue with details

---

**Last Updated**: October 2025  
**Version**: 1.0.0  
**Status**: Production Ready ✅