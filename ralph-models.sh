#!/bin/bash
# ralph-models.sh - List available models for each agent
# Usage: ./ralph-models.sh [agent-name] [--refresh]
#
# Options:
#   --refresh, -r    Force refresh of available models from CLIs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_CONFIG="$SCRIPT_DIR/agent.yaml"

# Source model refresh utility
if [ -f "$SCRIPT_DIR/lib/model-refresh.sh" ]; then
  source "$SCRIPT_DIR/lib/model-refresh.sh"
  MODELS_CACHE="$SCRIPT_DIR/.ralph-models-cache.json"
else
  echo "Warning: model-refresh.sh not found, using static model lists" >&2
  HAS_MODEL_REFRESH=false
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Ralph Available Models${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Claude Code models
show_claude_models() {
  echo -e "${BLUE}Claude Code${NC} (via claude CLI)"
  echo -e "  ${YELLOW}Current:${NC} $(yq '.claude-code.model // "claude-sonnet-4-20250514"' "$AGENT_CONFIG" 2>/dev/null)"
  echo ""

  # Get available models dynamically
  if [ -f "$SCRIPT_DIR/lib/model-refresh.sh" ]; then
    echo -e "  ${GREEN}Available models (auto-detected):${NC}"

    # Get models and format them
    local models
    models=$(get_claude_models 2>/dev/null)

    if [ -n "$models" ]; then
      while IFS= read -r model; do
        # Annotate recommended models
        case "$model" in
          *"claude-sonnet-4"*|*"claude-sonnet-4-5"*)
            echo "    • $model ${CYAN}(recommended, fast)${NC}"
            ;;
          *"claude-opus-4"*)
            echo "    • $model ${CYAN}(powerful, slower)${NC}"
            ;;
          *)
            echo "    • $model"
            ;;
        esac
      done <<< "$models"
    else
      echo "    ${YELLOW}No models detected, showing defaults:${NC}"
      echo "    • claude-sonnet-4-20250514 (recommended, fast)"
      echo "    • claude-opus-4-20250514   (powerful, slower)"
      echo "    • claude-3-5-sonnet-20241022"
      echo "    • claude-3-5-haiku-20241022"
    fi
  else
    echo -e "  ${GREEN}Available models:${NC}"
    echo "    • claude-sonnet-4-20250514 (recommended, fast)"
    echo "    • claude-opus-4-20250514   (powerful, slower)"
    echo "    • claude-3-5-sonnet-20241022"
    echo "    • claude-3-5-haiku-20241022"
  fi
  echo ""

  CLAUDE_CMD=""
  if command -v claude &>/dev/null; then
    CLAUDE_CMD="claude"
  elif [ -x "$HOME/.local/bin/claude" ]; then
    CLAUDE_CMD="$HOME/.local/bin/claude"
  fi

  if [ -n "$CLAUDE_CMD" ]; then
    echo -e "  ${GREEN}CLI found:${NC} $("$CLAUDE_CMD" --version 2>/dev/null || echo 'unknown version')"
  else
    echo -e "  ${RED}CLI not found${NC} - install from https://claude.ai/download"
  fi
  echo ""
}

# Codex models
show_codex_models() {
  echo -e "${BLUE}Codex${NC} (via codex CLI)"
  echo -e "  ${YELLOW}Current:${NC} $(yq '.codex.model // "gpt-5.2-codex"' "$AGENT_CONFIG" 2>/dev/null)"
  echo ""

  # Get available models dynamically
  if [ -f "$SCRIPT_DIR/lib/model-refresh.sh" ]; then
    echo -e "  ${GREEN}Available models (auto-detected):${NC}"

    # Get models and format them
    local models
    models=$(get_codex_models 2>/dev/null)

    if [ -n "$models" ]; then
      while IFS= read -r model; do
        # Annotate recommended models
        case "$model" in
          "gpt-5.2-codex")
            echo "    • $model ${CYAN}(latest frontier agentic coding)${NC}"
            ;;
          "gpt-5.1-codex-max")
            echo "    • $model ${CYAN}(flagship deep reasoning)${NC}"
            ;;
          "gpt-5.1-codex-mini")
            echo "    • $model ${CYAN}(faster, cheaper)${NC}"
            ;;
          "gpt-5.2")
            echo "    • $model ${CYAN}(frontier with reasoning/coding)${NC}"
            ;;
          o3|o4*)
            echo "    • $model ${CYAN}(reasoning model)${NC}"
            ;;
          *)
            echo "    • $model"
            ;;
        esac
      done <<< "$models"
    else
      echo "    ${YELLOW}No models detected, showing defaults:${NC}"
      echo "    • gpt-5.2-codex      (latest frontier agentic coding)"
      echo "    • gpt-5.1-codex-max  (flagship deep reasoning)"
      echo "    • gpt-5.1-codex-mini (faster, cheaper)"
      echo "    • gpt-5.2            (frontier with reasoning/coding)"
      echo "    • gpt-4o             (legacy, still available)"
    fi
  else
    echo -e "  ${GREEN}Available models:${NC}"
    echo "    • gpt-5.2-codex      (latest frontier agentic coding)"
    echo "    • gpt-5.1-codex-max  (flagship deep reasoning)"
    echo "    • gpt-5.1-codex-mini (faster, cheaper)"
    echo "    • gpt-5.2            (frontier with reasoning/coding)"
    echo "    • gpt-4o             (legacy, still available)"
  fi
  echo ""

  if command -v codex &>/dev/null; then
    echo -e "  ${GREEN}CLI found:${NC} $(codex --version 2>/dev/null || echo 'unknown version')"
    echo -e "  ${CYAN}Tip:${NC} Run 'codex' then /model to see all available models"
  else
    echo -e "  ${RED}CLI not found${NC} - install with 'npm install -g @openai/codex'"
  fi
  echo ""
}

# Gemini models
show_gemini_models() {
  echo -e "${BLUE}Gemini${NC} (via gemini CLI)"
  echo -e "  ${YELLOW}Current:${NC} $(yq '.gemini.model // "gemini-3-pro"' "$AGENT_CONFIG" 2>/dev/null)"
  echo ""

  # Get available models dynamically
  if [ -f "$SCRIPT_DIR/lib/model-refresh.sh" ]; then
    echo -e "  ${GREEN}Available models (auto-detected):${NC}"

    # Get models and format them
    local models
    models=$(get_gemini_models 2>/dev/null)

    if [ -n "$models" ]; then
      while IFS= read -r model; do
        # Annotate recommended models
        case "$model" in
          "gemini-3-pro")
            echo -e "    • $model ${CYAN}(Gemini 3, powerful)${NC}"
            ;;
          "gemini-3-flash")
            echo -e "    • $model ${CYAN}(Gemini 3, fast)${NC}"
            ;;
          "gemini-2.5-pro")
            echo -e "    • $model ${CYAN}(Gemini 2.5, powerful)${NC}"
            ;;
          "gemini-2.5-flash")
            echo -e "    • $model ${CYAN}(Gemini 2.5, fast)${NC}"
            ;;
          *)
            echo "    • $model"
            ;;
        esac
      done <<< "$models"
    else
      echo "    ${YELLOW}No models detected, showing defaults:${NC}"
      echo "    • gemini-3-pro       (Gemini 3, powerful)"
      echo "    • gemini-3-flash     (Gemini 3, fast)"
      echo "    • gemini-2.5-pro     (Gemini 2.5, powerful)"
      echo "    • gemini-2.5-flash   (Gemini 2.5, fast)"
    fi
  else
    echo -e "  ${GREEN}Available models:${NC}"
    echo "    • gemini-3-pro       (Gemini 3, powerful)"
    echo "    • gemini-3-flash     (Gemini 3, fast)"
    echo "    • gemini-2.5-pro     (Gemini 2.5, powerful)"
    echo "    • gemini-2.5-flash   (Gemini 2.5, fast)"
  fi
  echo ""

  if command -v gemini &>/dev/null; then
    echo -e "  ${GREEN}CLI found:${NC} $(gemini --version 2>/dev/null || echo 'unknown version')"
    echo -e "  ${CYAN}Tip:${NC} Run 'gemini' then /model to see all available models"
  else
    echo -e "  ${RED}CLI not found${NC} - install with 'npm install -g @anthropic/gemini-cli'"
  fi
  echo ""
}

# Current config
show_current_config() {
  echo -e "${YELLOW}Current Configuration${NC} ($AGENT_CONFIG)"
  echo ""
  if [ -f "$AGENT_CONFIG" ]; then
    cat "$AGENT_CONFIG" | sed 's/^/  /'
  else
    echo -e "  ${RED}No agent.yaml found${NC}"
  fi
  echo ""
}

# Parse arguments
FORCE_REFRESH=false
SHOW_MODE="all"

for arg in "$@"; do
  case "$arg" in
    --refresh|-r)
      FORCE_REFRESH=true
      ;;
    --help|-h)
      echo "Usage: $0 [agent-name] [--refresh]"
      echo ""
      echo "Agent names:"
      echo "  all          Show all agents (default)"
      echo "  claude       Show Claude Code models only"
      echo "  codex        Show Codex models only"
      echo "  gemini       Show Gemini models only"
      echo "  config       Show current configuration"
      echo ""
      echo "Options:"
      echo "  --refresh, -r    Force refresh of available models"
      echo "  --help, -h       Show this help message"
      exit 0
      ;;
    claude|claude-code|codex|openai|gemini|config)
      SHOW_MODE="$arg"
      ;;
  esac
done

# Force refresh if requested
if [ "$FORCE_REFRESH" = true ] && [ -f "$SCRIPT_DIR/lib/model-refresh.sh" ]; then
  echo -e "${YELLOW}Forcing model refresh...${NC}"
  refresh_models --force >/dev/null 2>&1
  echo -e "${GREEN}✓ Models refreshed${NC}"
  echo ""
fi

# Show cache info if model refresh is available
if [ -f "$SCRIPT_DIR/lib/model-refresh.sh" ] && [ -f "$MODELS_CACHE" ]; then
  cache_info=$(get_cache_info)
  echo -e "${CYAN}$cache_info${NC}"
  echo ""
fi

# Main
case "${SHOW_MODE}" in
  claude|claude-code)
    show_claude_models
    ;;
  codex|openai)
    show_codex_models
    ;;
  gemini)
    show_gemini_models
    ;;
  config)
    show_current_config
    ;;
  all|*)
    show_claude_models
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo ""
    show_codex_models
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo ""
    show_gemini_models
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo ""
    show_current_config
    ;;
esac

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "To change model: edit ${BLUE}agent.yaml${NC} and update the model field"
echo -e "To refresh models: run ${BLUE}./ralph-models.sh --refresh${NC}"
echo ""
