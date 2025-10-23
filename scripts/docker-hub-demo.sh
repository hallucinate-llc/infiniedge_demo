#!/bin/bash

# InfiniteEdge Docker Hub Deployment Demo
# This script demonstrates how to deploy InfiniteEdge containers to Docker Hub

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 InfiniteEdge Docker Hub Deployment Demo${NC}"
echo
echo -e "${CYAN}This demo will guide you through deploying InfiniteEdge containers to Docker Hub.${NC}"
echo

# Check if credentials are set
if [[ -z "${DOCKER_HUB_USERNAME:-}" ]]; then
    echo -e "${YELLOW}⚠️  DOCKER_HUB_USERNAME not set${NC}"
    echo "Please set your Docker Hub username:"
    read -r -p "Username: " DOCKER_HUB_USERNAME
    export DOCKER_HUB_USERNAME
fi

if [[ -z "${DOCKER_HUB_PASSWORD:-}" ]]; then
    echo -e "${YELLOW}⚠️  DOCKER_HUB_PASSWORD not set${NC}"
    echo "Please enter your Docker Hub password/token:"
    read -r -s -p "Password/Token: " DOCKER_HUB_PASSWORD
    export DOCKER_HUB_PASSWORD
    echo
fi

echo
echo -e "${GREEN}✅ Credentials configured${NC}"
echo "Username: $DOCKER_HUB_USERNAME"
echo "Organization: hallucinate"
echo

# Show available deployment options
echo -e "${CYAN}Available deployment options:${NC}"
echo
echo "1. Quick Deploy (v1.0.0 amd64) - Recommended for testing"
echo "2. ARM64 Deploy (v1.0.0 arm64) - For ARM64 systems"
echo "3. Custom Deploy - Specify your own version and architecture"
echo "4. Multi-Arch Deploy - Build both amd64 and arm64"
echo "5. Show Help"
echo

read -r -p "Select option (1-5): " choice

case $choice in
    1)
        echo -e "${GREEN}🔨 Starting Quick Deploy (v1.0.0 amd64)...${NC}"
        ./scripts/docker-hub-deploy-streamlined.sh v1.0.0 amd64
        ;;
    2)
        echo -e "${GREEN}🔨 Starting ARM64 Deploy (v1.0.0 arm64)...${NC}"
        ./scripts/docker-hub-deploy-streamlined.sh v1.0.0 arm64
        ;;
    3)
        echo "Enter version tag (e.g., v1.0.0, latest):"
        read -r version
        echo "Enter architecture (amd64 or arm64):"
        read -r arch
        echo -e "${GREEN}🔨 Starting Custom Deploy ($version $arch)...${NC}"
        ./scripts/docker-hub-deploy-streamlined.sh "$version" "$arch"
        ;;
    4)
        echo -e "${GREEN}🔨 Starting Multi-Arch Deploy...${NC}"
        echo "Building for amd64..."
        ./scripts/docker-hub-deploy-streamlined.sh v1.0.0 amd64
        echo
        echo "Building for arm64..."
        ./scripts/docker-hub-deploy-streamlined.sh v1.0.0 arm64
        ;;
    5)
        ./scripts/docker-hub-deploy-streamlined.sh --help
        ;;
    *)
        echo -e "${YELLOW}Invalid option. Running help...${NC}"
        ./scripts/docker-hub-deploy-streamlined.sh --help
        ;;
esac

echo
echo -e "${GREEN}🎉 Demo completed!${NC}"
echo
echo -e "${CYAN}Next steps:${NC}"
echo "1. Visit https://hub.docker.com/u/hallucinate to see your images"
echo "2. Test your containers locally:"
echo "   docker run -it hallucinate/infiniteedge-aegis-edge-ai:v1.0.0-amd64"
echo "3. Use in production with docker-compose or Kubernetes"
echo
echo -e "${CYAN}Documentation:${NC}"
echo "- README.md for detailed usage"
echo "- docs/ directory for architecture details"
echo "- scripts/docker-hub-deploy-streamlined.sh --help for options"