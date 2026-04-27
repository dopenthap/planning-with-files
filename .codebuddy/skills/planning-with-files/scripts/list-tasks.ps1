# list-tasks.ps1
# Lists all tasks in the current planning session with their statuses
# Usage: .\list-tasks.ps1 [-SessionDir <path>] [-Status <filter>] [-Verbose]

param(
    [string]$SessionDir = "",
    [string]$Status = "all",
    [switch]$Verbose
)

# Determine session directory
if ([string]::IsNullOrEmpty($SessionDir)) {
    $SessionDir = Join-Path $PWD ".planning-session"
}

# Validate session directory exists
if (-not (Test-Path $SessionDir)) {
    Write-Error "No planning session found at: $SessionDir"
    Write-Host "Run init-session.ps1 to start a new session."
    exit 1
}

# Load session metadata
$MetaFile = Join-Path $SessionDir "session.json"
if (-not (Test-Path $MetaFile)) {
    Write-Error "Session metadata not found. Session may be corrupted."
    exit 1
}

$Session = Get-Content $MetaFile -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "=== Planning Session: $($Session.name) ==="  -ForegroundColor Cyan
Write-Host "Created: $($Session.created_at)"
Write-Host "Last updated: $($Session.updated_at)"
Write-Host ""

# Collect tasks from task files
$TaskFiles = Get-ChildItem -Path $SessionDir -Filter "task-*.json" | Sort-Object Name

if ($TaskFiles.Count -eq 0) {
    Write-Host "No tasks found in this session." -ForegroundColor Yellow
    exit 0
}

$Tasks = @()
foreach ($File in $TaskFiles) {
    $Task = Get-Content $File.FullName -Raw | ConvertFrom-Json
    $Tasks += $Task
}

# Filter by status if specified
$ValidStatuses = @("all", "pending", "in-progress", "complete", "blocked")
if ($Status -notin $ValidStatuses) {
    Write-Error "Invalid status filter: $Status. Valid options: $($ValidStatuses -join ', ')"
    exit 1
}

if ($Status -ne "all") {
    $Tasks = $Tasks | Where-Object { $_.status -eq $Status }
}

# Status color mapping
function Get-StatusColor {
    param([string]$TaskStatus)
    switch ($TaskStatus) {
        "complete"    { return "Green" }
        "in-progress" { return "Yellow" }
        "blocked"     { return "Red" }
        default       { return "Gray" }
    }
}

# Status symbol mapping
function Get-StatusSymbol {
    param([string]$TaskStatus)
    switch ($TaskStatus) {
        "complete"    { return "[x]" }
        "in-progress" { return "[~]" }
        "blocked"     { return "[!]" }
        default       { return "[ ]" }
    }
}

# Display tasks
$Counts = @{ pending = 0; "in-progress" = 0; complete = 0; blocked = 0 }

foreach ($Task in $Tasks) {
    $Symbol = Get-StatusSymbol -TaskStatus $Task.status
    $Color  = Get-StatusColor  -TaskStatus $Task.status

    Write-Host ("  {0} [{1}] {2}" -f $Symbol, $Task.id, $Task.title) -ForegroundColor $Color

    if ($Verbose -and -not [string]::IsNullOrEmpty($Task.description)) {
        Write-Host ("        {0}" -f $Task.description) -ForegroundColor DarkGray
    }

    if ($Verbose -and $Task.notes) {
        Write-Host ("        Notes: {0}" -f $Task.notes) -ForegroundColor DarkGray
    }

    # Tally counts
    if ($Counts.ContainsKey($Task.status)) {
        $Counts[$Task.status]++
    }
}

# Summary footer
Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Cyan
Write-Host ("  Total:       {0}" -f $Tasks.Count)
Write-Host ("  Pending:     {0}" -f $Counts["pending"])     -ForegroundColor Gray
Write-Host ("  In Progress: {0}" -f $Counts["in-progress"]) -ForegroundColor Yellow
Write-Host ("  Complete:    {0}" -f $Counts["complete"])    -ForegroundColor Green
Write-Host ("  Blocked:     {0}" -f $Counts["blocked"])     -ForegroundColor Red
Write-Host ""
