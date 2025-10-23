#!/bin/bash

# InfiniteEdge Workflow Monitor Script
# Usage: ./scripts/monitor-workflow.sh [RUN_ID] [OPTIONS]

set -euo pipefail

# Configuration
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-hallucinate-llc}"
REPO_NAME="${GITHUB_REPOSITORY_NAME:-edge-whisper}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
API_BASE="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
ICON_SUCCESS="✅"
ICON_FAILURE="❌"
ICON_PENDING="⏳"
ICON_RUNNING="🔄"
ICON_CANCELLED="⏹️"
ICON_SKIPPED="⏭️"

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

# Help function
show_help() {
    cat << EOF
InfiniteEdge Workflow Monitor

Usage: $0 [RUN_ID] [OPTIONS]

Options:
  -f, --follow          Follow logs in real-time
  -j, --json            Output in JSON format
  -s, --summary         Show summary only
  -l, --logs            Show job logs
  -r, --refresh SECS    Refresh interval in seconds [default: 10]
  -h, --help            Show this help

Environment Variables:
  GITHUB_TOKEN          GitHub personal access token (required)
  GITHUB_REPOSITORY_OWNER Repository owner
  GITHUB_REPOSITORY_NAME Repository name

Examples:
  $0 1234567890                    # Monitor specific run
  $0 1234567890 -f -l              # Follow run with logs
  $0 --summary                     # Show latest runs summary

EOF
}

# Parse arguments
RUN_ID=""
FOLLOW_LOGS="false"
JSON_OUTPUT="false"
SUMMARY_ONLY="false"
SHOW_LOGS="false"
REFRESH_INTERVAL=10

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW_LOGS="true"
            shift
            ;;
        -j|--json)
            JSON_OUTPUT="true"
            shift
            ;;
        -s|--summary)
            SUMMARY_ONLY="true"
            shift
            ;;
        -l|--logs)
            SHOW_LOGS="true"
            shift
            ;;
        -r|--refresh)
            REFRESH_INTERVAL="$2"
            shift 2
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
            if [[ -z "$RUN_ID" ]]; then
                RUN_ID="$1"
            else
                log_error "Unexpected argument: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate GitHub token
if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GITHUB_TOKEN environment variable is required"
    exit 1
fi

# Function to get status icon
get_status_icon() {
    local status="$1"
    local conclusion="$2"
    
    case "$status" in
        "completed")
            case "$conclusion" in
                "success") echo "$ICON_SUCCESS" ;;
                "failure") echo "$ICON_FAILURE" ;;
                "cancelled") echo "$ICON_CANCELLED" ;;
                "skipped") echo "$ICON_SKIPPED" ;;
                *) echo "$ICON_FAILURE" ;;
            esac
            ;;
        "in_progress") echo "$ICON_RUNNING" ;;
        "queued") echo "$ICON_PENDING" ;;
        *) echo "❓" ;;
    esac
}

# Function to get colored status
get_colored_status() {
    local status="$1"
    local conclusion="$2"
    
    case "$status" in
        "completed")
            case "$conclusion" in
                "success") echo -e "${GREEN}SUCCESS${NC}" ;;
                "failure") echo -e "${RED}FAILURE${NC}" ;;
                "cancelled") echo -e "${YELLOW}CANCELLED${NC}" ;;
                "skipped") echo -e "${CYAN}SKIPPED${NC}" ;;
                *) echo -e "${RED}$conclusion${NC}" ;;
            esac
            ;;
        "in_progress") echo -e "${BLUE}RUNNING${NC}" ;;
        "queued") echo -e "${YELLOW}QUEUED${NC}" ;;
        *) echo -e "${PURPLE}$status${NC}" ;;
    esac
}

# Function to format duration
format_duration() {
    local start="$1"
    local end="${2:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
    
    if [[ "$start" == "null" || -z "$start" ]]; then
        echo "N/A"
        return
    fi
    
    local start_epoch=$(date -d "$start" +%s 2>/dev/null || echo "0")
    local end_epoch=$(date -d "$end" +%s 2>/dev/null || date +%s)
    
    local duration=$((end_epoch - start_epoch))
    
    if [[ $duration -lt 60 ]]; then
        echo "${duration}s"
    elif [[ $duration -lt 3600 ]]; then
        echo "$((duration / 60))m $((duration % 60))s"
    else
        echo "$((duration / 3600))h $(((duration % 3600) / 60))m"
    fi
}

# Function to show workflow summary
show_workflow_summary() {
    log_info "Fetching recent workflow runs..."
    
    local response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/runs?per_page=10")
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$response"
        return
    fi
    
    echo
    echo -e "${CYAN}Recent Workflow Runs:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    printf "%-10s %-15s %-20s %-10s %-15s\n" "ID" "STATUS" "WORKFLOW" "BRANCH" "DURATION"
    echo "─────────────────────────────────────────────────────────────────"
    
    echo "$response" | jq -r '.workflow_runs[] | 
        [.id, .status, .conclusion // "null", .name, .head_branch, .created_at, .updated_at] | 
        @tsv' | while IFS=$'\t' read -r id status conclusion name branch created updated; do
        
        local icon=$(get_status_icon "$status" "$conclusion")
        local colored_status=$(get_colored_status "$status" "$conclusion")
        local duration=$(format_duration "$created" "$updated")
        
        printf "%-10s %s %-12s %-20s %-10s %-15s\n" \
            "$id" "$icon" "$colored_status" "${name:0:18}" "${branch:0:8}" "$duration"
    done
}

# Function to monitor specific run
monitor_run() {
    local run_id="$1"
    
    log_info "Monitoring workflow run: $run_id"
    
    # Create log file for this session
    local log_file="/tmp/workflow-monitor-$run_id-$(date +%s).log"
    echo "Workflow Monitor Session - $(date)" > "$log_file"
    
    local previous_status=""
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        
        # Get run details
        local run_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "$API_BASE/runs/$run_id")
        
        if echo "$run_response" | jq -e '.message' > /dev/null 2>&1; then
            log_error "API Error: $(echo "$run_response" | jq -r '.message')"
            exit 1
        fi
        
        local status=$(echo "$run_response" | jq -r '.status')
        local conclusion=$(echo "$run_response" | jq -r '.conclusion')
        local workflow_name=$(echo "$run_response" | jq -r '.name')
        local branch=$(echo "$run_response" | jq -r '.head_branch')
        local commit=$(echo "$run_response" | jq -r '.head_sha[0:7]')
        local created_at=$(echo "$run_response" | jq -r '.created_at')
        local updated_at=$(echo "$run_response" | jq -r '.updated_at')
        local html_url=$(echo "$run_response" | jq -r '.html_url')
        
        # Clear screen for real-time updates (only if following)
        if [[ "$FOLLOW_LOGS" == "true" && $iteration -gt 1 ]]; then
            clear
        fi
        
        # Show run header
        echo
        echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  InfiniteEdge Workflow Monitor${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
        echo
        echo -e "${BLUE}Workflow:${NC} $workflow_name"
        echo -e "${BLUE}Run ID:${NC} $run_id"
        echo -e "${BLUE}Branch:${NC} $branch"
        echo -e "${BLUE}Commit:${NC} $commit"
        echo -e "${BLUE}URL:${NC} $html_url"
        echo
        
        # Show status
        local icon=$(get_status_icon "$status" "$conclusion")
        local colored_status=$(get_colored_status "$status" "$conclusion")
        local duration=$(format_duration "$created_at" "$updated_at")
        
        echo -e "${BLUE}Status:${NC} $icon $colored_status"
        echo -e "${BLUE}Duration:${NC} $duration"
        echo -e "${BLUE}Last Updated:${NC} $updated_at"
        echo
        
        # Get jobs
        local jobs_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "$API_BASE/runs/$run_id/jobs")
        
        echo -e "${CYAN}Jobs:${NC}"
        echo "─────────────────────────────────────────────────────────────"
        printf "%-25s %-15s %-20s\n" "JOB NAME" "STATUS" "DURATION"
        echo "─────────────────────────────────────────────────────────────"
        
        echo "$jobs_response" | jq -r '.jobs[] | 
            [.name, .status, .conclusion // "null", .started_at, .completed_at] | 
            @tsv' | while IFS=$'\t' read -r job_name job_status job_conclusion job_start job_end; do
            
            local job_icon=$(get_status_icon "$job_status" "$job_conclusion")
            local job_colored_status=$(get_colored_status "$job_status" "$job_conclusion")
            local job_duration=$(format_duration "$job_start" "$job_end")
            
            printf "%-25s %s %-12s %-20s\n" \
                "${job_name:0:23}" "$job_icon" "$job_colored_status" "$job_duration"
        done
        
        # Log to file
        echo "[$(date)] Status: $status, Conclusion: $conclusion" >> "$log_file"
        
        # Show logs if requested
        if [[ "$SHOW_LOGS" == "true" ]]; then
            echo
            echo -e "${CYAN}Recent Job Logs:${NC}"
            echo "─────────────────────────────────────────────────────────────"
            
            # Get logs for running/completed jobs
            echo "$jobs_response" | jq -r '.jobs[] | select(.status == "completed" or .status == "in_progress") | .id' | head -3 | while read -r job_id; do
                local job_logs=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    "$API_BASE/jobs/$job_id/logs" 2>/dev/null || echo "No logs available")
                
                if [[ ${#job_logs} -lt 1000 && "$job_logs" != "No logs available" ]]; then
                    echo "$job_logs" | tail -10
                fi
            done
        fi
        
        # Check if completed
        if [[ "$status" == "completed" ]]; then
            echo
            if [[ "$conclusion" == "success" ]]; then
                log_success "Workflow completed successfully!"
            else
                log_error "Workflow failed with conclusion: $conclusion"
            fi
            
            echo -e "${BLUE}Log file saved:${NC} $log_file"
            
            if [[ "$conclusion" == "success" ]]; then
                exit 0
            else
                exit 1
            fi
        fi
        
        # Status change notification
        if [[ "$previous_status" != "$status" && -n "$previous_status" ]]; then
            log_info "Status changed: $previous_status → $status"
        fi
        previous_status="$status"
        
        # Wait before next update (only if following)
        if [[ "$FOLLOW_LOGS" == "true" ]]; then
            echo
            echo -e "${YELLOW}Refreshing in ${REFRESH_INTERVAL}s... (Ctrl+C to stop)${NC}"
            sleep "$REFRESH_INTERVAL"
        else
            break
        fi
    done
}

# Main execution
if [[ "$SUMMARY_ONLY" == "true" ]]; then
    show_workflow_summary
elif [[ -n "$RUN_ID" ]]; then
    monitor_run "$RUN_ID"
else
    # If no run ID provided, monitor the latest run
    log_info "No run ID provided, finding latest run..."
    
    latest_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$API_BASE/runs?per_page=1")
    
    latest_run_id=$(echo "$latest_response" | jq -r '.workflow_runs[0].id')
    
    if [[ -z "$latest_run_id" || "$latest_run_id" == "null" ]]; then
        log_error "No workflow runs found"
        show_workflow_summary
        exit 1
    fi
    
    log_info "Monitoring latest run: $latest_run_id"
    monitor_run "$latest_run_id"
fi
