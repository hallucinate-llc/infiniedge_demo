#!/bin/bash

# GitHub Copilot Integration Script for InfiniteEdge CI/CD
# Provides workflow monitoring and analysis for Copilot agent pull requests

set -euo pipefail

# Configuration
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-hallucinate-llc}"
REPO_NAME="${GITHUB_REPOSITORY_NAME:-edge-whisper}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
API_BASE="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
ICON_ROBOT="🤖"
ICON_SUCCESS="✅"
ICON_FAILURE="❌"
ICON_PENDING="⏳"
ICON_RUNNING="🔄"

# Logging functions
log_copilot() {
    echo -e "${PURPLE}${ICON_ROBOT} [COPILOT]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
GitHub Copilot Integration for InfiniteEdge CI/CD

Usage: $0 COMMAND [OPTIONS]

COMMANDS:
  monitor-pr PR_NUMBER      Monitor workflows for a specific PR
  analyze-logs RUN_ID       Analyze workflow logs for insights
  trigger-build BRANCH      Trigger build for Copilot changes
  status-report             Generate status report for Copilot
  watch-copilot             Watch for Copilot PR activities

OPTIONS:
  -f, --follow             Follow logs in real-time
  -j, --json              Output in JSON format
  -v, --verbose           Verbose output
  -h, --help              Show this help

Environment Variables:
  GITHUB_TOKEN            GitHub personal access token (required)
  GITHUB_REPOSITORY_OWNER Repository owner
  GITHUB_REPOSITORY_NAME  Repository name

Examples:
  $0 monitor-pr 123                    # Monitor PR #123
  $0 analyze-logs 1234567890           # Analyze specific run
  $0 trigger-build copilot-feature     # Trigger build for branch
  $0 watch-copilot -f                  # Watch Copilot activity

EOF
}

# Check if PR is from Copilot
is_copilot_pr() {
    local pr_number="$1"
    
    local pr_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/pulls/$pr_number")
    
    local author=$(echo "$pr_response" | jq -r '.user.login')
    local title=$(echo "$pr_response" | jq -r '.title')
    local body=$(echo "$pr_response" | jq -r '.body // ""')
    
    # Check for Copilot indicators
    if [[ "$author" =~ ^github-actions || "$author" =~ copilot ]] || \
       [[ "$title" =~ [Cc]opilot || "$title" =~ [Aa]gent ]] || \
       [[ "$body" =~ "copilot" || "$body" =~ "agent" ]]; then
        return 0
    else
        return 1
    fi
}

# Monitor PR workflows
monitor_pr() {
    local pr_number="$1"
    local follow="${2:-false}"
    
    log_copilot "Monitoring workflows for PR #$pr_number"
    
    # Check if it's a Copilot PR
    if is_copilot_pr "$pr_number"; then
        log_copilot "Detected Copilot-generated PR #$pr_number"
    else
        log_info "Regular PR #$pr_number (not Copilot-generated)"
    fi
    
    # Get PR details
    local pr_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/pulls/$pr_number")
    
    local head_sha=$(echo "$pr_response" | jq -r '.head.sha')
    local branch=$(echo "$pr_response" | jq -r '.head.ref')
    local title=$(echo "$pr_response" | jq -r '.title')
    
    echo
    echo -e "${CYAN}PR Details:${NC}"
    echo "  Number: #$pr_number"
    echo "  Title: $title"
    echo "  Branch: $branch"
    echo "  Commit: $head_sha"
    echo
    
    # Get workflow runs for this PR
    local runs_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/actions/runs?head_sha=$head_sha")
    
    local run_ids=($(echo "$runs_response" | jq -r '.workflow_runs[].id'))
    
    if [[ ${#run_ids[@]} -eq 0 ]]; then
        log_error "No workflow runs found for PR #$pr_number"
        return 1
    fi
    
    log_copilot "Found ${#run_ids[@]} workflow run(s) for this PR"
    
    # Monitor each workflow run
    for run_id in "${run_ids[@]}"; do
        if [[ "$follow" == "true" ]]; then
            ./scripts/monitor-workflow.sh "$run_id" --follow
        else
            ./scripts/monitor-workflow.sh "$run_id"
        fi
        echo
    done
}

# Analyze workflow logs for insights
analyze_logs() {
    local run_id="$1"
    
    log_copilot "Analyzing logs for workflow run: $run_id"
    
    # Get run details
    local run_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/actions/runs/$run_id")
    
    local workflow_name=$(echo "$run_response" | jq -r '.name')
    local status=$(echo "$run_response" | jq -r '.status')
    local conclusion=$(echo "$run_response" | jq -r '.conclusion')
    local created_at=$(echo "$run_response" | jq -r '.created_at')
    
    echo
    echo -e "${CYAN}Workflow Analysis:${NC}"
    echo "  Run ID: $run_id"
    echo "  Workflow: $workflow_name"
    echo "  Status: $status"
    echo "  Conclusion: $conclusion"
    echo "  Created: $created_at"
    echo
    
    # Get jobs for detailed analysis
    local jobs_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/actions/runs/$run_id/jobs")
    
    echo -e "${CYAN}Job Analysis:${NC}"
    
    local total_jobs=$(echo "$jobs_response" | jq '.jobs | length')
    local failed_jobs=$(echo "$jobs_response" | jq '[.jobs[] | select(.conclusion == "failure")] | length')
    local successful_jobs=$(echo "$jobs_response" | jq '[.jobs[] | select(.conclusion == "success")] | length')
    
    echo "  Total Jobs: $total_jobs"
    echo "  Successful: $successful_jobs"
    echo "  Failed: $failed_jobs"
    echo
    
    # Analyze failed jobs
    if [[ $failed_jobs -gt 0 ]]; then
        echo -e "${RED}Failed Jobs Analysis:${NC}"
        
        echo "$jobs_response" | jq -r '.jobs[] | select(.conclusion == "failure") | 
            "  - " + .name + " (" + .status + ")"'
        
        echo
        
        # Get logs for failed jobs
        log_copilot "Analyzing failure patterns..."
        
        local failure_patterns=()
        
        echo "$jobs_response" | jq -r '.jobs[] | select(.conclusion == "failure") | .id' | while read -r job_id; do
            local job_logs=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                "$API_BASE/actions/jobs/$job_id/logs" 2>/dev/null || echo "")
            
            # Analyze common failure patterns
            if echo "$job_logs" | grep -qi "docker.*not found"; then
                failure_patterns+=("Docker not available")
            elif echo "$job_logs" | grep -qi "permission denied"; then
                failure_patterns+=("Permission denied")
            elif echo "$job_logs" | grep -qi "timeout"; then
                failure_patterns+=("Timeout occurred")
            elif echo "$job_logs" | grep -qi "connection refused"; then
                failure_patterns+=("Connection refused")
            elif echo "$job_logs" | grep -qi "out of memory"; then
                failure_patterns+=("Out of memory")
            elif echo "$job_logs" | grep -qi "no space left"; then
                failure_patterns+=("Disk space exhausted")
            fi
        done
        
        if [[ ${#failure_patterns[@]} -gt 0 ]]; then
            echo -e "${YELLOW}Common Failure Patterns:${NC}"
            for pattern in "${failure_patterns[@]}"; do
                echo "  - $pattern"
            done
            echo
        fi
    fi
    
    # Performance analysis
    echo -e "${CYAN}Performance Analysis:${NC}"
    
    local total_duration=$(echo "$jobs_response" | jq -r '
        [.jobs[] | select(.started_at and .completed_at) | 
         ((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601))] | 
        add // 0')
    
    local avg_duration=0
    if [[ $successful_jobs -gt 0 ]]; then
        avg_duration=$(echo "scale=2; $total_duration / $successful_jobs" | bc -l || echo "0")
    fi
    
    echo "  Total Duration: ${total_duration}s"
    echo "  Average Job Duration: ${avg_duration}s"
    
    # Resource usage insights
    local build_jobs=$(echo "$jobs_response" | jq '[.jobs[] | select(.name | contains("build") or contains("Build"))] | length')
    local test_jobs=$(echo "$jobs_response" | jq '[.jobs[] | select(.name | contains("test") or contains("Test"))] | length')
    
    echo "  Build Jobs: $build_jobs"
    echo "  Test Jobs: $test_jobs"
    echo
    
    # Generate recommendations for Copilot
    log_copilot "Generating recommendations..."
    
    if [[ $failed_jobs -gt 0 ]]; then
        echo -e "${YELLOW}Recommendations:${NC}"
        
        if [[ $failed_jobs -eq $total_jobs ]]; then
            echo "  - All jobs failed - check basic configuration"
        elif [[ $failed_jobs -gt $((total_jobs / 2)) ]]; then
            echo "  - Most jobs failed - check system dependencies"
        else
            echo "  - Some jobs failed - check specific job configurations"
        fi
        
        if [[ $avg_duration -gt 300 ]]; then  # 5 minutes
            echo "  - Jobs are taking longer than expected - optimize build steps"
        fi
        
        echo "  - Review failed job logs for specific error patterns"
        echo "  - Consider running tests locally before pushing"
    else
        echo -e "${GREEN}All jobs passed successfully! ${ICON_SUCCESS}${NC}"
    fi
}

# Trigger build for Copilot changes
trigger_build() {
    local branch="$1"
    
    log_copilot "Triggering build for branch: $branch"
    
    # Use the existing trigger script
    ./scripts/trigger-workflow.sh ci-cd --branch "$branch" --arch both --test
}

# Generate status report for Copilot
status_report() {
    log_copilot "Generating InfiniteEdge status report"
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "                     INFINITEEDGE CI/CD STATUS REPORT                        "
    echo "                        $(date)                           "
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Get recent workflow runs
    local runs_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/actions/runs?per_page=20")
    
    local total_runs=$(echo "$runs_response" | jq '.workflow_runs | length')
    local successful_runs=$(echo "$runs_response" | jq '[.workflow_runs[] | select(.conclusion == "success")] | length')
    local failed_runs=$(echo "$runs_response" | jq '[.workflow_runs[] | select(.conclusion == "failure")] | length')
    local in_progress_runs=$(echo "$runs_response" | jq '[.workflow_runs[] | select(.status == "in_progress")] | length')
    
    # Calculate success rate
    local success_rate=0
    local completed_runs=$((successful_runs + failed_runs))
    if [[ $completed_runs -gt 0 ]]; then
        success_rate=$(( successful_runs * 100 / completed_runs ))
    fi
    
    echo -e "${CYAN}Overall Statistics (Last 20 Runs):${NC}"
    echo "  Total Runs: $total_runs"
    echo "  Successful: $successful_runs"
    echo "  Failed: $failed_runs"
    echo "  In Progress: $in_progress_runs"
    echo "  Success Rate: ${success_rate}%"
    echo
    
    # Recent activity
    echo -e "${CYAN}Recent Activity:${NC}"
    echo "$runs_response" | jq -r '.workflow_runs[0:5][] | 
        "  " + (.created_at | fromdateiso8601 | strftime("%Y-%m-%d %H:%M")) + 
        " - " + .name + 
        " (" + .status + 
        (if .conclusion then "/" + .conclusion else "" end) + ")"'
    
    echo
    
    # Architecture-specific status
    echo -e "${CYAN}Architecture Status:${NC}"
    
    # Check for ARM64 and x86_64 specific runs
    local arm64_runs=$(echo "$runs_response" | jq '[.workflow_runs[] | select(.name | contains("arm64") or contains("ARM64"))] | length')
    local x86_64_runs=$(echo "$runs_response" | jq '[.workflow_runs[] | select(.name | contains("x86_64") or contains("amd64"))] | length')
    
    echo "  ARM64 Runs: $arm64_runs"
    echo "  x86_64 Runs: $x86_64_runs"
    echo "  Multi-arch Runs: $((total_runs - arm64_runs - x86_64_runs))"
    echo
    
    # Service health (if available)
    echo -e "${CYAN}Service Health:${NC}"
    
    local services=(
        "AegisEdgeAI:9080"
        "SPEAR:9081"
        "YoMo:9082"
        "Shifu:9083"
    )
    
    for service_info in "${services[@]}"; do
        local name=$(echo "$service_info" | cut -d':' -f1)
        local port=$(echo "$service_info" | cut -d':' -f2)
        
        if timeout 5 curl -sf "http://localhost:$port/health" >/dev/null 2>&1; then
            echo "  $name: ${ICON_SUCCESS} Healthy"
        else
            echo "  $name: ${ICON_FAILURE} Unavailable"
        fi
    done
    
    echo
    
    # Recommendations
    echo -e "${CYAN}Recommendations:${NC}"
    
    if [[ $success_rate -lt 80 ]]; then
        echo "  ${ICON_FAILURE} Success rate is below 80% - investigate recent failures"
    else
        echo "  ${ICON_SUCCESS} Success rate is healthy at ${success_rate}%"
    fi
    
    if [[ $in_progress_runs -gt 3 ]]; then
        echo "  ⚠️  High number of concurrent runs - consider resource limits"
    fi
    
    if [[ $failed_runs -gt $((total_runs / 3)) ]]; then
        echo "  ${ICON_FAILURE} High failure rate - review common failure patterns"
    fi
    
    echo "  ${ICON_ROBOT} Use 'copilot-integration.sh analyze-logs RUN_ID' for detailed analysis"
    echo "  ${ICON_ROBOT} Use 'copilot-integration.sh monitor-pr PR_NUMBER' to track PR progress"
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Watch for Copilot activity
watch_copilot() {
    local follow="${1:-false}"
    
    log_copilot "Watching for Copilot PR activities..."
    
    while true; do
        # Get recent PRs
        local prs_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "$API_BASE/pulls?state=open&per_page=10")
        
        local copilot_prs=()
        
        # Check each PR for Copilot indicators
        while read -r pr_number; do
            if is_copilot_pr "$pr_number"; then
                copilot_prs+=("$pr_number")
            fi
        done < <(echo "$prs_response" | jq -r '.[].number')
        
        if [[ ${#copilot_prs[@]} -gt 0 ]]; then
            log_copilot "Found ${#copilot_prs[@]} active Copilot PR(s): ${copilot_prs[*]}"
            
            for pr_num in "${copilot_prs[@]}"; do
                echo "  - PR #$pr_num"
            done
        else
            log_info "No active Copilot PRs found"
        fi
        
        if [[ "$follow" != "true" ]]; then
            break
        fi
        
        echo "Checking again in 60 seconds..."
        sleep 60
        clear
    done
}

# Parse arguments
COMMAND="$1"
shift || { show_help; exit 1; }

case "$COMMAND" in
    monitor-pr)
        PR_NUMBER="$1"
        FOLLOW="${2:-false}"
        monitor_pr "$PR_NUMBER" "$FOLLOW"
        ;;
    analyze-logs)
        RUN_ID="$1"
        analyze_logs "$RUN_ID"
        ;;
    trigger-build)
        BRANCH="$1"
        trigger_build "$BRANCH"
        ;;
    status-report)
        status_report
        ;;
    watch-copilot)
        FOLLOW="true"
        if [[ $# -gt 0 && "$1" == "--no-follow" ]]; then
            FOLLOW="false"
        fi
        watch_copilot "$FOLLOW"
        ;;
    -h|--help)
        show_help
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
