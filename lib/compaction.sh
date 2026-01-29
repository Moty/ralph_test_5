#!/usr/bin/env bash
# Memory compaction library for Ralph
# Automatically compacts progress.txt when it exceeds threshold
# Supports two modes: line-based (default) and semantic (relevance-based)

# Default threshold in lines (configurable)
COMPACTION_THRESHOLD=${RALPH_COMPACTION_THRESHOLD:-400}

# Number of lines to preserve from start (patterns section)
PRESERVE_START=${RALPH_PRESERVE_START:-50}

# Number of lines to preserve from end (recent entries)
PRESERVE_END=${RALPH_PRESERVE_END:-200}

# Compaction mode: "line" (default) or "semantic"
COMPACTION_MODE=${RALPH_COMPACTION_MODE:-line}

# Script directory for loading semantic compaction
COMPACTION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Compact progress.txt if it exceeds threshold
# Preserves patterns section and recent entries
# Summarizes middle section to key bullet points
compact_progress() {
  local progress_file="${1:-progress.txt}"
  local compaction_log=".ralph/compaction.log"
  
  # Ensure .ralph directory exists
  mkdir -p .ralph
  
  # Check if file exists
  if [[ ! -f "$progress_file" ]]; then
    echo "Progress file not found: $progress_file" >&2
    return 1
  fi
  
  # Count lines in progress file
  local line_count=$(wc -l < "$progress_file" | tr -d ' ')
  
  # Check if compaction is needed
  if [[ $line_count -le $COMPACTION_THRESHOLD ]]; then
    return 0
  fi
  
  # Log compaction action
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] Compacting $progress_file ($line_count lines -> ~$(($PRESERVE_START + $PRESERVE_END + 20)) lines)" >> "$compaction_log"
  
  # Create temporary files
  local temp_file=$(mktemp)
  local middle_file=$(mktemp)
  
  # Extract start section (patterns)
  head -n "$PRESERVE_START" "$progress_file" > "$temp_file"
  
  # Calculate middle section range
  local middle_start=$(($PRESERVE_START + 1))
  local middle_end=$(($line_count - $PRESERVE_END))
  local middle_lines=$(($middle_end - $middle_start + 1))
  
  # Extract and summarize middle section if it exists
  if [[ $middle_lines -gt 0 ]]; then
    echo "" >> "$temp_file"
    echo "## Compacted History Summary" >> "$temp_file"
    echo "Automatically compacted on $timestamp" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Extract middle section
    tail -n "+$middle_start" "$progress_file" | head -n "$middle_lines" > "$middle_file"
    
    # Extract story IDs and titles from middle section
    grep -E '^## [0-9]{4}-[0-9]{2}-[0-9]{2} .* - US-' "$middle_file" | while IFS= read -r line; do
      # Extract story ID
      local story_id=$(echo "$line" | grep -oE 'US-[0-9]+')
      if [[ -n "$story_id" ]]; then
        echo "- Completed: $story_id" >> "$temp_file"
      fi
    done
    
    # Add key learnings from middle section
    echo "" >> "$temp_file"
    echo "**Key Learnings from compacted section:**" >> "$temp_file"
    grep -A 10 '^\*\*Learnings for future iterations:\*\*' "$middle_file" | \
      grep -E '^\s*-' | \
      head -n 10 >> "$temp_file" || true
    
    echo "" >> "$temp_file"
    echo "---" >> "$temp_file"
  fi
  
  # Extract end section (recent entries)
  tail -n "$PRESERVE_END" "$progress_file" >> "$temp_file"
  
  # Backup original file
  cp "$progress_file" "${progress_file}.backup.$(date '+%Y%m%d_%H%M%S')"
  
  # Replace original with compacted version
  mv "$temp_file" "$progress_file"
  
  # Clean up
  rm -f "$middle_file"
  
  # Log completion
  local new_line_count=$(wc -l < "$progress_file" | tr -d ' ')
  echo "[$timestamp] Compaction complete. New size: $new_line_count lines" >> "$compaction_log"
  
  return 0
}

# Pre-iteration hook for Ralph
# Call this before each iteration to check and compact if needed
# Uses semantic mode if RALPH_COMPACTION_MODE=semantic
pre_iteration_compact() {
  local progress_file="${1:-progress.txt}"
  local keywords="${2:-}"

  if [ "$COMPACTION_MODE" = "semantic" ]; then
    # Load semantic compaction library if not already loaded
    if ! type do_semantic_compact >/dev/null 2>&1; then
      if [ -f "$COMPACTION_SCRIPT_DIR/semantic-compaction.sh" ]; then
        source "$COMPACTION_SCRIPT_DIR/semantic-compaction.sh"
      else
        echo "Warning: semantic-compaction.sh not found, falling back to line mode" >&2
        compact_progress "$progress_file"
        return
      fi
    fi

    # Get keywords from current task if not provided
    if [ -z "$keywords" ] && type get_current_task_keywords >/dev/null 2>&1; then
      keywords=$(get_current_task_keywords)
    fi

    do_semantic_compact "$progress_file" "$keywords"
  else
    # Default line-based compaction
    compact_progress "$progress_file"
  fi
}

# Force line-based compaction regardless of mode
# Usage: force_line_compact <progress_file>
force_line_compact() {
  local progress_file="${1:-progress.txt}"
  compact_progress "$progress_file"
}

# Force semantic compaction regardless of mode
# Usage: force_semantic_compact <progress_file> [keywords]
force_semantic_compact() {
  local progress_file="${1:-progress.txt}"
  local keywords="${2:-}"

  if ! type do_semantic_compact >/dev/null 2>&1; then
    if [ -f "$COMPACTION_SCRIPT_DIR/semantic-compaction.sh" ]; then
      source "$COMPACTION_SCRIPT_DIR/semantic-compaction.sh"
    else
      echo "Error: semantic-compaction.sh not found" >&2
      return 1
    fi
  fi

  do_semantic_compact "$progress_file" "$keywords"
}
