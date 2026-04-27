# delete-task.ps1
# Deletes a task file from the planning session
# Usage: .\delete-task.ps1 -TaskId <id> [-SessionDir <dir>] [-Force]

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,

    [Parameter(Mandatory=$false)]
    [string]$SessionDir = ".codebuddy/planning",

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Resolve session directory
$resolvedDir = $SessionDir
if (-not [System.IO.Path]::IsPathRooted($SessionDir)) {
    $resolvedDir = Join-Path (Get-Location) $SessionDir
}

# Check if session directory exists
if (-not (Test-Path $resolvedDir)) {
    Write-Error "Session directory not found: $resolvedDir"
    exit 1
}

# Find the task file (support both numeric and full id formats)
$taskFile = $null

# Try direct match first
$directPath = Join-Path $resolvedDir "task-$TaskId.md"
if (Test-Path $directPath) {
    $taskFile = $directPath
} else {
    # Search for a file matching the task id pattern
    $candidates = Get-ChildItem -Path $resolvedDir -Filter "task-*.md" | Where-Object {
        $_.BaseName -match "task-$([regex]::Escape($TaskId))"
    }
    if ($candidates.Count -eq 1) {
        $taskFile = $candidates[0].FullName
    } elseif ($candidates.Count -gt 1) {
        Write-Error "Ambiguous task id '$TaskId' matches multiple files:"
        $candidates | ForEach-Object { Write-Error "  $($_.Name)" }
        exit 1
    }
}

if (-not $taskFile) {
    Write-Error "Task not found: $TaskId"
    exit 1
}

# Read task title for confirmation message
$taskTitle = ""
try {
    $firstLine = Get-Content $taskFile -TotalCount 1
    if ($firstLine -match '^#\s+(.+)') {
        $taskTitle = $Matches[1]
    }
} catch {
    $taskTitle = (Split-Path $taskFile -Leaf)
}

# Confirm deletion unless -Force is specified
if (-not $Force) {
    $displayName = if ($taskTitle) { "'$taskTitle'" } else { (Split-Path $taskFile -Leaf) }
    $confirm = Read-Host "Delete task $displayName? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Deletion cancelled."
        exit 0
    }
}

# Perform deletion
try {
    Remove-Item $taskFile -Force
    $fileName = Split-Path $taskFile -Leaf
    Write-Host "Deleted: $fileName"

    # Update session index if it exists
    $indexFile = Join-Path $resolvedDir "index.md"
    if (Test-Path $indexFile) {
        $indexContent = Get-Content $indexFile -Raw
        # Remove any line referencing this task file
        $fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($taskFile)
        $updatedContent = ($indexContent -split "`n" | Where-Object {
            $_ -notmatch [regex]::Escape($fileBaseName)
        }) -join "`n"
        Set-Content $indexFile $updatedContent -NoNewline
        Write-Host "Updated index."
    }

    exit 0
} catch {
    Write-Error "Failed to delete task: $_"
    exit 1
}
