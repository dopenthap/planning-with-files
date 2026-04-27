#!/bin/bash
# list-tasks.sh - List all tasks and their current status from the planning session
# Usage: ./list-tasks.sh [--filter <status>] [--session <session-dir>]

set -e

# Default values
FILTER=""
SESSION_DIR=".planning-session"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      FILTER="$2"
      shift 2
      ;;
    --session)
      SESSION_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--filter <status>] [--session <session-dir>]"
      echo ""
      echo "Options:"
      echo "  --filter <status>   Filter tasks by status (todo, in-progress, done, blocked)"
      echo "  --session <dir>     Path to session directory (default: .planning-session)"
      echo "  -h, --help          Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Check if session directory exists
if [ ! -d "$SESSION_DIR" ]; then
  echo "Error: Session directory '$SESSION_DIR' not found."
  echo "Run init-session.sh to create a new planning session."
  exit 1
fi

TASKS_FILE="$SESSION_DIR/tasks.md"

if [ ! -f "$TASKS_FILE" ]; then
  echo "Error: Tasks file not found at '$TASKS_FILE'."
  exit 1
fi

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Count tasks by status
total=$(grep -c '^## Task' "$TASKS_FILE" 2>/dev/null || echo 0)
todo=$(grep -c 'Status: todo' "$TASKS_FILE" 2>/dev/null || echo 0)
in_progress=$(grep -c 'Status: in-progress' "$TASKS_FILE" 2>/dev/null || echo 0)
done_count=$(grep -c 'Status: done' "$TASKS_FILE" 2>/dev/null || echo 0)
blocked=$(grep -c 'Status: blocked' "$TASKS_FILE" 2>/dev/null || echo 0)

echo -e "${CYAN}=== Planning Session Tasks ===${NC}"
echo -e "Session: ${BLUE}$SESSION_DIR${NC}"
echo ""
echo -e "Summary: ${NC}Total: $total | ${YELLOW}Todo: $todo${NC} | ${BLUE}In-Progress: $in_progress${NC} | ${GREEN}Done: $done_count${NC} | ${RED}Blocked: $blocked${NC}"
echo ""

# Parse and display tasks
current_task=""
current_status=""
current_priority=""
current_assignee=""

while IFS= read -r line; do
  if [[ "$line" =~ ^##\ Task ]]; then
    current_task=$(echo "$line" | sed 's/^## //')
    current_status=""
    current_priority=""
    current_assignee=""
  elif [[ "$line" =~ ^\*\*Status:\*\* ]]; then
    current_status=$(echo "$line" | sed 's/\*\*Status:\*\* //')
  elif [[ "$line" =~ ^\*\*Priority:\*\* ]]; then
    current_priority=$(echo "$line" | sed 's/\*\*Priority:\*\* //')
  elif [[ "$line" =~ ^\*\*Assignee:\*\* ]]; then
    current_assignee=$(echo "$line" | sed 's/\*\*Assignee:\*\* //')
  elif [[ -z "$line" && -n "$current_task" && -n "$current_status" ]]; then
    # Apply filter if specified
    if [[ -z "$FILTER" || "$current_status" == "$FILTER" ]]; then
      # Color based on status
      case "$current_status" in
        todo)        status_color=$YELLOW ;;
        in-progress) status_color=$BLUE ;;
        done)        status_color=$GREEN ;;
        blocked)     status_color=$RED ;;
        *)           status_color=$NC ;;
      esac

      echo -e "  ${NC}${current_task}"
      echo -e "    Status:   ${status_color}${current_status}${NC}"
      [ -n "$current_priority" ] && echo -e "    Priority: $current_priority"
      [ -n "$current_assignee" ] && echo -e "    Assignee: $current_assignee"
      echo ""
    fi
    current_task=""
    current_status=""
  fi
done < "$TASKS_FILE"

# Handle last task if file doesn't end with blank line
if [[ -n "$current_task" && -n "$current_status" ]]; then
  if [[ -z "$FILTER" || "$current_status" == "$FILTER" ]]; then
    case "$current_status" in
      todo)        status_color=$YELLOW ;;
      in-progress) status_color=$BLUE ;;
      done)        status_color=$GREEN ;;
      blocked)     status_color=$RED ;;
      *)           status_color=$NC ;;
    esac
    echo -e "  ${NC}${current_task}"
    echo -e "    Status:   ${status_color}${current_status}${NC}"
    [ -n "$current_priority" ] && echo -e "    Priority: $current_priority"
    [ -n "$current_assignee" ] && echo -e "    Assignee: $current_assignee"
    echo ""
  fi
fi

if [ "$total" -eq 0 ]; then
  echo "No tasks found in session."
fi
