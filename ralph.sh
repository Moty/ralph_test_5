#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop (agent-agnostic)
# Usage: ./ralph.sh [max_iterations] [--no-sleep-prevent] [--verbose] [--timeout SECONDS] [--no-timeout] [--greenfield] [--brownfield] [--update] [--check-update]
# Agent priority: GitHub Copilot CLI → Claude Code → Gemini → Codex

set -e

# ---- Configuration ------------------------------------------------

PREVENT_SLEEP=true
export VERBOSE=false
AGENT_TIMEOUT=7200  # Default 2 hour timeout per agent iteration (0 = no timeout)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_TYPE=""  # greenfield, brownfield, or auto-detected
DO_UPDATE=false
CHECK_UPDATE_ONLY=false
MAX_ITERATIONS=10

# Check for flags first (before processing positional args)
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
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

# Set MAX_ITERATIONS from positional arg if provided
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
  MAX_ITERATIONS="${POSITIONAL_ARGS[0]}"
fi

PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
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
    echo "unknown"
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

# ---- Helper Functions ---------------------------------------------

require_bin jq
require_bin yq

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
      local ready_tasks=$(get_ready_tasks 2>/dev/null || echo "")
      if [ -n "$ready_tasks" ]; then
        echo "$ready_tasks" | head -n 1
        return
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
      local blockedBy=$(echo "$story_json" | jq -r '.blockedBy // empty | .[]' 2>/dev/null)
      
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
get_claude_model() { yq '.claude-code.model // "claude-sonnet-4-20250514"' "$AGENT_CONFIG"; }
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

  case "$AGENT" in
    claude-code)
      local MODEL=$(get_claude_model)
      echo -e "→ Running ${CYAN}Claude Code${NC} (model: $MODEL, timeout: $TIMEOUT_DISPLAY)"
      [ -z "$CLAUDE_CMD" ] && { echo -e "${RED}Error: Claude CLI not found${NC}"; return 1; }

      # Run with timeout if run_with_timeout function exists and timeout > 0
      if type run_with_timeout >/dev/null 2>&1 && [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
        run_with_timeout "$AGENT_TIMEOUT" "$CLAUDE_CMD" --print --dangerously-skip-permissions --model "$MODEL" \
          --system-prompt "$SCRIPT_DIR/system_instructions/system_instructions.md" \
          "Read prd.json and implement the next incomplete story. Follow the system instructions exactly."
      else
        "$CLAUDE_CMD" --print --dangerously-skip-permissions --model "$MODEL" \
          --system-prompt "$SCRIPT_DIR/system_instructions/system_instructions.md" \
          "Read prd.json and implement the next incomplete story. Follow the system instructions exactly."
      fi
      ;;
    codex)
      local MODEL=$(get_codex_model)
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

      # Run with timeout if run_with_timeout function exists and timeout > 0
      if type run_with_timeout >/dev/null 2>&1 && [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
        run_with_timeout "$AGENT_TIMEOUT" codex exec $CODEX_FLAGS -m "$MODEL" --skip-git-repo-check \
          "Read prd.json and implement the next incomplete story. Follow system_instructions/system_instructions_codex.md. When all stories complete, output: RALPH_COMPLETE"
      else
        codex exec $CODEX_FLAGS -m "$MODEL" --skip-git-repo-check \
          "Read prd.json and implement the next incomplete story. Follow system_instructions/system_instructions_codex.md. When all stories complete, output: RALPH_COMPLETE"
      fi
      ;;
    github-copilot)
      local TOOL_APPROVAL=$(get_copilot_tool_approval)
      local COPILOT_MODEL=$(get_copilot_model)
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
      
      # Add tool approval flags
      if [ "$TOOL_APPROVAL" = "allow-all" ]; then
        COPILOT_FLAGS+=("--allow-all-tools")
        # Add deny-tools if specified
        local DENY_TOOLS="$(get_copilot_deny_tools)"
        if [ -n "$DENY_TOOLS" ]; then
          while IFS= read -r tool; do
            [ -n "$tool" ] && COPILOT_FLAGS+=("--deny-tool" "$tool")
          done <<< "$DENY_TOOLS"
        fi
      fi

      # Construct the prompt
      local PROMPT="Read prd.json and implement the next incomplete story. Follow the instructions in system_instructions/system_instructions_copilot.md exactly. When all stories are complete, output: RALPH_COMPLETE"

      # Run with timeout if run_with_timeout function exists and timeout > 0
      if type run_with_timeout >/dev/null 2>&1 && [ "$AGENT_TIMEOUT" -gt 0 ] 2>/dev/null; then
        run_with_timeout "$AGENT_TIMEOUT" copilot -p "$PROMPT" "${COPILOT_FLAGS[@]}"
      else
        copilot -p "$PROMPT" "${COPILOT_FLAGS[@]}"
      fi
      ;;
    gemini)
      local MODEL=$(get_gemini_model)
      echo -e "→ Running ${CYAN}Gemini${NC} (model: $MODEL, timeout: $TIMEOUT_DISPLAY)"
      command -v gemini >/dev/null 2>&1 || { echo -e "${RED}Error: Gemini CLI not found${NC}"; echo -e "${YELLOW}Install: npm install -g @anthropic/gemini-cli or pip install google-generativeai${NC}"; return 1; }

      # Construct the prompt for Gemini
      local PROMPT="Read prd.json and implement the next incomplete story. Follow the instructions in system_instructions/system_instructions.md exactly. When all stories are complete, output: RALPH_COMPLETE"

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
echo -e "Log file: ${BLUE}$LOG_FILE${NC}"
echo -e "Started at: ${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"

start_sleep_prevention

for i in $(seq 1 "$MAX_ITERATIONS"); do
  ITERATION_START=$(date +%s)
  
  # Run pre-iteration compaction if enabled
  if [ "$COMPACTION_ENABLED" = true ]; then
    pre_iteration_compact "$PROGRESS_FILE" 2>/dev/null || true
  fi
  
  print_status $i $MAX_ITERATIONS

  set +e
  OUTPUT=$(run_agent "$PRIMARY_AGENT" 2>&1 | tee /dev/stderr)
  STATUS=$?
  set -e

  if check_rate_limit "$OUTPUT"; then
    print_iteration_summary $i 0 "rate_limited"
    echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ⚠ Rate limit hit - Ralph stopping${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "Resume later with: ${YELLOW}./ralph.sh $((MAX_ITERATIONS - i + 1))${NC}"
    exit 1
  fi

  if [ $STATUS -ne 0 ] && [ -n "$FALLBACK_AGENT" ]; then
    echo -e "${YELLOW}Primary agent failed — trying $FALLBACK_AGENT${NC}"
    set +e
    OUTPUT=$(run_agent "$FALLBACK_AGENT" 2>&1 | tee /dev/stderr)
    STATUS=$?
    set -e
    check_rate_limit "$OUTPUT" && { echo -e "${RED}⚠ Rate limit on fallback${NC}"; exit 1; }
  fi

  ITERATION_END=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END - ITERATION_START))

  # Check for RALPH_COMPLETE - must be a standalone line, not part of the prompt
  # The prompt contains "output: RALPH_COMPLETE" so we need to match it as standalone
  if echo "$OUTPUT" | grep -qE '^RALPH_COMPLETE$|^[^:]*RALPH_COMPLETE[^"]*$'; then
    # Double-check: verify all stories in PRD are marked as passing
    ALL_PASS=$(jq '[.userStories[].passes] | all' "$PRD_FILE" 2>/dev/null || echo "false")
    if [ "$ALL_PASS" = "true" ]; then
      print_iteration_summary $i $ITERATION_DURATION "success"
      echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${GREEN}  🎉 Ralph completed all tasks!${NC}"
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "Completed at iteration ${YELLOW}$i${NC} | Total time: ${BLUE}$(get_elapsed_time)${NC}"
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
