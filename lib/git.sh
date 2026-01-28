#!/bin/bash
# Ralph Git Library - Git operations for branch management, pushing, and PRs
# Source this file from ralph.sh: source "$SCRIPT_DIR/lib/git.sh"

# ---- Git Configuration Getters -----------------------------------

# Get git.auto-checkout-branch setting (default: true)
get_git_auto_checkout_branch() {
  local value=$(yq '.git.auto-checkout-branch // true' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# Get git.base-branch setting (default: main)
get_git_base_branch() {
  yq '.git.base-branch // "main"' "$AGENT_CONFIG" 2>/dev/null
}

# Get git.push.enabled setting (default: false)
get_git_push_enabled() {
  local value=$(yq '.git.push.enabled // false' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# Get git.push.timing setting (default: iteration)
get_git_push_timing() {
  yq '.git.push.timing // "iteration"' "$AGENT_CONFIG" 2>/dev/null
}

# Get git.pr.enabled setting (default: false)
get_git_pr_enabled() {
  local value=$(yq '.git.pr.enabled // false' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# Get git.pr.draft setting (default: false)
get_git_pr_draft() {
  local value=$(yq '.git.pr.draft // false' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# Get git.pr.auto-merge setting (default: false)
get_git_pr_auto_merge() {
  local value=$(yq '.git.pr.auto-merge // false' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# ---- Branch Management Functions ---------------------------------

# Delete local branches that have been merged into the current branch
# Skips the current branch and base branch (main). Useful for cleaning up
# stale sub-branches from old Ralph workflows.
# Usage: cleanup_merged_branches
cleanup_merged_branches() {
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  local base_branch=$(get_git_base_branch 2>/dev/null || echo "main")
  local deleted=0

  # Get branches merged into current branch, excluding current and base
  local merged_branches
  merged_branches=$(git branch --merged 2>/dev/null | grep -v '^\*' | grep -v "^[[:space:]]*${base_branch}$" | sed 's/^[[:space:]]*//')

  if [ -z "$merged_branches" ]; then
    return 0
  fi

  while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    # Skip the current branch (safety check)
    [ "$branch" = "$current_branch" ] && continue
    git branch -d "$branch" >/dev/null 2>&1 && ((deleted++)) || true
  done <<< "$merged_branches"

  if [ "$deleted" -gt 0 ]; then
    log_info "Cleaned up $deleted merged branch(es)"
    echo -e "${GREEN}✓ Cleaned up $deleted merged branch(es)${NC}"
  fi
}

# Ensure the feature branch exists and we're on it
# Usage: ensure_feature_branch <branch_name>
# Creates from base-branch if it doesn't exist
# Returns 0 on success, 1 on failure
ensure_feature_branch() {
  local branch_name="$1"
  local base_branch=$(get_git_base_branch)

  if [ -z "$branch_name" ]; then
    log_error "No branch name provided to ensure_feature_branch"
    return 1
  fi

  log_info "Ensuring feature branch: $branch_name"

  # Stash any uncommitted changes to allow branch switching
  local stash_needed=false
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    log_info "Stashing uncommitted changes before branch switch"
    if git stash push -m "Ralph auto-stash before switching to $branch_name"; then
      stash_needed=true
    else
      log_error "Failed to stash changes, attempting checkout anyway"
    fi
  fi

  local checkout_success=false

  # Check if branch exists locally
  if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
    log_debug "Branch $branch_name exists locally"
    if git checkout "$branch_name" 2>/dev/null; then
      checkout_success=true
    fi
  # Check if branch exists on remote
  elif git ls-remote --exit-code --heads origin "$branch_name" >/dev/null 2>&1; then
    log_debug "Branch $branch_name exists on remote, checking out"
    git fetch origin "$branch_name"
    if git checkout -b "$branch_name" "origin/$branch_name" 2>/dev/null; then
      checkout_success=true
    fi
  else
    # Create new branch from base
    log_info "Creating new branch $branch_name from $base_branch"

    # Fetch latest from remote (for awareness) but create from LOCAL base branch
    # to include any local commits (e.g., new prd.json from create-prd.sh)
    if git ls-remote --exit-code --heads origin "$base_branch" >/dev/null 2>&1; then
      git fetch origin "$base_branch"
    fi

    # Create from local base branch (includes unpushed commits like new prd.json)
    if git show-ref --verify --quiet "refs/heads/$base_branch" 2>/dev/null; then
      if git checkout -b "$branch_name" "$base_branch" 2>/dev/null; then
        checkout_success=true
      fi
    else
      # No local base branch, fall back to current HEAD
      if git checkout -b "$branch_name" 2>/dev/null; then
        checkout_success=true
      fi
    fi
  fi

  # Restore stashed changes if we stashed them
  if [ "$stash_needed" = true ]; then
    log_info "Restoring stashed changes"
    git stash pop 2>/dev/null || log_warn "Could not restore stashed changes"
  fi

  # Verify we're on the correct branch
  local current_branch=$(git branch --show-current 2>/dev/null)
  if [ "$current_branch" = "$branch_name" ]; then
    log_info "Now on branch: $current_branch"
    return 0
  else
    log_error "Failed to switch to branch $branch_name (currently on: $current_branch)"
    echo -e "${RED}✗ Failed to switch to feature branch ${branch_name}${NC}"
    echo -e "${YELLOW}  Current branch: ${current_branch}${NC}"
    echo -e "${YELLOW}  Try: git stash && git checkout $branch_name${NC}"
    return 1
  fi
}

# Verify we're on the expected feature branch
# Usage: verify_on_feature_branch <expected_branch>
# Returns 0 if on correct branch (or successfully switched), 1 on failure
verify_on_feature_branch() {
  local expected_branch="$1"
  local current_branch=$(git branch --show-current 2>/dev/null)

  if [ "$current_branch" = "$expected_branch" ]; then
    return 0
  fi

  log_warn "Not on expected branch. Expected: $expected_branch, Current: $current_branch"
  if git checkout "$expected_branch" 2>/dev/null; then
    log_info "Recovered: switched to $expected_branch"
    return 0
  fi

  log_error "Failed to switch to $expected_branch"
  return 1
}

# ---- PRD State Functions -----------------------------------------

# Preserve story completion status after merge conflict
# Usage: preserve_story_completion <story_id>
# Updates prd.json on current branch to mark story as complete
preserve_story_completion() {
  local story_id="$1"
  local prd_file="${PRD_FILE:-prd.json}"

  if [ ! -f "$prd_file" ]; then
    log_error "PRD file not found: $prd_file"
    return 1
  fi

  # Update prd.json on current branch to mark story as complete
  local temp_file=$(mktemp)
  if jq --arg id "$story_id" \
    '(.userStories[] | select(.id == $id)).passes = true' \
    "$prd_file" > "$temp_file"; then
    mv "$temp_file" "$prd_file"
  else
    rm -f "$temp_file"
    log_error "Failed to update prd.json for $story_id"
    return 1
  fi

  # Commit the prd.json update
  git add "$prd_file"
  git commit -m "chore: Preserve $story_id completion after merge conflict"

  log_info "Preserved completion status for $story_id"
  echo -e "${GREEN}✓ Preserved ${story_id} completion status${NC}"
  return 0
}

# ---- Push Functions ----------------------------------------------

# Push a branch to remote with upstream tracking
# Usage: push_branch <branch_name>
push_branch() {
  local branch_name="$1"

  log_info "Pushing branch: $branch_name"

  # Check if remote exists
  if ! git remote get-url origin >/dev/null 2>&1; then
    log_warn "No remote 'origin' configured, skipping push"
    echo -e "${YELLOW}⚠ No remote configured, skipping push${NC}"
    return 1
  fi

  # Push with upstream tracking
  if git push -u origin "$branch_name" 2>&1; then
    log_info "Successfully pushed $branch_name"
    echo -e "${GREEN}✓ Pushed ${branch_name}${NC}"
    return 0
  else
    log_error "Failed to push $branch_name"
    echo -e "${RED}✗ Failed to push ${branch_name}${NC}"
    return 1
  fi
}

# ---- Pull Request Functions --------------------------------------

# Create a pull request using GitHub CLI
# Usage: create_pr <feature_branch> [base_branch] [title] [body]
create_pr() {
  local feature_branch="$1"
  local base_branch="${2:-$(get_git_base_branch)}"
  local title="${3:-}"
  local body="${4:-}"

  log_info "Creating PR: $feature_branch -> $base_branch"

  # Check if gh CLI is available
  if ! command -v gh >/dev/null 2>&1; then
    log_error "GitHub CLI (gh) not found, cannot create PR"
    echo -e "${RED}✗ GitHub CLI not installed. Install: brew install gh${NC}"
    return 1
  fi

  # Check if authenticated
  if ! gh auth status >/dev/null 2>&1; then
    log_error "Not authenticated with GitHub CLI"
    echo -e "${RED}✗ Not authenticated. Run: gh auth login${NC}"
    return 1
  fi

  # Generate title if not provided
  if [ -z "$title" ]; then
    # Extract feature name from branch (ralph/feature-name -> Feature name)
    local feature_name=$(echo "$feature_branch" | sed 's|^ralph/||' | tr '-' ' ')
    title="$feature_name"
  fi

  # Generate body if not provided
  if [ -z "$body" ]; then
    body=$(generate_pr_body)
  fi

  # Build gh pr create command
  local gh_cmd="gh pr create --base \"$base_branch\" --head \"$feature_branch\" --title \"$title\""

  # Add draft flag if configured
  if get_git_pr_draft; then
    gh_cmd="$gh_cmd --draft"
  fi

  # Create PR
  echo -e "${CYAN}Creating pull request...${NC}"

  local pr_url
  if get_git_pr_draft; then
    pr_url=$(gh pr create --base "$base_branch" --head "$feature_branch" --title "$title" --body "$body" --draft 2>&1)
  else
    pr_url=$(gh pr create --base "$base_branch" --head "$feature_branch" --title "$title" --body "$body" 2>&1)
  fi

  if [ $? -eq 0 ]; then
    log_info "PR created: $pr_url"
    echo -e "${GREEN}✓ Pull request created${NC}"
    echo -e "  ${CYAN}$pr_url${NC}"
    return 0
  else
    log_error "Failed to create PR: $pr_url"
    echo -e "${RED}✗ Failed to create pull request${NC}"
    echo "$pr_url"
    return 1
  fi
}

# Merge a PR into its base branch
# Usage: merge_pr <feature_branch>
# Attempts direct merge first, falls back to enabling auto-merge (for repos with required checks)
merge_pr() {
  local feature_branch="$1"

  log_info "Merging PR for branch: $feature_branch"

  # Try direct merge first
  local merge_output
  merge_output=$(gh pr merge "$feature_branch" --merge --delete-branch 2>&1)
  if [ $? -eq 0 ]; then
    log_info "PR merged successfully"
    echo -e "${GREEN}✓ Pull request merged into $(get_git_base_branch)${NC}"
    return 0
  fi

  # Direct merge failed - try enabling auto-merge (waits for required checks)
  log_info "Direct merge failed, attempting auto-merge: $merge_output"
  merge_output=$(gh pr merge "$feature_branch" --auto --merge --delete-branch 2>&1)
  if [ $? -eq 0 ]; then
    log_info "Auto-merge enabled for PR"
    echo -e "${GREEN}✓ Auto-merge enabled (will merge when checks pass)${NC}"
    return 0
  fi

  log_error "Failed to merge PR: $merge_output"
  echo -e "${RED}✗ Could not merge PR automatically${NC}"
  echo -e "${YELLOW}  Merge manually: gh pr merge $feature_branch --merge${NC}"
  return 1
}

# Generate PR body from prd.json and progress
# Usage: pr_body=$(generate_pr_body)
generate_pr_body() {
  local prd_file="${PRD_FILE:-prd.json}"

  local project_desc=""
  local stories_summary=""

  if [ -f "$prd_file" ]; then
    project_desc=$(jq -r '.description // ""' "$prd_file" 2>/dev/null)

    # Generate stories summary
    stories_summary=$(jq -r '.userStories[] | "- [x] \(.id): \(.title)"' "$prd_file" 2>/dev/null | head -20)
  fi

  cat << EOF
## Summary
${project_desc:-"Feature implementation completed by Ralph"}

## Completed Stories
${stories_summary:-"See prd.json for details"}

## Test Plan
- [ ] Review code changes
- [ ] Run test suite
- [ ] Manual verification

---
*Generated by [Ralph](https://github.com/Moty/ralph)*
EOF
}

# ---- Utility Functions -------------------------------------------

# Get the story ID that was just completed in this iteration
# Usage: story_id=$(get_completed_story_id)
# Returns: The ID of the story that just had passes set to true
get_completed_story_id() {
  local prd_file="${PRD_FILE:-prd.json}"

  # Get the most recently modified story that has passes: true
  # This assumes the agent just set it, so it's the current story
  # We use the story selection logic from get_current_story but inverted

  # Get the highest priority story that was just completed
  # Since agents work on highest priority incomplete story, the most recently
  # completed one is the highest priority one with passes: true
  jq -r '[.userStories[] | select(.passes == true)] | sort_by(.priority) | last | .id // empty' "$prd_file" 2>/dev/null
}

# Check if we're in a git repository
# Usage: is_git_repo && echo "yes"
is_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

# Get the current branch name
# Usage: branch=$(get_current_branch)
get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Check if there are uncommitted changes
# Usage: has_uncommitted_changes && echo "dirty"
has_uncommitted_changes() {
  ! git diff-index --quiet HEAD -- 2>/dev/null
}

# Validate that git remote is configured
# Usage: validate_git_remote
validate_git_remote() {
  if ! git remote get-url origin >/dev/null 2>&1; then
    log_warn "No git remote 'origin' configured"
    echo -e "${YELLOW}Warning: No git remote configured${NC}"
    echo -e "${YELLOW}Push and PR features will be disabled${NC}"
    return 1
  fi

  log_debug "Git remote configured: $(git remote get-url origin)"
  return 0
}

# ---- Initialization ----------------------------------------------

log_debug "Git library loaded"
