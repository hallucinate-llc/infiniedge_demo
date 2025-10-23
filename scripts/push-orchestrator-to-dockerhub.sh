#!/bin/bash

# InfiniteEdge Orchestrator Docker Hub Push Script
# This script pushes the orchestrator container to Docker Hub

set -e

echo "🚀 InfiniteEdge Orchestrator Docker Hub Push"
echo "============================================"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

# Check if image exists locally
if ! docker images | grep -q "hallucinate/infiniteedge-orchestrator"; then
    echo "❌ Error: Local orchestrator image not found"
    echo "Please run: docker build -f orchestrator/Dockerfile.working -t hallucinate/infiniteedge-orchestrator:latest ."
    exit 1
fi

# Login to Docker Hub
echo "🔐 Logging into Docker Hub..."
echo "Please enter your Docker Hub credentials:"

if ! docker login; then
    echo "❌ Docker Hub login failed"
    exit 1
fi

echo "✅ Docker Hub login successful"

# Get image info
echo "📦 Image Information:"
docker images | grep "hallucinate/infiniteedge-orchestrator" | head -5

# Push all tags
echo "⬆️  Pushing orchestrator container to Docker Hub..."
echo "This may take several minutes due to the image size (~9GB)..."

echo "Pushing latest tag..."
docker push hallucinate/infiniteedge-orchestrator:latest

echo "Pushing v1.0.0-amd64 tag..."
docker push hallucinate/infiniteedge-orchestrator:v1.0.0-amd64

echo "Pushing latest-amd64 tag..."
docker push hallucinate/infiniteedge-orchestrator:latest-amd64

echo ""
echo "🎉 SUCCESS! Orchestrator container pushed to Docker Hub"
echo "============================================"
echo ""
echo "📋 Repository Information:"
echo "Repository: https://hub.docker.com/r/hallucinate/infiniteedge-orchestrator"
echo ""
echo "🐳 Available Tags:"
echo "  • hallucinate/infiniteedge-orchestrator:latest"
echo "  • hallucinate/infiniteedge-orchestrator:latest-amd64"
echo "  • hallucinate/infiniteedge-orchestrator:v1.0.0-amd64"
echo ""
echo "🚀 Usage Examples:"
echo "  # Pull and run:"
echo "  docker pull hallucinate/infiniteedge-orchestrator:latest"
echo "  docker run -d -p 80:80 --name infiniteedge hallucinate/infiniteedge-orchestrator:latest"
echo ""
echo "  # Docker Compose:"
echo "  docker-compose -f docker-compose.orchestrator.yml up -d"
echo ""
echo "📊 Container Features:"
echo "  • Multi-service orchestration (11+ services)"
echo "  • HTTP Gateway on port 80"
echo "  • Health monitoring and auto-restart"
echo "  • ARM64/AMD64 compatible"
echo "  • Supervisor-based process management"
echo ""
echo "✅ Deployment complete!"