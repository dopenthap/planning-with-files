#!/bin/bash
# complete-task.sh - Mark a task as completed
# Usage: ./complete-task.sh <session_id> <task_id> [notes]

set -e

# --- Configuration ---
PLANNING_DIR="${PLANNING_DIR:-.planning}"
DATE_FORMAT="%Y-%m-%dT%H:%M:%S"

# --- Helpers ---
usage() {
    echo "Usage: $0 <session_id> <task_id> [notes]"
    echo ""
    echo "Arguments:"
    echo "  session_id   The session identifier"
    echo "  task_id      The task identifier to mark as complete"
    echo "  notes        Optional completion notes"
    echo ""
    echo "Example:"
    echo "  $0 my-session task-001 'All tests passing'"
    exit 1
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- Validate Arguments ---
if [ $# -lt 2 ]; then
    usage
fi

SESSION_ID="$1"
TASK_ID="$2"
NOTES="${3:-}"

# --- Resolve Paths ---
SESSION_DIR="$PLANNING_DIR/$SESSION_ID"
TASKS_DIR="$SESSION_DIR/tasks"
TASK_FILE="$TASKS_DIR/${TASK_ID}.md"

# --- Validate Session ---
if [ ! -d "$SESSION_DIR" ]; then
    error "Session '$SESSION_ID' not found. Run init-session.sh first."
fi

if [ ! -d "$TASKS_DIR" ]; then
    error "Tasks directory not found for session '$SESSION_ID'."
fi

# --- Validate Task ---
if [ ! -f "$TASK_FILE" ]; then
    error "Task '$TASK_ID' not found in session '$SESSION_ID'."
fi

# --- Check Current Status ---
CURRENT_STATUS=$(grep -m1 '^status:' "$TASK_FILE" | sed 's/status:[[:space:]]*//' | tr -d '\r')

if [ "$CURRENT_STATUS" = "completed" ]; then
    echo "Task '$TASK_ID' is already marked as completed."
    exit 0
fi

# --- Update Task File ---
COMPLETED_AT=$(date +"$DATE_FORMAT")
TEMP_FILE=$(mktemp)

# Update status and add completed_at timestamp
awk -v completed_at="$COMPLETED_AT" -v notes="$NOTES" '
    /^status:/ { print "status: completed"; next }
    /^updated_at:/ { print "updated_at: " completed_at; next }
    /^## Notes/ && notes != "" {
        print $0
        print ""
        print "**Completion notes:** " notes
        printed_notes = 1
        next
    }
    { print }
    END {
        if (notes != "" && !printed_notes) {
            print ""
            print "## Completion Notes"
            print ""
            print notes
        }
    }
' "$TASK_FILE" > "$TEMP_FILE"

# Insert completed_at after updated_at if not already present
if ! grep -q '^completed_at:' "$TEMP_FILE"; then
    sed -i "/^updated_at:/a completed_at: $COMPLETED_AT" "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$TASK_FILE"

# --- Update Session Summary ---
SESSION_FILE="$SESSION_DIR/session.md"
if [ -f "$SESSION_FILE" ]; then
    TOTAL=$(find "$TASKS_DIR" -name '*.md' | wc -l | tr -d ' ')
    DONE=$(grep -rl '^status: completed' "$TASKS_DIR" 2>/dev/null | wc -l | tr -d ' ')
    sed -i "s/^completed_tasks:.*/completed_tasks: $DONE/" "$SESSION_FILE"
    sed -i "s/^total_tasks:.*/total_tasks: $TOTAL/" "$SESSION_FILE"
fi

# --- Output Result ---
echo "✓ Task '$TASK_ID' marked as completed."
echo "  Session : $SESSION_ID"
echo "  Task    : $TASK_ID"
echo "  Time    : $COMPLETED_AT"
if [ -n "$NOTES" ]; then
    echo "  Notes   : $NOTES"
fi
