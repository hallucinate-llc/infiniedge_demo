#!/bin/bash

# Script to fork all submodules to your GitHub userspace and commit changes

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🍴 InfinieEdge Demo Platform - Fork and Commit Script"
echo "===================================================="

# Configuration
GITHUB_USERNAME=${GITHUB_USERNAME:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

# Get GitHub username if not set
get_github_username() {
    if [ -z "$GITHUB_USERNAME" ]; then
        print_info "Enter your GitHub username:"
        read -r GITHUB_USERNAME
        export GITHUB_USERNAME
    fi
    
    print_info "Using GitHub username: $GITHUB_USERNAME"
}

# Get GitHub token if not set
get_github_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        print_warning "GitHub token not set. For private repos and higher rate limits:"
        print_info "1. Go to https://github.com/settings/tokens"
        print_info "2. Generate a token with 'repo' scope"
        print_info "3. Enter token (optional, press Enter to skip):"
        read -rs GITHUB_TOKEN
        export GITHUB_TOKEN
    fi
}

# Function to check if GitHub CLI is available
check_gh_cli() {
    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            print_success "GitHub CLI is available and authenticated"
            return 0
        else
            print_warning "GitHub CLI is available but not authenticated"
            print_info "Run: gh auth login"
            return 1
        fi
    else
        print_warning "GitHub CLI not found. Install with: sudo apt install gh"
        return 1
    fi
}

# Function to fork repository using GitHub API
fork_repository() {
    local original_repo="$1"
    local repo_name=$(basename "$original_repo")
    
    print_info "Forking $original_repo..."
    
    # Check if fork already exists
    if curl -s -H "Authorization: token $GITHUB_TOKEN" \
       "https://api.github.com/repos/$GITHUB_USERNAME/$repo_name" | grep -q '"id"'; then
        print_warning "Fork already exists: $GITHUB_USERNAME/$repo_name"
        return 0
    fi
    
    # Fork the repository
    if [ -n "$GITHUB_TOKEN" ]; then
        local response=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$original_repo/forks")
        
        if echo "$response" | grep -q '"id"'; then
            print_success "Successfully forked $original_repo"
            return 0
        else
            print_error "Failed to fork $original_repo"
            echo "Response: $response"
            return 1
        fi
    else
        print_warning "No GitHub token provided. Please fork manually: https://github.com/$original_repo"
        return 1
    fi
}

# Function to fork repository using GitHub CLI
fork_repository_gh() {
    local original_repo="$1"
    local repo_name=$(basename "$original_repo")
    
    print_info "Forking $original_repo using GitHub CLI..."
    
    if gh repo fork "$original_repo" --clone=false >/dev/null 2>&1; then
        print_success "Successfully forked $original_repo"
        return 0
    else
        print_warning "Fork may already exist or failed: $original_repo"
        return 1
    fi
}

# Function to update submodule remote
update_submodule_remote() {
    local submodule_path="$1"
    local original_repo="$2"
    local repo_name=$(basename "$original_repo")
    
    print_info "Updating remote for $submodule_path..."
    
    cd "$submodule_path"
    
    # Add your fork as origin
    local fork_url="https://github.com/$GITHUB_USERNAME/$repo_name.git"
    
    # Check if we can access the fork
    if git ls-remote "$fork_url" >/dev/null 2>&1; then
        # Set your fork as the new origin
        git remote set-url origin "$fork_url"
        
        # Add upstream remote for the original repo
        git remote add upstream "https://github.com/$original_repo.git" 2>/dev/null || true
        
        print_success "Updated remotes for $submodule_path"
        git remote -v
    else
        print_error "Cannot access fork: $fork_url"
        return 1
    fi
    
    cd - >/dev/null
}

# Function to commit and push changes
commit_and_push_changes() {
    local submodule_path="$1"
    local repo_name=$(basename "$submodule_path")
    
    print_info "Committing and pushing changes for $repo_name..."
    
    cd "$submodule_path"
    
    # Check if there are any changes
    if git status --porcelain | grep -q .; then
        # Add all changes
        git add .
        
        # Commit changes
        local commit_message="Add Docker configuration and InfinieEdge integration
        
- Added Dockerfile for containerization
- Added docker-compose configuration
- Added service startup scripts
- Added health check endpoints
- Integrated with InfinieEdge Demo Platform
- Added external orchestration support

Co-authored-by: InfinieEdge Platform <infiniedge@example.com>"
        
        git commit -m "$commit_message"
        
        # Push to your fork
        if git push origin "$(git branch --show-current)"; then
            print_success "Successfully pushed changes for $repo_name"
        else
            print_error "Failed to push changes for $repo_name"
            return 1
        fi
    else
        print_warning "No changes to commit in $repo_name"
    fi
    
    cd - >/dev/null
}

# Function to get original repository info from submodule
get_original_repo() {
    local submodule_path="$1"
    
    cd "$submodule_path"
    local remote_url=$(git remote get-url origin)
    
    # Extract owner/repo from URL
    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        print_error "Cannot parse GitHub URL: $remote_url"
        return 1
    fi
    
    cd - >/dev/null
}

# Main function to process all submodules
process_all_submodules() {
    print_header "Processing All Submodules"
    
    # Get list of submodules
    local submodules=(
        "AegisEdgeAI"
        "SPEAR" 
        "yomo"
        "shifu"
        "AIOps"
        "eda"
        "edge-whisper"
        "Whisper-Finetune"
        "Megatron-LM"
        "transformers"
    )
    
    print_info "Found ${#submodules[@]} submodules to process"
    
    for submodule in "${submodules[@]}"; do
        if [ -d "$submodule" ]; then
            print_header "Processing $submodule"
            
            # Get original repository info
            local original_repo=$(get_original_repo "$submodule")
            print_info "Original repository: $original_repo"
            
            # Fork the repository
            if check_gh_cli; then
                fork_repository_gh "$original_repo"
            else
                fork_repository "$original_repo"
            fi
            
            # Update submodule remote
            update_submodule_remote "$submodule" "$original_repo"
            
            # Commit and push changes
            commit_and_push_changes "$submodule"
            
            print_success "Completed processing $submodule"
        else
            print_warning "Submodule directory not found: $submodule"
        fi
    done
}

# Function to create a summary
create_summary() {
    print_header "Creating Fork Summary"
    
    cat > FORK_SUMMARY.md << EOF
# InfinieEdge Demo Platform - Fork Summary

This document summarizes the forked repositories and changes made for the InfinieEdge Demo Platform.

## Forked Repositories

The following repositories have been forked to \`$GITHUB_USERNAME\` userspace:

| Original Repository | Your Fork | Status |
|---------------------|-----------|--------|
EOF

    local submodules=(
        "AegisEdgeAI"
        "SPEAR" 
        "yomo"
        "shifu"
        "AIOps"
        "eda"
        "edge-whisper"
        "Whisper-Finetune"
        "Megatron-LM"
        "transformers"
    )
    
    for submodule in "${submodules[@]}"; do
        if [ -d "$submodule" ]; then
            local original_repo=$(get_original_repo "$submodule" 2>/dev/null || echo "unknown")
            echo "| \`$original_repo\` | \`$GITHUB_USERNAME/$submodule\` | ✅ Forked |" >> FORK_SUMMARY.md
        fi
    done
    
    cat >> FORK_SUMMARY.md << EOF

## Changes Made

Each forked repository includes the following additions:

- **Dockerfile**: Containerization configuration for the service
- **docker-compose.yml**: Service orchestration configuration  
- **Health Check Endpoints**: `/health` endpoint for monitoring
- **Startup Scripts**: Service-specific startup and configuration scripts
- **External Orchestration**: Integration with the external orchestrator container
- **Documentation**: Updated README with Docker instructions

## External Orchestrator Container

The main innovation is the external orchestrator container that:

- Runs ALL services simultaneously in a single container
- Provides unified routing through Nginx gateway
- Includes comprehensive health monitoring
- Offers a beautiful web dashboard at http://localhost/
- Manages all service lifecycles with supervisor

## Usage

### Build and Run External Container
\`\`\`bash
# Build the external orchestrator
docker-compose -f docker-compose.external.yml build

# Run all services in one container
docker-compose -f docker-compose.external.yml up -d

# Access the dashboard
open http://localhost/
\`\`\`

### Access Individual Services
- **Main Dashboard**: http://localhost/
- **AegisEdgeAI**: http://localhost/aegis/
- **SPEAR**: http://localhost/spear/
- **YoMo**: http://localhost/yomo/
- **Shifu**: http://localhost/shifu/
- **And 6 more services...**

## Repository Structure

\`\`\`
infiniedge_demo/
├── orchestrator/                 # External orchestrator configuration
│   ├── Dockerfile               # Main orchestrator container
│   ├── supervisord.conf         # Process management
│   ├── nginx.conf              # Gateway configuration
│   └── scripts/                # Service startup scripts
├── docker-compose.external.yml  # External container deployment
├── AegisEdgeAI/                # Forked submodule
├── SPEAR/                      # Forked submodule
├── yomo/                       # Forked submodule
└── ...                         # All other forked submodules
\`\`\`

Generated on: $(date)
EOF

    print_success "Fork summary created: FORK_SUMMARY.md"
}

# Main execution
main() {
    get_github_username
    get_github_token
    
    print_warning "This script will:"
    print_warning "1. Fork all submodule repositories to your GitHub account"
    print_warning "2. Update submodule remotes to point to your forks"
    print_warning "3. Commit and push all Docker configurations"
    print_warning ""
    print_info "Continue? (y/N)"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
    
    process_all_submodules
    create_summary
    
    print_success "🎉 All repositories forked and changes committed!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Build external container: docker-compose -f docker-compose.external.yml build"
    print_info "2. Run all services: docker-compose -f docker-compose.external.yml up -d"
    print_info "3. Access dashboard: http://localhost/"
    print_info "4. Review fork summary: cat FORK_SUMMARY.md"
}

# Execute main function
main "$@"