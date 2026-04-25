# update-task.ps1
# PowerShell equivalent of update-task.sh
# Updates a task's status in the planning session files

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,

    [Parameter(Mandatory=$true)]
    [ValidateSet("todo", "in-progress", "done", "blocked", "skipped")]
    [string]$Status,

    [Parameter(Mandatory=$false)]
    [string]$Note = "",

    [Parameter(Mandatory=$false)]
    [string]$SessionDir = ".codebuddy/session"
)

$ErrorActionPreference = "Stop"

# Resolve session directory
$SessionPath = Join-Path (Get-Location) $SessionDir

if (-not (Test-Path $SessionPath)) {
    Write-Error "Session directory not found: $SessionPath"
    Write-Error "Run init-session.ps1 first to initialize a planning session."
    exit 1
}

# Find the tasks file
$TasksFile = Join-Path $SessionPath "tasks.md"

if (-not (Test-Path $TasksFile)) {
    Write-Error "Tasks file not found: $TasksFile"
    exit 1
}

# Read current content
$Content = Get-Content $TasksFile -Raw

# Status emoji mapping
$StatusEmoji = @{
    "todo"        = "[ ]"
    "in-progress" = "[~]"
    "done"        = "[x]"
    "blocked"     = "[!]"
    "skipped"     = "[-]"
}

$NewMark = $StatusEmoji[$Status]

# Pattern to find the task by ID
# Tasks are expected to be formatted as: - [ ] TASK-001: Description
$Pattern = "(?m)^(- )\[[x~! \-]\]( $([regex]::Escape($TaskId)):.*)"

if ($Content -notmatch $Pattern) {
    Write-Error "Task '$TaskId' not found in $TasksFile"
    exit 1
}

# Replace the status marker
$UpdatedContent = [regex]::Replace($Content, $Pattern, "\`$1$NewMark\`$2")

# Append note if provided
if ($Note -ne "") {
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $NoteEntry = "  - [$Timestamp] $Note"

    # Insert note after the task line
    $NotePattern = "(?m)^(- \[$([regex]::Escape($NewMark[1]))\] $([regex]::Escape($TaskId)):.*)"
    $UpdatedContent = [regex]::Replace($UpdatedContent, $NotePattern, "\`$1`n$NoteEntry")
}

# Write updated content back
Set-Content -Path $TasksFile -Value $UpdatedContent -NoNewline

Write-Host "Updated task '$TaskId' -> $Status" -ForegroundColor Green

if ($Note -ne "") {
    Write-Host "  Note: $Note" -ForegroundColor Cyan
}

# Update the session log
$LogFile = Join-Path $SessionPath "session.log"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogEntry = "[$Timestamp] TASK_UPDATE: $TaskId => $Status"

if ($Note -ne "") {
    $LogEntry += " | $Note"
}

Add-Content -Path $LogFile -Value $LogEntry

Write-Host "Session log updated." -ForegroundColor DarkGray
