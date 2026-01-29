#!/usr/bin/env bash
# REPL (Read-Evaluate-Print-Loop) integration for Ralph
# Enables iterative refinement within complex tasks
# Based on MIT RLM paper concepts for recursive language model execution

# ---- Configuration ------------------------------------------------

# Enable/disable REPL mode
REPL_ENABLED=${RALPH_REPL_ENABLED:-true}

# Maximum REPL cycles before forcing exit
REPL_MAX_CYCLES=${RALPH_REPL_MAX_CYCLES:-3}

# Script directory for loading dependencies
REPL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# REPL state directory
REPL_STATE_DIR="${RALPH_DIR:-.ralph}/repl"

# ---- Complexity Detection -----------------------------------------

# Detect if a task should use REPL mode
# Usage: should_enable_repl <description> <ac_count>
# Returns: 0 if REPL should be enabled, 1 otherwise
should_enable_repl() {
  local description="$1"
  local ac_count="${2:-0}"

  # Disabled globally
  if [ "$REPL_ENABLED" != "true" ]; then
    return 1
  fi

  # Trigger 1: High acceptance criteria count (>3)
  if [ "$ac_count" -gt 3 ]; then
    return 0
  fi

  # Trigger 2: Complexity indicators in description
  local complexity_patterns="integration|refactor|migration|multi-step|complex|multiple files|across.*files|end-to-end|full-stack|database.*and.*api|api.*and.*ui"

  if echo "$description" | grep -qiE "$complexity_patterns"; then
    return 0
  fi

  # Trigger 3: Multi-component indicators
  if echo "$description" | grep -qiE "frontend.*backend|client.*server|ui.*api|database.*migration"; then
    return 0
  fi

  # Not complex enough for REPL
  return 1
}

# Get complexity reason for logging
# Usage: get_complexity_reason <description> <ac_count>
get_complexity_reason() {
  local description="$1"
  local ac_count="${2:-0}"

  if [ "$ac_count" -gt 3 ]; then
    echo "high acceptance criteria count ($ac_count)"
    return
  fi

  if echo "$description" | grep -qiE "integration"; then
    echo "integration task"
  elif echo "$description" | grep -qiE "refactor"; then
    echo "refactoring task"
  elif echo "$description" | grep -qiE "migration"; then
    echo "migration task"
  elif echo "$description" | grep -qiE "multi-step|complex"; then
    echo "multi-step complexity"
  elif echo "$description" | grep -qiE "multiple files|across.*files"; then
    echo "multi-file changes"
  else
    echo "general complexity"
  fi
}

# ---- REPL State Management ----------------------------------------

# Initialize REPL state directory
init_repl() {
  mkdir -p "$REPL_STATE_DIR"
}

# Initialize a new REPL cycle for a task
# Usage: init_repl_cycle <task_id>
# Returns: cycle state file path
init_repl_cycle() {
  local task_id="$1"

  init_repl

  local state_file="$REPL_STATE_DIR/${task_id}_state.json"

  # Create initial state
  jq -n \
    --arg task_id "$task_id" \
    --arg started_at "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')" \
    '{
      task_id: $task_id,
      started_at: $started_at,
      current_cycle: 1,
      max_cycles: '"$REPL_MAX_CYCLES"',
      status: "in_progress",
      cycles: [],
      last_test_result: null,
      last_lint_result: null,
      stuck_count: 0
    }' > "$state_file"

  echo "$state_file"
}

# Get current REPL state for a task
# Usage: get_repl_state <task_id>
get_repl_state() {
  local task_id="$1"

  init_repl

  local state_file="$REPL_STATE_DIR/${task_id}_state.json"

  if [ -f "$state_file" ]; then
    cat "$state_file"
  else
    echo "{}"
  fi
}

# Get current cycle number
# Usage: get_repl_cycle <task_id>
get_repl_cycle() {
  local task_id="$1"
  local state=$(get_repl_state "$task_id")

  if [ -n "$state" ] && [ "$state" != "{}" ]; then
    echo "$state" | jq -r '.current_cycle // 1'
  else
    echo "1"
  fi
}

# Advance to next REPL cycle
# Usage: advance_repl_cycle <task_id>
advance_repl_cycle() {
  local task_id="$1"

  local state_file="$REPL_STATE_DIR/${task_id}_state.json"

  if [ ! -f "$state_file" ]; then
    init_repl_cycle "$task_id"
    return
  fi

  # Increment cycle and add cycle record
  local current_cycle=$(jq -r '.current_cycle' "$state_file")
  local next_cycle=$((current_cycle + 1))

  jq --argjson next "$next_cycle" \
     --arg timestamp "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')" \
     '.current_cycle = $next | .cycles += [{cycle: .current_cycle, completed_at: $timestamp}]' \
     "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

  echo "$next_cycle"
}

# Record test/lint results for cycle
# Usage: record_cycle_result <task_id> <test_passed> <lint_passed> [error_summary]
record_cycle_result() {
  local task_id="$1"
  local test_passed="$2"
  local lint_passed="$3"
  local error_summary="${4:-}"

  local state_file="$REPL_STATE_DIR/${task_id}_state.json"

  if [ ! -f "$state_file" ]; then
    return 1
  fi

  # Check for stuck condition (same errors for multiple cycles)
  local last_errors=$(jq -r '.last_error_summary // ""' "$state_file")
  local stuck_count=$(jq -r '.stuck_count // 0' "$state_file")

  if [ -n "$error_summary" ] && [ "$error_summary" = "$last_errors" ]; then
    stuck_count=$((stuck_count + 1))
  else
    stuck_count=0
  fi

  jq --argjson test "$test_passed" \
     --argjson lint "$lint_passed" \
     --arg errors "$error_summary" \
     --argjson stuck "$stuck_count" \
     '.last_test_result = $test | .last_lint_result = $lint | .last_error_summary = $errors | .stuck_count = $stuck' \
     "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

# ---- REPL Exit Conditions -----------------------------------------

# Evaluate if REPL should exit
# Usage: evaluate_repl_exit <task_id> <test_passed> <lint_passed>
# Returns: "SUCCESS", "PARTIAL", "STUCK", or "CONTINUE"
evaluate_repl_exit() {
  local task_id="$1"
  local test_passed="${2:-false}"
  local lint_passed="${3:-false}"

  local state=$(get_repl_state "$task_id")
  local current_cycle=$(echo "$state" | jq -r '.current_cycle // 1')
  local max_cycles=$(echo "$state" | jq -r '.max_cycles // '"$REPL_MAX_CYCLES")
  local stuck_count=$(echo "$state" | jq -r '.stuck_count // 0')

  # Success: all checks pass
  if [ "$test_passed" = "true" ] && [ "$lint_passed" = "true" ]; then
    update_repl_status "$task_id" "success"
    echo "SUCCESS"
    return
  fi

  # Stuck: same errors for 2+ cycles
  if [ "$stuck_count" -ge 2 ]; then
    update_repl_status "$task_id" "stuck"
    echo "STUCK"
    return
  fi

  # Max cycles reached
  if [ "$current_cycle" -ge "$max_cycles" ]; then
    update_repl_status "$task_id" "partial"
    echo "PARTIAL"
    return
  fi

  # Continue iterating
  echo "CONTINUE"
}

# Update REPL status
# Usage: update_repl_status <task_id> <status>
update_repl_status() {
  local task_id="$1"
  local status="$2"

  local state_file="$REPL_STATE_DIR/${task_id}_state.json"

  if [ -f "$state_file" ]; then
    jq --arg status "$status" '.status = $status' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
  fi
}

# ---- REPL Status for Prompts --------------------------------------

# Get REPL status for injection into agent prompt
# Usage: get_repl_status <task_id>
get_repl_status() {
  local task_id="$1"

  local state=$(get_repl_state "$task_id")

  if [ -z "$state" ] || [ "$state" = "{}" ]; then
    echo ""
    return
  fi

  local current_cycle=$(echo "$state" | jq -r '.current_cycle // 1')
  local max_cycles=$(echo "$state" | jq -r '.max_cycles // '"$REPL_MAX_CYCLES")
  local status=$(echo "$state" | jq -r '.status // "in_progress"')
  local last_test=$(echo "$state" | jq -r '.last_test_result // "unknown"')
  local last_lint=$(echo "$state" | jq -r '.last_lint_result // "unknown"')
  local stuck_count=$(echo "$state" | jq -r '.stuck_count // 0')

  cat <<EOF
## REPL MODE ACTIVE

**Cycle:** $current_cycle of $max_cycles
**Status:** $status
**Last Test Result:** $last_test
**Last Lint Result:** $last_lint
**Stuck Count:** $stuck_count

### REPL Protocol
1. **Read**: Examine current state, review any errors from previous cycle
2. **Evaluate**: Determine the minimal fix needed
3. **Print**: Implement the fix, output results
4. **Loop**: Run tests/lint, decide to continue or exit

### Exit Conditions
- **SUCCESS**: Tests pass AND lint passes → task complete
- **PARTIAL**: Max cycles ($max_cycles) reached → commit partial progress
- **STUCK**: Same errors for 2 cycles → need human intervention

EOF
}

# ---- REPL Checkpointing Integration -------------------------------

# Create a REPL checkpoint (integrates with checkpointing.sh)
# Usage: create_repl_checkpoint <task_id> <cycle_name>
create_repl_checkpoint() {
  local task_id="$1"
  local cycle_name="${2:-repl_cycle}"

  # Load checkpointing library if available
  if ! type create_named_checkpoint >/dev/null 2>&1; then
    if [ -f "$REPL_SCRIPT_DIR/checkpointing.sh" ]; then
      source "$REPL_SCRIPT_DIR/checkpointing.sh"
    else
      echo "Checkpointing not available" >&2
      return 1
    fi
  fi

  local cycle=$(get_repl_cycle "$task_id")
  create_named_checkpoint "${cycle_name}_${cycle}" "$task_id" "repl_cycle_$cycle"
}

# ---- Cleanup ------------------------------------------------------

# Clean up REPL state for completed task
# Usage: cleanup_repl <task_id>
cleanup_repl() {
  local task_id="$1"

  local state_file="$REPL_STATE_DIR/${task_id}_state.json"

  if [ -f "$state_file" ]; then
    rm -f "$state_file"
  fi
}

# Clean all old REPL state files
# Usage: cleanup_old_repl [days]
cleanup_old_repl() {
  local days="${1:-1}"

  init_repl

  find "$REPL_STATE_DIR" -name "*.json" -type f -mtime "+$days" -delete 2>/dev/null || true
}

# ---- Helper for ralph.sh Integration ------------------------------

# Check if task should use REPL and initialize if so
# Usage: maybe_init_repl <task_id> <description> <ac_count>
# Returns: 0 if REPL initialized, 1 if not
maybe_init_repl() {
  local task_id="$1"
  local description="$2"
  local ac_count="${3:-0}"

  if should_enable_repl "$description" "$ac_count"; then
    local reason=$(get_complexity_reason "$description" "$ac_count")
    echo "REPL mode enabled for $task_id ($reason)" >&2
    init_repl_cycle "$task_id" > /dev/null
    return 0
  fi

  return 1
}

# Get count of acceptance criteria from task JSON
# Usage: count_acceptance_criteria <task_json>
count_acceptance_criteria() {
  local task_json="$1"

  echo "$task_json" | jq -r '.acceptanceCriteria | length // 0' 2>/dev/null || echo "0"
}
