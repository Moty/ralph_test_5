#!/bin/bash
# Ralph Rotation Library - Intelligent model/agent rotation on failures and rate limits
# Source this file from ralph.sh: source "$SCRIPT_DIR/lib/rotation.sh"
#
# Bash 3.2 compatible (no associative arrays)

# ---- Configuration ------------------------------------------------

ROTATION_STATE_DIR="${SCRIPT_DIR:-.}/.ralph"
ROTATION_STATE_FILE="$ROTATION_STATE_DIR/rotation-state.json"

# ---- Config Readers -----------------------------------------------

is_rotation_enabled() {
  local enabled=$(yq '.rotation.enabled // "false"' "$AGENT_CONFIG" 2>/dev/null)
  [ "$enabled" = "true" ]
}

get_failure_threshold() {
  yq '.rotation.failure-threshold // 2' "$AGENT_CONFIG" 2>/dev/null || echo "2"
}

get_rate_limit_cooldown() {
  yq '.rotation.rate-limit-cooldown // 300' "$AGENT_CONFIG" 2>/dev/null || echo "300"
}

get_rotation_strategy() {
  yq '.rotation.strategy // "sequential"' "$AGENT_CONFIG" 2>/dev/null || echo "sequential"
}

get_agent_models() {
  local agent="$1"
  local models=$(yq ".[\"$agent\"].models[]?" "$AGENT_CONFIG" 2>/dev/null)
  if [ -z "$models" ]; then
    # Fallback to single model field
    local single_model=$(yq ".[\"$agent\"].model // \"\"" "$AGENT_CONFIG" 2>/dev/null)
    if [ -n "$single_model" ] && [ "$single_model" != "null" ]; then
      echo "$single_model"
    fi
  else
    echo "$models"
  fi
}

get_agent_rotation_list() {
  local list=$(yq '.agent-rotation[]?' "$AGENT_CONFIG" 2>/dev/null)
  if [ -z "$list" ]; then
    # Fallback: primary then fallback
    local primary=$(yq '.agent.primary // ""' "$AGENT_CONFIG" 2>/dev/null)
    local fallback=$(yq '.agent.fallback // ""' "$AGENT_CONFIG" 2>/dev/null)
    [ -n "$primary" ] && [ "$primary" != "null" ] && echo "$primary"
    [ -n "$fallback" ] && [ "$fallback" != "null" ] && echo "$fallback"
  else
    echo "$list"
  fi
}

get_command_agent_rotation() {
  local cmd="$1"
  local list=$(yq ".commands.[\"$cmd\"].agent-rotation[]?" "$AGENT_CONFIG" 2>/dev/null)
  if [ -n "$list" ]; then
    echo "$list"
  else
    get_agent_rotation_list
  fi
}

get_command_dangerous_permissions() {
  local cmd="$1"
  local val=$(yq ".commands.[\"$cmd\"].dangerous-permissions // \"true\"" "$AGENT_CONFIG" 2>/dev/null)
  [ "$val" = "true" ]
}

# ---- State Management ---------------------------------------------

init_rotation_state() {
  mkdir -p "$ROTATION_STATE_DIR"
  if [ ! -f "$ROTATION_STATE_FILE" ]; then
    cat > "$ROTATION_STATE_FILE" << 'EOF'
{
  "version": 1,
  "current_agent_index": 0,
  "current_model_indices": {},
  "rate_limits": {},
  "stories": {},
  "usage": {},
  "rotations_count": 0,
  "rate_limits_count": 0
}
EOF
    log_debug "Initialized rotation state file" 2>/dev/null || true
  fi
}

get_current_agent_index() {
  jq -r '.current_agent_index // 0' "$ROTATION_STATE_FILE" 2>/dev/null || echo "0"
}

get_current_model_index() {
  local agent="$1"
  jq -r ".current_model_indices[\"$agent\"] // 0" "$ROTATION_STATE_FILE" 2>/dev/null || echo "0"
}

set_current_agent_index() {
  local index="$1"
  local tmp="${ROTATION_STATE_FILE}.tmp"
  jq ".current_agent_index = $index" "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"
}

set_current_model_index() {
  local agent="$1"
  local index="$2"
  local tmp="${ROTATION_STATE_FILE}.tmp"
  jq ".current_model_indices[\"$agent\"] = $index" "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"
}

# ---- Agent/Model Selection ----------------------------------------

select_agent_and_model() {
  local story_id="$1"
  local command="${2:-build}"

  if ! is_rotation_enabled; then
    # Return default agent and model (no rotation)
    local agent=$(yq '.agent.primary // "claude-code"' "$AGENT_CONFIG" 2>/dev/null)
    local model=""
    case "$agent" in
      claude-code) model=$(yq '.claude-code.model // "claude-sonnet-4-5-20250929"' "$AGENT_CONFIG" 2>/dev/null) ;;
      github-copilot) model=$(yq '.github-copilot.model // "auto"' "$AGENT_CONFIG" 2>/dev/null) ;;
      gemini) model=$(yq '.gemini.model // "gemini-3-pro"' "$AGENT_CONFIG" 2>/dev/null) ;;
      codex) model=$(yq '.codex.model // "gpt-5.2-codex"' "$AGENT_CONFIG" 2>/dev/null) ;;
    esac
    echo "${agent}|${model}"
    return
  fi

  init_rotation_state

  # Get rotation list (command-specific or global)
  local rotation_list
  rotation_list=$(get_command_agent_rotation "$command")
  local agent_count=0
  local agents_arr=""
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    agent_count=$((agent_count + 1))
    agents_arr="${agents_arr}${a}
"
  done <<< "$rotation_list"

  if [ "$agent_count" -eq 0 ]; then
    echo "claude-code|claude-sonnet-4-5-20250929"
    return
  fi

  local strategy=$(get_rotation_strategy)
  local agent_idx=$(get_current_agent_index)
  if [ "$agent_idx" -ge "$agent_count" ]; then
    agent_idx=0
  fi

  local current_agent=""
  local selected_idx="$agent_idx"

  if [ "$strategy" = "priority" ]; then
    # Priority: pick the first available agent in the rotation list
    local idx=0
    while IFS= read -r candidate; do
      [ -z "$candidate" ] && continue
      if is_agent_cooled_down "$candidate"; then
        current_agent="$candidate"
        selected_idx="$idx"
        break
      fi
      log_debug "Agent $candidate in cooldown, skipping" 2>/dev/null || true
      idx=$((idx + 1))
    done <<< "$rotation_list"
  else
    # Sequential: start from current index and skip agents in cooldown
    current_agent=$(echo "$agents_arr" | sed -n "$((agent_idx + 1))p")
    local attempts=0
    while [ $attempts -lt $agent_count ]; do
      if is_agent_cooled_down "$current_agent"; then
        selected_idx="$agent_idx"
        break
      fi
      log_debug "Agent $current_agent in cooldown, skipping" 2>/dev/null || true
      agent_idx=$(( (agent_idx + 1) % agent_count ))
      current_agent=$(echo "$agents_arr" | sed -n "$((agent_idx + 1))p")
      attempts=$((attempts + 1))
    done

    if [ $attempts -ge $agent_count ]; then
      # All agents in cooldown, use the current index anyway
      agent_idx=$(get_current_agent_index)
      current_agent=$(echo "$agents_arr" | sed -n "$((agent_idx + 1))p")
      selected_idx="$agent_idx"
      log_warn "All agents in cooldown, using $current_agent anyway" 2>/dev/null || true
    fi
  fi

  if [ -z "$current_agent" ]; then
    current_agent=$(echo "$agents_arr" | sed -n "$((agent_idx + 1))p")
    selected_idx="$agent_idx"
    log_warn "No available agent found, using $current_agent" 2>/dev/null || true
  fi

  set_current_agent_index "$selected_idx"

  # Get current model for this agent
  local model_idx=$(get_current_model_index "$current_agent")
  local models_list
  models_list=$(get_agent_models "$current_agent")
  local model_count=0
  local models_arr=""
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    model_count=$((model_count + 1))
    models_arr="${models_arr}${m}
"
  done <<< "$models_list"

  local current_model=""
  if [ "$model_count" -gt 0 ]; then
    if [ "$model_idx" -ge "$model_count" ]; then
      model_idx=0
      set_current_model_index "$current_agent" 0
    fi
    current_model=$(echo "$models_arr" | sed -n "$((model_idx + 1))p")
  fi

  echo "${current_agent}|${current_model}"
}

# ---- Rotation Logic -----------------------------------------------

rotate_model() {
  local agent="$1"
  local command="$2"

  local models_list
  models_list=$(get_agent_models "$agent")
  local model_count=0
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    model_count=$((model_count + 1))
  done <<< "$models_list"

  if [ "$model_count" -le 1 ]; then
    # No more models to rotate to, rotate agent instead
    rotate_agent "$command"
    return $?
  fi

  local current_idx=$(get_current_model_index "$agent")
  local next_idx=$(( (current_idx + 1) % model_count ))

  if [ "$next_idx" -eq 0 ]; then
    # Wrapped around all models, rotate to next agent
    log_info "All models exhausted for $agent, rotating agent" 2>/dev/null || true
    rotate_agent "$command"
    return $?
  fi

  set_current_model_index "$agent" "$next_idx"
  local new_model=$(echo "$models_list" | sed -n "$((next_idx + 1))p")
  log_info "Rotated model for $agent: index $current_idx -> $next_idx ($new_model)" 2>/dev/null || true

  # Increment rotation counter
  local tmp="${ROTATION_STATE_FILE}.tmp"
  jq '.rotations_count = (.rotations_count // 0) + 1' "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"

  return 0
}

rotate_agent() {
  local command="$1"
  local rotation_list
  if [ -n "$command" ]; then
    rotation_list=$(get_command_agent_rotation "$command")
  else
    rotation_list=$(get_agent_rotation_list)
  fi
  local agent_count=0
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    agent_count=$((agent_count + 1))
  done <<< "$rotation_list"

  if [ "$agent_count" -le 1 ]; then
    log_warn "No agents available to rotate to" 2>/dev/null || true
    return 1
  fi

  local current_idx=$(get_current_agent_index)
  local next_idx=$(( (current_idx + 1) % agent_count ))

  set_current_agent_index "$next_idx"
  # Reset model index for new agent
  local new_agent=$(echo "$rotation_list" | sed -n "$((next_idx + 1))p")
  set_current_model_index "$new_agent" 0

  log_info "Rotated agent: index $current_idx -> $next_idx ($new_agent)" 2>/dev/null || true

  # Increment rotation counter
  local tmp="${ROTATION_STATE_FILE}.tmp"
  jq '.rotations_count = (.rotations_count // 0) + 1' "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"

  if [ "$next_idx" -eq 0 ]; then
    # Wrapped around all agents
    log_warn "All agents exhausted, wrapping to beginning" 2>/dev/null || true
    return 2
  fi

  return 0
}

should_rotate() {
  local story_id="$1"
  local agent="$2"
  local model="$3"

  local threshold=$(get_failure_threshold)
  local consecutive=$(jq -r ".stories[\"$story_id\"].attempts | map(select(.agent == \"$agent\" and .model == \"$model\" and .result == \"failure\")) | length // 0" "$ROTATION_STATE_FILE" 2>/dev/null || echo "0")

  [ "$consecutive" -ge "$threshold" ]
}

# ---- State Updates ------------------------------------------------

update_rotation_state() {
  local story_id="$1"
  local agent="$2"
  local model="$3"
  local event="$4"  # attempt, failure, success, rate_limit
  local timestamp=$(date +%s)

  init_rotation_state

  local tmp="${ROTATION_STATE_FILE}.tmp"
  local attempt_entry="{\"agent\": \"$agent\", \"model\": \"$model\", \"timestamp\": $timestamp, \"result\": \"$event\"}"

  # Ensure stories object and story array exist, then append
  jq "
    .stories[\"$story_id\"] //= {\"attempts\": [], \"total_attempts\": 0} |
    .stories[\"$story_id\"].attempts += [$attempt_entry] |
    .stories[\"$story_id\"].total_attempts += 1
  " "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"
}

reset_story_state() {
  local story_id="$1"
  local tmp="${ROTATION_STATE_FILE}.tmp"
  jq "del(.stories[\"$story_id\"])" "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"
}

# ---- Rate Limit Handling ------------------------------------------

is_agent_cooled_down() {
  local agent="$1"
  local now=$(date +%s)
  local cooldown_until=$(jq -r ".rate_limits[\"$agent\"].cooldown_until // 0" "$ROTATION_STATE_FILE" 2>/dev/null || echo "0")

  [ "$now" -ge "$cooldown_until" ]
}

record_rate_limit() {
  local agent="$1"
  local now=$(date +%s)
  local cooldown=$(get_rate_limit_cooldown)
  local cooldown_until=$((now + cooldown))

  local tmp="${ROTATION_STATE_FILE}.tmp"
  jq "
    .rate_limits[\"$agent\"] = {\"hit_at\": $now, \"cooldown_until\": $cooldown_until} |
    .rate_limits_count = (.rate_limits_count // 0) + 1
  " "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"

  log_info "Rate limit recorded for $agent, cooldown until $(date -r $cooldown_until '+%H:%M:%S' 2>/dev/null || date -d @$cooldown_until '+%H:%M:%S' 2>/dev/null || echo $cooldown_until)" 2>/dev/null || true
}

check_rate_limit_extended() {
  local agent="$1"
  local output="$2"

  case "$agent" in
    claude-code)
      echo "$output" | grep -qi "hit your limit\|rate limit\|quota exceeded\|resets [0-9]" && return 0
      ;;
    github-copilot)
      echo "$output" | grep -qi "rate_limited\|rate limit\|premium.*limit" && return 0
      ;;
    codex)
      echo "$output" | grep -qi "RateLimitError\|429\|Too Many Requests" && return 0
      ;;
    gemini)
      echo "$output" | grep -qi "RESOURCE_EXHAUSTED\|429\|quota exceeded" && return 0
      ;;
    *)
      # Generic check
      echo "$output" | grep -qi "rate limit\|429\|quota exceeded\|too many requests" && return 0
      ;;
  esac

  return 1
}

# ---- Usage Tracking -----------------------------------------------

parse_usage_from_output() {
  local agent="$1"
  local output="$2"

  case "$agent" in
    github-copilot)
      # Look for "Premium requests: X" or similar patterns
      local premium_count=$(echo "$output" | grep -oi "premium request[s]*[: ]*[0-9]*" | grep -o "[0-9]*" | tail -1)
      if [ -n "$premium_count" ]; then
        local tmp="${ROTATION_STATE_FILE}.tmp"
        jq ".usage[\"github-copilot\"].premium_requests_used = (.usage[\"github-copilot\"].premium_requests_used // 0) + $premium_count" "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"
      fi
      ;;
    claude-code)
      # Look for token usage patterns
      local tokens=$(echo "$output" | grep -oi "tokens[: ]*[0-9,]*" | grep -o "[0-9]*" | tail -1)
      if [ -n "$tokens" ]; then
        local tmp="${ROTATION_STATE_FILE}.tmp"
        jq ".usage[\"claude-code\"].tokens_used = (.usage[\"claude-code\"].tokens_used // 0) + $tokens" "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"
      fi
      ;;
    gemini)
      local requests=$(echo "$output" | grep -oi "request[s]*[: ]*[0-9]*" | grep -o "[0-9]*" | tail -1)
      if [ -n "$requests" ]; then
        local tmp="${ROTATION_STATE_FILE}.tmp"
        jq ".usage[\"gemini\"].requests_used = (.usage[\"gemini\"].requests_used // 0) + $requests" "$ROTATION_STATE_FILE" > "$tmp" && mv "$tmp" "$ROTATION_STATE_FILE"
      fi
      ;;
  esac
}

# ---- Status Display -----------------------------------------------

print_rotation_status() {
  if [ ! -f "$ROTATION_STATE_FILE" ]; then
    echo "Rotation: not initialized"
    return
  fi

  local rotations=$(jq -r '.rotations_count // 0' "$ROTATION_STATE_FILE" 2>/dev/null)
  local rate_limits=$(jq -r '.rate_limits_count // 0' "$ROTATION_STATE_FILE" 2>/dev/null)
  local agent_idx=$(get_current_agent_index)
  local agents_list=$(get_agent_rotation_list)
  local current_agent=$(echo "$agents_list" | sed -n "$((agent_idx + 1))p")
  local model_idx=$(get_current_model_index "$current_agent")
  local models_list=$(get_agent_models "$current_agent")
  local current_model=$(echo "$models_list" | sed -n "$((model_idx + 1))p")

  echo -e "Rotation: ${YELLOW}$rotations${NC} rotations, ${YELLOW}$rate_limits${NC} rate limits"
  if [ -n "$current_agent" ]; then
    echo -e "Current: ${CYAN}$current_agent${NC} (model: ${CYAN}${current_model:-default}${NC})"
  fi

  # Show cooldown status
  local now=$(date +%s)
  local has_cooldowns=false
  while IFS= read -r agent; do
    [ -z "$agent" ] && continue
    local cooldown_until=$(jq -r ".rate_limits[\"$agent\"].cooldown_until // 0" "$ROTATION_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$cooldown_until" -gt "$now" ]; then
      local remaining=$((cooldown_until - now))
      echo -e "  ${RED}$agent${NC}: cooldown ${remaining}s remaining"
      has_cooldowns=true
    fi
  done <<< "$agents_list"
}

# ---- Initialization -----------------------------------------------

log_debug "Rotation library loaded" 2>/dev/null || true
