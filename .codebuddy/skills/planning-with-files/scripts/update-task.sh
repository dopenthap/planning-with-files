#!/bin/bash

# update-task.sh
# Updates the status of a task in the current planning session
# Usage: ./update-task.sh <task-id> <status> [notes]
# Status options: todo, in-progress, done, blocked, skipped

set -e

# ─── Constants ────────────────────────────────────────────────────────────────

VALID_STATUSES=("todo" "in-progress" "done" "blocked" "skipped")
SESSION_DIR=".codebuddy/session"
PLAN_FILE="$SESSION_DIR/plan.md"
LOG_FILE="$SESSION_DIR/task-log.md"

# ─── Helpers ──────────────────────────────────────────────────────────────────

log() {
  echo "[update-task] $*"
}

error() {
  echo "[update-task] ERROR: $*" >&2
  exit 1
}

is_valid_status() {
  local status="$1"
  for s in "${VALID_STATUSES[@]}"; do
    [[ "$s" == "$status" ]] && return 0
  done
  return 1
}

status_emoji() {
  case "$1" in
    todo)        echo "⬜" ;;
    in-progress) echo "🔄" ;;
    done)        echo "✅" ;;
    blocked)     echo "🚫" ;;
    skipped)     echo "⏭️" ;;
    *)           echo "❓" ;;
  esac
}

# ─── Argument Validation ──────────────────────────────────────────────────────

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <task-id> <status> [notes]"
  echo "  task-id : identifier used in plan.md (e.g. TASK-001)"
  echo "  status  : ${VALID_STATUSES[*]}"
  echo "  notes   : optional free-text note appended to the log"
  exit 1
fi

TASK_ID="$1"
NEW_STATUS="$2"
NOTES="${3:-}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if ! is_valid_status "$NEW_STATUS"; then
  error "Invalid status '$NEW_STATUS'. Valid options: ${VALID_STATUSES[*]}"
fi

# ─── Pre-flight Checks ────────────────────────────────────────────────────────

if [[ ! -d "$SESSION_DIR" ]]; then
  error "Session directory '$SESSION_DIR' not found. Run init-session.sh first."
fi

if [[ ! -f "$PLAN_FILE" ]]; then
  error "Plan file '$PLAN_FILE' not found. Run init-session.sh first."
fi

# ─── Update plan.md ───────────────────────────────────────────────────────────

# Check that the task ID exists in the plan
if ! grep -q "$TASK_ID" "$PLAN_FILE"; then
  error "Task ID '$TASK_ID' not found in $PLAN_FILE"
fi

EMOJI=$(status_emoji "$NEW_STATUS")

# Replace any existing status emoji on the line containing TASK_ID
# Pattern matches lines with the task id and swaps the leading emoji/status marker
sed -i.bak \
  "s|\(.*$TASK_ID.*\)\(⬜\|🔄\|✅\|🚫\|⏭️\|❓\)|$EMOJI \1|" \
  "$PLAN_FILE" 2>/dev/null || true

# Simpler fallback: append status tag at end of matching line if no emoji found
if ! grep -q "$EMOJI" "$PLAN_FILE"; then
  sed -i.bak "/$TASK_ID/s/$/ [$NEW_STATUS]/" "$PLAN_FILE"
fi

rm -f "$PLAN_FILE.bak"
log "Updated '$TASK_ID' → $NEW_STATUS $EMOJI in $PLAN_FILE"

# ─── Append to Task Log ───────────────────────────────────────────────────────

if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" <<EOF
# Task Log

Auto-generated log of task status changes.

| Timestamp | Task ID | Status | Notes |
|-----------|---------|--------|-------|
EOF
  log "Created task log at $LOG_FILE"
fi

echo "| $TIMESTAMP | $TASK_ID | $EMOJI $NEW_STATUS | $NOTES |" >> "$LOG_FILE"
log "Appended entry to $LOG_FILE"

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "  Task   : $TASK_ID"
echo "  Status : $EMOJI $NEW_STATUS"
[[ -n "$NOTES" ]] && echo "  Notes  : $NOTES"
echo ""
