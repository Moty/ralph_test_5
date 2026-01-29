#!/usr/bin/env bash
# Dynamic context management library for Ralph
# Provides budget-aware context building with priority levels
# Prevents context overflow while preserving critical information

# ---- Configuration ------------------------------------------------

# Approximate token budget (default ~100k tokens)
# Note: This is approximate - 1 token ≈ 4 characters for estimation
CONTEXT_BUDGET=${RALPH_CONTEXT_BUDGET:-100000}

# Approximate characters per token (for estimation)
CHARS_PER_TOKEN=4

# Priority levels for context sections (higher = more important, never remove)
PRIORITY_SYSTEM_INSTRUCTIONS=100   # Never remove
PRIORITY_CURRENT_TASK=95           # Never remove
PRIORITY_PATTERNS=90               # High priority
PRIORITY_RECENT_PROGRESS=80        # High priority
PRIORITY_PIN_INDEX=70              # Medium priority
PRIORITY_MATCHED_SPECS=60          # Medium priority
PRIORITY_OLDER_PROGRESS=40         # Lower priority
PRIORITY_FULL_SPECS=30             # Lowest priority (expand on demand)

# ---- Token Estimation ---------------------------------------------

# Estimate token count for text
# Usage: estimate_tokens <text>
# Returns: approximate token count
estimate_tokens() {
  local text="$1"

  if [ -z "$text" ]; then
    echo 0
    return
  fi

  local char_count=${#text}
  local tokens=$((char_count / CHARS_PER_TOKEN))

  # Minimum 1 token for non-empty text
  if [ $tokens -eq 0 ] && [ $char_count -gt 0 ]; then
    tokens=1
  fi

  echo $tokens
}

# Estimate tokens in a file
# Usage: estimate_file_tokens <file_path>
estimate_file_tokens() {
  local file_path="$1"

  if [ ! -f "$file_path" ]; then
    echo 0
    return
  fi

  local char_count=$(wc -c < "$file_path" | tr -d ' ')
  echo $((char_count / CHARS_PER_TOKEN))
}

# ---- Context Section Management -----------------------------------

# Build context section with tracking
# Usage: build_section <name> <priority> <content>
# Returns: section with metadata comment
build_section() {
  local name="$1"
  local priority="$2"
  local content="$3"

  if [ -z "$content" ]; then
    return
  fi

  local tokens=$(estimate_tokens "$content")

  echo "<!-- CONTEXT_SECTION: $name | priority: $priority | tokens: ~$tokens -->"
  echo "$content"
  echo "<!-- END_SECTION: $name -->"
}

# ---- Budget-Aware Context Building --------------------------------

# Build context with budget constraints
# Usage: build_context_with_budget <task_title> <task_description> [budget]
# Includes sections by priority until budget is exhausted
build_context_with_budget() {
  local task_title="$1"
  local task_description="$2"
  local budget="${3:-$CONTEXT_BUDGET}"
  local pin_file="${4:-specs/INDEX.md}"
  local progress_file="${5:-progress.txt}"

  local total_tokens=0
  local output=""

  # Helper to add section if within budget
  add_if_budget() {
    local name="$1"
    local priority="$2"
    local content="$3"
    local required="${4:-false}"

    local tokens=$(estimate_tokens "$content")

    if [ "$required" = "true" ] || [ $((total_tokens + tokens)) -le $budget ]; then
      output+="## $name"$'\n\n'
      output+="$content"$'\n\n'
      total_tokens=$((total_tokens + tokens))
      return 0
    else
      return 1
    fi
  }

  # 1. REQUIRED: Current task (priority 95) - always included
  local task_section="**Title:** $task_title"$'\n'
  task_section+="**Description:** $task_description"$'\n'
  add_if_budget "Current Task" $PRIORITY_CURRENT_TASK "$task_section" true

  # 2. REQUIRED: Codebase patterns from progress.txt (priority 90)
  if [ -f "$progress_file" ]; then
    local patterns=$(awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {exit} {print}' "$progress_file" 2>/dev/null | head -n 80)
    if [ -n "$patterns" ]; then
      add_if_budget "Codebase Patterns" $PRIORITY_PATTERNS "$patterns" true
    fi
  fi

  # 3. HIGH: Recent progress (priority 80) - last 100 lines
  if [ -f "$progress_file" ]; then
    local recent=$(tail -n 100 "$progress_file" 2>/dev/null)
    if [ -n "$recent" ]; then
      add_if_budget "Recent Progress" $PRIORITY_RECENT_PROGRESS "$recent"
    fi
  fi

  # 4. MEDIUM: Pin index header (priority 70) - first 40 lines
  if [ -f "$pin_file" ]; then
    local pin_header=$(head -n 40 "$pin_file" 2>/dev/null)
    if [ -n "$pin_header" ]; then
      add_if_budget "Discovery Index (The Pin)" $PRIORITY_PIN_INDEX "$pin_header"
    fi
  fi

  # 5. MEDIUM: Matched specs from keywords (priority 60)
  if [ -f "$pin_file" ]; then
    # Extract keywords from task
    local keywords=$(echo "$task_title $task_description" | \
      tr '[:upper:]' '[:lower:]' | \
      tr -cs '[:alnum:]' '\n' | \
      grep -v -E '^(the|and|or|of|to|a|an|in|on|at|for|with|as|by|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|should|could|may|might|can|must|i|want|so|that)$' | \
      grep -E '^.{3,}$' | \
      sort | uniq | \
      head -n 10)

    if [ -n "$keywords" ]; then
      local matched_content=""
      local match_count=0

      while IFS= read -r keyword; do
        if [ -n "$keyword" ] && grep -qi "$keyword" "$pin_file" 2>/dev/null; then
          # Find matching module sections (limited per keyword)
          local matches=$(grep -i -A 20 "### .*$keyword" "$pin_file" 2>/dev/null | head -n 60)
          if [ -n "$matches" ]; then
            matched_content+="**Matches for: $keyword**"$'\n'
            matched_content+="$matches"$'\n\n'
            match_count=$((match_count + 1))
            # Limit to 3 keyword matches to stay within budget
            if [ $match_count -ge 3 ]; then
              break
            fi
          fi
        fi
      done <<< "$keywords"

      if [ -n "$matched_content" ]; then
        add_if_budget "Relevant Modules (keyword matches)" $PRIORITY_MATCHED_SPECS "$matched_content"
      fi
    fi
  fi

  # 6. LOWER: Older progress entries (priority 40) - if budget allows
  if [ -f "$progress_file" ]; then
    local line_count=$(wc -l < "$progress_file" | tr -d ' ')
    if [ $line_count -gt 150 ]; then
      # Get middle section (after patterns, before recent)
      local older=$(tail -n +80 "$progress_file" 2>/dev/null | head -n 100)
      if [ -n "$older" ]; then
        add_if_budget "Earlier Progress" $PRIORITY_OLDER_PROGRESS "$older"
      fi
    fi
  fi

  # Add budget summary
  local remaining=$((budget - total_tokens))
  output+="---"$'\n'
  output+="*Context: ~$total_tokens tokens used, ~$remaining remaining of $budget budget*"$'\n'

  echo "$output"
}

# ---- Context Expansion (On-Demand) --------------------------------

# Handle agent request for additional context
# Usage: handle_context_request <type> <param>
# Types: spec (read full spec), file (read file), expand (expand section)
handle_context_request() {
  local request_type="$1"
  local param="$2"

  case "$request_type" in
    spec)
      # Read full spec from Pin
      local pin_file="${3:-specs/INDEX.md}"
      if [ -f "$pin_file" ]; then
        awk -v module="### $param" '
          $0 ~ module { found=1; print; next }
          found && /^---$/ { found=0 }
          found && /^### / { found=0 }
          found { print }
        ' "$pin_file"
      fi
      ;;

    file)
      # Read file content (limited)
      if [ -f "$param" ]; then
        head -n 200 "$param"
        local total=$(wc -l < "$param" | tr -d ' ')
        if [ $total -gt 200 ]; then
          echo "... ($((total - 200)) more lines)"
        fi
      else
        echo "File not found: $param"
      fi
      ;;

    progress)
      # Get more progress history
      local progress_file="${3:-progress.txt}"
      if [ -f "$progress_file" ]; then
        local offset="${param:-0}"
        tail -n "+$offset" "$progress_file" | head -n 100
      fi
      ;;

    *)
      echo "Unknown context request type: $request_type"
      return 1
      ;;
  esac
}

# ---- Budget Monitoring --------------------------------------------

# Check current context usage
# Usage: check_context_usage <context_text>
check_context_usage() {
  local context="$1"
  local budget="${2:-$CONTEXT_BUDGET}"

  local used=$(estimate_tokens "$context")
  local remaining=$((budget - used))
  local percent=$((used * 100 / budget))

  echo "Context usage: ~$used tokens ($percent% of $budget budget)"
  echo "Remaining: ~$remaining tokens"

  if [ $percent -gt 90 ]; then
    echo "WARNING: Context usage high (>90%)"
    return 1
  elif [ $percent -gt 75 ]; then
    echo "NOTE: Context usage elevated (>75%)"
  fi

  return 0
}

# Get compact context summary for status display
# Usage: get_context_summary
get_context_summary() {
  local pin_file="${1:-specs/INDEX.md}"
  local progress_file="${2:-progress.txt}"

  local pin_tokens=0
  local progress_tokens=0

  if [ -f "$pin_file" ]; then
    pin_tokens=$(estimate_file_tokens "$pin_file")
  fi

  if [ -f "$progress_file" ]; then
    progress_tokens=$(estimate_file_tokens "$progress_file")
  fi

  echo "Pin: ~$pin_tokens tokens | Progress: ~$progress_tokens tokens"
}

# ---- Integration with context-builder.sh --------------------------

# Drop-in replacement for build_context when dynamic mode is desired
# Usage: build_dynamic_context <task_title> <task_description> [pin_file] [progress_file]
build_dynamic_context() {
  local task_title="$1"
  local task_description="$2"
  local pin_file="${3:-specs/INDEX.md}"
  local progress_file="${4:-progress.txt}"

  build_context_with_budget "$task_title" "$task_description" "$CONTEXT_BUDGET" "$pin_file" "$progress_file"
}
