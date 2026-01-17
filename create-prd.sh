#!/bin/bash
# Automated PRD creation and conversion to Ralph format
# Usage: ./create-prd.sh [OPTIONS] "your project description"
# Supports: GitHub Copilot CLI, Claude Code, Codex, Gemini

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DESC=""
DRAFT_ONLY=false
PROJECT_TYPE=""  # greenfield, brownfield, or auto
PREFERRED_MODEL=""  # Optional model override

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---- Help & Usage -------------------------------------------------

show_help() {
  echo "create-prd.sh - Automated PRD generation and conversion"
  echo ""
  echo "Usage: ./create-prd.sh [OPTIONS] \"your project description\""
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo "  --draft-only      Generate PRD draft only (skip JSON conversion)"
  echo "  --greenfield      Force greenfield mode (new project from scratch)"
  echo "  --brownfield      Force brownfield mode (adding to existing codebase)"
  echo "  --model MODEL     Specify AI model for PRD generation:"
  echo "                      claude-opus    - Best for technical PRDs (Claude Opus 4.5)"
  echo "                      claude-sonnet  - Balanced quality/cost (Claude Sonnet 4.5)"
  echo "                      gemini-pro     - Large context analysis (Gemini 2.5 Pro)"
  echo "                      gpt-codex      - OpenAI Codex models"
  echo ""
  echo "Agent priority: GitHub Copilot CLI → Claude Code → Gemini → Codex"
  echo ""
  echo "Project Type Detection (automatic unless --greenfield/--brownfield specified):"
  echo "  Greenfield: No package.json/requirements.txt, no src/, <10 git commits"
  echo "  Brownfield: Existing codebase with established patterns"
  echo ""
  echo "Model Recommendations:"
  echo "  Greenfield projects   → claude-sonnet (best balance for new architecture)"
  echo "  Small brownfield      → claude-opus (best technical accuracy)"
  echo "  Large brownfield      → gemini-pro (1M token context for full codebase)"
  echo ""
  echo "Examples:"
  echo "  ./create-prd.sh \"A task management API with CRUD operations\""
  echo "  ./create-prd.sh --brownfield \"Add user notifications to existing app\""
  echo "  ./create-prd.sh --model gemini-pro --brownfield \"Refactor authentication\""
  echo ""
  echo "Output:"
  echo "  - tasks/prd-draft.md   Markdown PRD document"
  echo "  - prd.json             Ralph-formatted JSON (unless --draft-only)"
  exit 0
}

# ---- Parse Arguments ----------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    --draft-only)
      DRAFT_ONLY=true
      shift
      ;;
    --greenfield)
      PROJECT_TYPE="greenfield"
      shift
      ;;
    --brownfield)
      PROJECT_TYPE="brownfield"
      shift
      ;;
    --model)
      shift
      PREFERRED_MODEL="$1"
      shift
      ;;
    *)
      if [ -z "$PROJECT_DESC" ]; then
        PROJECT_DESC="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$PROJECT_DESC" ]; then
  echo "Usage: ./create-prd.sh [OPTIONS] \"your project description\""
  echo "Run './create-prd.sh --help' for more options"
  exit 1
fi

# ---- Project Type Detection ---------------------------------------

detect_project_type() {
  local indicators=0

  # Check for package managers / project files
  if [ -f "package.json" ] || [ -f "requirements.txt" ] || [ -f "Cargo.toml" ] || \
     [ -f "go.mod" ] || [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "Gemfile" ]; then
    indicators=$((indicators + 2))
  fi

  # Check for source directories
  if [ -d "src" ] || [ -d "lib" ] || [ -d "app" ] || [ -d "pkg" ]; then
    indicators=$((indicators + 2))
  fi

  # Check git history
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    if [ "$commit_count" -gt 10 ]; then
      indicators=$((indicators + 2))
    elif [ "$commit_count" -gt 3 ]; then
      indicators=$((indicators + 1))
    fi
  fi

  # Check for existing tests
  if [ -d "tests" ] || [ -d "test" ] || [ -d "__tests__" ] || [ -d "spec" ]; then
    indicators=$((indicators + 1))
  fi

  # Check for config files indicating established project
  if [ -f ".eslintrc.js" ] || [ -f "tsconfig.json" ] || [ -f "jest.config.js" ] || \
     [ -f ".prettierrc" ] || [ -f "webpack.config.js" ] || [ -f "vite.config.ts" ]; then
    indicators=$((indicators + 1))
  fi

  # Threshold: 3+ indicators = brownfield
  if [ $indicators -ge 3 ]; then
    echo "brownfield"
  else
    echo "greenfield"
  fi
}

gather_brownfield_context() {
  local context=""

  # Gather tech stack
  if [ -f "package.json" ]; then
    context+="## Tech Stack (from package.json)\n"
    context+="Dependencies: $(jq -r '.dependencies | keys | join(", ")' package.json 2>/dev/null || echo 'N/A')\n"
    context+="Dev Dependencies: $(jq -r '.devDependencies | keys | join(", ")' package.json 2>/dev/null || echo 'N/A')\n\n"
  fi

  if [ -f "requirements.txt" ]; then
    context+="## Tech Stack (from requirements.txt)\n"
    context+="$(head -20 requirements.txt)\n\n"
  fi

  # Gather directory structure
  context+="## Directory Structure\n"
  context+="\`\`\`\n"
  context+="$(find . -maxdepth 3 -type d ! -path '*/node_modules/*' ! -path '*/.git/*' ! -path '*/.*' 2>/dev/null | head -30 || echo 'Unable to list directories')\n"
  context+="\`\`\`\n\n"

  # Gather API routes if they exist
  if [ -d "app/api" ] || [ -d "src/api" ] || [ -d "pages/api" ]; then
    context+="## Existing API Routes\n"
    context+="\`\`\`\n"
    context+="$(find . -path '*/api/*.ts' -o -path '*/api/*.js' 2>/dev/null | head -20 || echo 'None found')\n"
    context+="\`\`\`\n\n"
  fi

  # Check for database schema
  if [ -d "prisma" ] || [ -d "drizzle" ] || [ -d "migrations" ]; then
    context+="## Database Schema Location\n"
    if [ -f "prisma/schema.prisma" ]; then
      context+="Schema: prisma/schema.prisma\n"
      context+="Models: $(grep -c '^model ' prisma/schema.prisma 2>/dev/null || echo '0') models found\n"
    fi
    if [ -d "drizzle" ]; then
      context+="Schema: drizzle/ directory\n"
    fi
    context+="\n"
  fi

  # Check for component library patterns
  if [ -d "src/components" ] || [ -d "components" ] || [ -d "app/components" ]; then
    context+="## UI Component Patterns\n"
    context+="Components found in: $(find . -type d -name 'components' 2>/dev/null | head -3 | tr '\n' ', ')\n"
    context+="Sample components: $(find . -path '*/components/*.tsx' -o -path '*/components/*.jsx' 2>/dev/null | head -5 | xargs -I {} basename {} 2>/dev/null | tr '\n' ', ')\n\n"
  fi

  echo -e "$context"
}

# Auto-detect if not specified
if [ -z "$PROJECT_TYPE" ]; then
  PROJECT_TYPE=$(detect_project_type)
  echo -e "${CYAN}Auto-detected project type: ${YELLOW}$PROJECT_TYPE${NC}"
fi

echo -e "${GREEN}Project type: ${YELLOW}$PROJECT_TYPE${NC}"

# ---- Detect available agents --------------------------------------

AGENT=""
AGENT_NAME=""

# If a model was specified, infer which agent to use
infer_agent_from_model() {
  case "$1" in
    gemini-*)
      if command -v gemini &>/dev/null; then
        AGENT="gemini"
        AGENT_NAME="Gemini"
        return 0
      else
        echo -e "${RED}Error: Gemini CLI not installed but gemini model specified${NC}"
        echo "Install: npm install -g @google/gemini-cli"
        exit 1
      fi
      ;;
    claude-*)
      if command -v claude &>/dev/null; then
        AGENT="claude"
        AGENT_NAME="Claude Code"
        return 0
      elif [ -x "$HOME/.local/bin/claude" ]; then
        AGENT="$HOME/.local/bin/claude"
        AGENT_NAME="Claude Code"
        return 0
      else
        echo -e "${RED}Error: Claude CLI not installed but claude model specified${NC}"
        echo "Install: https://docs.anthropic.com/claude/docs/cli"
        exit 1
      fi
      ;;
    gpt-*|codex)
      if command -v codex &>/dev/null; then
        AGENT="codex"
        AGENT_NAME="Codex"
        return 0
      else
        echo -e "${RED}Error: Codex CLI not installed but gpt/codex model specified${NC}"
        echo "Install: npm install -g @openai/codex"
        exit 1
      fi
      ;;
  esac
  return 1
}

# If model was specified via --model, try to infer agent from it
if [ -n "$PREFERRED_MODEL" ]; then
  if infer_agent_from_model "$PREFERRED_MODEL"; then
    echo -e "${CYAN}Model specified: ${YELLOW}$PREFERRED_MODEL${NC} → using ${CYAN}$AGENT_NAME${NC}"
  fi
fi

# If agent wasn't set by model inference, auto-detect by priority
if [ -z "$AGENT" ]; then
  # Priority 1: GitHub Copilot CLI
  if command -v copilot &>/dev/null; then
    AGENT="copilot"
    AGENT_NAME="GitHub Copilot CLI"
  # Priority 2: Claude Code
  elif command -v claude &>/dev/null; then
    AGENT="claude"
    AGENT_NAME="Claude Code"
  elif [ -x "$HOME/.local/bin/claude" ]; then
    AGENT="$HOME/.local/bin/claude"
    AGENT_NAME="Claude Code"
  # Priority 3: Gemini
  elif command -v gemini &>/dev/null; then
    AGENT="gemini"
    AGENT_NAME="Gemini"
  # Priority 4: Codex
  elif command -v codex &>/dev/null; then
    AGENT="codex"
    AGENT_NAME="Codex"
  else
    echo -e "${RED}Error: No AI agent found.${NC}"
    echo "Please install one of the following:"
    echo "  - GitHub Copilot CLI: https://github.com/github/gh-copilot"
    echo "  - Claude Code: https://docs.anthropic.com/claude/docs/cli"
    echo "  - Gemini CLI: npm install -g @google/gemini-cli"
    echo "  - Codex: npm install -g @openai/codex"
    exit 1
  fi
fi

echo -e "${GREEN}Using agent: ${CYAN}$AGENT_NAME${NC}"

# ---- Model Selection ----------------------------------------------

get_recommended_model() {
  local type="$1"
  case "$type" in
    greenfield)
      echo "claude-sonnet"  # Best balance for new architecture decisions
      ;;
    brownfield)
      # Check codebase size
      local file_count=$(find . -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | wc -l)
      if [ "$file_count" -gt 100 ]; then
        echo "gemini-pro"  # Large context for big codebases
      else
        echo "claude-opus"  # Best accuracy for smaller brownfield
      fi
      ;;
    *)
      echo "claude-sonnet"
      ;;
  esac
}

if [ -z "$PREFERRED_MODEL" ]; then
  PREFERRED_MODEL=$(get_recommended_model "$PROJECT_TYPE")
  echo -e "${CYAN}Recommended model for $PROJECT_TYPE: ${YELLOW}$PREFERRED_MODEL${NC}"
fi

# ---- Agent-specific run functions ---------------------------------

run_copilot() {
  local prompt="$1"
  local model_flag=""
  case "$PREFERRED_MODEL" in
    claude-opus) model_flag="--model claude-opus-4.5" ;;
    claude-sonnet) model_flag="--model claude-sonnet-4.5" ;;
    claude-haiku) model_flag="--model claude-haiku-4.5" ;;
    gemini-pro) model_flag="--model gpt-5.2-codex" ;;  # Fallback: Copilot doesn't have Gemini
    gpt-codex) model_flag="--model gpt-5.2-codex" ;;
    *) model_flag="" ;;  # Use Copilot's default
  esac
  if [ -n "$model_flag" ]; then
    echo -e "${CYAN}Using Copilot with model: ${YELLOW}${model_flag#--model }${NC}"
  fi
  copilot -p "$prompt" --allow-all-tools $model_flag
}

run_claude() {
  local prompt="$1"
  local model_flag=""
  case "$PREFERRED_MODEL" in
    claude-opus) model_flag="--model claude-opus-4-20250514" ;;
    claude-sonnet) model_flag="--model claude-sonnet-4-20250514" ;;
    *) model_flag="" ;;  # Use default
  esac
  local claude_cmd="$AGENT"
  [ "$AGENT" = "claude" ] && claude_cmd="claude"
  "$claude_cmd" --print --dangerously-skip-permissions $model_flag "$prompt"
}

run_gemini() {
  local prompt="$1"
  local model="gemini-2.5-pro"
  case "$PREFERRED_MODEL" in
    gemini-pro) model="gemini-2.5-pro" ;;
    gemini-flash) model="gemini-2.5-flash" ;;
  esac
  gemini --model "$model" --yolo "$prompt"
}

run_codex() {
  local prompt="$1"
  codex exec --full-auto "$prompt"
}

run_agent() {
  local prompt="$1"
  case "$AGENT" in
    copilot) run_copilot "$prompt" ;;
    claude|"$HOME/.local/bin/claude") run_claude "$prompt" ;;
    gemini) run_gemini "$prompt" ;;
    codex) run_codex "$prompt" ;;
    *) echo -e "${RED}Unknown agent: $AGENT${NC}"; exit 1 ;;
  esac
}

# ---- Gather Context for Brownfield --------------------------------

BROWNFIELD_CONTEXT=""
if [ "$PROJECT_TYPE" = "brownfield" ]; then
  echo ""
  echo -e "${CYAN}Gathering existing codebase context...${NC}"
  BROWNFIELD_CONTEXT=$(gather_brownfield_context)
  echo -e "${GREEN}✓ Context gathered${NC}"
fi

# ---- Step 1: Generate PRD -----------------------------------------

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Generating PRD ($PROJECT_TYPE mode)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create tasks directory if it doesn't exist
mkdir -p tasks

# Select the appropriate skill file
SKILL_FILE="$SCRIPT_DIR/skills/prd/SKILL.md"
if [ "$PROJECT_TYPE" = "greenfield" ] && [ -f "$SCRIPT_DIR/skills/prd/GREENFIELD.md" ]; then
  SKILL_FILE="$SCRIPT_DIR/skills/prd/GREENFIELD.md"
elif [ "$PROJECT_TYPE" = "brownfield" ] && [ -f "$SCRIPT_DIR/skills/prd/BROWNFIELD.md" ]; then
  SKILL_FILE="$SCRIPT_DIR/skills/prd/BROWNFIELD.md"
fi

# Build the prompt
PRD_PROMPT="Load the prd skill from $SKILL_FILE and create a PRD for: $PROJECT_DESC

Project type: $PROJECT_TYPE"

if [ "$PROJECT_TYPE" = "brownfield" ] && [ -n "$BROWNFIELD_CONTEXT" ]; then
  PRD_PROMPT+="

## Existing Codebase Context
$BROWNFIELD_CONTEXT

IMPORTANT: Consider the existing patterns, tech stack, and architecture when defining requirements.
Ensure new features integrate smoothly with existing code."
fi

PRD_PROMPT+="

Answer all clarifying questions with reasonable defaults and generate the complete PRD. Save it to tasks/prd-draft.md"

# Generate PRD using the detected agent with the PRD skill
run_agent "$PRD_PROMPT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Converting PRD to Ralph JSON format..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if PRD was created
if [ ! -f "tasks/prd-draft.md" ]; then
  echo -e "${RED}Error: PRD file not found at tasks/prd-draft.md${NC}"
  exit 1
fi

# If draft-only mode, skip conversion
if [ "$DRAFT_ONLY" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✓ PRD Draft Complete!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "File created:"
  echo "  - tasks/prd-draft.md - Original PRD"
  echo ""
  echo "Next steps:"
  echo "  1. Review tasks/prd-draft.md"
  echo "  2. Run without --draft-only to convert to prd.json"
  echo "  3. Or manually convert: Load the ralph skill and convert tasks/prd-draft.md"
  echo ""
  exit 0
fi

# Warn if prd.json already exists
if [ -f "prd.json" ]; then
  echo ""
  echo -e "${YELLOW}Warning: prd.json already exists in this directory.${NC}"
  echo "   Continuing will overwrite the existing file."
  echo ""
  read -p "Continue? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled. Your existing prd.json was not modified."
    exit 0
  fi
fi

# Convert PRD to prd.json using the detected agent with the Ralph skill
run_agent "Load the ralph skill from $SCRIPT_DIR/skills/ralph/SKILL.md and convert tasks/prd-draft.md to prd.json.

Make sure each story is small and completable in one iteration. Save the output to prd.json in the current directory."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ PRD Creation Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Files created:"
echo "  - tasks/prd-draft.md - Original PRD ($PROJECT_TYPE)"
echo "  - prd.json - Ralph-formatted requirements"
echo ""
echo "Next steps:"
echo "  1. Review prd.json to ensure stories are appropriately sized"
echo "  2. Run Ralph: ./ralph.sh"
echo ""
