#!/bin/bash

# InfiniteEdge Orchestrator Docker Hub Push Script (endomorphosis)
# This script pushes the orchestrator container to Docker Hub under endomorphosis

set -e

echo "🚀 InfiniteEdge Orchestrator Docker Hub Push (endomorphosis)"
echo "============================================"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

# Check if image exists locally
if ! docker images | grep -q "endomorphosis/infiniteedge-orchestrator"; then
    echo "❌ Error: Local orchestrator image not found"
    echo "Please run the re-tagging commands first"
    exit 1
fi

# Verify Docker Hub login
USERNAME=$(docker info 2>/dev/null | grep "Username:" | awk '{print $2}' || echo "")
if [ "$USERNAME" != "endomorphosis" ]; then
    echo "⚠️  Warning: Not logged in as endomorphosis (current: $USERNAME)"
    echo "🔐 Please login to Docker Hub as endomorphosis..."
    if ! docker login; then
        echo "❌ Docker Hub login failed"
        exit 1
    fi
fi

echo "✅ Docker Hub login verified (endomorphosis)"

# Get image info
echo "📦 Image Information:"
docker images | grep "endomorphosis/infiniteedge-orchestrator" | head -5

# Push all tags
echo "⬆️  Pushing orchestrator container to Docker Hub..."
echo "This may take several minutes due to the image size (~9GB)..."

echo "Pushing latest tag..."
docker push endomorphosis/infiniteedge-orchestrator:latest

echo "Pushing v1.0.0-amd64 tag..."
docker push endomorphosis/infiniteedge-orchestrator:v1.0.0-amd64

echo "Pushing latest-amd64 tag..."
docker push endomorphosis/infiniteedge-orchestrator:latest-amd64

echo ""
echo "🎉 SUCCESS! Orchestrator container pushed to Docker Hub"
echo "============================================"
echo ""
echo "📋 Repository Information:"
echo "Repository: https://hub.docker.com/r/endomorphosis/infiniteedge-orchestrator"
echo ""
echo "🐳 Available Tags:"
echo "  • endomorphosis/infiniteedge-orchestrator:latest"
echo "  • endomorphosis/infiniteedge-orchestrator:latest-amd64"
echo "  • endomorphosis/infiniteedge-orchestrator:v1.0.0-amd64"
echo ""
echo "🚀 Usage Examples:"
echo "  # Pull and run:"
echo "  docker pull endomorphosis/infiniteedge-orchestrator:latest"
echo "  docker run -d -p 80:80 --name infiniteedge endomorphosis/infiniteedge-orchestrator:latest"
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