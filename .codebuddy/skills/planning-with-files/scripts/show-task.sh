#!/bin/bash
# show-task.sh - Display detailed information about a specific task
# Usage: ./show-task.sh <task-id> [session-dir]

set -euo pipefail

# ─── Arguments ────────────────────────────────────────────────────────────────
TASK_ID="${1:-}"
SESSION_DIR="${2:-.planning-session}"

# ─── Validation ───────────────────────────────────────────────────────────────
if [[ -z "$TASK_ID" ]]; then
  echo "Error: task-id is required." >&2
  echo "Usage: $0 <task-id> [session-dir]" >&2
  exit 1
fi

if [[ ! -d "$SESSION_DIR" ]]; then
  echo "Error: session directory '$SESSION_DIR' not found." >&2
  echo "Run init-session.sh first to create a planning session." >&2
  exit 1
fi

TASKS_DIR="$SESSION_DIR/tasks"

if [[ ! -d "$TASKS_DIR" ]]; then
  echo "Error: tasks directory not found inside '$SESSION_DIR'." >&2
  exit 1
fi

# ─── Locate task file ─────────────────────────────────────────────────────────
# Support both exact match and prefix match (e.g. "01" matches "01-some-task.md")
TASK_FILE=""

for f in "$TASKS_DIR"/*.md; do
  [[ -e "$f" ]] || continue
  basename_f="$(basename "$f" .md)"
  if [[ "$basename_f" == "$TASK_ID" ]] || [[ "$basename_f" == "${TASK_ID}-"* ]]; then
    TASK_FILE="$f"
    break
  fi
done

if [[ -z "$TASK_FILE" ]]; then
  echo "Error: No task found matching id '$TASK_ID' in '$TASKS_DIR'." >&2
  exit 1
fi

# ─── Parse frontmatter helpers ────────────────────────────────────────────────
get_field() {
  local field="$1"
  grep -m1 "^${field}:" "$TASK_FILE" | sed "s/^${field}:[[:space:]]*//' | tr -d '\r'
}

# ─── Display task ─────────────────────────────────────────────────────────────
TITLE="$(get_field 'title')"
STATUS="$(get_field 'status')"
PRIORITY="$(get_field 'priority')"
CREATED="$(get_field 'created')"
UPDATED="$(get_field 'updated')"
ASSIGNED="$(get_field 'assigned')"

# Colour codes
RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"
GREY="\033[90m"

status_color() {
  case "$1" in
    done|complete|completed) echo -e "${GREEN}$1${RESET}" ;;
    in-progress|in_progress|wip) echo -e "${YELLOW}$1${RESET}" ;;
    blocked) echo -e "${RED}$1${RESET}" ;;
    *) echo -e "${GREY}$1${RESET}" ;;
  esac
}

priority_color() {
  case "$1" in
    high|critical) echo -e "${RED}$1${RESET}" ;;
    medium|normal) echo -e "${YELLOW}$1${RESET}" ;;
    low) echo -e "${GREY}$1${RESET}" ;;
    *) echo "$1" ;;
  esac
}

echo -e ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
echo -e "${BOLD} Task: ${TITLE:-$(basename "$TASK_FILE" .md)}${RESET}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
echo -e "  ${BOLD}File:${RESET}     $(basename "$TASK_FILE")"
[[ -n "$STATUS" ]]   && echo -e "  ${BOLD}Status:${RESET}   $(status_color "$STATUS")"
[[ -n "$PRIORITY" ]] && echo -e "  ${BOLD}Priority:${RESET} $(priority_color "$PRIORITY")"
[[ -n "$ASSIGNED" ]] && echo -e "  ${BOLD}Assigned:${RESET} $ASSIGNED"
[[ -n "$CREATED" ]]  && echo -e "  ${BOLD}Created:${RESET}  ${GREY}$CREATED${RESET}"
[[ -n "$UPDATED" ]]  && echo -e "  ${BOLD}Updated:${RESET}  ${GREY}$UPDATED${RESET}"
echo -e "${CYAN}──────────────────────────────────────────${RESET}"

# Print body (everything after the closing ---)
IN_FRONTMATTER=false
FRONT_COUNT=0
while IFS= read -r line; do
  if [[ "$line" == "---" ]]; then
    FRONT_COUNT=$((FRONT_COUNT + 1))
    [[ $FRONT_COUNT -eq 2 ]] && IN_FRONTMATTER=false && continue
    IN_FRONTMATTER=true
    continue
  fi
  [[ $IN_FRONTMATTER == false && $FRONT_COUNT -ge 2 ]] && echo "$line"
done < "$TASK_FILE"

echo -e "${CYAN}══════════════════════════════════════════${RESET}"
echo ""
