#!/bin/bash
# Ralph Context Management Library
# Tracks task state with dependency awareness for complex projects
# Source this file: source "$(dirname "$0")/lib/context.sh"

# ---- Constants ----------------------------------------------------

RALPH_DIR="${RALPH_DIR:-.ralph}"
CONTEXT_FILE="$RALPH_DIR/context.json"

# ---- Initialization -----------------------------------------------

# Initialize context directory and files
# Usage: init_context
init_context() {
  if [ ! -d "$RALPH_DIR" ]; then
    mkdir -p "$RALPH_DIR"
    echo "Initialized Ralph context directory: $RALPH_DIR" >&2
  fi
  
  if [ ! -f "$CONTEXT_FILE" ]; then
    echo '{"tasks": []}' > "$CONTEXT_FILE"
    echo "Initialized context file: $CONTEXT_FILE" >&2
  fi
}

# ---- Task State Management ----------------------------------------

# Get tasks that are ready to be worked on (not done, not blocked)
# Returns JSON array of tasks
# Usage: get_ready_tasks
get_ready_tasks() {
  init_context
  
  if [ ! -f "$CONTEXT_FILE" ]; then
    echo "[]"
    return
  fi
  
  local all_tasks
  all_tasks=$(jq -r '.tasks' "$CONTEXT_FILE" 2>/dev/null || echo "[]")
  
  # Filter for tasks that are:
  # 1. Not done (passes == false)
  # 2. Not blocked (all blockedBy tasks have passes == true)
  jq -r --argjson tasks "$all_tasks" '
    $tasks | map(
      select(.passes == false) |
      . as $task |
      select(
        if ($task.blockedBy | length) > 0 then
          all(
            $task.blockedBy[];
            . as $dep_id |
            ($tasks | map(select(.id == $dep_id and .passes == true)) | length) > 0
          )
        else
          true
        end
      )
    )' <<< "$all_tasks"
}

# Update a task's state
# Usage: update_task <task_id> <passes_value>
# Example: update_task "US-001" true
update_task() {
  local task_id="$1"
  local passes="$2"
  
  init_context
  
  if [ ! -f "$CONTEXT_FILE" ]; then
    echo "Error: Context file not found" >&2
    return 1
  fi
  
  # Update the task's passes field
  local updated
  updated=$(jq --arg id "$task_id" --argjson passes "$passes" '
    .tasks |= map(
      if .id == $id then
        .passes = $passes
      else
        .
      end
    )
  ' "$CONTEXT_FILE")
  
  echo "$updated" > "$CONTEXT_FILE"
  echo "Updated task $task_id: passes=$passes" >&2
}

# Create a new discovered task
# Usage: create_discovered_task <id> <title> <description> <priority> [blockedBy...]
# Example: create_discovered_task "US-NEW" "New Feature" "Description" 5 "US-001" "US-002"
create_discovered_task() {
  local task_id="$1"
  local title="$2"
  local description="$3"
  local priority="$4"
  shift 4
  local blocked_by=("$@")
  
  init_context
  
  # Build blockedBy array
  local blocked_json="[]"
  if [ ${#blocked_by[@]} -gt 0 ]; then
    blocked_json=$(printf '%s\n' "${blocked_by[@]}" | jq -R . | jq -s .)
  fi
  
  # Create new task object
  local new_task
  new_task=$(jq -n \
    --arg id "$task_id" \
    --arg title "$title" \
    --arg description "$description" \
    --argjson priority "$priority" \
    --argjson blockedBy "$blocked_json" \
    '{
      id: $id,
      title: $title,
      description: $description,
      priority: $priority,
      blockedBy: $blockedBy,
      passes: false,
      notes: ""
    }')
  
  # Add to context
  local updated
  updated=$(jq --argjson task "$new_task" '.tasks += [$task]' "$CONTEXT_FILE")
  echo "$updated" > "$CONTEXT_FILE"
  
  echo "Created new task: $task_id" >&2
}

# ---- PRD Integration ----------------------------------------------

# Import an existing prd.json into context format
# Usage: import_prd <prd_file_path>
# Example: import_prd "prd.json"
import_prd() {
  local prd_file="$1"
  
  if [ ! -f "$prd_file" ]; then
    echo "Error: PRD file not found: $prd_file" >&2
    return 1
  fi
  
  init_context
  
  # Extract userStories and store as tasks
  local tasks
  tasks=$(jq '.userStories' "$prd_file")
  
  # Create context with tasks
  jq -n --argjson tasks "$tasks" '{tasks: $tasks}' > "$CONTEXT_FILE"
  
  echo "Imported $(echo "$tasks" | jq 'length') tasks from $prd_file" >&2
}

# ---- Helper Functions ---------------------------------------------

# Get task by ID
# Usage: get_task <task_id>
get_task() {
  local task_id="$1"
  
  init_context
  
  jq -r --arg id "$task_id" '.tasks[] | select(.id == $id)' "$CONTEXT_FILE"
}

# List all tasks
# Usage: list_tasks
list_tasks() {
  init_context
  
  jq -r '.tasks' "$CONTEXT_FILE"
}

# Get count of incomplete tasks
# Usage: get_incomplete_count
get_incomplete_count() {
  init_context
  
  jq -r '[.tasks[] | select(.passes == false)] | length' "$CONTEXT_FILE"
}
