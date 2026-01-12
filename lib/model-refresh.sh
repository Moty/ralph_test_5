#!/bin/bash
# model-refresh.sh - Dynamically detect and cache available models
# Usage: source lib/model-refresh.sh && refresh_models [--force]

# Cache file location (relative to project root)
MODELS_CACHE="${MODELS_CACHE:-.ralph-models-cache.json}"
CACHE_MAX_AGE_HOURS=24

# Default fallback models (used if detection fails)
DEFAULT_CLAUDE_MODELS='[
  "claude-sonnet-4-20250514",
  "claude-opus-4-20250514",
  "claude-sonnet-4-5-20250929",
  "claude-3-5-sonnet-20241022",
  "claude-3-5-haiku-20241022"
]'

DEFAULT_CODEX_MODELS='[
  "gpt-5.2-codex",
  "gpt-5.1-codex-max",
  "gpt-5.1-codex-mini",
  "gpt-5.2",
  "gpt-4o",
  "o4-mini"
]'

DEFAULT_GEMINI_MODELS='[
  "gemini-3-pro",
  "gemini-3-flash",
  "gemini-2.5-pro",
  "gemini-2.5-flash"
]'

# Detect available Claude models
detect_claude_models() {
  # For now, we use curated default lists
  # Future enhancement: Add API integration to fetch live model lists
  # The 'claude models' command is not reliable for automated scripts

  # Find Claude CLI to verify it's installed
  CLAUDE_CMD=""
  if command -v claude &>/dev/null; then
    CLAUDE_CMD="claude"
  elif [ -x "$HOME/.local/bin/claude" ]; then
    CLAUDE_CMD="$HOME/.local/bin/claude"
  fi

  if [ -z "$CLAUDE_CMD" ]; then
    # CLI not installed, return minimal set
    echo '["claude-sonnet-4-20250514"]'
    return 0
  fi

  # CLI is installed, return full curated list
  # This list is maintained and updated with each Ralph release
  echo "$DEFAULT_CLAUDE_MODELS"
  return 0
}

# Detect available Codex/OpenAI models
detect_codex_models() {
  # For now, we use curated default lists
  # Future enhancement: Add OpenAI API integration to fetch live model lists

  # Check if Codex CLI is available
  if ! command -v codex &>/dev/null; then
    # CLI not installed, return minimal set
    echo '["gpt-4o"]'
    return 0
  fi

  # CLI is installed, return full curated list
  # This list is maintained and updated with each Ralph release
  echo "$DEFAULT_CODEX_MODELS"
  return 0
}

# Detect available Gemini models
detect_gemini_models() {
  # Gemini CLI models: Auto (Gemini 3) and Auto (Gemini 2.5)
  # gemini-3-pro, gemini-3-flash, gemini-2.5-pro, gemini-2.5-flash

  # Check if Gemini CLI is available
  if ! command -v gemini &>/dev/null; then
    # CLI not installed, return minimal set
    echo '["gemini-3-pro"]'
    return 0
  fi

  # CLI is installed, return full curated list
  echo "$DEFAULT_GEMINI_MODELS"
  return 0
}

# Check if cache is valid and not expired
is_cache_valid() {
  [ ! -f "$MODELS_CACHE" ] && return 1

  # Check if cache file is valid JSON
  if ! jq empty "$MODELS_CACHE" 2>/dev/null; then
    return 1
  fi

  # Check cache age
  local cache_timestamp
  cache_timestamp=$(jq -r '.timestamp // 0' "$MODELS_CACHE" 2>/dev/null)

  if [ "$cache_timestamp" = "0" ]; then
    return 1
  fi

  local current_timestamp
  current_timestamp=$(date +%s)
  local age_seconds=$((current_timestamp - cache_timestamp))
  local max_age_seconds=$((CACHE_MAX_AGE_HOURS * 3600))

  [ $age_seconds -lt $max_age_seconds ]
}

# Get models from cache
get_cached_models() {
  if [ -f "$MODELS_CACHE" ]; then
    cat "$MODELS_CACHE"
  else
    echo '{}'
  fi
}

# Refresh models and update cache
refresh_models() {
  local force_refresh=false

  if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    force_refresh=true
  fi

  # Check if we need to refresh
  if [ "$force_refresh" = false ] && is_cache_valid; then
    # Cache is valid, return cached data
    get_cached_models
    return 0
  fi

  # Perform refresh
  echo "Refreshing available models..." >&2

  local claude_models
  local codex_models
  local gemini_models

  claude_models=$(detect_claude_models)
  codex_models=$(detect_codex_models)
  gemini_models=$(detect_gemini_models)

  # Create cache JSON
  local cache_data
  cache_data=$(jq -n \
    --argjson claude "$claude_models" \
    --argjson codex "$codex_models" \
    --argjson gemini "$gemini_models" \
    --arg timestamp "$(date +%s)" \
    --arg refreshed "$(date -u +"%Y-%m-%d %H:%M:%S UTC")" \
    '{
      timestamp: $timestamp | tonumber,
      refreshed: $refreshed,
      claude: $claude,
      codex: $codex,
      gemini: $gemini
    }')

  # Write cache
  echo "$cache_data" > "$MODELS_CACHE"

  echo "Models refreshed and cached." >&2
  echo "$cache_data"
}

# Get models (from cache or refresh)
get_models() {
  local force=false

  if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    force=true
  fi

  if [ "$force" = true ]; then
    refresh_models --force
  elif ! is_cache_valid; then
    refresh_models
  else
    get_cached_models
  fi
}

# Get Claude models only
get_claude_models() {
  get_models "$@" | jq -r '.claude[]' 2>/dev/null || echo "$DEFAULT_CLAUDE_MODELS" | jq -r '.[]'
}

# Get Codex models only
get_codex_models() {
  get_models "$@" | jq -r '.codex[]' 2>/dev/null || echo "$DEFAULT_CODEX_MODELS" | jq -r '.[]'
}

# Get Gemini models only
get_gemini_models() {
  get_models "$@" | jq -r '.gemini[]' 2>/dev/null || echo "$DEFAULT_GEMINI_MODELS" | jq -r '.[]'
}

# Get cache info
get_cache_info() {
  if [ -f "$MODELS_CACHE" ]; then
    local refreshed
    refreshed=$(jq -r '.refreshed // "never"' "$MODELS_CACHE" 2>/dev/null)
    echo "Last refreshed: $refreshed"
  else
    echo "Cache not found. Run 'refresh_models' to detect models."
  fi
}

# Main CLI interface (if script is executed directly)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  case "${1:-get}" in
    refresh|--refresh|-r)
      refresh_models --force
      ;;
    claude)
      get_claude_models "$@"
      ;;
    codex)
      get_codex_models "$@"
      ;;
    gemini)
      get_gemini_models "$@"
      ;;
    info)
      get_cache_info
      ;;
    get|*)
      get_models "$@"
      ;;
  esac
fi
