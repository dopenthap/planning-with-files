# show-task.ps1
# Display detailed information about a specific task
# Usage: .\show-task.ps1 -TaskId <task-id> [-SessionDir <path>]

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,

    [Parameter(Mandatory=$false)]
    [string]$SessionDir = ".codebuddy/sessions"
)

# ANSI color codes
$ESC = [char]27
$RESET = "$ESC[0m"
$BOLD = "$ESC[1m"
$CYAN = "$ESC[36m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$RED = "$ESC[31m"
$BLUE = "$ESC[34m"
$MAGENTA = "$ESC[35m"
$DIM = "$ESC[2m"

function Write-ColorLine {
    param([string]$Text, [string]$Color = $RESET)
    Write-Host "${Color}${Text}${RESET}"
}

function Get-StatusColor {
    param([string]$Status)
    switch ($Status.ToLower()) {
        "done"        { return $GREEN }
        "in-progress" { return $YELLOW }
        "blocked"     { return $RED }
        "pending"     { return $BLUE }
        default       { return $DIM }
    }
}

function Get-StatusIcon {
    param([string]$Status)
    switch ($Status.ToLower()) {
        "done"        { return "[x]" }
        "in-progress" { return "[~]" }
        "blocked"     { return "[!]" }
        "pending"     { return "[ ]" }
        default       { return "[?]" }
    }
}

# Find the most recent session directory
if (-not (Test-Path $SessionDir)) {
    Write-ColorLine "Error: Session directory '$SessionDir' not found." $RED
    exit 1
}

$sessions = Get-ChildItem -Path $SessionDir -Directory | Sort-Object Name -Descending
if ($sessions.Count -eq 0) {
    Write-ColorLine "Error: No sessions found in '$SessionDir'." $RED
    exit 1
}

$latestSession = $sessions[0].FullName
$tasksDir = Join-Path $latestSession "tasks"

if (-not (Test-Path $tasksDir)) {
    Write-ColorLine "Error: Tasks directory not found in session '$latestSession'." $RED
    exit 1
}

# Find task file matching the given ID
$taskFile = $null
$taskFiles = Get-ChildItem -Path $tasksDir -Filter "*.md" -File

foreach ($file in $taskFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "(?m)^id:\s*$([regex]::Escape($TaskId))\s*$") {
        $taskFile = $file.FullName
        break
    }
}

if (-not $taskFile) {
    Write-ColorLine "Error: Task '$TaskId' not found in session '$($sessions[0].Name)'." $RED
    exit 1
}

# Parse task file
$lines = Get-Content $taskFile
$metadata = @{}
$bodyLines = @()
$inFrontMatter = $false
$frontMatterDone = $false
$frontMatterCount = 0

foreach ($line in $lines) {
    if ($line -eq "---" -and -not $frontMatterDone) {
        $frontMatterCount++
        if ($frontMatterCount -eq 1) { $inFrontMatter = $true; continue }
        if ($frontMatterCount -eq 2) { $inFrontMatter = $false; $frontMatterDone = $true; continue }
    }
    if ($inFrontMatter) {
        if ($line -match "^(\w[\w-]*):\s*(.*)$") {
            $metadata[$Matches[1]] = $Matches[2].Trim()
        }
    } elseif ($frontMatterDone) {
        $bodyLines += $line
    }
}

$status = if ($metadata["status"]) { $metadata["status"] } else { "unknown" }
$statusColor = Get-StatusColor $status
$statusIcon = Get-StatusIcon $status

# Display task details
Write-Host ""
Write-ColorLine "$BOLD========================================$RESET"
Write-Host "${BOLD}${CYAN}Task: $($metadata['id'])${RESET}"
Write-ColorLine "========================================" $BOLD
Write-Host ""

if ($metadata["title"]) {
    Write-Host "${BOLD}Title:${RESET}    $($metadata['title'])"
}

Write-Host "${BOLD}Status:${RESET}   ${statusColor}${statusIcon} ${status}${RESET}"

if ($metadata["priority"]) {
    Write-Host "${BOLD}Priority:${RESET} $($metadata['priority'])"
}

if ($metadata["created"]) {
    Write-Host "${BOLD}Created:${RESET}  $($metadata['created'])"
}

if ($metadata["updated"]) {
    Write-Host "${BOLD}Updated:${RESET}  $($metadata['updated'])"
}

if ($metadata["depends"]) {
    Write-Host "${BOLD}Depends:${RESET}  ${MAGENTA}$($metadata['depends'])${RESET}"
}

Write-Host ""

if ($bodyLines.Count -gt 0) {
    Write-ColorLine "--- Description ---" $DIM
    foreach ($line in $bodyLines) {
        Write-Host $line
    }
}

Write-Host ""
Write-ColorLine "Session: $($sessions[0].Name)" $DIM
Write-Host ""
