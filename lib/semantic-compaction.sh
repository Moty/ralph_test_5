#!/usr/bin/env bash
# Semantic compaction library for Ralph
# Provides relevance-based compression of progress.txt
# Preserves high-value entries based on content scoring

# ---- Configuration ------------------------------------------------

# Weights for different entry types (higher = more important)
WEIGHT_PATTERN=10      # Pattern markers: [PATTERN], pattern, always, never, convention
WEIGHT_GOTCHA=8        # Error/gotcha markers: [GOTCHA], gotcha, fix, avoid, bug, error
WEIGHT_INTEGRATION=7   # Dependency markers: [INTEGRATION], depends, requires, integration
WEIGHT_RECENT=5        # Recent entries (within last 3 iterations)
WEIGHT_KEYWORD=2       # Match with current task keywords

# Minimum score to preserve an entry
MIN_SCORE_THRESHOLD=${RALPH_MIN_SCORE_THRESHOLD:-5}

# ---- Scoring Functions --------------------------------------------

# Score a single entry based on relevance markers
# Usage: score_entry_markers <entry_text>
# Returns: numeric score
score_entry_markers() {
  local entry="$1"
  local score=0

  # Pattern indicators (highest priority - these are reusable knowledge)
  if echo "$entry" | grep -qiE '\[PATTERN\]|^-.*pattern|always use|never use|convention'; then
    score=$((score + WEIGHT_PATTERN))
  fi

  # Error/gotcha indicators (high priority - prevents repeating mistakes)
  if echo "$entry" | grep -qiE '\[GOTCHA\]|gotcha|fix:|avoid|bug|error|warning|careful|important'; then
    score=$((score + WEIGHT_GOTCHA))
  fi

  # Integration/dependency indicators (medium-high priority)
  if echo "$entry" | grep -qiE '\[INTEGRATION\]|depends on|requires|integration|connected to|coupled with'; then
    score=$((score + WEIGHT_INTEGRATION))
  fi

  # API/schema changes (medium priority - often referenced)
  if echo "$entry" | grep -qiE 'api|endpoint|schema|migration|database|model'; then
    score=$((score + 4))
  fi

  # Configuration changes
  if echo "$entry" | grep -qiE 'config|setting|environment|env var|variable'; then
    score=$((score + 3))
  fi

  echo "$score"
}

# Score an entry based on keyword matches with current task
# Usage: score_entry_keywords <entry_text> <keywords_file_or_string>
# Returns: numeric score (WEIGHT_KEYWORD per match, max 6)
score_entry_keywords() {
  local entry="$1"
  local keywords="$2"
  local score=0
  local match_count=0

  # Read keywords (can be newline-separated or space-separated)
  while IFS= read -r keyword || [ -n "$keyword" ]; do
    if [ -n "$keyword" ] && echo "$entry" | grep -qi "$keyword"; then
      match_count=$((match_count + 1))
    fi
  done <<< "$(echo "$keywords" | tr ' ' '\n' | grep -v '^$')"

  # Cap at 3 keyword matches to avoid over-weighting
  if [ $match_count -gt 3 ]; then
    match_count=3
  fi

  score=$((match_count * WEIGHT_KEYWORD))
  echo "$score"
}

# Calculate total score for an entry
# Usage: score_entry <entry_text> <current_keywords>
# Returns: total numeric score
score_entry() {
  local entry="$1"
  local keywords="${2:-}"

  local marker_score=$(score_entry_markers "$entry")
  local keyword_score=0

  if [ -n "$keywords" ]; then
    keyword_score=$(score_entry_keywords "$entry" "$keywords")
  fi

  echo $((marker_score + keyword_score))
}

# ---- Entry Parsing ------------------------------------------------

# Parse progress.txt into sections
# Returns entries with their section boundaries
parse_progress_sections() {
  local progress_file="$1"

  if [ ! -f "$progress_file" ]; then
    return 1
  fi

  # Extract date-based sections (## YYYY-MM-DD format)
  awk '
    /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      if (section != "") {
        print section_start ":" NR-1 ":" section
      }
      section_start = NR
      section = $0
      next
    }
    /^---$/ {
      if (section != "") {
        print section_start ":" NR ":" section
        section = ""
      }
      next
    }
    section != "" {
      section = section "\n" $0
    }
  ' "$progress_file"
}

# ---- Semantic Compaction ------------------------------------------

# Perform semantic compaction on progress.txt
# Usage: semantic_compact_progress <progress_file> [keywords]
# Preserves: Patterns section, high-scoring entries, recent entries
semantic_compact_progress() {
  local progress_file="${1:-progress.txt}"
  local keywords="${2:-}"
  local compaction_log=".ralph/compaction.log"

  # Ensure .ralph directory exists
  mkdir -p .ralph

  if [ ! -f "$progress_file" ]; then
    echo "Progress file not found: $progress_file" >&2
    return 1
  fi

  local line_count=$(wc -l < "$progress_file" | tr -d ' ')

  # Get threshold from compaction.sh or default
  local threshold=${COMPACTION_THRESHOLD:-400}

  if [ "$line_count" -le "$threshold" ]; then
    return 0  # No compaction needed
  fi

  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] Semantic compaction triggered ($line_count lines)" >> "$compaction_log"

  # Create temporary files
  local temp_file=$(mktemp)
  local entries_file=$(mktemp)
  local scored_file=$(mktemp)

  # 1. Preserve the Codebase Patterns section (everything before first ## date entry)
  awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {exit} {print}' "$progress_file" > "$temp_file"

  # 2. Extract all date-based entries
  awk '
    /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      if (entry != "") {
        # Print previous entry with line range
        print start_line ":" NR-1 ":" entry
      }
      start_line = NR
      entry = $0
      next
    }
    /^---$/ {
      if (entry != "") {
        entry = entry "\n---"
        print start_line ":" NR ":" entry
        entry = ""
      }
      next
    }
    entry != "" {
      entry = entry "\n" $0
    }
    END {
      if (entry != "") {
        print start_line ":" NR ":" entry
      }
    }
  ' "$progress_file" > "$entries_file"

  # 3. Score each entry
  local total_entries=0
  local kept_entries=0

  while IFS=':' read -r start_line end_line entry; do
    if [ -z "$entry" ]; then
      continue
    fi

    total_entries=$((total_entries + 1))
    local score=$(score_entry "$entry" "$keywords")

    # Check if entry is recent (within last 3 entries based on position)
    local entries_from_end=$((total_entries))  # Will be adjusted after counting

    echo "$score:$start_line:$end_line:$entry" >> "$scored_file"
  done < "$entries_file"

  # 4. Determine which entries to keep
  # Keep: All entries scoring >= threshold, plus last 5 entries regardless of score
  local entry_count=$(wc -l < "$scored_file" | tr -d ' ')

  # Add recent entry bonus
  local line_num=0
  local temp_scored=$(mktemp)

  while IFS=':' read -r score start_line end_line entry; do
    line_num=$((line_num + 1))
    local entries_from_end=$((entry_count - line_num))

    # Boost recent entries
    if [ $entries_from_end -lt 3 ]; then
      score=$((score + WEIGHT_RECENT))
    fi

    echo "$score:$start_line:$end_line:$entry" >> "$temp_scored"
  done < "$scored_file"

  mv "$temp_scored" "$scored_file"

  # 5. Build compacted output
  echo "" >> "$temp_file"
  echo "## Compacted History (Semantic)" >> "$temp_file"
  echo "Compacted on $timestamp using relevance scoring" >> "$temp_file"
  echo "" >> "$temp_file"

  # Collect low-scoring entries summary
  local low_score_stories=""

  while IFS=':' read -r score start_line end_line entry; do
    if [ $score -ge $MIN_SCORE_THRESHOLD ]; then
      # Keep high-scoring entry
      echo "$entry" >> "$temp_file"
      echo "" >> "$temp_file"
      kept_entries=$((kept_entries + 1))
    else
      # Extract story ID from low-scoring entry for summary
      local story_id=$(echo "$entry" | grep -oE 'US-[0-9]+' | head -n 1)
      if [ -n "$story_id" ]; then
        low_score_stories="$low_score_stories- Completed: $story_id (score: $score)\n"
      fi
    fi
  done < "$scored_file"

  # Add summary of compacted (low-scoring) entries
  if [ -n "$low_score_stories" ]; then
    echo "**Compacted entries (low relevance):**" >> "$temp_file"
    echo -e "$low_score_stories" >> "$temp_file"
    echo "" >> "$temp_file"
  fi

  echo "---" >> "$temp_file"

  # 6. Backup and replace
  cp "$progress_file" "${progress_file}.backup.$(date '+%Y%m%d_%H%M%S')"
  mv "$temp_file" "$progress_file"

  # Cleanup
  rm -f "$entries_file" "$scored_file"

  # Log results
  local new_line_count=$(wc -l < "$progress_file" | tr -d ' ')
  echo "[$timestamp] Semantic compaction complete: $total_entries -> $kept_entries entries, $line_count -> $new_line_count lines" >> "$compaction_log"

  echo "Semantic compaction: kept $kept_entries/$total_entries entries (score >= $MIN_SCORE_THRESHOLD)" >&2
}

# ---- Integration with compaction.sh -------------------------------

# Wrapper function that can be called by pre_iteration_compact
# when RALPH_COMPACTION_MODE=semantic
do_semantic_compact() {
  local progress_file="${1:-progress.txt}"
  local keywords="${2:-}"

  semantic_compact_progress "$progress_file" "$keywords"
}

# Extract keywords from current task for relevance scoring
# Usage: get_current_task_keywords
get_current_task_keywords() {
  if [ ! -f "prd.json" ]; then
    return
  fi

  # Get the current incomplete story with highest priority
  local story=$(jq -r '
    [.userStories[] | select(.passes == false)]
    | sort_by(.priority)
    | .[0]
    | "\(.title // "") \(.description // "")"
  ' prd.json 2>/dev/null || echo "")

  if [ -n "$story" ]; then
    # Extract meaningful keywords (simplified version)
    echo "$story" | \
      tr '[:upper:]' '[:lower:]' | \
      tr -cs '[:alnum:]' '\n' | \
      grep -v -E '^(the|and|or|of|to|a|an|in|on|at|for|with|as|by|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|should|could|may|might|can|must|i|want|so|that|user|story)$' | \
      grep -E '^.{3,}$' | \
      sort | uniq | \
      head -n 10
  fi
}
