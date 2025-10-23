#!/bin/bash

# InfiniteEdge Docker Hub Build and Push Script
# Organization: hallucinate-llc

set -euo pipefail

# Configuration
DOCKER_HUB_ORG="hallucinate"
IMAGE_BASE_NAME="infiniteedge"
VERSION_TAG="${1:-latest}"
ARCHITECTURE="${2:-amd64}"
BUILD_CONTEXT="."
DOCKERFILE_PATH="orchestrator/Dockerfile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons
ICON_BUILD="🔨"
ICON_TEST="🧪"
ICON_PUSH="📤"
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_section() {
    echo
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
}

# Help function
show_help() {
    cat << EOF
InfiniteEdge Docker Hub Build and Push Script

Usage: $0 [VERSION_TAG] [ARCHITECTURE] [OPTIONS]

Arguments:
  VERSION_TAG     Version tag for the image (default: latest)
  ARCHITECTURE    Target architecture: amd64, arm64, or multi (default: amd64)

Options:
  --org ORG       Docker Hub organization (default: hallucinate)
  --name NAME     Base image name (default: infiniteedge)
  --test-only     Build and test only, don't push
  --push-only     Skip build and test, push existing image
  --no-cache      Build without Docker cache
  --verbose       Enable verbose output
  --help          Show this help

Examples:
  $0                           # Build latest for amd64
  $0 v1.0.0                   # Build v1.0.0 for amd64
  $0 latest arm64             # Build latest for arm64
  $0 v1.0.0 multi             # Build multi-arch v1.0.0
  $0 latest amd64 --test-only # Build and test only

Environment Variables:
  DOCKER_HUB_USERNAME    Docker Hub username (required for push)
  DOCKER_HUB_PASSWORD    Docker Hub password/token (required for push)

EOF
}

# Parse arguments
DOCKER_HUB_ORG="hallucinate"
IMAGE_BASE_NAME="infiniteedge"
TEST_ONLY=false
PUSH_ONLY=false
NO_CACHE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --org)
            DOCKER_HUB_ORG="$2"
            shift 2
            ;;
        --name)
            IMAGE_BASE_NAME="$2"
            shift 2
            ;;
        --test-only)
            TEST_ONLY=true
            shift
            ;;
        --push-only)
            PUSH_ONLY=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            # Positional arguments handled above
            shift
            ;;
    esac
done

# Image tags
FULL_IMAGE_NAME="${DOCKER_HUB_ORG}/${IMAGE_BASE_NAME}"
IMAGE_TAG="${FULL_IMAGE_NAME}:${VERSION_TAG}"

if [[ "$ARCHITECTURE" != "multi" ]]; then
    IMAGE_TAG="${IMAGE_TAG}-${ARCHITECTURE}"
fi

log_section "${ICON_BUILD} INFINITEEDGE DOCKER BUILD & PUSH"

echo -e "${CYAN}Configuration:${NC}"
echo "  Docker Hub Org: $DOCKER_HUB_ORG"
echo "  Image Name: $IMAGE_BASE_NAME"
echo "  Version: $VERSION_TAG"
echo "  Architecture: $ARCHITECTURE"
echo "  Full Tag: $IMAGE_TAG"
echo "  Build Context: $BUILD_CONTEXT"
echo "  Dockerfile: $DOCKERFILE_PATH"
echo "  Test Only: $TEST_ONLY"
echo "  Push Only: $PUSH_ONLY"
echo "  No Cache: $NO_CACHE"
echo

# Pre-flight checks
check_prerequisites() {
    log_section "${ICON_TEST} PRE-FLIGHT CHECKS"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Docker version: $(docker --version)"
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check Dockerfile exists
    if [[ ! -f "$DOCKERFILE_PATH" ]]; then
        log_error "Dockerfile not found at: $DOCKERFILE_PATH"
        exit 1
    fi
    
    log_info "Dockerfile found: $DOCKERFILE_PATH"
    
    # Check build context
    if [[ ! -d "$BUILD_CONTEXT" ]]; then
        log_error "Build context not found: $BUILD_CONTEXT"
        exit 1
    fi
    
    log_info "Build context: $BUILD_CONTEXT"
    
    # Check Docker Hub credentials (if not test-only)
    if [[ "$TEST_ONLY" != true && "$PUSH_ONLY" != true ]]; then
        if [[ -z "${DOCKER_HUB_USERNAME:-}" ]]; then
            log_warning "DOCKER_HUB_USERNAME not set - will prompt for login"
        fi
        if [[ -z "${DOCKER_HUB_PASSWORD:-}" ]]; then
            log_warning "DOCKER_HUB_PASSWORD not set - will prompt for login"
        fi
    fi
    
    # Check architecture support
    if [[ "$ARCHITECTURE" == "multi" ]]; then
        if ! docker buildx version &> /dev/null; then
            log_error "Docker Buildx is required for multi-architecture builds"
            exit 1
        fi
        log_info "Docker Buildx version: $(docker buildx version)"
    fi
    
    log_success "Pre-flight checks completed"
}

# Docker login
docker_login() {
    if [[ "$TEST_ONLY" == true ]]; then
        log_info "Skipping Docker Hub login (test-only mode)"
        return 0
    fi
    
    log_section "${ICON_PUSH} DOCKER HUB LOGIN"
    
    if [[ -n "${DOCKER_HUB_USERNAME:-}" && -n "${DOCKER_HUB_PASSWORD:-}" ]]; then
        log_info "Logging in to Docker Hub using environment variables..."
        echo "$DOCKER_HUB_PASSWORD" | docker login --username "$DOCKER_HUB_USERNAME" --password-stdin
    else
        log_info "Please login to Docker Hub:"
        docker login
    fi
    
    log_success "Docker Hub login successful"
}\n\n# Build function\nbuild_image() {\n    if [[ "$PUSH_ONLY" == true ]]; then\n        log_info "Skipping build (push-only mode)"\n        return 0\n    fi\n    \n    log_section "${ICON_BUILD} BUILDING DOCKER IMAGE"\n    \n    local build_args=()\n    build_args+=(\"--file\" \"$DOCKERFILE_PATH\")\n    build_args+=(\"--tag\" \"$IMAGE_TAG\")\n    \n    # Add build arguments\n    build_args+=(\"--build-arg\" \"BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')\")\n    build_args+=(\"--build-arg\" \"VERSION=$VERSION_TAG\")\n    build_args+=(\"--build-arg\" \"VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')\")\n    build_args+=(\"--build-arg\" \"VCS_URL=$(git config --get remote.origin.url 2>/dev/null || echo 'unknown')\")\n    \n    # Architecture-specific builds\n    case \"$ARCHITECTURE\" in\n        \"amd64\")\n            build_args+=(\"--platform\" \"linux/amd64\")\n            ;;\n        \"arm64\")\n            build_args+=(\"--platform\" \"linux/arm64\")\n            # Use buildx for ARM64\n            if docker buildx version &> /dev/null; then\n                build_args=(\"buildx\" \"build\" \"${build_args[@]}\")\n            fi\n            ;;\n        \"multi\")\n            log_info \"Building multi-architecture image...\"\n            build_args=(\"buildx\" \"build\" \"${build_args[@]}\")\n            build_args+=(\"--platform\" \"linux/amd64,linux/arm64\")\n            build_args+=(\"--push\")  # buildx multi-arch requires push\n            ;;\n        *)\n            log_error \"Unsupported architecture: $ARCHITECTURE\"\n            exit 1\n            ;;\n    esac\n    \n    # No cache option\n    if [[ \"$NO_CACHE\" == true ]]; then\n        build_args+=(\"--no-cache\")\n    fi\n    \n    # Verbose output\n    if [[ \"$VERBOSE\" == true ]]; then\n        build_args+=(\"--progress\" \"plain\")\n    fi\n    \n    # Add build context\n    build_args+=(\"$BUILD_CONTEXT\")\n    \n    log_info \"Building image: $IMAGE_TAG\"\n    log_info \"Architecture: $ARCHITECTURE\"\n    log_info \"Build command: docker ${build_args[*]}\"\n    \n    # Execute build\n    if docker \"${build_args[@]}\"; then\n        log_success \"Image built successfully: $IMAGE_TAG\"\n        \n        # Show image info\n        if [[ \"$ARCHITECTURE\" != \"multi\" ]]; then\n            local image_size=$(docker images --format \"table {{.Size}}\" \"$IMAGE_TAG\" | tail -n +2)\n            local image_id=$(docker images --format \"table {{.ID}}\" \"$IMAGE_TAG\" | tail -n +2)\n            log_info \"Image ID: $image_id\"\n            log_info \"Image Size: $image_size\"\n        fi\n    else\n        log_error \"Image build failed\"\n        exit 1\n    fi\n}\n\n# Test function\ntest_image() {\n    if [[ \"$PUSH_ONLY\" == true || \"$ARCHITECTURE\" == \"multi\" ]]; then\n        log_info \"Skipping tests (push-only mode or multi-arch build)\"\n        return 0\n    fi\n    \n    log_section \"${ICON_TEST} TESTING DOCKER IMAGE\"\n    \n    # Basic image inspection\n    log_info \"Inspecting image...\"\n    docker inspect \"$IMAGE_TAG\" > /dev/null\n    \n    # Test container startup\n    log_info \"Testing container startup...\"\n    local container_id\n    container_id=$(docker run -d --name \"infiniteedge-test-$(date +%s)\" -p 8888:80 \"$IMAGE_TAG\")\n    \n    if [[ -z \"$container_id\" ]]; then\n        log_error \"Failed to start test container\"\n        exit 1\n    fi\n    \n    log_info \"Test container started: $container_id\"\n    \n    # Wait for container to be ready\n    log_info \"Waiting for container to be ready...\"\n    local retries=30\n    local ready=false\n    \n    for ((i=1; i<=retries; i++)); do\n        if docker exec \"$container_id\" curl -sf http://localhost/health >/dev/null 2>&1; then\n            ready=true\n            break\n        fi\n        \n        if [[ $i -eq $retries ]]; then\n            log_error \"Container health check failed after $retries attempts\"\n            docker logs \"$container_id\"\n            docker stop \"$container_id\" >/dev/null 2>&1 || true\n            docker rm \"$container_id\" >/dev/null 2>&1 || true\n            exit 1\n        fi\n        \n        log_info \"Health check $i/$retries failed, retrying in 2s...\"\n        sleep 2\n    done\n    \n    if [[ \"$ready\" == true ]]; then\n        log_success \"Container is healthy and ready\"\n        \n        # Test basic endpoints\n        log_info \"Testing basic endpoints...\"\n        \n        # Test health endpoint\n        if docker exec \"$container_id\" curl -sf http://localhost/health >/dev/null; then\n            log_success \"Health endpoint test passed\"\n        else\n            log_error \"Health endpoint test failed\"\n        fi\n        \n        # Test API endpoint\n        if docker exec \"$container_id\" curl -sf http://localhost/api/v1/status >/dev/null; then\n            log_success \"API endpoint test passed\"\n        else\n            log_warning \"API endpoint test failed (might be expected)\"\n        fi\n        \n        # Test service ports (basic connectivity)\n        local test_ports=(8080 8081 8082 8083)\n        for port in \"${test_ports[@]}\"; do\n            if docker exec \"$container_id\" nc -z localhost \"$port\" 2>/dev/null; then\n                log_success \"Port $port is accessible\"\n            else\n                log_warning \"Port $port is not accessible (might be expected)\"\n            fi\n        done\n        \n    else\n        log_error \"Container failed to become ready\"\n        exit 1\n    fi\n    \n    # Cleanup test container\n    log_info \"Cleaning up test container...\"\n    docker stop \"$container_id\" >/dev/null 2>&1 || true\n    docker rm \"$container_id\" >/dev/null 2>&1 || true\n    \n    log_success \"Image testing completed successfully\"\n}\n\n# Push function\npush_image() {\n    if [[ \"$TEST_ONLY\" == true ]]; then\n        log_info \"Skipping push (test-only mode)\"\n        return 0\n    fi\n    \n    if [[ \"$ARCHITECTURE\" == \"multi\" ]]; then\n        log_info \"Multi-arch image already pushed during build\"\n        return 0\n    fi\n    \n    log_section \"${ICON_PUSH} PUSHING TO DOCKER HUB\"\n    \n    log_info \"Pushing image: $IMAGE_TAG\"\n    \n    if docker push \"$IMAGE_TAG\"; then\n        log_success \"Image pushed successfully to Docker Hub\"\n        log_info \"Image available at: https://hub.docker.com/r/$DOCKER_HUB_ORG/$IMAGE_BASE_NAME\"\n        \n        # Also push latest tag if version is not latest\n        if [[ \"$VERSION_TAG\" != \"latest\" ]]; then\n            local latest_tag=\"${FULL_IMAGE_NAME}:latest-${ARCHITECTURE}\"\n            log_info \"Tagging and pushing as latest: $latest_tag\"\n            docker tag \"$IMAGE_TAG\" \"$latest_tag\"\n            docker push \"$latest_tag\"\n        fi\n    else\n        log_error \"Failed to push image to Docker Hub\"\n        exit 1\n    fi\n}\n\n# Create manifest for multi-arch (if applicable)\ncreate_manifest() {\n    if [[ \"$TEST_ONLY\" == true || \"$ARCHITECTURE\" != \"multi\" ]]; then\n        return 0\n    fi\n    \n    log_section \"📋 CREATING MULTI-ARCH MANIFEST\"\n    \n    local manifest_tag=\"${FULL_IMAGE_NAME}:${VERSION_TAG}\"\n    \n    log_info \"Creating manifest: $manifest_tag\"\n    \n    # The manifest is automatically created by buildx for multi-arch builds\n    log_success \"Multi-arch manifest created successfully\"\n}\n\n# Generate summary report\ngenerate_summary() {\n    log_section \"📊 BUILD SUMMARY REPORT\"\n    \n    echo -e \"${CYAN}Build Configuration:${NC}\"\n    echo \"  Organization: $DOCKER_HUB_ORG\"\n    echo \"  Image Name: $IMAGE_BASE_NAME\"\n    echo \"  Version: $VERSION_TAG\"\n    echo \"  Architecture: $ARCHITECTURE\"\n    echo \"  Full Tag: $IMAGE_TAG\"\n    echo\n    \n    echo -e \"${CYAN}Build Results:${NC}\"\n    if [[ \"$PUSH_ONLY\" != true ]]; then\n        echo \"  ${ICON_BUILD} Build: ${GREEN}Success${NC}\"\n    fi\n    \n    if [[ \"$TEST_ONLY\" != true && \"$PUSH_ONLY\" != true && \"$ARCHITECTURE\" != \"multi\" ]]; then\n        echo \"  ${ICON_TEST} Tests: ${GREEN}Success${NC}\"\n    fi\n    \n    if [[ \"$TEST_ONLY\" != true ]]; then\n        echo \"  ${ICON_PUSH} Push: ${GREEN}Success${NC}\"\n    fi\n    \n    echo\n    echo -e \"${CYAN}Image Information:${NC}\"\n    echo \"  Docker Hub URL: https://hub.docker.com/r/$DOCKER_HUB_ORG/$IMAGE_BASE_NAME\"\n    echo \"  Pull Command: docker pull $IMAGE_TAG\"\n    \n    if [[ \"$ARCHITECTURE\" != \"multi\" ]]; then\n        echo \"  Run Command: docker run -p 8888:80 $IMAGE_TAG\"\n    fi\n    \n    echo\n    echo -e \"${GREEN}${ICON_SUCCESS} Build and push completed successfully!${NC}\"\n}\n\n# Main execution\nmain() {\n    check_prerequisites\n    \n    if [[ \"$TEST_ONLY\" != true && \"$PUSH_ONLY\" != true ]]; then\n        docker_login\n    fi\n    \n    build_image\n    test_image\n    push_image\n    create_manifest\n    generate_summary\n}\n\n# Error handling\ntrap 'log_error \"Script failed at line $LINENO\"' ERR\n\n# Execute main function\nif [[ \"${BASH_SOURCE[0]}\" == \"${0}\" ]]; then\n    main\nfi