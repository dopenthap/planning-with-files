#!/bin/bash
# init-session.sh
# Initializes a planning session by creating the necessary file structure
# and populating initial plan files based on user input.

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULT_PLAN_DIR="./plan"
DATE=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Helpers ─────────────────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Initialize a new planning-with-files session.

Options:
  -d, --dir DIR        Directory to create plan files in (default: ./plan)
  -n, --name NAME      Project/session name
  -t, --template TPL   Template to use: basic | detailed | sprint (default: basic)
  -f, --force          Overwrite existing session files
  -h, --help           Show this help message

Examples:
  $(basename "$0") --name "my-feature" --dir ./plans
  $(basename "$0") -n "Q3 Roadmap" -t detailed -d ./roadmap
EOF
}

# ─── Argument Parsing ────────────────────────────────────────────────────────
PLAN_DIR="$DEFAULT_PLAN_DIR"
SESSION_NAME=""
TEMPLATE="basic"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)      PLAN_DIR="$2";      shift 2 ;;
    -n|--name)     SESSION_NAME="$2";  shift 2 ;;
    -t|--template) TEMPLATE="$2";      shift 2 ;;
    -f|--force)    FORCE=true;          shift   ;;
    -h|--help)     usage; exit 0        ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ─── Validation ──────────────────────────────────────────────────────────────
if [[ -z "$SESSION_NAME" ]]; then
  log_error "Session name is required. Use -n / --name."
  usage
  exit 1
fi

case "$TEMPLATE" in
  basic|detailed|sprint) ;;
  *) log_error "Invalid template '$TEMPLATE'. Choose: basic, detailed, sprint."; exit 1 ;;
esac

# ─── Directory Setup ─────────────────────────────────────────────────────────
if [[ -d "$PLAN_DIR" && "$FORCE" == false ]]; then
  log_warn "Directory '$PLAN_DIR' already exists. Use --force to overwrite."
  exit 1
fi

mkdir -p "$PLAN_DIR"
log_success "Created plan directory: $PLAN_DIR"

# ─── Write Session Metadata ──────────────────────────────────────────────────
cat > "$PLAN_DIR/session.json" <<EOF
{
  "name": "$SESSION_NAME",
  "template": "$TEMPLATE",
  "created": "$DATE",
  "timestamp": "$TIMESTAMP",
  "status": "in-progress",
  "tasks": []
}
EOF
log_success "Written session metadata: $PLAN_DIR/session.json"

# ─── Write Plan Files Based on Template ──────────────────────────────────────
write_basic() {
  cat > "$PLAN_DIR/plan.md" <<EOF
# $SESSION_NAME
_Created: $DATE_

## Goal
<!-- Describe the overall goal of this session -->

## Tasks
- [ ] Task 1
- [ ] Task 2

## Notes
<!-- Any additional context or blockers -->
EOF
}

write_detailed() {
  write_basic
  cat > "$PLAN_DIR/breakdown.md" <<EOF
# Detailed Breakdown — $SESSION_NAME
_Created: $DATE_

## Milestones
| # | Milestone | Owner | Due | Status |
|---|-----------|-------|-----|--------|
| 1 | | | | pending |

## Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| | | | |
EOF
}

write_sprint() {
  write_basic
  cat > "$PLAN_DIR/sprint.md" <<EOF
# Sprint Plan — $SESSION_NAME
_Created: $DATE_

## Sprint Goal

## Backlog
| ID | Story | Points | Assignee | Status |
|----|-------|--------|----------|--------|
| 1  |       |        |          | todo   |

## Definition of Done
- [ ] Code reviewed
- [ ] Tests passing
- [ ] Documentation updated
EOF
}

case "$TEMPLATE" in
  basic)    write_basic    ;;
  detailed) write_detailed ;;
  sprint)   write_sprint   ;;
esac

log_success "Written plan files for template: $TEMPLATE"

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
log_success "Session '${SESSION_NAME}' initialized in '${PLAN_DIR}'"
log_info "Next step: edit ${PLAN_DIR}/plan.md and start adding tasks."
