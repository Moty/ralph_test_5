#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop (agent-agnostic)
# Usage: ./ralph.sh [max_iterations|status|review|filebug|change] [--no-sleep-prevent] [--verbose] [--timeout SECONDS] [--no-timeout] [--greenfield] [--brownfield] [--update] [--check-update] [--push|--no-push] [--create-pr|--no-pr] [--auto-merge|--no-auto-merge] [--rotation|--no-rotation] [--fixes] [--file FILE]
# Agent priority: GitHub Copilot CLI → Claude Code → Gemini → Codex

set -e

# ---- Version ------------------------------------------------------
RALPH_VERSION="1.4.0"

# ---- Configuration ------------------------------------------------

PREVENT_SLEEP=true
export VERBOSE=false
AGENT_TIMEOUT=7200  # Default 2 hour timeout per agent iteration (0 = no timeout)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_TYPE=""  # greenfield, brownfield, or auto-detected
DO_UPDATE=false
CHECK_UPDATE_ONLY=false
MAX_ITERATIONS=10

# Git workflow CLI overrides (empty = use config file)
GIT_PUSH_OVERRIDE=""
GIT_PR_OVERRIDE=""
GIT_AUTO_MERGE_OVERRIDE=""

# Rotation CLI overrides
ROTATION_OVERRIDE=""
# Command mode: build (default), review, status, filebug, change
CURRENT_COMMAND="build"
# Fixes mode: read from fixes.json instead of prd.json
USE_FIXES=false
# Filebug/change: description and optional file reference
FILEBUG_DESCRIPTION=""
FILEBUG_FILE=""
CHANGE_DESCRIPTION=""

# ---- Help --------------------------------------------------------

show_help() {
  cat <<HELPEOF
Ralph - Autonomous AI Agent Loop (v${RALPH_VERSION})

Usage: ./ralph.sh [max_iterations] [options]
       ./ralph.sh <subcommand> [args] [options]

Subcommands:
  status                         Show project status, story progress, rotation state
  review                         Run code review, produce fixes.json
  filebug "description"          File a bug as a fix story in fixes.json
  filebug --file FILE "desc"     File a bug with a specific file reference
  change "description"           Apply a mid-build change to prd.json

Core Options:
  -h, --help                     Show this help message
  -V, --version                  Show Ralph version
  -v, --verbose                  Enable debug logging
  --timeout SECONDS              Set timeout per iteration (default: 7200)
  --no-timeout                   Disable iteration timeout
  --no-sleep-prevent             Disable caffeinate/systemd-inhibit
  --fixes                        Build from fixes.json instead of prd.json
  --greenfield                   Force greenfield project type
  --brownfield                   Force brownfield project type

Git Options:
  --push                         Enable auto-push after each iteration
  --no-push                      Disable auto-push
  --create-pr                    Enable PR creation when all stories complete
  --no-pr                        Disable PR creation
  --auto-merge                   Enable auto-merge of PR into base branch
  --no-auto-merge                Disable auto-merge

Rotation Options:
  --rotation                     Enable model/agent rotation
  --no-rotation                  Disable rotation

Update Options:
  --check-update                 Check if Ralph updates are available
  --update                       Self-update from source repository

Examples:
  ./ralph.sh                     Run with defaults (10 iterations)
  ./ralph.sh 20 --verbose        Run 20 iterations with debug logging
  ./ralph.sh --push --create-pr  Enable push and PR for this run
  ./ralph.sh --fixes             Build from fixes.json
  ./ralph.sh review              Run code review
  ./ralph.sh filebug "Login button broken after auth redirect"
  ./ralph.sh change "Add pagination to user list endpoint"
  ./ralph.sh status              Show current project status
HELPEOF
  exit 0
}

# Check for flags first (before processing positional args)
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -V|--version)
      echo "Ralph v${RALPH_VERSION}"
      exit 0
      ;;
    --no-sleep-prevent)
      PREVENT_SLEEP=false
      shift
      ;;
    --verbose|-v)
      export VERBOSE=true
      shift
      ;;
    --no-timeout)
      AGENT_TIMEOUT=0
      shift
      ;;
    --timeout)
      shift
      AGENT_TIMEOUT="$1"
      shift
      ;;
    --greenfield)
      PROJECT_TYPE="greenfield"
      shift
      ;;
    --brownfield)
      PROJECT_TYPE="brownfield"
      shift
      ;;
    --update)
      DO_UPDATE=true
      shift
      ;;
    --check-update)
      CHECK_UPDATE_ONLY=true
      shift
      ;;
    --push)
      GIT_PUSH_OVERRIDE="true"
      shift
      ;;
    --no-push)
      GIT_PUSH_OVERRIDE="false"
      shift
      ;;
    --create-pr)
      GIT_PR_OVERRIDE="true"
      shift
      ;;
    --no-pr)
      GIT_PR_OVERRIDE="false"
      shift
      ;;
    --auto-merge)
      GIT_AUTO_MERGE_OVERRIDE="true"
      shift
      ;;
    --no-auto-merge)
      GIT_AUTO_MERGE_OVERRIDE="false"
      shift
      ;;
    --rotation)
      ROTATION_OVERRIDE="true"
      shift
      ;;
    --no-rotation)
      ROTATION_OVERRIDE="false"
      shift
      ;;
    --fixes)
      USE_FIXES=true
      shift
      ;;
    --file)
      shift
      FILEBUG_FILE="$1"
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Check for subcommands (status, review, filebug, change) as first positional arg
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
  case "${POSITIONAL_ARGS[0]}" in
    status)
      CURRENT_COMMAND="status"
      ;;
    review)
      CURRENT_COMMAND="review"
      ;;
    filebug)
      CURRENT_COMMAND="filebug"
      # Remaining positional args become the bug description
      FILEBUG_DESCRIPTION="${POSITIONAL_ARGS[*]:1}"
      ;;
    change)
      CURRENT_COMMAND="change"
      # Remaining positional args become the change description
      CHANGE_DESCRIPTION="${POSITIONAL_ARGS[*]:1}"
      ;;
    *)
      MAX_ITERATIONS="${POSITIONAL_ARGS[0]}"
      ;;
  esac
fi

PRD_FILE="$SCRIPT_DIR/prd.json"
FIXES_FILE="$SCRIPT_DIR/fixes.json"
if [ "$USE_FIXES" = true ]; then
  PRD_FILE="$FIXES_FILE"
  PROGRESS_FILE="$SCRIPT_DIR/fixes-progress.txt"
else
  PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
fi
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
AGENT_CONFIG="$SCRIPT_DIR/agent.yaml"
VERSION_FILE="$SCRIPT_DIR/.ralph-version"
export LOG_FILE="$SCRIPT_DIR/ralph.log"
START_TIME=$(date +%s)

# ---- Self-Update Functions ----------------------------------------

get_local_version() {
  if [ -f "$VERSION_FILE" ]; then
    grep '^version=' "$VERSION_FILE" 2>/dev/null | sed 's/version=//' || head -n 1 "$VERSION_FILE"
  else
    # Fall back to embedded version constant
    echo "$RALPH_VERSION"
  fi
}

get_source_repo() {
  # First check the version file for stored source path
  if [ -f "$VERSION_FILE" ]; then
    local source_from_file=$(grep '^source=' "$VERSION_FILE" 2>/dev/null | sed 's/source=//')
    if [ -n "$source_from_file" ] && [ -d "$source_from_file" ]; then
      echo "$source_from_file"
      return
    fi
  fi
  
  # Fallback: check if ralph-setup exists globally and extract source path
  if command -v ralph-setup >/dev/null 2>&1; then
    local setup_path=$(command -v ralph-setup)
    if [ -f "$setup_path" ]; then
      grep 'RALPH_SOURCE=' "$setup_path" 2>/dev/null | sed 's/.*RALPH_SOURCE="//' | sed 's/".*//' || echo ""
    fi
  fi
}

get_source_version() {
  local source_repo="$1"
  if [ -n "$source_repo" ] && [ -f "$source_repo/setup-ralph.sh" ]; then
    grep '^RALPH_VERSION=' "$source_repo/setup-ralph.sh" 2>/dev/null | sed 's/RALPH_VERSION="//' | sed 's/".*//' || echo "unknown"
  else
    echo "unknown"
  fi
}

check_for_updates() {
  local local_ver=$(get_local_version)
  local source_repo=$(get_source_repo)
  local source_ver=$(get_source_version "$source_repo")
  
  echo "Local version:  $local_ver"
  echo "Source version: $source_ver"
  
  if [ "$source_repo" != "" ]; then
    echo "Source repo:    $source_repo"
  else
    echo "Source repo:    Not found (ralph-setup not installed globally)"
  fi
  
  if [ "$local_ver" = "unknown" ] || [ "$source_ver" = "unknown" ]; then
    echo ""
    echo "Unable to compare versions."
    return 1
  fi
  
  if [ "$local_ver" != "$source_ver" ]; then
    echo ""
    echo "Update available! Run: ./ralph.sh --update"
    return 0
  else
    echo ""
    echo "You're up to date."
    return 1
  fi
}

run_self_update() {
  local source_repo=$(get_source_repo)
  
  if [ -z "$source_repo" ]; then
    echo "Error: Cannot find Ralph source repository."
    echo "ralph-setup is not installed globally, or RALPH_SOURCE is not set."
    echo ""
    echo "Options:"
    echo "  1. Install globally: cd /path/to/ralph && ./install.sh"
    echo "  2. Update manually: /path/to/ralph/setup-ralph.sh --update ."
    exit 1
  fi
  
  if [ ! -f "$source_repo/setup-ralph.sh" ]; then
    echo "Error: setup-ralph.sh not found in $source_repo"
    echo "Make sure your Ralph source repository is up to date."
    exit 1
  fi
  
  echo "Updating Ralph from: $source_repo"
  echo ""
  
  # Run the setup script in update mode
  "$source_repo/setup-ralph.sh" --update "$SCRIPT_DIR"
  
  echo ""
  echo "Update complete!"
  exit 0
}

# Handle update commands before main execution
if [ "$CHECK_UPDATE_ONLY" = true ]; then
  check_for_updates
  exit 0
fi

if [ "$DO_UPDATE" = true ]; then
  run_self_update
fi

# ---- Load Common Library ------------------------------------------

if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  source "$SCRIPT_DIR/lib/common.sh"
else
  echo "Warning: lib/common.sh not found, using basic functions"
  # Fallback color definitions
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
fi

# ---- Load Optional Context System Libraries -----------------------

# Load context management library if present
if [ -f "$SCRIPT_DIR/lib/context.sh" ]; then
  source "$SCRIPT_DIR/lib/context.sh"
  CONTEXT_SYSTEM_ENABLED=true
  # Initialize context from PRD if available
  if [ -f "$PRD_FILE" ]; then
    import_prd "$PRD_FILE" 2>/dev/null || true
  fi
else
  CONTEXT_SYSTEM_ENABLED=false
fi

# Load compaction library if present
if [ -f "$SCRIPT_DIR/lib/compaction.sh" ]; then
  source "$SCRIPT_DIR/lib/compaction.sh"
  COMPACTION_ENABLED=true
else
  COMPACTION_ENABLED=false
fi

# Load checkpointing library if present
if [ -f "$SCRIPT_DIR/lib/checkpointing.sh" ]; then
  source "$SCRIPT_DIR/lib/checkpointing.sh"
  CHECKPOINTING_ENABLED=true
else
  CHECKPOINTING_ENABLED=false
fi

# Load REPL library if present
if [ -f "$SCRIPT_DIR/lib/repl.sh" ]; then
  source "$SCRIPT_DIR/lib/repl.sh"
  REPL_LIBRARY_LOADED=true
else
  REPL_LIBRARY_LOADED=false
fi

# Load dynamic context library if present
if [ -f "$SCRIPT_DIR/lib/dynamic-context.sh" ]; then
  source "$SCRIPT_DIR/lib/dynamic-context.sh"
  DYNAMIC_CONTEXT_ENABLED=true
else
  DYNAMIC_CONTEXT_ENABLED=false
fi

# Load git workflow library if present
if [ -f "$SCRIPT_DIR/lib/git.sh" ]; then
  source "$SCRIPT_DIR/lib/git.sh"
  GIT_LIBRARY_LOADED=true
else
  GIT_LIBRARY_LOADED=false
fi

# Load rotation library if present
if [ -f "$SCRIPT_DIR/lib/rotation.sh" ]; then
  source "$SCRIPT_DIR/lib/rotation.sh"
  ROTATION_LIBRARY_LOADED=true
else
  ROTATION_LIBRARY_LOADED=false
fi

# ---- Helper Functions ---------------------------------------------

require_bin jq
require_bin yq

# Check if push is enabled (respects CLI override)
# Usage: should_push && push_branch ...
should_push() {
  # CLI override takes precedence
  if [ "$GIT_PUSH_OVERRIDE" = "true" ]; then
    return 0
  elif [ "$GIT_PUSH_OVERRIDE" = "false" ]; then
    return 1
  fi

  # Fall back to config file
  if [ "$GIT_LIBRARY_LOADED" = true ] && type get_git_push_enabled >/dev/null 2>&1; then
    get_git_push_enabled
  else
    return 1
  fi
}

# Check if PR creation is enabled (respects CLI override)
# Usage: should_create_pr && create_pr ...
should_create_pr() {
  # CLI override takes precedence
  if [ "$GIT_PR_OVERRIDE" = "true" ]; then
    return 0
  elif [ "$GIT_PR_OVERRIDE" = "false" ]; then
    return 1
  fi

  # Fall back to config file
  if [ "$GIT_LIBRARY_LOADED" = true ] && type get_git_pr_enabled >/dev/null 2>&1; then
    get_git_pr_enabled
  else
    return 1
  fi
}

# Check if PR auto-merge is enabled (respects CLI override)
# Usage: should_auto_merge_pr && merge_pr ...
should_auto_merge_pr() {
  # CLI override takes precedence
  if [ "$GIT_AUTO_MERGE_OVERRIDE" = "true" ]; then
    return 0
  elif [ "$GIT_AUTO_MERGE_OVERRIDE" = "false" ]; then
    return 1
  fi

  # Fall back to config file
  if [ "$GIT_LIBRARY_LOADED" = true ] && type get_git_pr_auto_merge >/dev/null 2>&1; then
    get_git_pr_auto_merge
  else
    return 1
  fi
}

# Check if rotation is enabled (respects CLI override)
should_use_rotation() {
  if [ "$ROTATION_OVERRIDE" = "true" ]; then
    return 0
  elif [ "$ROTATION_OVERRIDE" = "false" ]; then
    return 1
  fi
  # Fall back to config file
  if [ "$ROTATION_LIBRARY_LOADED" = true ] && type is_rotation_enabled >/dev/null 2>&1; then
    is_rotation_enabled
  else
    return 1
  fi
}

# Use format_duration from common.sh, or define fallback if not loaded
if ! type format_duration >/dev/null 2>&1; then
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
fi

get_elapsed_time() {
  local now=$(date +%s)
  local elapsed=$((now - START_TIME))
  format_duration $elapsed
}

get_current_story() {
  if [ -f "$PRD_FILE" ]; then
    # Use context system if available
    if [ "$CONTEXT_SYSTEM_ENABLED" = true ]; then
      local ready_tasks=$(get_ready_tasks 2>/dev/null || echo "[]")
      if [ "$ready_tasks" != "[]" ] && [ -n "$ready_tasks" ]; then
        local first_task=$(echo "$ready_tasks" | jq -r '.[0] | "\(.id): \(.title)"' 2>/dev/null)
        if [ -n "$first_task" ] && [ "$first_task" != "null: null" ]; then
          echo "$first_task"
          return
        fi
      fi
    fi
    
    # Fallback to traditional PRD-based selection
    # Get all incomplete stories
    local incomplete_stories=$(jq -r '.userStories[] | select(.passes == false) | @json' "$PRD_FILE" 2>/dev/null)
    
    if [ -z "$incomplete_stories" ]; then
      echo "All stories complete"
      return
    fi
    
    # Find first ready story (incomplete with all dependencies met)
    local ready_story=""
    while IFS= read -r story_json; do
      local story_id=$(echo "$story_json" | jq -r '.id')
      local blockedBy=$(echo "$story_json" | jq -r '.blockedBy[]?' 2>/dev/null)
      
      # Check if all dependencies are complete
      local is_ready=true
      if [ -n "$blockedBy" ]; then
        while IFS= read -r dep_id; do
          if [ -n "$dep_id" ]; then
            local dep_passes=$(jq -r ".userStories[] | select(.id == \"$dep_id\") | .passes" "$PRD_FILE" 2>/dev/null)
            if [ "$dep_passes" != "true" ]; then
              is_ready=false
              break
            fi
          fi
        done <<< "$blockedBy"
      fi
      
      if [ "$is_ready" = true ]; then
        ready_story=$(echo "$story_json" | jq -r '"\(.id): \(.title)"')
        break
      fi
    done <<< "$incomplete_stories"
    
    if [ -n "$ready_story" ]; then
      echo "$ready_story"
    else
      # No ready stories but incomplete stories exist - all are blocked
      echo -e "${YELLOW}Warning: All incomplete stories are blocked by dependencies${NC}" >&2
      echo "All stories blocked"
    fi
  else
    echo "No PRD found"
  fi
}

get_story_progress() {
  if [ -f "$PRD_FILE" ]; then
    local total=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null)
    local complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null)
    echo "$complete/$total"
  else
    echo "?/?"
  fi
}

check_rate_limit() {
  local output="$1"
  if echo "$output" | grep -qi "hit your limit\|rate limit\|quota exceeded\|too many requests\|resets [0-9]"; then
    return 0
  fi
  return 1
}

rotate_log_if_needed() {
  local max_mb="${RALPH_LOG_MAX_SIZE_MB:-10}"
  local retention_days="${RALPH_LOG_RETENTION_DAYS:-14}"
  local log_file="$LOG_FILE"
  local logs_dir="$SCRIPT_DIR/logs"

  [ -f "$log_file" ] || return 0
  [ "$max_mb" -gt 0 ] 2>/dev/null || return 0

  local size_bytes
  size_bytes=$(wc -c < "$log_file" 2>/dev/null || echo "0")
  local max_bytes=$((max_mb * 1024 * 1024))

  if [ "$size_bytes" -ge "$max_bytes" ]; then
    mkdir -p "$logs_dir"
    local ts
    ts=$(date '+%Y%m%d-%H%M%S')
    mv "$log_file" "$logs_dir/ralph_${ts}.log" 2>/dev/null || true
    touch "$log_file" 2>/dev/null || true
  fi

  if [ -d "$logs_dir" ]; then
    find "$logs_dir" -name "*.log" -type f -mtime "+$retention_days" -delete 2>/dev/null || true
  fi
}

cleanup_old_logs() {
  local days="${1:-14}"
  local logs_dir="$SCRIPT_DIR/logs"
  [ -d "$logs_dir" ] || return 0
  find "$logs_dir" -name "*.log" -type f -mtime "+$days" -delete 2>/dev/null || true
}

check_error() {
  local output="$1"
  if echo "$output" | grep -qi '"is_error":true\|error_during_execution'; then
    return 0
  fi
  return 1
}

print_status() {
  local iteration=$1
  local max=$2
  local story=$(get_current_story)
  local progress=$(get_story_progress)
  local elapsed=$(get_elapsed_time)
  
  if [ ${#story} -gt 45 ]; then
    story="${story:0:42}..."
  fi
  
  echo ""
  echo -e "${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC}  ${BLUE}Ralph Iteration${NC} ${YELLOW}$iteration${NC} of ${YELLOW}$max${NC}"
  echo -e "${CYAN}├─────────────────────────────────────────────────────────┤${NC}"
  echo -e "${CYAN}│${NC}  📊 Stories: ${GREEN}$progress${NC} complete"
  echo -e "${CYAN}│${NC}  🎯 Current: ${YELLOW}$story${NC}"
  if [ -n "$ACTIVE_AGENT" ]; then
    local agent_display="$ACTIVE_AGENT"
    [ -n "$RALPH_OVERRIDE_MODEL" ] && agent_display="$agent_display ($RALPH_OVERRIDE_MODEL)"
    echo -e "${CYAN}│${NC}  🤖 Agent: ${CYAN}$agent_display${NC}"
  fi
  echo -e "${CYAN}│${NC}  ⏱️  Elapsed: ${BLUE}$elapsed${NC}"
  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""
}

print_iteration_summary() {
  local iteration=$1
  local duration=$2
  local status=$3
  local elapsed=$(get_elapsed_time)
  local progress=$(get_story_progress)
  local duration_str=$(format_duration $duration)
  
  if [ "$status" == "success" ]; then
    echo -e "${GREEN}✓ Iteration $iteration complete${NC} ($duration_str) | Stories: $progress | Total: $elapsed"
  elif [ "$status" == "rate_limited" ]; then
    echo -e "${RED}⚠ Rate limited${NC} - stopping Ralph"
  elif [ "$status" == "error" ]; then
    echo -e "${YELLOW}⚠ Iteration $iteration had errors${NC} ($duration_str) | Stories: $progress"
  else
    echo -e "${BLUE}→ Iteration $iteration finished${NC} ($duration_str)"
  fi
}

rotate_log_if_needed

cleanup() {
  if [ -n "$CAFFEINATE_PID" ]; then
    kill $CAFFEINATE_PID 2>/dev/null || true
  fi
  echo ""
  echo -e "${YELLOW}Ralph stopped.${NC}"
  local elapsed=$(get_elapsed_time)
  local progress=$(get_story_progress)
  echo -e "Total time: ${BLUE}$elapsed${NC} | Stories completed: ${GREEN}$progress${NC}"
}

trap cleanup EXIT

# ---- Sleep Prevention ---------------------------------------------

start_sleep_prevention() {
  if [ "$PREVENT_SLEEP" = true ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      caffeinate -i -w $$ &
      CAFFEINATE_PID=$!
      echo -e "${GREEN}☕ Sleep prevention enabled (caffeinate)${NC}"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
      echo -e "${YELLOW}⚠ Windows detected - disable sleep manually or run:${NC}"
      echo "  powercfg -change -standby-timeout-ac 0"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      if command -v systemd-inhibit &>/dev/null; then
        systemd-inhibit --what=idle --who=ralph --why="Running Ralph iterations" --mode=block sleep infinity &
        CAFFEINATE_PID=$!
        echo -e "${GREEN}☕ Sleep prevention enabled (systemd-inhibit)${NC}"
      else
        echo -e "${YELLOW}⚠ No sleep prevention tool found.${NC}"
      fi
    fi
  fi
}

# ---- Project Type Detection ---------------------------------------

detect_project_type() {
  local indicators=0

  # Check for package managers / project files
  if [ -f "package.json" ] || [ -f "requirements.txt" ] || [ -f "Cargo.toml" ] || \
     [ -f "go.mod" ] || [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "Gemfile" ]; then
    indicators=$((indicators + 2))
  fi

  # Check for source directories
  if [ -d "src" ] || [ -d "lib" ] || [ -d "app" ] || [ -d "pkg" ]; then
    indicators=$((indicators + 2))
  fi

  # Check git history
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    if [ "$commit_count" -gt 10 ]; then
      indicators=$((indicators + 2))
    elif [ "$commit_count" -gt 3 ]; then
      indicators=$((indicators + 1))
    fi
  fi

  # Check for existing tests
  if [ -d "tests" ] || [ -d "test" ] || [ -d "__tests__" ] || [ -d "spec" ]; then
    indicators=$((indicators + 1))
  fi

  # Check for config files indicating established project
  if [ -f ".eslintrc.js" ] || [ -f "tsconfig.json" ] || [ -f "jest.config.js" ] || \
     [ -f ".prettierrc" ] || [ -f "webpack.config.js" ] || [ -f "vite.config.ts" ]; then
    indicators=$((indicators + 1))
  fi

  # Threshold: 3+ indicators = brownfield
  if [ $indicators -ge 3 ]; then
    echo "brownfield"
  else
    echo "greenfield"
  fi
}

# Auto-detect project type if not specified
if [ -z "$PROJECT_TYPE" ]; then
  PROJECT_TYPE=$(detect_project_type)
  echo -e "${CYAN}Auto-detected project type: ${YELLOW}$PROJECT_TYPE${NC}"
else
  echo -e "${GREEN}Project type: ${YELLOW}$PROJECT_TYPE${NC}"
fi

# ---- Auto-detect Agent (if not configured) ------------------------
# Priority: GitHub Copilot CLI → Claude Code → Gemini → Codex

auto_detect_agent() {
  # Priority 1: GitHub Copilot CLI
  if command -v copilot &>/dev/null; then
    echo "github-copilot"
    return 0
  fi
  
  # Priority 2: Claude Code
  if command -v claude &>/dev/null; then
    echo "claude-code"
    return 0
  fi
  if [ -x "$HOME/.local/bin/claude" ]; then
    echo "claude-code"
    return 0
  fi
  
  # Priority 3: Gemini
  if command -v gemini &>/dev/null; then
    echo "gemini"
    return 0
  fi
  
  # Priority 4: Codex
  if command -v codex &>/dev/null; then
    echo "codex"
    return 0
  fi
  
  # No agent found
  echo ""
  return 1
}

check_agent_available() {
  local agent="$1"
  case "$agent" in
    github-copilot)
      command -v copilot &>/dev/null
      ;;
    claude-code)
      command -v claude &>/dev/null || [ -x "$HOME/.local/bin/claude" ]
      ;;
    gemini)
      command -v gemini &>/dev/null
      ;;
    codex)
      command -v codex &>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

# ---- Agent Configuration ------------------------------------------

get_agent() {
  local configured_agent=$(yq '.agent.primary' "$AGENT_CONFIG" 2>/dev/null)
  
  # If agent is configured and available, use it
  if [ -n "$configured_agent" ] && [ "$configured_agent" != "null" ] && [ "$configured_agent" != "auto" ]; then
    if check_agent_available "$configured_agent"; then
      echo "$configured_agent"
      return 0
    else
      echo -e "${YELLOW}Warning: Configured agent '$configured_agent' not available, auto-detecting...${NC}" >&2
    fi
  fi
  
  # Auto-detect agent based on priority
  local detected=$(auto_detect_agent)
  if [ -n "$detected" ]; then
    echo "$detected"
    return 0
  fi
  
  # No agent found
  echo -e "${RED}Error: No AI agent found.${NC}" >&2
  echo "Please install one of the following:" >&2
  echo "  - GitHub Copilot CLI: https://github.com/github/gh-copilot" >&2
  echo "  - Claude Code: https://docs.anthropic.com/claude/docs/cli" >&2
  echo "  - Gemini CLI: npm install -g @google/gemini-cli" >&2
  echo "  - Codex: npm install -g @openai/codex" >&2
  return 1
}

get_fallback_agent() { yq '.agent.fallback // ""' "$AGENT_CONFIG"; }
get_claude_model() { yq '.claude-code.model // "claude-sonnet-4-5-20250929"' "$AGENT_CONFIG"; }
get_codex_model() { yq '.codex.model // "gpt-4o"' "$AGENT_CONFIG"; }
get_codex_approval_mode() { yq '.codex.approval-mode // "full-auto"' "$AGENT_CONFIG"; }
get_codex_sandbox() { yq '.codex.sandbox // "full-access"' "$AGENT_CONFIG"; }
get_copilot_tool_approval() { yq '.github-copilot.tool-approval // "allow-all"' "$AGENT_CONFIG"; }
get_copilot_deny_tools() { yq '.github-copilot.deny-tools[]? // ""' "$AGENT_CONFIG"; }
get_copilot_model() { yq '.github-copilot.model // "auto"' "$AGENT_CONFIG"; }
get_gemini_model() { yq '.gemini.model // "gemini-2.5-pro"' "$AGENT_CONFIG"; }

CLAUDE_CMD=""
if command -v claude &>/dev/null; then
  CLAUDE_CMD="claude"
elif [ -x "$HOME/.local/bin/claude" ]; then
  CLAUDE_CMD="$HOME/.local/bin/claude"
fi

run_agent() {
  local AGENT="$1"
  local TIMEOUT_DISPLAY="no timeout"
  [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null && TIMEOUT_DISPLAY="${AGENT_TIMEOUT}s"

  log_info "Starting agent: $AGENT (timeout: $TIMEOUT_DISPLAY)" 2>/dev/null || true

  # Determine if dangerous permissions are allowed for this command
  local USE_DANGEROUS_PERMS=true
  if [ "$ROTATION_LIBRARY_LOADED" = true ] && type get_command_dangerous_permissions >/dev/null 2>&1; then
    if ! get_command_dangerous_permissions "$CURRENT_COMMAND"; then
      USE_DANGEROUS_PERMS=false
    fi
  fi

  case "$AGENT" in
    claude-code)
      local MODEL=$(get_claude_model)
      # Override model if RALPH_OVERRIDE_MODEL is set
      [ -n "$RALPH_OVERRIDE_MODEL" ] && MODEL="$RALPH_OVERRIDE_MODEL"
      echo -e "→ Running ${CYAN}Claude Code${NC} (model: $MODEL, timeout: $TIMEOUT_DISPLAY)"
      [ -z "$CLAUDE_CMD" ] && { echo -e "${RED}Error: Claude CLI not found${NC}"; return 1; }

      # Build Claude flags
      local CLAUDE_FLAGS=("--print" "--model" "$MODEL")
      if [ "$USE_DANGEROUS_PERMS" = true ]; then
        CLAUDE_FLAGS+=("--dangerously-skip-permissions")
      fi

      # Select system instructions based on command mode
      local SYS_INSTRUCTIONS="$SCRIPT_DIR/system_instructions/system_instructions.md"
      local BACKLOG_NAME=$(basename "$PRD_FILE")
      local FIXES_NOTE=""
      if [ "$USE_FIXES" = true ]; then
        FIXES_NOTE=" IMPORTANT: You are in fixes mode. Use fixes.json instead of prd.json for all reads and writes."
      fi
      local CLAUDE_PROMPT="Read ${BACKLOG_NAME} and implement the next incomplete story. Follow the system instructions exactly.${FIXES_NOTE}"
      if [ "$CURRENT_COMMAND" = "review" ] && [ -f "$SCRIPT_DIR/system_instructions/system_instructions_review.md" ]; then
        SYS_INSTRUCTIONS="$SCRIPT_DIR/system_instructions/system_instructions_review.md"
        CLAUDE_PROMPT="Review the codebase and produce fix stories. Follow the review system instructions exactly."
      elif [ "$CURRENT_COMMAND" = "filebug" ] && [ -f "$SCRIPT_DIR/system_instructions/system_instructions_filebug.md" ]; then
        SYS_INSTRUCTIONS="$SCRIPT_DIR/system_instructions/system_instructions_filebug.md"
        CLAUDE_PROMPT="Analyze this bug report and produce a fix story. Bug: ${FILEBUG_DESCRIPTION}. ${FILEBUG_FILE:+Related file: $FILEBUG_FILE. }Follow the filebug system instructions exactly."
      elif [ "$CURRENT_COMMAND" = "change" ] && [ -f "$SCRIPT_DIR/system_instructions/system_instructions_change.md" ]; then
        SYS_INSTRUCTIONS="$SCRIPT_DIR/system_instructions/system_instructions_change.md"
        CLAUDE_PROMPT="Apply this change request to ${BACKLOG_NAME}: ${CHANGE_DESCRIPTION}. Follow the change system instructions exactly.${FIXES_NOTE}"
      fi
      CLAUDE_FLAGS+=("--system-prompt" "$SYS_INSTRUCTIONS")

      # Use script command to create PTY (prevents output buffering when piped)
      # macOS: script -q /dev/null command...
      # Linux: script -q -c "command..." /dev/null
      local RUN_CMD
      if [[ "$OSTYPE" == "darwin"* ]]; then
        RUN_CMD=(script -q /dev/null "$CLAUDE_CMD" "${CLAUDE_FLAGS[@]}" "$CLAUDE_PROMPT")
      else
        # Linux script syntax
        RUN_CMD=(script -q -c "$CLAUDE_CMD ${CLAUDE_FLAGS[*]} '$CLAUDE_PROMPT'" /dev/null)
      fi

      # Run with timeout if run_with_timeout function exists and timeout > 0
      if type run_with_timeout >/dev/null 2>&1 && [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
        run_with_timeout "$AGENT_TIMEOUT" "${RUN_CMD[@]}"
      else
        "${RUN_CMD[@]}"
      fi
      ;;
    codex)
      local MODEL=$(get_codex_model)
      [ -n "$RALPH_OVERRIDE_MODEL" ] && MODEL="$RALPH_OVERRIDE_MODEL"
      local APPROVAL=$(get_codex_approval_mode)
      local SANDBOX=$(get_codex_sandbox)
      echo -e "→ Running ${CYAN}Codex${NC} (model: $MODEL, approval: $APPROVAL, sandbox: $SANDBOX, timeout: $TIMEOUT_DISPLAY)"
      
      local CODEX_FLAGS=""
      # Handle approval mode and sandbox
      # Note: --full-auto forces workspace-write sandbox, so for full-access we need danger mode
      if [ "$APPROVAL" = "danger" ] || [ "$SANDBOX" = "full-access" ]; then
        # Full access requires bypassing the sandbox entirely
        CODEX_FLAGS="--dangerously-bypass-approvals-and-sandbox"
      elif [ "$APPROVAL" = "full-auto" ]; then
        # Full-auto with workspace-write sandbox (default)
        CODEX_FLAGS="--full-auto"
      else
        # Just set the sandbox mode explicitly
        case "$SANDBOX" in
          workspace-write) CODEX_FLAGS="--sandbox workspace-write" ;;
          read-only) CODEX_FLAGS="--sandbox read-only" ;;
        esac
      fi

      # Construct the prompt for Codex based on command mode
      local BACKLOG_NAME=$(basename "$PRD_FILE")
      local FIXES_NOTE=""
      if [ "$USE_FIXES" = true ]; then
        FIXES_NOTE=" IMPORTANT: You are in fixes mode. Use fixes.json instead of prd.json for all reads and writes."
      fi
      local CODEX_PROMPT="Read ${BACKLOG_NAME} and implement the next incomplete story. Follow system_instructions/system_instructions_codex.md. When all stories complete, output: RALPH_COMPLETE${FIXES_NOTE}"
      if [ "$CURRENT_COMMAND" = "filebug" ]; then
        CODEX_PROMPT="Analyze this bug report and produce a fix story. Bug: ${FILEBUG_DESCRIPTION}. ${FILEBUG_FILE:+Related file: $FILEBUG_FILE. }Follow system_instructions/system_instructions_filebug.md exactly."
      elif [ "$CURRENT_COMMAND" = "change" ]; then
        CODEX_PROMPT="Apply this change request to ${BACKLOG_NAME}: ${CHANGE_DESCRIPTION}. Follow system_instructions/system_instructions_change.md exactly.${FIXES_NOTE}"
      elif [ "$CURRENT_COMMAND" = "review" ]; then
        CODEX_PROMPT="Review the codebase and produce fix stories. Follow system_instructions/system_instructions_review.md exactly."
      fi

      # Run with timeout if run_with_timeout function exists and timeout > 0
      if type run_with_timeout >/dev/null 2>&1 && [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
        run_with_timeout "$AGENT_TIMEOUT" codex exec $CODEX_FLAGS -m "$MODEL" --skip-git-repo-check \
          "$CODEX_PROMPT"
      else
        codex exec $CODEX_FLAGS -m "$MODEL" --skip-git-repo-check \
          "$CODEX_PROMPT"
      fi
      ;;
    github-copilot)
      local TOOL_APPROVAL=$(get_copilot_tool_approval)
      local COPILOT_MODEL=$(get_copilot_model)
      [ -n "$RALPH_OVERRIDE_MODEL" ] && COPILOT_MODEL="$RALPH_OVERRIDE_MODEL"
      local MODEL_DISPLAY="auto"
      [ "$COPILOT_MODEL" != "auto" ] && MODEL_DISPLAY="$COPILOT_MODEL"
      echo -e "→ Running ${CYAN}GitHub Copilot${NC} (model: $MODEL_DISPLAY, tool-approval: $TOOL_APPROVAL, timeout: $TIMEOUT_DISPLAY)"
      command -v copilot >/dev/null 2>&1 || { echo -e "${RED}Error: Copilot CLI not found${NC}"; return 1; }

      # Build flags as an array for proper quoting
      local COPILOT_FLAGS=()
      
      # Add model flag if not auto
      if [ -n "$COPILOT_MODEL" ] && [ "$COPILOT_MODEL" != "auto" ] && [ "$COPILOT_MODEL" != "null" ]; then
        COPILOT_FLAGS+=("--model" "$COPILOT_MODEL")
      fi
      
      # Add tool approval flags (respect per-command permissions)
      if [ "$TOOL_APPROVAL" = "allow-all" ] && [ "$USE_DANGEROUS_PERMS" = true ]; then
        COPILOT_FLAGS+=("--allow-all-tools")
        # Add deny-tools if specified
        local DENY_TOOLS="$(get_copilot_deny_tools)"
        if [ -n "$DENY_TOOLS" ]; then
          while IFS= read -r tool; do
            [ -n "$tool" ] && COPILOT_FLAGS+=("--deny-tool" "$tool")
          done <<< "$DENY_TOOLS"
        fi
      fi

      # Construct the prompt based on command mode
      local BACKLOG_NAME=$(basename "$PRD_FILE")
      local FIXES_NOTE=""
      if [ "$USE_FIXES" = true ]; then
        FIXES_NOTE=" IMPORTANT: You are in fixes mode. Use fixes.json instead of prd.json for all reads and writes."
      fi
      local PROMPT="Read ${BACKLOG_NAME} and implement the next incomplete story. Follow the instructions in system_instructions/system_instructions_copilot.md exactly. When all stories are complete, output: RALPH_COMPLETE${FIXES_NOTE}"
      if [ "$CURRENT_COMMAND" = "filebug" ]; then
        PROMPT="Analyze this bug report and produce a fix story. Bug: ${FILEBUG_DESCRIPTION}. ${FILEBUG_FILE:+Related file: $FILEBUG_FILE. }Follow the instructions in system_instructions/system_instructions_filebug.md exactly."
      elif [ "$CURRENT_COMMAND" = "change" ]; then
        PROMPT="Apply this change request to ${BACKLOG_NAME}: ${CHANGE_DESCRIPTION}. Follow the instructions in system_instructions/system_instructions_change.md exactly.${FIXES_NOTE}"
      elif [ "$CURRENT_COMMAND" = "review" ]; then
        PROMPT="Review the codebase and produce fix stories. Follow the instructions in system_instructions/system_instructions_review.md exactly."
      fi

      # Run with timeout if run_with_timeout function exists and timeout > 0
      if type run_with_timeout >/dev/null 2>&1 && [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
        run_with_timeout "$AGENT_TIMEOUT" copilot -p "$PROMPT" "${COPILOT_FLAGS[@]}"
      else
        copilot -p "$PROMPT" "${COPILOT_FLAGS[@]}"
      fi
      ;;
    gemini)
      local MODEL=$(get_gemini_model)
      [ -n "$RALPH_OVERRIDE_MODEL" ] && MODEL="$RALPH_OVERRIDE_MODEL"
      echo -e "→ Running ${CYAN}Gemini${NC} (model: $MODEL, timeout: $TIMEOUT_DISPLAY)"
      command -v gemini >/dev/null 2>&1 || { echo -e "${RED}Error: Gemini CLI not found${NC}"; echo -e "${YELLOW}Install: npm install -g @anthropic/gemini-cli or pip install google-generativeai${NC}"; return 1; }

      # Construct the prompt for Gemini based on command mode
      local BACKLOG_NAME=$(basename "$PRD_FILE")
      local FIXES_NOTE=""
      if [ "$USE_FIXES" = true ]; then
        FIXES_NOTE=" IMPORTANT: You are in fixes mode. Use fixes.json instead of prd.json for all reads and writes."
      fi
      local PROMPT="Read ${BACKLOG_NAME} and implement the next incomplete story. Follow the instructions in system_instructions/system_instructions.md exactly. When all stories are complete, output: RALPH_COMPLETE${FIXES_NOTE}"
      if [ "$CURRENT_COMMAND" = "filebug" ]; then
        PROMPT="Analyze this bug report and produce a fix story. Bug: ${FILEBUG_DESCRIPTION}. ${FILEBUG_FILE:+Related file: $FILEBUG_FILE. }Follow the instructions in system_instructions/system_instructions_filebug.md exactly."
      elif [ "$CURRENT_COMMAND" = "change" ]; then
        PROMPT="Apply this change request to ${BACKLOG_NAME}: ${CHANGE_DESCRIPTION}. Follow the instructions in system_instructions/system_instructions_change.md exactly.${FIXES_NOTE}"
      elif [ "$CURRENT_COMMAND" = "review" ]; then
        PROMPT="Review the codebase and produce fix stories. Follow the instructions in system_instructions/system_instructions_review.md exactly."
      fi

      # Run with timeout if run_with_timeout function exists and timeout > 0
      if type run_with_timeout >/dev/null 2>&1 && [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
        run_with_timeout "$AGENT_TIMEOUT" gemini --model "$MODEL" --yolo "$PROMPT"
      else
        gemini --model "$MODEL" --yolo "$PROMPT"
      fi
      ;;
    *) echo -e "${RED}Unknown agent: $AGENT${NC}"; exit 1 ;;
  esac

  local exit_code=$?
  if [ $exit_code -eq 124 ]; then
    log_error "Agent timed out after ${AGENT_TIMEOUT}s" 2>/dev/null || true
    echo -e "${RED}Error: Agent execution timed out after ${AGENT_TIMEOUT}s${NC}"
    echo -e "${YELLOW}Try increasing timeout with: --timeout <seconds> or --no-timeout${NC}"
  fi

  return $exit_code
}

# ---- REPL-Aware Agent Runner --------------------------------------

# Run agent with REPL support for complex tasks
# Usage: run_agent_with_repl <agent> <task_id> <task_description> <ac_count>
run_agent_with_repl() {
  local agent="$1"
  local task_id="$2"
  local task_description="$3"
  local ac_count="${4:-0}"

  # Check if REPL should be enabled for this task
  if [ "$REPL_LIBRARY_LOADED" = true ] && type should_enable_repl >/dev/null 2>&1; then
    if should_enable_repl "$task_description" "$ac_count"; then
      local reason=$(get_complexity_reason "$task_description" "$ac_count")
      echo -e "${CYAN}REPL mode enabled:${NC} $reason"

      # Initialize REPL state
      init_repl_cycle "$task_id" > /dev/null

      # Create initial checkpoint if available
      if [ "$CHECKPOINTING_ENABLED" = true ]; then
        create_named_checkpoint "repl_start" "$task_id" "in_progress" "Starting REPL cycle" > /dev/null 2>&1 || true
      fi

      # Run agent (REPL logic is handled in system instructions)
      run_agent "$agent"
      local result=$?

      # Clean up REPL state on completion
      cleanup_repl "$task_id" 2>/dev/null || true

      return $result
    fi
  fi

  # Standard agent run (no REPL)
  run_agent "$agent"
}

# Get current task details for REPL integration
# Usage: get_current_task_details
# Returns: task_id|description|ac_count (pipe-separated)
get_current_task_details() {
  if [ ! -f "$PRD_FILE" ]; then
    echo "||0"
    return
  fi

  # Get the highest priority incomplete story that's not blocked
  local task_json=$(jq -r '
    [.userStories[] | select(.passes == false)] |
    sort_by(.priority) |
    .[0] // empty
  ' "$PRD_FILE" 2>/dev/null)

  if [ -z "$task_json" ] || [ "$task_json" = "null" ]; then
    echo "||0"
    return
  fi

  local task_id=$(echo "$task_json" | jq -r '.id // ""')
  local description=$(echo "$task_json" | jq -r '.description // ""')
  local ac_count=$(echo "$task_json" | jq -r '.acceptanceCriteria | length // 0')

  echo "${task_id}|${description}|${ac_count}"
}

# ---- Archive previous run -----------------------------------------

if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||' | sed 's|/|-|g')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$(date +%Y-%m-%d)-$FOLDER_NAME"
    echo -e "${YELLOW}Archiving previous run:${NC} $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
    # Reset rotation state for new PRD - start fresh with primary agent
    if [ -f "$SCRIPT_DIR/.ralph/rotation-state.json" ]; then
      echo -e "${CYAN}Resetting rotation state for new PRD${NC}"
      rm -f "$SCRIPT_DIR/.ralph/rotation-state.json"
    fi
  fi
fi

[ -f "$PRD_FILE" ] && echo "$(jq -r '.branchName // empty' "$PRD_FILE")" > "$LAST_BRANCH_FILE"

[ ! -f "$PROGRESS_FILE" ] && { echo "# Ralph Progress Log" > "$PROGRESS_FILE"; echo "Started: $(date)" >> "$PROGRESS_FILE"; echo "---" >> "$PROGRESS_FILE"; }

# ---- Validation ---------------------------------------------------

echo ""
echo -e "${CYAN}Running pre-flight checks...${NC}"
echo ""

# Validate agent configuration
if type validate_agent_yaml >/dev/null 2>&1; then
  if ! validate_agent_yaml "$AGENT_CONFIG"; then
    echo -e "${RED}Agent configuration validation failed. Exiting.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Warning: Agent validation not available (lib/common.sh not loaded)${NC}"
fi

# Validate PRD if it exists
if [ -f "$PRD_FILE" ]; then
  if type validate_prd_json >/dev/null 2>&1; then
    if ! validate_prd_json "$PRD_FILE"; then
      echo -e "${RED}PRD validation failed. Exiting.${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}Warning: PRD validation not available (lib/common.sh not loaded)${NC}"
  fi
else
  echo -e "${YELLOW}Warning: prd.json not found at $PRD_FILE${NC}"
  echo -e "${YELLOW}Ralph may not be able to proceed without a valid PRD${NC}"
fi

# Validate git status
if type validate_git_status >/dev/null 2>&1; then
  if ! validate_git_status true; then
    echo -e "${RED}Git status check failed or was cancelled. Exiting.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Warning: Git validation not available (lib/common.sh not loaded)${NC}"
fi

echo -e "${GREEN}✓ Pre-flight checks complete${NC}"
echo ""

# ---- Git Branch Setup ---------------------------------------------

BRANCH_NAME=""
if [ -f "$PRD_FILE" ]; then
  BRANCH_NAME=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null)
fi

# Ensure feature branch exists and checkout if git library is loaded
if [ "$GIT_LIBRARY_LOADED" = true ] && [ -n "$BRANCH_NAME" ]; then
  if get_git_auto_checkout_branch 2>/dev/null; then
    echo -e "${CYAN}Setting up git branch workflow...${NC}"

    # Validate remote if push is enabled
    if should_push; then
      validate_git_remote || true
    fi

    # Ensure we're on the feature branch (CRITICAL - must succeed)
    if ! ensure_feature_branch "$BRANCH_NAME"; then
      echo -e "${RED}✗ Failed to switch to feature branch: ${BRANCH_NAME}${NC}"
      echo -e "${YELLOW}This is required for proper git workflow. Please resolve manually:${NC}"
      echo -e "${YELLOW}  1. Commit or stash your changes: git stash${NC}"
      echo -e "${YELLOW}  2. Switch to feature branch: git checkout ${BRANCH_NAME}${NC}"
      echo -e "${YELLOW}  3. Re-run Ralph${NC}"
      cleanup
      exit 1
    else
      echo -e "${GREEN}✓ On branch: ${BRANCH_NAME}${NC}"
    fi
    echo ""
  fi
fi

# ---- Handle Subcommands (status, review) --------------------------

if [ "$CURRENT_COMMAND" = "status" ]; then
  # Status subcommand: display project info, story progress, rotation state
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  Ralph Status${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [ -f "$PRD_FILE" ]; then
    local_project=$(jq -r '.project // "Unknown"' "$PRD_FILE" 2>/dev/null)
    local_branch=$(jq -r '.branchName // "N/A"' "$PRD_FILE" 2>/dev/null)
    echo -e "Project: ${YELLOW}$local_project${NC}"
    echo -e "Branch: ${CYAN}$local_branch${NC}"
  else
    echo -e "${YELLOW}No prd.json found${NC}"
  fi

  # Show current agent/model
  if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
    local_selection=$(select_agent_and_model "" "$CURRENT_COMMAND" 2>/dev/null)
    local_agent=$(echo "$local_selection" | cut -d'|' -f1)
    local_model=$(echo "$local_selection" | cut -d'|' -f2)
    echo -e "Agent: ${CYAN}$local_agent${NC} (model: ${CYAN}${local_model:-default}${NC})"
  else
    local_agent=$(get_agent 2>/dev/null || echo "unknown")
    echo -e "Agent: ${CYAN}$local_agent${NC}"
  fi

  echo ""

  # Story progress
  if [ -f "$PRD_FILE" ]; then
    local_total=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null || echo "0")
    local_complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "0")
    local_pct=0
    [ "$local_total" -gt 0 ] && local_pct=$(( (local_complete * 100) / local_total ))
    echo -e "Stories: ${GREEN}$local_complete${NC}/${YELLOW}$local_total${NC} complete (${local_pct}%)"

    # List each story with status
    jq -r '.userStories[] | "\(.passes)|\(.id)|\(.title)|\(.blockedBy // [] | join(","))"' "$PRD_FILE" 2>/dev/null | while IFS='|' read -r passes sid stitle blocked; do
      if [ "$passes" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} $sid: $stitle"
      elif [ -n "$blocked" ]; then
        echo -e "  ${RED}○${NC} $sid: $stitle ${YELLOW}(blocked by $blocked)${NC}"
      else
        echo -e "  ${BLUE}○${NC} $sid: $stitle ${GREEN}(ready)${NC}"
      fi
    done
  fi

  echo ""

  # Rotation status
  if [ "$ROTATION_LIBRARY_LOADED" = true ] && should_use_rotation; then
    print_rotation_status
  else
    echo -e "Rotation: ${YELLOW}disabled${NC}"
  fi

  # Last iteration time (check log file modification time)
  if [ -f "$LOG_FILE" ]; then
    local_log_mtime=$(stat -f "%m" "$LOG_FILE" 2>/dev/null || stat -c "%Y" "$LOG_FILE" 2>/dev/null || echo "0")
    local_now=$(date +%s)
    local_ago=$((local_now - local_log_mtime))
    if [ "$local_ago" -gt 0 ] && [ "$local_ago" -lt 86400 ]; then
      echo -e "Last activity: ${BLUE}$(format_duration $local_ago)${NC} ago"
    fi
  fi

  echo ""
  exit 0
fi

# ---- Review Subcommand --------------------------------------------

if [ "$CURRENT_COMMAND" = "review" ]; then
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  Ralph Review${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Select agent for review (uses commands.review config)
  export RALPH_OVERRIDE_MODEL=""
  if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
    SELECTION=$(select_agent_and_model "" "review")
    REVIEW_AGENT=$(echo "$SELECTION" | cut -d'|' -f1)
    RALPH_OVERRIDE_MODEL=$(echo "$SELECTION" | cut -d'|' -f2)
  else
    REVIEW_AGENT=$(get_agent 2>/dev/null || echo "claude-code")
  fi

  # Verify agent is available
  if ! check_agent_available "$REVIEW_AGENT"; then
    echo -e "${RED}Review agent $REVIEW_AGENT not available${NC}"
    exit 1
  fi

  echo -e "Review agent: ${CYAN}$REVIEW_AGENT${NC} (model: ${CYAN}${RALPH_OVERRIDE_MODEL:-default}${NC})"
  echo ""

  # Run the review agent
  set +e
  REVIEW_OUTPUT=$(run_agent "$REVIEW_AGENT" 2>&1 | tee /dev/stderr)
  REVIEW_STATUS=$?
  set -e

  if [ $REVIEW_STATUS -ne 0 ]; then
    echo -e "${RED}Review agent failed with exit code $REVIEW_STATUS${NC}"
    exit 1
  fi

  # Parse fixes from output (between RALPH_FIXES_START and RALPH_FIXES_END markers)
  FIXES_JSON=$(echo "$REVIEW_OUTPUT" | sed -n '/RALPH_FIXES_START/,/RALPH_FIXES_END/p' | sed '1d;$d')

  if [ -z "$FIXES_JSON" ]; then
    echo -e "${YELLOW}No fix stories found in review output${NC}"
    echo -e "${YELLOW}The review agent did not produce structured fixes.${NC}"
    exit 0
  fi

  # Validate the extracted JSON
  if ! echo "$FIXES_JSON" | jq empty 2>/dev/null; then
    echo -e "${RED}Error: Review output contains invalid JSON${NC}"
    echo "$FIXES_JSON" | head -5
    exit 1
  fi

  # Get fix count
  FIX_COUNT=$(echo "$FIXES_JSON" | jq '.fixes | length' 2>/dev/null || echo "0")

  if [ "$FIX_COUNT" -eq 0 ]; then
    echo -e "${GREEN}No issues found! Codebase looks good.${NC}"
    exit 0
  fi

  # Build fixes.json with project metadata
  FIXES_PROJECT=$(jq -r '.project // "Unknown"' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "Unknown")
  FIXES_BRANCH=$(jq -r '.branchName // "unknown"' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "unknown")

  echo "$FIXES_JSON" | jq --arg project "$FIXES_PROJECT" --arg branch "$FIXES_BRANCH" '
    {
      project: $project,
      branchName: $branch,
      userStories: [.fixes[] | . + {passes: false, blockedBy: []}]
    }
  ' > "$FIXES_FILE"

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Review complete: $FIX_COUNT fix(es) found${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Fixes saved to: ${BLUE}$FIXES_FILE${NC}"
  echo -e "Run fixes with: ${YELLOW}./ralph.sh --fixes${NC}"
  echo ""

  # List the fixes
  jq -r '.userStories[] | "  \(.priority). [\(.id)] \(.title)"' "$FIXES_FILE" 2>/dev/null

  exit 0
fi

# ---- Filebug Subcommand -------------------------------------------

if [ "$CURRENT_COMMAND" = "filebug" ]; then
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  Ralph Filebug${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Validate bug description is not empty
  if [ -z "$FILEBUG_DESCRIPTION" ]; then
    echo -e "${RED}Error: Bug description is required${NC}"
    echo -e "Usage: ${YELLOW}./ralph.sh filebug \"description of the bug\"${NC}"
    echo -e "       ${YELLOW}./ralph.sh filebug --file src/auth.ts \"Login redirect broken\"${NC}"
    exit 1
  fi

  echo -e "Bug: ${YELLOW}$FILEBUG_DESCRIPTION${NC}"
  [ -n "$FILEBUG_FILE" ] && echo -e "File: ${CYAN}$FILEBUG_FILE${NC}"
  echo ""

  # Determine next FIX-NNN ID from existing fixes.json
  NEXT_FIX_ID="FIX-001"
  if [ -f "$FIXES_FILE" ]; then
    HIGHEST_FIX=$(jq -r '.userStories[].id' "$FIXES_FILE" 2>/dev/null | grep -o '[0-9]*' | sort -n | tail -1)
    if [ -n "$HIGHEST_FIX" ]; then
      NEXT_FIX_NUM=$((HIGHEST_FIX + 1))
      NEXT_FIX_ID=$(printf "FIX-%03d" "$NEXT_FIX_NUM")
    fi
  fi
  echo -e "Next fix ID: ${CYAN}$NEXT_FIX_ID${NC}"

  # Append next ID info to the description for the agent
  FILEBUG_DESCRIPTION="${FILEBUG_DESCRIPTION} Use fix ID: ${NEXT_FIX_ID}."

  # Select agent for filebug (uses commands.filebug config)
  export RALPH_OVERRIDE_MODEL=""
  if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
    SELECTION=$(select_agent_and_model "" "filebug")
    FILEBUG_AGENT=$(echo "$SELECTION" | cut -d'|' -f1)
    RALPH_OVERRIDE_MODEL=$(echo "$SELECTION" | cut -d'|' -f2)
  else
    FILEBUG_AGENT=$(get_agent 2>/dev/null || echo "claude-code")
  fi

  # Verify agent is available
  if ! check_agent_available "$FILEBUG_AGENT"; then
    echo -e "${RED}Filebug agent $FILEBUG_AGENT not available${NC}"
    exit 1
  fi

  echo -e "Agent: ${CYAN}$FILEBUG_AGENT${NC} (model: ${CYAN}${RALPH_OVERRIDE_MODEL:-default}${NC})"
  echo ""

  # Run the filebug agent
  ACTIVE_AGENT="$FILEBUG_AGENT"
  set +e
  FILEBUG_OUTPUT=$(run_agent "$FILEBUG_AGENT" 2>&1 | tee /dev/stderr)
  FILEBUG_STATUS=$?
  set -e

  if [ $FILEBUG_STATUS -ne 0 ]; then
    echo -e "${RED}Filebug agent failed with exit code $FILEBUG_STATUS${NC}"
    exit 1
  fi

  # Parse fix story from output (between RALPH_FIX_START and RALPH_FIX_END markers)
  FIX_JSON=$(echo "$FILEBUG_OUTPUT" | sed -n '/RALPH_FIX_START/,/RALPH_FIX_END/p' | sed '1d;$d')

  if [ -z "$FIX_JSON" ]; then
    echo -e "${YELLOW}No fix story found in agent output${NC}"
    echo -e "${YELLOW}The agent did not produce a structured fix story.${NC}"
    exit 1
  fi

  # Validate the extracted JSON
  if ! echo "$FIX_JSON" | jq empty 2>/dev/null; then
    echo -e "${RED}Error: Agent output contains invalid JSON${NC}"
    echo "$FIX_JSON" | head -5
    exit 1
  fi

  # Build or append to fixes.json
  FIXES_PROJECT=$(jq -r '.project // "Unknown"' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "Unknown")
  FIXES_BRANCH=$(jq -r '.branchName // "unknown"' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "unknown")

  # Add passes: false and blockedBy: [] to the fix story
  FIX_STORY=$(echo "$FIX_JSON" | jq '. + {passes: false, blockedBy: []}')

  if [ -f "$FIXES_FILE" ] && jq empty "$FIXES_FILE" 2>/dev/null; then
    # Append to existing fixes.json
    jq --argjson fix "$FIX_STORY" '.userStories += [$fix]' "$FIXES_FILE" > "${FIXES_FILE}.tmp" && mv "${FIXES_FILE}.tmp" "$FIXES_FILE"
  else
    # Create new fixes.json
    jq -n --arg project "$FIXES_PROJECT" --arg branch "$FIXES_BRANCH" --argjson fix "$FIX_STORY" '
      {
        project: $project,
        branchName: $branch,
        userStories: [$fix]
      }
    ' > "$FIXES_FILE"
  fi

  # Validate resulting JSON
  if ! jq empty "$FIXES_FILE" 2>/dev/null; then
    echo -e "${RED}Error: Resulting fixes.json is invalid${NC}"
    exit 1
  fi

  FIX_TITLE=$(echo "$FIX_STORY" | jq -r '.title // "Untitled"')
  FIX_ID=$(echo "$FIX_STORY" | jq -r '.id // "FIX-???"')
  FIX_PRIORITY=$(echo "$FIX_STORY" | jq -r '.priority // "?"')

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Bug filed: [$FIX_ID] $FIX_TITLE (priority: $FIX_PRIORITY)${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Fixes saved to: ${BLUE}$FIXES_FILE${NC}"
  echo -e "Run fixes with: ${YELLOW}./ralph.sh --fixes${NC}"
  echo ""

  # List all fixes
  jq -r '.userStories[] | "  \(.priority). [\(.id)] \(.title)"' "$FIXES_FILE" 2>/dev/null

  exit 0
fi

# ---- Change Subcommand --------------------------------------------

if [ "$CURRENT_COMMAND" = "change" ]; then
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  Ralph Change Request${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Validate change description is not empty
  if [ -z "$CHANGE_DESCRIPTION" ]; then
    echo -e "${RED}Error: Change description is required${NC}"
    echo -e "Usage: ${YELLOW}./ralph.sh change \"Add pagination to the user list endpoint\"${NC}"
    echo -e "       ${YELLOW}./ralph.sh change \"Remove the export feature\"${NC}"
    echo -e "       ${YELLOW}./ralph.sh change \"Update US-003 to handle edge case\"${NC}"
    exit 1
  fi

  # Validate PRD exists
  if [ ! -f "$SCRIPT_DIR/prd.json" ]; then
    echo -e "${RED}Error: prd.json not found — nothing to change${NC}"
    exit 1
  fi

  echo -e "Change: ${YELLOW}$CHANGE_DESCRIPTION${NC}"
  echo ""

  # Backup prd.json before making changes
  CHANGE_BACKUP_DIR="$SCRIPT_DIR/.ralph-backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$CHANGE_BACKUP_DIR"
  cp "$SCRIPT_DIR/prd.json" "$CHANGE_BACKUP_DIR/prd.json"
  echo -e "Backup: ${CYAN}$CHANGE_BACKUP_DIR/prd.json${NC}"

  # Select agent for change (uses commands.change config)
  export RALPH_OVERRIDE_MODEL=""
  if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
    SELECTION=$(select_agent_and_model "" "change")
    CHANGE_AGENT=$(echo "$SELECTION" | cut -d'|' -f1)
    RALPH_OVERRIDE_MODEL=$(echo "$SELECTION" | cut -d'|' -f2)
  else
    CHANGE_AGENT=$(get_agent 2>/dev/null || echo "claude-code")
  fi

  # Verify agent is available
  if ! check_agent_available "$CHANGE_AGENT"; then
    echo -e "${RED}Change agent $CHANGE_AGENT not available${NC}"
    exit 1
  fi

  echo -e "Agent: ${CYAN}$CHANGE_AGENT${NC} (model: ${CYAN}${RALPH_OVERRIDE_MODEL:-default}${NC})"
  echo ""

  # Run the change agent (agent modifies prd.json directly)
  ACTIVE_AGENT="$CHANGE_AGENT"
  set +e
  CHANGE_OUTPUT=$(run_agent "$CHANGE_AGENT" 2>&1 | tee /dev/stderr)
  CHANGE_STATUS=$?
  set -e

  if [ $CHANGE_STATUS -ne 0 ]; then
    echo -e "${RED}Change agent failed with exit code $CHANGE_STATUS${NC}"
    echo -e "${YELLOW}Restoring prd.json from backup...${NC}"
    cp "$CHANGE_BACKUP_DIR/prd.json" "$SCRIPT_DIR/prd.json"
    echo -e "${GREEN}prd.json restored${NC}"
    exit 1
  fi

  # Post-validation: validate the resulting prd.json
  if type validate_prd_json >/dev/null 2>&1; then
    if ! validate_prd_json "$SCRIPT_DIR/prd.json"; then
      echo -e "${RED}Error: Agent produced invalid prd.json${NC}"
      echo -e "${YELLOW}Restoring prd.json from backup...${NC}"
      cp "$CHANGE_BACKUP_DIR/prd.json" "$SCRIPT_DIR/prd.json"
      echo -e "${GREEN}prd.json restored${NC}"
      exit 1
    fi
  fi

  # Show summary of changes
  STORIES_BEFORE_CHANGE=$(jq '.userStories | length' "$CHANGE_BACKUP_DIR/prd.json" 2>/dev/null || echo "0")
  STORIES_AFTER_CHANGE=$(jq '.userStories | length' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "0")
  REMOVED_COUNT=$(jq '[.userStories[] | select(.status == "removed")] | length' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "0")
  CHANGE_REQUESTS=$(jq '.changeRequests | length // 0' "$SCRIPT_DIR/prd.json" 2>/dev/null || echo "0")

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Change request applied${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Stories: ${YELLOW}$STORIES_BEFORE_CHANGE${NC} → ${GREEN}$STORIES_AFTER_CHANGE${NC} (${RED}$REMOVED_COUNT removed${NC})"
  echo -e "Change requests logged: ${CYAN}$CHANGE_REQUESTS${NC}"
  echo -e "Backup: ${CYAN}$CHANGE_BACKUP_DIR/prd.json${NC}"
  echo ""

  # List updated story list
  jq -r '.userStories[] | "\(.passes)|\(.id)|\(.title)|\(.status // "")"' "$SCRIPT_DIR/prd.json" 2>/dev/null | while IFS='|' read -r passes sid stitle sstatus; do
    if [ "$sstatus" = "removed" ]; then
      echo -e "  ${RED}✗${NC} $sid: $stitle ${RED}(removed)${NC}"
    elif [ "$passes" = "true" ]; then
      echo -e "  ${GREEN}✓${NC} $sid: $stitle"
    else
      echo -e "  ${BLUE}○${NC} $sid: $stitle"
    fi
  done

  echo ""
  echo -e "Continue building with: ${YELLOW}./ralph.sh${NC}"

  exit 0
fi

# ---- Main loop ----------------------------------------------------

PRIMARY_AGENT=$(get_agent)
if [ -z "$PRIMARY_AGENT" ]; then
  echo -e "${RED}Failed to detect or configure an agent. Exiting.${NC}"
  exit 1
fi
FALLBACK_AGENT=$(get_fallback_agent)

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🐻 Starting Ralph${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Project type: ${YELLOW}$PROJECT_TYPE${NC}"
echo -e "Primary agent: ${CYAN}$PRIMARY_AGENT${NC}"
[ -n "$FALLBACK_AGENT" ] && echo -e "Fallback agent: ${CYAN}$FALLBACK_AGENT${NC}"
echo -e "Max iterations: ${YELLOW}$MAX_ITERATIONS${NC}"
if [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
  echo -e "Agent timeout: ${YELLOW}${AGENT_TIMEOUT}s${NC}"
else
  echo -e "Agent timeout: ${YELLOW}no timeout${NC}"
fi
[ "$VERBOSE" = true ] && echo -e "Verbose mode: ${GREEN}enabled${NC}"
if should_use_rotation; then
  echo -e "Rotation: ${GREEN}enabled${NC} (threshold: $(get_failure_threshold 2>/dev/null || echo 2), cooldown: $(get_rate_limit_cooldown 2>/dev/null || echo 300)s)"
else
  echo -e "Rotation: ${YELLOW}disabled${NC}"
fi
echo -e "Log file: ${BLUE}$LOG_FILE${NC}"
echo -e "Started at: ${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
# Show git workflow status
if [ -n "$BRANCH_NAME" ]; then
  echo -e "Feature branch: ${CYAN}$BRANCH_NAME${NC}"
  if should_push; then
    PUSH_TIMING=$(get_git_push_timing 2>/dev/null || echo "iteration")
    echo -e "Auto-push: ${GREEN}enabled${NC} (timing: $PUSH_TIMING)"
  else
    echo -e "Auto-push: ${YELLOW}disabled${NC}"
  fi
  if should_create_pr; then
    echo -e "Auto-PR: ${GREEN}enabled${NC}"
    if should_auto_merge_pr; then
      echo -e "Auto-merge: ${GREEN}enabled${NC}"
    fi
  else
    echo -e "Auto-PR: ${YELLOW}disabled${NC}"
  fi
fi

start_sleep_prevention

# Initialize rotation state if rotation is enabled
if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
  init_rotation_state
fi

# Clean up stale branches from previous runs (merged sub-branches)
if [ "$GIT_LIBRARY_LOADED" = true ] && [ -n "$BRANCH_NAME" ]; then
  cleanup_merged_branches
fi

for i in $(seq 1 "$MAX_ITERATIONS"); do
  ITERATION_START=$(date +%s)

  # Ensure we're on the feature branch and pull latest before each iteration
  if [ "$GIT_LIBRARY_LOADED" = true ] && [ -n "$BRANCH_NAME" ]; then
    if get_git_auto_checkout_branch 2>/dev/null; then
      GIT_TERMINAL_PROMPT=0 git checkout "$BRANCH_NAME" 2>/dev/null || true
      # Only pull if we're behind origin, not ahead; use GIT_TERMINAL_PROMPT=0 to prevent hanging on auth
      if git rev-list --count HEAD..origin/"$BRANCH_NAME" 2>/dev/null | grep -q '^[1-9]'; then
        GIT_TERMINAL_PROMPT=0 git pull --no-edit origin "$BRANCH_NAME" 2>/dev/null || true
      fi
    fi
  fi

  # Sync context system from PRD (captures agent's prd.json updates from previous iteration)
  if [ "$CONTEXT_SYSTEM_ENABLED" = true ] && [ -f "$PRD_FILE" ]; then
    import_prd "$PRD_FILE" 2>/dev/null || true
  fi

  # Run pre-iteration compaction if enabled
  if [ "$COMPACTION_ENABLED" = true ]; then
    pre_iteration_compact "$PROGRESS_FILE" 2>/dev/null || true
  fi

  # Clean old checkpoints periodically (every 5 iterations)
  if [ "$CHECKPOINTING_ENABLED" = true ] && [ $((i % 5)) -eq 1 ]; then
    clean_old_checkpoints 2>/dev/null || true
  fi
  if [ "$REPL_LIBRARY_LOADED" = true ] && [ $((i % 5)) -eq 1 ]; then
    cleanup_old_repl "${RALPH_REPL_RETENTION_DAYS:-1}" 2>/dev/null || true
  fi
  if [ $((i % 5)) -eq 1 ]; then
    cleanup_old_logs "${RALPH_LOG_RETENTION_DAYS:-14}" 2>/dev/null || true
  fi

  # Get current task details for REPL integration
  TASK_DETAILS=$(get_current_task_details)
  CURRENT_TASK_ID=$(echo "$TASK_DETAILS" | cut -d'|' -f1)
  CURRENT_TASK_DESC=$(echo "$TASK_DETAILS" | cut -d'|' -f2)
  CURRENT_AC_COUNT=$(echo "$TASK_DETAILS" | cut -d'|' -f3)

  # Select agent and model (rotation-aware or static)
  ACTIVE_AGENT="$PRIMARY_AGENT"
  export RALPH_OVERRIDE_MODEL=""
  if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
    SELECTION=$(select_agent_and_model "$CURRENT_TASK_ID" "$CURRENT_COMMAND")
    ACTIVE_AGENT=$(echo "$SELECTION" | cut -d'|' -f1)
    RALPH_OVERRIDE_MODEL=$(echo "$SELECTION" | cut -d'|' -f2)
    # Verify selected agent is available
    if ! check_agent_available "$ACTIVE_AGENT"; then
      log_warn "Selected agent $ACTIVE_AGENT not available, rotating" 2>/dev/null || true
      rotate_agent "$CURRENT_COMMAND" 2>/dev/null || true
      SELECTION=$(select_agent_and_model "$CURRENT_TASK_ID" "$CURRENT_COMMAND")
      ACTIVE_AGENT=$(echo "$SELECTION" | cut -d'|' -f1)
      RALPH_OVERRIDE_MODEL=$(echo "$SELECTION" | cut -d'|' -f2)
    fi
  fi

  # Track story progress before agent runs (for auto-commit detection)
  STORIES_BEFORE=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "0")

  print_status $i $MAX_ITERATIONS

  set +e
  # Use REPL-aware runner if we have task details
  # Use temp file to capture output while displaying in real-time
  TEMP_OUTPUT=$(mktemp)
  trap "rm -f '$TEMP_OUTPUT'" EXIT

  # Run agent and capture output to file while streaming to terminal
  # The | cat at the end helps with buffering on some systems
  if [ -n "$CURRENT_TASK_ID" ] && [ "$REPL_LIBRARY_LOADED" = true ]; then
    run_agent_with_repl "$ACTIVE_AGENT" "$CURRENT_TASK_ID" "$CURRENT_TASK_DESC" "$CURRENT_AC_COUNT" 2>&1 | tee "$TEMP_OUTPUT"
  else
    run_agent "$ACTIVE_AGENT" 2>&1 | tee "$TEMP_OUTPUT"
  fi
  STATUS=${PIPESTATUS[0]}
  OUTPUT=$(cat "$TEMP_OUTPUT" 2>/dev/null || echo "")
  rm -f "$TEMP_OUTPUT"
  set -e

  # Parse usage metrics from output
  if [ "$ROTATION_LIBRARY_LOADED" = true ] && should_use_rotation; then
    parse_usage_from_output "$ACTIVE_AGENT" "$OUTPUT" 2>/dev/null || true
  fi

  # Handle rate limits
  RATE_LIMITED=false
  if check_rate_limit "$OUTPUT" || { [ "$ROTATION_LIBRARY_LOADED" = true ] && check_rate_limit_extended "$ACTIVE_AGENT" "$OUTPUT"; }; then
    RATE_LIMITED=true
    if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
      # Rotation enabled: record rate limit, rotate, and continue
      # Note: || true prevents set -e from exiting on rotation function failures
      record_rate_limit "$ACTIVE_AGENT" 2>/dev/null || true
      update_rotation_state "$CURRENT_TASK_ID" "$ACTIVE_AGENT" "$RALPH_OVERRIDE_MODEL" "rate_limit" 2>/dev/null || true
      echo -e "${YELLOW}⚠ Rate limit hit on $ACTIVE_AGENT — rotating to next agent${NC}"
      set +e
      rotate_agent "$CURRENT_COMMAND" 2>/dev/null
      ROTATE_RESULT=$?
      set -e
      if [ $ROTATE_RESULT -eq 2 ]; then
        # All agents exhausted
        echo -e "${RED}All agents exhausted after rate limits. Waiting for cooldown...${NC}"
        local_cooldown=$(get_rate_limit_cooldown)
        echo -e "Sleeping ${YELLOW}${local_cooldown}s${NC} for cooldown..."
        sleep "$local_cooldown"
      fi
      # Continue to next iteration instead of exiting
      sleep 2
      continue
    else
      # No rotation: exit as before
      print_iteration_summary $i 0 "rate_limited"
      echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${RED}  ⚠ Rate limit hit - Ralph stopping${NC}"
      echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
      echo -e "Resume later with: ${YELLOW}./ralph.sh $((MAX_ITERATIONS - i + 1))${NC}"
      exit 1
    fi
  fi

  # Handle failures
  if [ $STATUS -ne 0 ]; then
    if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ]; then
      # Rotation enabled: track failure, possibly rotate
      # Note: || true prevents set -e from exiting on rotation function failures
      update_rotation_state "$CURRENT_TASK_ID" "$ACTIVE_AGENT" "$RALPH_OVERRIDE_MODEL" "failure" 2>/dev/null || true
      if should_rotate "$CURRENT_TASK_ID" "$ACTIVE_AGENT" "$RALPH_OVERRIDE_MODEL" 2>/dev/null; then
        echo -e "${YELLOW}Failure threshold reached for $ACTIVE_AGENT ($RALPH_OVERRIDE_MODEL) — rotating${NC}"
        rotate_model "$ACTIVE_AGENT" "$CURRENT_COMMAND" 2>/dev/null || true
      fi
      # Continue to next iteration (retry with rotated model/agent)
      sleep 2
      continue
    elif [ -n "$FALLBACK_AGENT" ]; then
      # Legacy fallback behavior
      echo -e "${YELLOW}Primary agent failed — trying $FALLBACK_AGENT${NC}"
      set +e
      OUTPUT=$(run_agent "$FALLBACK_AGENT" 2>&1 | tee /dev/stderr)
      STATUS=$?
      set -e
      check_rate_limit "$OUTPUT" && { echo -e "${RED}⚠ Rate limit on fallback${NC}"; exit 1; }
    fi
  else
    # Success: update rotation state
    if should_use_rotation && [ "$ROTATION_LIBRARY_LOADED" = true ] && [ -n "$CURRENT_TASK_ID" ]; then
      update_rotation_state "$CURRENT_TASK_ID" "$ACTIVE_AGENT" "$RALPH_OVERRIDE_MODEL" "success" 2>/dev/null || true
      reset_story_state "$CURRENT_TASK_ID" 2>/dev/null || true
    fi
  fi

  ITERATION_END=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END - ITERATION_START))

  # ---- Post-iteration Git Workflow ----
  # Verify we're still on the feature branch; push if enabled
  if [ "$GIT_LIBRARY_LOADED" = true ] && [ -n "$BRANCH_NAME" ]; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
      echo -e "${YELLOW}⚠ Agent switched to branch: ${CURRENT_BRANCH}, returning to ${BRANCH_NAME}${NC}"
      log_warn "Agent switched to $CURRENT_BRANCH, recovering to $BRANCH_NAME"
      if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git add -A
        git commit -m "chore: auto-commit uncommitted agent work before branch restore" 2>/dev/null || true
      fi
      git checkout "$BRANCH_NAME" 2>/dev/null || true
    fi

    # Auto-commit uncommitted changes if agent made progress but forgot to commit
    # Check if story progress was made (comparing before/after)
    STORIES_AFTER=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "0")
    STORY_PROGRESS_MADE=false
    if [ "$STORIES_AFTER" -gt "$STORIES_BEFORE" ]; then
      STORY_PROGRESS_MADE=true
    fi
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
      # There are uncommitted changes
      UNCOMMITTED_SRC=$(git diff --name-only HEAD 2>/dev/null | grep -c '^src/' || echo "0")
      UNCOMMITTED_PRD=$(git diff --name-only HEAD 2>/dev/null | grep -c 'prd.json' || echo "0")

      if [ "$STORIES_AFTER" -gt "$STORIES_BEFORE" ]; then
        # Story progress was made but changes weren't committed - auto-commit
        echo -e "${YELLOW}⚠ Agent made progress but didn't commit - auto-committing${NC}"
        COMPLETED_STORY=$(jq -r ".userStories[] | select(.passes == true) | .id" "$PRD_FILE" 2>/dev/null | tail -1)
        git add -A
        git commit -m "feat: ${COMPLETED_STORY:-story} - auto-commit by Ralph (agent forgot to commit)" 2>/dev/null || true
      elif [ "$UNCOMMITTED_SRC" -gt 0 ] || [ "$UNCOMMITTED_PRD" -gt 0 ]; then
        # Source or PRD changes exist - warn but don't auto-commit (might be incomplete work)
        echo -e "${YELLOW}⚠ Uncommitted changes detected (${UNCOMMITTED_SRC} src files, prd: ${UNCOMMITTED_PRD})${NC}"
        log_warn "Uncommitted changes after iteration: $UNCOMMITTED_SRC src files" 2>/dev/null || true
      fi
    fi

    # Push if enabled and timing is "iteration"
    if should_push; then
      PUSH_TIMING=$(get_git_push_timing 2>/dev/null || echo "iteration")
      if [ "$PUSH_TIMING" = "iteration" ] && [ "$STORY_PROGRESS_MADE" = true ]; then
        push_branch "$BRANCH_NAME"
      fi
    fi
  fi

  # Check for RALPH_COMPLETE - must be a standalone line, not part of the prompt
  # The prompt contains "output: RALPH_COMPLETE" so we need to match only standalone occurrence
  if echo "$OUTPUT" | grep -qxE '\s*RALPH_COMPLETE\s*'; then
    # Double-check: verify all stories in PRD are marked as passing
    ALL_PASS=$(jq '[.userStories[].passes] | all' "$PRD_FILE" 2>/dev/null || echo "false")
    if [ "$ALL_PASS" = "true" ]; then
      print_iteration_summary $i $ITERATION_DURATION "success"
      echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${GREEN}  🎉 Ralph completed all tasks!${NC}"
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "Completed at iteration ${YELLOW}$i${NC} | Total time: ${BLUE}$(get_elapsed_time)${NC}"

      # ---- Final Git Workflow ----
      if [ "$GIT_LIBRARY_LOADED" = true ] && [ -n "$BRANCH_NAME" ]; then
        echo ""
        push_succeeded=true

        # Final push (if timing is "end" or we haven't pushed yet)
        if should_push; then
          PUSH_TIMING=$(get_git_push_timing 2>/dev/null || echo "iteration")
          if [ "$PUSH_TIMING" = "end" ]; then
            echo -e "${CYAN}Pushing final changes...${NC}"
            if ! push_branch "$BRANCH_NAME"; then
              push_succeeded=false
              echo -e "${YELLOW}Push failed - PR creation skipped${NC}"
            fi
          fi
        fi

        # Create PR if enabled (only if push succeeded)
        if should_create_pr; then
          if [ "$push_succeeded" = true ]; then
            echo -e "${CYAN}Creating pull request...${NC}"
            BASE_BRANCH=$(get_git_base_branch 2>/dev/null || echo "main")
            if create_pr "$BRANCH_NAME" "$BASE_BRANCH"; then
              # Auto-merge PR if enabled
              if should_auto_merge_pr; then
                echo -e "${CYAN}Merging pull request...${NC}"
                merge_pr "$BRANCH_NAME"
              fi
            fi
          else
            echo -e "${YELLOW}Skipping PR creation due to push failure${NC}"
            echo -e "${YELLOW}Push manually: git push -u origin $BRANCH_NAME${NC}"
          fi
        fi
      fi

      exit 0
    fi
  fi

  check_error "$OUTPUT" && print_iteration_summary $i $ITERATION_DURATION "error" || print_iteration_summary $i $ITERATION_DURATION "success"
  sleep 2
done

echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Ralph reached max iterations ($MAX_ITERATIONS)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Stories: ${GREEN}$(get_story_progress)${NC} | Check ${BLUE}$PROGRESS_FILE${NC}"
exit 1
