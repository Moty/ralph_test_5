#!/usr/bin/env bash
# Checkpointing library for Ralph
# Provides intermediate state persistence for complex tasks
# Allows recovery from interruptions and tracks task progress within iterations

# ---- Configuration ------------------------------------------------

CHECKPOINT_DIR="${RALPH_DIR:-.ralph}/checkpoints"
CHECKPOINT_RETENTION_DAYS=${RALPH_CHECKPOINT_RETENTION:-7}

# ---- Initialization -----------------------------------------------

# Initialize checkpointing directory
# Usage: init_checkpointing
init_checkpointing() {
  if [ ! -d "$CHECKPOINT_DIR" ]; then
    mkdir -p "$CHECKPOINT_DIR"
    echo "Initialized checkpoint directory: $CHECKPOINT_DIR" >&2
  fi
}

# ---- Checkpoint Creation ------------------------------------------

# Create a named checkpoint for current task state
# Usage: create_named_checkpoint <name> <task_id> <status> [notes]
# Status: in_progress, tests_failing, partial, completed
# Example: create_named_checkpoint "after_tests" "US-001" "tests_failing" "2 tests failing"
create_named_checkpoint() {
  local name="$1"
  local task_id="$2"
  local status="$3"
  local notes="${4:-}"

  init_checkpointing

  # Sanitize name for filename
  local safe_name=$(echo "$name" | tr ' ' '_' | tr -cd '[:alnum:]_-')
  local timestamp=$(date '+%Y%m%d_%H%M%S')
  local checkpoint_file="$CHECKPOINT_DIR/${task_id}_${timestamp}_${safe_name}.json"

  # Get git state
  local git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
  local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  local git_dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  # Get staged files
  local staged_files=$(git diff --cached --name-only 2>/dev/null | jq -R . | jq -s .)

  # Get modified files
  local modified_files=$(git diff --name-only 2>/dev/null | jq -R . | jq -s .)

  # Get task details from prd.json if available
  local task_title=""
  local task_description=""
  if [ -f "prd.json" ]; then
    task_title=$(jq -r --arg id "$task_id" '.userStories[] | select(.id == $id) | .title // ""' prd.json 2>/dev/null || echo "")
    task_description=$(jq -r --arg id "$task_id" '.userStories[] | select(.id == $id) | .description // ""' prd.json 2>/dev/null || echo "")
  fi

  # Build checkpoint JSON
  jq -n \
    --arg name "$name" \
    --arg task_id "$task_id" \
    --arg status "$status" \
    --arg notes "$notes" \
    --arg timestamp "$timestamp" \
    --arg created_at "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')" \
    --arg git_branch "$git_branch" \
    --arg git_commit "$git_commit" \
    --argjson git_dirty "$git_dirty" \
    --argjson staged_files "$staged_files" \
    --argjson modified_files "$modified_files" \
    --arg task_title "$task_title" \
    --arg task_description "$task_description" \
    '{
      checkpoint: {
        name: $name,
        timestamp: $timestamp,
        created_at: $created_at
      },
      task: {
        id: $task_id,
        title: $task_title,
        description: $task_description,
        status: $status,
        notes: $notes
      },
      git: {
        branch: $git_branch,
        commit: $git_commit,
        dirty_files: $git_dirty,
        staged_files: $staged_files,
        modified_files: $modified_files
      }
    }' > "$checkpoint_file"

  echo "$checkpoint_file"
}

# Create a quick checkpoint with auto-generated name
# Usage: create_checkpoint <task_id> <status> [notes]
create_checkpoint() {
  local task_id="$1"
  local status="$2"
  local notes="${3:-}"

  create_named_checkpoint "auto" "$task_id" "$status" "$notes"
}

# ---- Checkpoint Retrieval -----------------------------------------

# Get the latest checkpoint for a task
# Usage: get_latest_checkpoint <task_id>
# Returns: Path to most recent checkpoint file, or empty string
get_latest_checkpoint() {
  local task_id="$1"

  init_checkpointing

  # Find most recent checkpoint for this task
  local latest=$(find "$CHECKPOINT_DIR" -name "${task_id}_*.json" -type f 2>/dev/null | sort -r | head -n 1)

  echo "$latest"
}

# Get all checkpoints for a task
# Usage: list_task_checkpoints <task_id>
# Returns: List of checkpoint files, newest first
list_task_checkpoints() {
  local task_id="$1"

  init_checkpointing

  find "$CHECKPOINT_DIR" -name "${task_id}_*.json" -type f 2>/dev/null | sort -r
}

# Read checkpoint data
# Usage: read_checkpoint <checkpoint_file>
# Returns: JSON content of checkpoint
read_checkpoint() {
  local checkpoint_file="$1"

  if [ -f "$checkpoint_file" ]; then
    cat "$checkpoint_file"
  else
    echo "{}"
  fi
}

# Get checkpoint status
# Usage: get_checkpoint_status <checkpoint_file>
get_checkpoint_status() {
  local checkpoint_file="$1"

  if [ -f "$checkpoint_file" ]; then
    jq -r '.task.status // "unknown"' "$checkpoint_file"
  else
    echo "unknown"
  fi
}

# ---- Checkpoint Resume --------------------------------------------

# Resume from a checkpoint (outputs state info for agent)
# Usage: resume_from_checkpoint <checkpoint_file>
# Returns: Formatted state summary for injection into context
resume_from_checkpoint() {
  local checkpoint_file="$1"

  if [ ! -f "$checkpoint_file" ]; then
    echo "Error: Checkpoint file not found: $checkpoint_file" >&2
    return 1
  fi

  local checkpoint=$(cat "$checkpoint_file")

  local task_id=$(echo "$checkpoint" | jq -r '.task.id')
  local status=$(echo "$checkpoint" | jq -r '.task.status')
  local notes=$(echo "$checkpoint" | jq -r '.task.notes')
  local checkpoint_name=$(echo "$checkpoint" | jq -r '.checkpoint.name')
  local created_at=$(echo "$checkpoint" | jq -r '.checkpoint.created_at')
  local git_commit=$(echo "$checkpoint" | jq -r '.git.commit')
  local staged=$(echo "$checkpoint" | jq -r '.git.staged_files | length')
  local modified=$(echo "$checkpoint" | jq -r '.git.modified_files | length')

  cat <<EOF
## RESUMING FROM CHECKPOINT

**Task:** $task_id
**Checkpoint:** $checkpoint_name (created: $created_at)
**Status:** $status
**Notes:** $notes
**Git State:** commit $git_commit, $staged staged files, $modified modified files

Continue from where you left off. Review the current state and proceed.
EOF
}

# ---- Checkpoint Cleanup -------------------------------------------

# Clean old checkpoints
# Usage: clean_old_checkpoints [days]
# Default: 7 days
clean_old_checkpoints() {
  local days="${1:-$CHECKPOINT_RETENTION_DAYS}"

  init_checkpointing

  local count=0

  # Find and delete checkpoints older than N days
  while IFS= read -r file; do
    rm -f "$file"
    count=$((count + 1))
  done < <(find "$CHECKPOINT_DIR" -name "*.json" -type f -mtime "+$days" 2>/dev/null)

  if [ $count -gt 0 ]; then
    echo "Cleaned $count old checkpoints (older than $days days)" >&2
  fi
}

# Clean all checkpoints for a specific task
# Usage: clean_task_checkpoints <task_id>
clean_task_checkpoints() {
  local task_id="$1"

  init_checkpointing

  local count=0

  while IFS= read -r file; do
    rm -f "$file"
    count=$((count + 1))
  done < <(find "$CHECKPOINT_DIR" -name "${task_id}_*.json" -type f 2>/dev/null)

  if [ $count -gt 0 ]; then
    echo "Cleaned $count checkpoints for task $task_id" >&2
  fi
}

# ---- Helper Functions ---------------------------------------------

# Check if a checkpoint exists for a task
# Usage: has_checkpoint <task_id>
# Returns: 0 if exists, 1 if not
has_checkpoint() {
  local task_id="$1"

  local checkpoint=$(get_latest_checkpoint "$task_id")
  [ -n "$checkpoint" ] && [ -f "$checkpoint" ]
}

# Get checkpoint summary for status display
# Usage: get_checkpoint_summary <task_id>
get_checkpoint_summary() {
  local task_id="$1"

  local checkpoint=$(get_latest_checkpoint "$task_id")

  if [ -n "$checkpoint" ] && [ -f "$checkpoint" ]; then
    local status=$(jq -r '.task.status' "$checkpoint")
    local name=$(jq -r '.checkpoint.name' "$checkpoint")
    local timestamp=$(jq -r '.checkpoint.timestamp' "$checkpoint")
    echo "[$status] $name @ $timestamp"
  else
    echo "No checkpoint"
  fi
}

# Pre-iteration hook: check for and report existing checkpoint
# Usage: check_iteration_checkpoint <task_id>
check_iteration_checkpoint() {
  local task_id="$1"

  if has_checkpoint "$task_id"; then
    local checkpoint=$(get_latest_checkpoint "$task_id")
    local status=$(get_checkpoint_status "$checkpoint")

    echo "Found existing checkpoint for $task_id (status: $status)"

    # Return checkpoint file path for potential resume
    echo "$checkpoint"
  fi
}
