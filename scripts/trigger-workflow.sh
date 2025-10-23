#!/bin/bash

# InfiniteEdge CI/CD Workflow Trigger Script
# Usage: ./scripts/trigger-workflow.sh [workflow] [architecture] [options]

set -euo pipefail

# Configuration
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-hallucinate-llc}"
REPO_NAME="${GITHUB_REPOSITORY_NAME:-edge-whisper}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
WORKFLOW_API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/workflows"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
InfiniteEdge CI/CD Workflow Trigger

Usage: $0 [OPTIONS] WORKFLOW_TYPE

WORKFLOW_TYPE:
  ci-cd         Trigger main CI/CD workflow
  pr-test       Trigger PR preview and testing
  security      Trigger security scan only
  build         Trigger build only (no tests)

OPTIONS:
  -a, --arch ARCH        Architecture (x86_64, arm64, both) [default: both]
  -b, --branch BRANCH    Branch to build [default: current branch]
  -t, --test             Run integration tests [default: true]
  -d, --deploy MODE      Deployment mode (test, staging, production)
  -w, --wait             Wait for workflow completion
  -m, --monitor          Monitor workflow in real-time
  -h, --help             Show this help message

Environment Variables:
  GITHUB_TOKEN           GitHub personal access token (required)
  GITHUB_REPOSITORY_OWNER Repository owner [default: hallucinate-llc]
  GITHUB_REPOSITORY_NAME Repository name [default: edge-whisper]

Examples:
  $0 ci-cd                           # Trigger CI/CD for both architectures
  $0 ci-cd -a arm64 -b feature/new   # Trigger CI/CD for ARM64 on specific branch
  $0 pr-test -w -m                   # Trigger PR test and monitor progress
  $0 build -a x86_64 --no-test       # Build x86_64 only without tests

EOF
}

# Parse arguments
WORKFLOW_TYPE=""
ARCHITECTURE="both"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main')"
RUN_TESTS="true"
DEPLOY_MODE="test"
WAIT_FOR_COMPLETION="false"
MONITOR_WORKFLOW="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--arch)
            ARCHITECTURE="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -t|--test)
            RUN_TESTS="true"
            shift
            ;;
        --no-test)
            RUN_TESTS="false"
            shift
            ;;
        -d|--deploy)
            DEPLOY_MODE="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_FOR_COMPLETION="true"
            shift
            ;;
        -m|--monitor)
            MONITOR_WORKFLOW="true"
            WAIT_FOR_COMPLETION="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$WORKFLOW_TYPE" ]]; then
                WORKFLOW_TYPE="$1"
            else
                log_error "Unexpected argument: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$WORKFLOW_TYPE" ]]; then
    log_error "Workflow type is required"
    show_help
    exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GITHUB_TOKEN environment variable is required"
    log_info "Create a token at: https://github.com/settings/tokens"
    exit 1
fi

if [[ ! "$ARCHITECTURE" =~ ^(x86_64|arm64|both)$ ]]; then
    log_error "Invalid architecture: $ARCHITECTURE"
    log_info "Valid options: x86_64, arm64, both"
    exit 1
fi

if [[ ! "$DEPLOY_MODE" =~ ^(test|staging|production)$ ]]; then
    log_error "Invalid deploy mode: $DEPLOY_MODE"
    log_info "Valid options: test, staging, production"
    exit 1
fi

# Map workflow types to workflow files
case "$WORKFLOW_TYPE" in
    ci-cd)
        WORKFLOW_FILE="ci-cd-multi-arch.yml"
        ;;
    pr-test)
        WORKFLOW_FILE="pr-preview.yml"
        ;;
    security)
        WORKFLOW_FILE="security-scan.yml"
        ;;
    build)
        WORKFLOW_FILE="build-only.yml"
        ;;
    *)
        log_error "Unknown workflow type: $WORKFLOW_TYPE"
        log_info "Valid types: ci-cd, pr-test, security, build"
        exit 1
        ;;
esac

# Get workflow ID
log_info "Getting workflow ID for $WORKFLOW_FILE..."
WORKFLOW_RESPONSE=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$WORKFLOW_API_URL")

WORKFLOW_ID=$(echo "$WORKFLOW_RESPONSE" | jq -r ".workflows[] | select(.path | contains(\"$WORKFLOW_FILE\")) | .id")

if [[ -z "$WORKFLOW_ID" || "$WORKFLOW_ID" == "null" ]]; then
    log_error "Could not find workflow: $WORKFLOW_FILE"
    log_info "Available workflows:"
    echo "$WORKFLOW_RESPONSE" | jq -r '.workflows[].name'
    exit 1
fi

log_info "Found workflow ID: $WORKFLOW_ID"

# Prepare workflow inputs
INPUTS=$(jq -n \
    --arg arch "$ARCHITECTURE" \
    --arg test "$RUN_TESTS" \
    --arg deploy "$DEPLOY_MODE" \
    '{
        build_architecture: $arch,
        run_tests: ($test == "true"),
        deploy_mode: $deploy
    }')

# Trigger workflow
log_info "Triggering workflow on branch: $BRANCH"
log_info "Architecture: $ARCHITECTURE"
log_info "Run tests: $RUN_TESTS"
log_info "Deploy mode: $DEPLOY_MODE"

TRIGGER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    "$WORKFLOW_API_URL/$WORKFLOW_ID/dispatches" \
    -d "$(jq -n --arg ref "$BRANCH" --argjson inputs "$INPUTS" '{ref: $ref, inputs: $inputs}')")

HTTP_CODE=$(echo "$TRIGGER_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$TRIGGER_RESPONSE" | head -n -1)

if [[ "$HTTP_CODE" != "204" ]]; then
    log_error "Failed to trigger workflow. HTTP code: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

log_success "Workflow triggered successfully!"

# Wait for workflow run to appear
if [[ "$WAIT_FOR_COMPLETION" == "true" ]]; then
    log_info "Waiting for workflow run to start..."
    sleep 5
    
    # Get the latest run
    RUNS_RESPONSE=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$WORKFLOW_API_URL/$WORKFLOW_ID/runs?per_page=1")
    
    RUN_ID=$(echo "$RUNS_RESPONSE" | jq -r '.workflow_runs[0].id')
    RUN_URL=$(echo "$RUNS_RESPONSE" | jq -r '.workflow_runs[0].html_url')
    
    if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
        log_error "Could not find workflow run"
        exit 1
    fi
    
    log_info "Workflow run started: $RUN_URL"
    log_info "Run ID: $RUN_ID"
    
    if [[ "$MONITOR_WORKFLOW" == "true" ]]; then
        ./scripts/monitor-workflow.sh "$RUN_ID"
    else
        # Simple wait for completion
        log_info "Waiting for workflow completion..."
        while true; do
            RUN_STATUS_RESPONSE=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runs/$RUN_ID")
            
            STATUS=$(echo "$RUN_STATUS_RESPONSE" | jq -r '.status')
            CONCLUSION=$(echo "$RUN_STATUS_RESPONSE" | jq -r '.conclusion')
            
            if [[ "$STATUS" == "completed" ]]; then
                if [[ "$CONCLUSION" == "success" ]]; then
                    log_success "Workflow completed successfully!"
                    exit 0
                else
                    log_error "Workflow failed with conclusion: $CONCLUSION"
                    exit 1
                fi
            fi
            
            log_info "Workflow status: $STATUS"
            sleep 30
        done
    fi
else
    log_info "Workflow triggered. Check status at:"
    log_info "https://github.com/$REPO_OWNER/$REPO_NAME/actions"
fi
