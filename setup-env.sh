#!/usr/bin/env bash
set -euo pipefail

# worktree-ports
# Deterministic per-worktree port assignment for parallel development tools.
# Works with Conductor, OpenAI Codex, manual git worktrees, and more.
#
# Usage: curl -sSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash
#
# What it does:
# 1. Copies .env from the main worktree into the current worktree
# 2. Hashes the worktree directory name to a deterministic port in 4000-4999
# 3. Writes APP_PORT=<port> into .env (creates or updates)
#
# .env copy resolution order:
#   1. CONDUCTOR_ROOT_PATH (set automatically by Conductor)
#   2. Main git worktree (detected via `git worktree list`)
#
# Environment variables written to .env:
#   APP_PORT - the deterministic port number (4000-4999)

PREFIX="[worktree-ports]"

# --- Step 1: Copy .env from the main worktree ---
env_copied=false

# Priority 1: Conductor's CONDUCTOR_ROOT_PATH
if [[ -n "${CONDUCTOR_ROOT_PATH:-}" ]]; then
  if [[ -f "$CONDUCTOR_ROOT_PATH/.env" ]]; then
    cp "$CONDUCTOR_ROOT_PATH/.env" .env || { echo "$PREFIX Error: failed to copy .env from $CONDUCTOR_ROOT_PATH"; exit 1; }
    echo "$PREFIX Copied .env from root repo (via CONDUCTOR_ROOT_PATH)"
    env_copied=true
  else
    echo "$PREFIX Warning: CONDUCTOR_ROOT_PATH is set but no .env found at $CONDUCTOR_ROOT_PATH/.env"
  fi
fi

# Priority 2: Detect main worktree via git
if [[ "$env_copied" == false ]] && command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
  worktree_output=$(git worktree list --porcelain 2>&1) && {
    main_worktree=$(echo "$worktree_output" | head -1 | sed 's/worktree //')
  } || {
    echo "$PREFIX Warning: 'git worktree list' failed"
    main_worktree=""
  }
  if [[ -n "$main_worktree" && -d "$main_worktree" && "$main_worktree" != "$PWD" && -f "$main_worktree/.env" ]]; then
    cp "$main_worktree/.env" .env || { echo "$PREFIX Error: failed to copy .env from $main_worktree"; exit 1; }
    echo "$PREFIX Copied .env from main worktree ($main_worktree)"
    env_copied=true
  fi
fi

if [[ "$env_copied" == false ]]; then
  echo "$PREFIX No source .env found (checked CONDUCTOR_ROOT_PATH and main worktree)"
fi

# Only assign a port if .env exists (either copied above or already present)
if [[ ! -f .env ]]; then
  echo "$PREFIX No .env file found, skipping port assignment"
  exit 0
fi

# --- Step 2: Hash worktree directory name to a port ---
# djb2 hash: deterministically map a string to a port in the 4000-4999 range
djb2_hash() {
  local str="$1"
  local hash=5381
  for (( i = 0; i < ${#str}; i++ )); do
    char=$(printf '%d' "'${str:$i:1}")
    hash=$(( (hash * 33 + char) % 2147483647 ))
  done
  echo $(( hash % 1000 + 4000 ))
}

# --- Step 3: Write APP_PORT to .env ---
# Idempotently write a key=value into .env (update if exists, append if not)
upsert_env_var() {
  local key="$1"
  local value="$2"
  local file=".env"
  if grep -q "^${key}=" "$file"; then
    # macOS sed requires -i '' ; Linux sed requires -i without arg.
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s|^${key}=.*|${key}=${value}|" "$file" || { echo "$PREFIX Error: failed to update ${key} in $file"; exit 1; }
    else
      sed -i "s|^${key}=.*|${key}=${value}|" "$file" || { echo "$PREFIX Error: failed to update ${key} in $file"; exit 1; }
    fi
  else
    echo "${key}=${value}" >> "$file" || { echo "$PREFIX Error: failed to append ${key} to $file"; exit 1; }
  fi
}

workspace_dir="$(basename "$PWD")"
port=$(djb2_hash "$workspace_dir")
upsert_env_var "APP_PORT" "$port"
echo "$PREFIX APP_PORT set to $port (from worktree: $workspace_dir)"
