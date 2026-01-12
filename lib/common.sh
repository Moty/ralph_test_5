#!/bin/bash
# Ralph Common Library - Shared functions for validation, logging, and utilities
# Source this file from other Ralph scripts: source "$(dirname "$0")/lib/common.sh"

# ---- Colors -------------------------------------------------------
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# ---- Logging Functions --------------------------------------------

LOG_FILE="${LOG_FILE:-${SCRIPT_DIR:-.}/ralph.log}"
VERBOSE="${VERBOSE:-false}"

log_debug() {
  local message="$1"
  [ "$VERBOSE" = true ] && echo -e "${BLUE}[DEBUG]${NC} $message" >&2
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $message" >> "$LOG_FILE"
}

log_info() {
  local message="$1"
  echo -e "${GREEN}[INFO]${NC} $message" >&2
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE"
}

log_warn() {
  local message="$1"
  echo -e "${YELLOW}[WARN]${NC} $message" >&2
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $message" >> "$LOG_FILE"
}

log_error() {
  local message="$1"
  echo -e "${RED}[ERROR]${NC} $message" >&2
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE"
}

# ---- Dependency Checking ------------------------------------------

require_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "Missing required binary: $1"
    echo -e "${RED}Missing required binary: $1${NC}"
    echo -e "${YELLOW}Install it and try again.${NC}"
    exit 1
  }
}

check_bin_version() {
  local bin="$1"
  local min_version="$2"
  if ! command -v "$bin" >/dev/null 2>&1; then
    log_warn "$bin not found - skipping version check"
    return 1
  fi
  log_debug "$bin found - version check would compare against $min_version"
  # Note: Actual version comparison would go here
  # For now, we just log that the binary exists
  return 0
}

# ---- JSON Validation ----------------------------------------------

validate_json_file() {
  local file="$1"
  local file_type="$2"

  if [ ! -f "$file" ]; then
    log_error "$file_type not found: $file"
    echo -e "${RED}Error: $file_type not found: $file${NC}"
    return 1
  fi

  log_debug "Validating JSON file: $file"

  # Check if file is valid JSON
  if ! jq empty "$file" 2>/dev/null; then
    log_error "$file_type contains invalid JSON: $file"
    echo -e "${RED}Error: $file_type contains invalid JSON${NC}"
    echo -e "${YELLOW}Run: jq . $file${NC} to see the syntax error"
    return 1
  fi

  log_debug "JSON syntax valid: $file"
  return 0
}

validate_prd_json() {
  local prd_file="$1"

  log_info "Validating PRD structure: $prd_file"

  # First check basic JSON validity
  if ! validate_json_file "$prd_file" "prd.json"; then
    return 1
  fi

  # Check required top-level fields
  local required_fields=("project" "branchName" "userStories")
  for field in "${required_fields[@]}"; do
    if ! jq -e ".$field" "$prd_file" >/dev/null 2>&1; then
      log_error "PRD missing required field: $field"
      echo -e "${RED}Error: prd.json missing required field: $field${NC}"
      return 1
    fi
  done

  # Validate userStories is an array
  if ! jq -e '.userStories | type == "array"' "$prd_file" >/dev/null 2>&1; then
    log_error "PRD field 'userStories' must be an array"
    echo -e "${RED}Error: userStories must be an array${NC}"
    return 1
  fi

  # Check if userStories is empty
  local story_count=$(jq '.userStories | length' "$prd_file")
  if [ "$story_count" -eq 0 ]; then
    log_warn "PRD has no user stories"
    echo -e "${YELLOW}Warning: prd.json has no user stories${NC}"
    return 1
  fi

  # Validate each user story has required fields
  local story_required_fields=("id" "title" "description" "acceptanceCriteria" "priority" "passes")

  # More robust validation of user story structure
  local has_invalid=false
  for i in $(jq -r '.userStories | keys[]' "$prd_file"); do
    for field in "${story_required_fields[@]}"; do
      # Use has() to check field existence - jq -e fails on falsy values like 'false'
      if ! jq -e ".userStories[$i] | has(\"$field\")" "$prd_file" >/dev/null 2>&1; then
        log_error "User story at index $i missing field: $field"
        echo -e "${RED}Error: User story at index $i missing field: $field${NC}"
        has_invalid=true
      fi
    done
  done

  if [ "$has_invalid" = true ]; then
    return 1
  fi

  log_info "PRD validation successful: $story_count user stories found"
  echo -e "${GREEN}✓ PRD validation passed${NC} ($story_count stories)"
  return 0
}

# ---- YAML Validation ----------------------------------------------

validate_yaml_file() {
  local file="$1"
  local file_type="$2"

  if [ ! -f "$file" ]; then
    log_error "$file_type not found: $file"
    echo -e "${RED}Error: $file_type not found: $file${NC}"
    return 1
  fi

  log_debug "Validating YAML file: $file"

  # Check if file is valid YAML
  if ! yq eval '.' "$file" >/dev/null 2>&1; then
    log_error "$file_type contains invalid YAML: $file"
    echo -e "${RED}Error: $file_type contains invalid YAML${NC}"
    echo -e "${YELLOW}Run: yq eval . $file${NC} to see the syntax error"
    return 1
  fi

  log_debug "YAML syntax valid: $file"
  return 0
}

validate_agent_yaml() {
  local agent_file="$1"

  log_info "Validating agent configuration: $agent_file"

  # First check basic YAML validity
  if ! validate_yaml_file "$agent_file" "agent.yaml"; then
    return 1
  fi

  # Check required fields
  if ! yq eval '.agent.primary' "$agent_file" >/dev/null 2>&1; then
    log_error "agent.yaml missing required field: agent.primary"
    echo -e "${RED}Error: agent.yaml missing required field: agent.primary${NC}"
    return 1
  fi

  local primary_agent=$(yq eval '.agent.primary' "$agent_file")

  # Validate primary agent is a known type
  case "$primary_agent" in
    claude-code|codex|github-copilot|gemini)
      log_debug "Primary agent is valid: $primary_agent"
      ;;
    *)
      log_error "Unknown primary agent: $primary_agent"
      echo -e "${RED}Error: Unknown primary agent: $primary_agent${NC}"
      echo -e "${YELLOW}Valid options: claude-code, codex, github-copilot, gemini${NC}"
      return 1
      ;;
  esac

  # Validate fallback agent if present
  local fallback_agent=$(yq eval '.agent.fallback // ""' "$agent_file")
  if [ -n "$fallback_agent" ]; then
    case "$fallback_agent" in
      claude-code|codex|github-copilot|gemini)
        log_debug "Fallback agent is valid: $fallback_agent"
        ;;
      *)
        log_error "Unknown fallback agent: $fallback_agent"
        echo -e "${RED}Error: Unknown fallback agent: $fallback_agent${NC}"
        echo -e "${YELLOW}Valid options: claude-code, codex, github-copilot, gemini${NC}"
        return 1
        ;;
    esac
  fi

  log_info "Agent configuration validation successful"
  echo -e "${GREEN}✓ Agent configuration valid${NC} (primary: $primary_agent)"
  return 0
}

# ---- Git Validation -----------------------------------------------

validate_git_status() {
  local allow_uncommitted="${1:-false}"

  log_info "Checking git repository status"

  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a git repository"
    echo -e "${RED}Error: Not in a git repository${NC}"
    echo -e "${YELLOW}Initialize git with: git init${NC}"
    return 1
  fi

  # Check if there are uncommitted changes
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    if [ "$allow_uncommitted" = false ]; then
      log_warn "Git repository has uncommitted changes"
      echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
      echo -e "${YELLOW}Ralph will commit automatically, but you may want to commit or stash first.${NC}"
      echo ""
      git status --short
      echo ""
      read -p "Continue anyway? [y/N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "User cancelled due to uncommitted changes"
        return 1
      fi
    else
      log_debug "Uncommitted changes present (allowed)"
    fi
  else
    log_debug "Git working directory is clean"
  fi

  # Check if we're on a branch
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$current_branch" = "HEAD" ]; then
    log_error "Currently in detached HEAD state"
    echo -e "${RED}Error: Git is in detached HEAD state${NC}"
    echo -e "${YELLOW}Checkout a branch first${NC}"
    return 1
  fi

  log_info "Git status check passed (branch: $current_branch)"
  return 0
}

# ---- Process Utilities --------------------------------------------

run_with_timeout() {
  local timeout="$1"
  shift
  local command=("$@")

  log_debug "Running command with timeout ${timeout}s: ${command[*]}"

  # Run command in background
  "${command[@]}" &
  local pid=$!

  # Wait for command with timeout
  local count=0
  while kill -0 $pid 2>/dev/null; do
    if [ $count -ge "$timeout" ]; then
      log_error "Command timed out after ${timeout}s, killing process $pid"
      kill -TERM $pid 2>/dev/null || true
      sleep 2
      kill -KILL $pid 2>/dev/null || true
      return 124  # Standard timeout exit code
    fi
    sleep 1
    count=$((count + 1))
  done

  # Get exit status
  wait $pid
  return $?
}

cleanup_process() {
  local pid="$1"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    log_debug "Cleaning up process: $pid"
    kill -TERM "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi
}

# ---- Utility Functions --------------------------------------------

format_duration() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))
  if [ $hours -gt 0 ]; then
    printf "%dh %dm %ds" $hours $minutes $secs
  elif [ $minutes -gt 0 ]; then
    printf "%dm %ds" $minutes $secs
  else
    printf "%ds" $secs
  fi
}

confirm_action() {
  local prompt="$1"
  local default="${2:-n}"

  if [ "$default" = "y" ]; then
    read -p "$prompt [Y/n] " -n 1 -r
  else
    read -p "$prompt [y/N] " -n 1 -r
  fi
  echo

  if [ "$default" = "y" ]; then
    [[ ! $REPLY =~ ^[Nn]$ ]]
  else
    [[ $REPLY =~ ^[Yy]$ ]]
  fi
}

# ---- Initialization -----------------------------------------------

# Create log file if it doesn't exist
touch "$LOG_FILE" 2>/dev/null || true

log_debug "Common library loaded"
