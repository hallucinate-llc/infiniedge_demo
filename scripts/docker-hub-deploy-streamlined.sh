#!/bin/bash

# Streamlined InfiniteEdge Docker Build and Push Script
# Focuses on containers that successfully build and test

set -euo pipefail

# Configuration
DOCKER_HUB_ORG="hallucinate"
VERSION_TAG="${1:-v1.0.0}"
ARCHITECTURE="${2:-amd64}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
ICON_BUILD="🔨"
ICON_TEST="🧪"
ICON_PUSH="📤"
ICON_SUCCESS="✅"
ICON_ERROR="❌"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() {
    echo
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# Working containers configuration
declare -A WORKING_CONTAINERS=(
    ["orchestrator"]="orchestrator/Dockerfile.working:."
    ["aegis-edge-ai"]="AegisEdgeAI/Dockerfile.simple:AegisEdgeAI"
    ["yomo"]="yomo/Dockerfile.infiniedge:yomo"
    ["transformers"]="transformers/Dockerfile.infiniedge:transformers"
    ["whisper-finetune"]="Whisper-Finetune/Dockerfile.infiniedge:Whisper-Finetune"
)

# Pre-flight checks
check_prerequisites() {
    log_section "${ICON_TEST} PRE-FLIGHT CHECKS"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    log_info "Docker version: $(docker --version)"
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check Docker Hub credentials
    if [[ -z "${DOCKER_HUB_USERNAME:-}" || -z "${DOCKER_HUB_PASSWORD:-}" ]]; then
        log_error "Please set DOCKER_HUB_USERNAME and DOCKER_HUB_PASSWORD environment variables"
        exit 1
    fi
    
    log_success "Pre-flight checks completed"
}

# Docker Hub login
docker_login() {
    log_section "${ICON_PUSH} DOCKER HUB LOGIN"
    
    log_info "Logging in to Docker Hub..."
    echo "$DOCKER_HUB_PASSWORD" | docker login --username "$DOCKER_HUB_USERNAME" --password-stdin
    
    log_success "Docker Hub login successful"
}

# Build and push individual container
build_and_push_container() {
    local container_name=$1
    local dockerfile_info=$2
    
    IFS=':' read -r dockerfile build_context <<< "$dockerfile_info"
    
    log_section "${ICON_BUILD} BUILDING $container_name"
    
    # Check if Dockerfile exists
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    local image_name="${DOCKER_HUB_ORG}/infiniteedge-${container_name}"
    local full_tag="${image_name}:${VERSION_TAG}-${ARCHITECTURE}"
    local latest_tag="${image_name}:latest-${ARCHITECTURE}"
    
    log_info "Building image: $full_tag"
    log_info "Build context: $build_context"
    log_info "Dockerfile: $dockerfile"
    
    # Build the image
    local build_args=(
        "--file" "$dockerfile"
        "--tag" "$full_tag"
        "--tag" "$latest_tag"
        "--platform" "linux/$ARCHITECTURE"
        "--build-arg" "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        "--build-arg" "VERSION=$VERSION_TAG"
        "--build-arg" "VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    )
    
    if docker build "${build_args[@]}" "$build_context"; then
        log_success "$container_name built successfully"
        
        # Test the container quickly
        log_info "Quick test of $container_name..."
        local test_container="test-${container_name}-$$"
        
        if docker run -d --name "$test_container" "$full_tag" sleep 30; then
            log_success "$container_name container starts successfully"
            docker rm -f "$test_container" >/dev/null 2>&1
        else
            log_error "$container_name container test failed"
            return 1
        fi
        
        # Push to Docker Hub
        log_info "Pushing $full_tag to Docker Hub..."
        if docker push "$full_tag"; then
            log_success "$full_tag pushed successfully"
        else
            log_error "Failed to push $full_tag"
            return 1
        fi
        
        # Push latest tag
        log_info "Pushing $latest_tag to Docker Hub..."
        if docker push "$latest_tag"; then
            log_success "$latest_tag pushed successfully"
        else
            log_error "Failed to push $latest_tag"
            return 1
        fi
        
        # Clean up local images to save space
        docker rmi "$full_tag" "$latest_tag" >/dev/null 2>&1 || true
        
        return 0
    else
        log_error "$container_name build failed"
        return 1
    fi
}

# Main execution
main() {
    log_section "${ICON_BUILD} INFINITEEDGE STREAMLINED DOCKER BUILD & PUSH"
    
    echo -e "${CYAN}Configuration:${NC}"
    echo "  Docker Hub Org: $DOCKER_HUB_ORG"
    echo "  Version: $VERSION_TAG"
    echo "  Architecture: $ARCHITECTURE"
    echo "  Containers: ${!WORKING_CONTAINERS[*]}"
    echo
    
    check_prerequisites
    docker_login
    
    # Build and push each working container
    local successful_builds=()
    local failed_builds=()
    
    for container_name in "${!WORKING_CONTAINERS[@]}"; do
        dockerfile_info="${WORKING_CONTAINERS[$container_name]}"
        
        if build_and_push_container "$container_name" "$dockerfile_info"; then
            successful_builds+=("$container_name")
        else
            failed_builds+=("$container_name")
        fi
    done
    
    # Summary
    log_section "📊 BUILD SUMMARY"
    
    echo -e "${CYAN}Successful Builds (${#successful_builds[@]}):${NC}"
    for container in "${successful_builds[@]}"; do
        echo "  ${ICON_SUCCESS} $container"
        echo "    - docker pull ${DOCKER_HUB_ORG}/infiniteedge-${container}:${VERSION_TAG}-${ARCHITECTURE}"
        echo "    - docker pull ${DOCKER_HUB_ORG}/infiniteedge-${container}:latest-${ARCHITECTURE}"
    done
    
    if [[ ${#failed_builds[@]} -gt 0 ]]; then
        echo
        echo -e "${CYAN}Failed Builds (${#failed_builds[@]}):${NC}"
        for container in "${failed_builds[@]}"; do
            echo "  ${ICON_ERROR} $container"
        done
    fi
    
    echo
    if [[ ${#successful_builds[@]} -gt 0 ]]; then
        log_success "Docker Hub deployment completed with ${#successful_builds[@]} successful containers!"
        echo
        echo -e "${CYAN}Docker Hub Organization:${NC} https://hub.docker.com/u/$DOCKER_HUB_ORG"
        echo -e "${CYAN}Available Images:${NC}"
        for container in "${successful_builds[@]}"; do
            echo "  - https://hub.docker.com/r/${DOCKER_HUB_ORG}/infiniteedge-${container}"
        done
    else
        log_error "No containers were successfully built and pushed"
        exit 1
    fi
}

# Error handling
trap 'log_error "Script failed at line $LINENO"' ERR

# Help
if [[ "${1:-}" == "--help" ]]; then
    cat << EOF
InfiniteEdge Streamlined Docker Build and Push

Usage: $0 [VERSION] [ARCHITECTURE]

Arguments:
  VERSION       Version tag (default: v1.0.0)
  ARCHITECTURE  Architecture: amd64 or arm64 (default: amd64)

Environment Variables (required):
  DOCKER_HUB_USERNAME    Docker Hub username
  DOCKER_HUB_PASSWORD    Docker Hub password/token

Examples:
  export DOCKER_HUB_USERNAME="myusername"
  export DOCKER_HUB_PASSWORD="mytoken"
  
  $0                     # Build v1.0.0 for amd64
  $0 v1.1.0              # Build v1.1.0 for amd64
  $0 v1.0.0 arm64        # Build v1.0.0 for arm64

Working Containers:
EOF
    for container in "${!WORKING_CONTAINERS[@]}"; do
        echo "  - $container"
    done
    exit 0
fi

# Execute main function
main "$@"