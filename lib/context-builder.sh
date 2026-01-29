#!/usr/bin/env bash
# Context builder for dynamic context injection
# Builds relevant context for current task based on keywords
# Supports budget-aware mode via dynamic-context.sh

# Script directory for loading dynamic context library
CONTEXT_BUILDER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Context mode: "standard" (default) or "dynamic"
CONTEXT_MODE=${RALPH_CONTEXT_MODE:-standard}

# Extract keywords from text (title and description)
extract_keywords() {
  local text="$1"
  
  # Convert to lowercase, split on whitespace and common separators
  # Remove common words and keep meaningful terms
  echo "$text" | \
    tr '[:upper:]' '[:lower:]' | \
    tr -cs '[:alnum:]' '\n' | \
    grep -v -E '^(the|and|or|of|to|a|an|in|on|at|for|with|as|by|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|should|could|may|might|can|must|i|want|so|that)$' | \
    grep -E '^.{3,}$' | \
    sort | uniq
}

# Search The Pin for matching modules
search_pin() {
  local keywords="$1"
  local pin_file="${2:-specs/INDEX.md}"
  
  if [[ ! -f "$pin_file" ]]; then
    return 0
  fi
  
  # Extract module sections that match any keyword
  local current_module=""
  local matches=""
  
  while IFS= read -r keyword; do
    # Search for keyword in Pin (case insensitive)
    if grep -qi "$keyword" "$pin_file" 2>/dev/null; then
      # Extract module name from matched lines
      local matched_modules=$(grep -i "$keyword" "$pin_file" | \
        grep -B 5 "^###" | \
        grep "^###" | \
        sed 's/^### //' | \
        sort | uniq)
      
      if [[ -n "$matched_modules" ]]; then
        matches="$matches$matched_modules"$'\n'
      fi
    fi
  done <<< "$keywords"
  
  # Return unique module names
  echo "$matches" | sort | uniq | head -n 5
}

# Extract module content from The Pin
get_module_content() {
  local module_name="$1"
  local pin_file="${2:-specs/INDEX.md}"
  
  if [[ ! -f "$pin_file" ]]; then
    return 0
  fi
  
  # Extract content between "### module_name" and next "---"
  awk -v module="### $module_name" '
    $0 ~ module { found=1; print; next }
    found && /^---$/ { found=0 }
    found { print }
  ' "$pin_file"
}

# Build context for current task
# Returns: Pin index + matching module details + recent progress + patterns
build_context() {
  local task_title="$1"
  local task_description="$2"
  local pin_file="${3:-specs/INDEX.md}"
  local progress_file="${4:-progress.txt}"
  local output=""
  
  # Extract keywords from task
  local keywords=$(extract_keywords "$task_title $task_description")
  
  # Add Pin index header (first 30 lines)
  output+="## Discovery Index (The Pin)"$'\n'
  output+=""$'\n'
  if [[ -f "$pin_file" ]]; then
    output+=$(head -n 30 "$pin_file")
    output+=$'\n'$'\n'
  fi
  
  # Search Pin for matching modules
  local matching_modules=$(search_pin "$keywords" "$pin_file")
  
  if [[ -n "$matching_modules" ]]; then
    output+="## Relevant Modules (matched by keywords)"$'\n'
    output+=""$'\n'
    
    while IFS= read -r module; do
      if [[ -n "$module" ]]; then
        output+="### $module"$'\n'
        output+=$(get_module_content "$module" "$pin_file" | head -n 100)
        output+=$'\n'$'\n'
      fi
    done <<< "$matching_modules"
  fi
  
  # Add codebase patterns from progress.txt
  if [[ -f "$progress_file" ]]; then
    output+="## Codebase Patterns"$'\n'
    output+=""$'\n'
    # Extract patterns section (everything until first "## Date" entry)
    output+=$(awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {exit} {print}' "$progress_file" | head -n 50)
    output+=$'\n'$'\n'
    
    # Add recent progress (last 50 lines)
    output+="## Recent Progress"$'\n'
    output+=""$'\n'
    output+=$(tail -n 50 "$progress_file")
    output+=$'\n'
  fi
  
  echo "$output"
}

# Inject context into prompt
# Takes base prompt and prepends relevant context
inject_context() {
  local base_prompt="$1"
  local task_title="$2"
  local task_description="$3"
  local pin_file="${4:-specs/INDEX.md}"
  local progress_file="${5:-progress.txt}"

  local context=$(build_context "$task_title" "$task_description" "$pin_file" "$progress_file")

  # Build enhanced prompt
  echo "# CONTEXT FOR CURRENT TASK"
  echo ""
  echo "$context"
  echo ""
  echo "---"
  echo ""
  echo "# YOUR TASK"
  echo ""
  echo "$base_prompt"
}

# ---- Dynamic Context Integration ----------------------------------

# Smart context builder that uses dynamic mode when enabled
# Usage: smart_build_context <task_title> <task_description> [pin_file] [progress_file]
smart_build_context() {
  local task_title="$1"
  local task_description="$2"
  local pin_file="${3:-specs/INDEX.md}"
  local progress_file="${4:-progress.txt}"

  if [ "$CONTEXT_MODE" = "dynamic" ]; then
    # Load dynamic context library if not already loaded
    if ! type build_dynamic_context >/dev/null 2>&1; then
      if [ -f "$CONTEXT_BUILDER_SCRIPT_DIR/dynamic-context.sh" ]; then
        source "$CONTEXT_BUILDER_SCRIPT_DIR/dynamic-context.sh"
      else
        echo "Warning: dynamic-context.sh not found, using standard mode" >&2
        build_context "$task_title" "$task_description" "$pin_file" "$progress_file"
        return
      fi
    fi

    build_dynamic_context "$task_title" "$task_description" "$pin_file" "$progress_file"
  else
    # Standard context building
    build_context "$task_title" "$task_description" "$pin_file" "$progress_file"
  fi
}

# Smart inject context that uses dynamic mode when enabled
# Usage: smart_inject_context <base_prompt> <task_title> <task_description> [pin_file] [progress_file]
smart_inject_context() {
  local base_prompt="$1"
  local task_title="$2"
  local task_description="$3"
  local pin_file="${4:-specs/INDEX.md}"
  local progress_file="${5:-progress.txt}"

  local context=$(smart_build_context "$task_title" "$task_description" "$pin_file" "$progress_file")

  # Build enhanced prompt
  echo "# CONTEXT FOR CURRENT TASK"
  echo ""
  echo "$context"
  echo ""
  echo "---"
  echo ""
  echo "# YOUR TASK"
  echo ""
  echo "$base_prompt"
}
