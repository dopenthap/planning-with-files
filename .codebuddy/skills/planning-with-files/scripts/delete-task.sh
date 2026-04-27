#!/bin/bash
# delete-task.sh - Remove a task from the current planning session
# Usage: ./delete-task.sh <task-id> [--force]

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
SESSION_DIR="${PLANNING_SESSION_DIR:-./planning-session}"
TASKS_DIR="$SESSION_DIR/tasks"

# ─── Helpers ──────────────────────────────────────────────────────────────────
red()    { echo -e "\033[0;31m$*\033[0m"; }
green()  { echo -e "\033[0;32m$*\033[0m"; }
yellow() { echo -e "\033[0;33m$*\033[0m"; }
cyan()   { echo -e "\033[0;36m$*\033[0m"; }

usage() {
  echo "Usage: $0 <task-id> [--force]"
  echo ""
  echo "Arguments:"
  echo "  task-id   The ID of the task to delete (e.g. TASK-001)"
  echo ""
  echo "Options:"
  echo "  --force   Skip confirmation prompt"
  echo ""
  echo "Examples:"
  echo "  $0 TASK-003"
  echo "  $0 TASK-003 --force"
  exit 1
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
TASK_ID=""
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --help|-h) usage ;;
    *) TASK_ID="$arg" ;;
  esac
done

if [[ -z "$TASK_ID" ]]; then
  red "Error: task-id is required."
  usage
fi

# Normalise to uppercase
TASK_ID=$(echo "$TASK_ID" | tr '[:lower:]' '[:upper:]')

# ─── Validate session ─────────────────────────────────────────────────────────
if [[ ! -d "$TASKS_DIR" ]]; then
  red "Error: No planning session found at '$SESSION_DIR'."
  echo "Run init-session.sh first."
  exit 1
fi

# ─── Locate task file ─────────────────────────────────────────────────────────
TASK_FILE=$(find "$TASKS_DIR" -maxdepth 1 -name "${TASK_ID}*.md" | head -n 1)

if [[ -z "$TASK_FILE" ]]; then
  red "Error: Task '$TASK_ID' not found."
  echo ""
  echo "Available tasks:"
  find "$TASKS_DIR" -maxdepth 1 -name '*.md' -printf '  %f\n' | sort
  exit 1
fi

# ─── Show task summary before deletion ────────────────────────────────────────
cyan "Task to delete:"
echo ""

TITLE=$(grep -m1 '^# ' "$TASK_FILE" | sed 's/^# //')
STATUS=$(grep -m1 '^\*\*Status\*\*' "$TASK_FILE" | sed 's/.*: *//' | tr -d '`' || echo "unknown")

echo "  ID     : $TASK_ID"
echo "  Title  : $TITLE"
echo "  Status : $STATUS"
echo "  File   : $TASK_FILE"
echo ""

# ─── Confirm deletion ─────────────────────────────────────────────────────────
if [[ "$FORCE" == false ]]; then
  yellow "Are you sure you want to delete this task? This cannot be undone. [y/N]"
  read -r CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Deletion cancelled."
    exit 0
  fi
fi

# ─── Delete task file ─────────────────────────────────────────────────────────
rm -f "$TASK_FILE"
green "✓ Task '$TASK_ID' deleted."

# ─── Update session index if present ──────────────────────────────────────────
INDEX_FILE="$SESSION_DIR/index.md"
if [[ -f "$INDEX_FILE" ]]; then
  # Remove any line referencing this task ID from the index
  sed -i "/\b${TASK_ID}\b/d" "$INDEX_FILE"
  green "✓ Removed '$TASK_ID' from session index."
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
REMAINING=$(find "$TASKS_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
echo ""
cyan "Remaining tasks: $REMAINING"
