# Clean up old backup directories on Hetzner server
# Usage: .\deployment\cleanup-hetzner-backups.ps1 [-DryRun] [-KeepLast <number>]

param(
    [string]$ServerIP = "159.69.242.154",
    [string]$ServerUser = "root",
    [switch]$DryRun = $false,
    [int]$KeepLast = 3  # Keep the 3 most recent backups
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }

Write-Info "================================================"
Write-Info "Hetzner Server Backup Cleanup"
Write-Info "================================================"
Write-Host "Server: $ServerUser@$ServerIP" -ForegroundColor Yellow
Write-Host "Keep Last: $KeepLast backups" -ForegroundColor Yellow
if ($DryRun) {
    Write-Warn "DRY RUN MODE - No files will be deleted"
}
Write-Host ""

# Step 1: List all backup directories
Write-Info "Step 1: Finding backup directories..."
$backupDirs = ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -maxdepth 1 -name 'app.backup.*' -type d | sort -r"

if ([string]::IsNullOrWhiteSpace($backupDirs)) {
    Write-Ok "No backup directories found!"
    exit 0
}

$backupArray = $backupDirs -split "`n" | Where-Object { $_ -match '\S' }
$totalBackups = $backupArray.Count

Write-Info "Found $totalBackups backup directories"
Write-Host ""

# Step 2: Show size of backups
Write-Info "Step 2: Calculating backup sizes..."
Write-Host "Directory                                              Size"
Write-Host "-------------------------------------------------------- --------"
foreach ($backup in $backupArray) {
    $size = ssh "$ServerUser@$ServerIP" "du -sh '$backup' 2>/dev/null | cut -f1"
    $backupName = Split-Path -Leaf $backup
    Write-Host ("{0,-56} {1}" -f $backupName, $size)
}
Write-Host ""

# Calculate total backup size
$totalSize = ssh "$ServerUser@$ServerIP" "du -sh /opt/flipnosis/app.backup.* 2>/dev/null | tail -1 | cut -f1"
Write-Warn "Total space used by backups: $totalSize"
Write-Host ""

# Step 3: Determine which backups to delete
if ($totalBackups -le $KeepLast) {
    Write-Ok "Only $totalBackups backup(s) found. Keeping all (threshold: $KeepLast)"
    exit 0
}

$toDelete = $backupArray | Select-Object -Skip $KeepLast
$deleteCount = $toDelete.Count

Write-Info "Step 3: Backups to delete ($deleteCount directories)"
Write-Host "----------------------------------------"
foreach ($backup in $toDelete) {
    Write-Host "  - $(Split-Path -Leaf $backup)" -ForegroundColor Red
}
Write-Host ""

Write-Info "Keeping the $KeepLast most recent backups:"
$toKeep = $backupArray | Select-Object -First $KeepLast
foreach ($backup in $toKeep) {
    Write-Host "  + $(Split-Path -Leaf $backup)" -ForegroundColor Green
}
Write-Host ""

# Step 4: Confirm deletion
if (!$DryRun) {
    Write-Warn "WARNING: About to delete $deleteCount backup directories!"
    $confirm = Read-Host "Type 'DELETE' to confirm, or anything else to cancel"

    if ($confirm -ne "DELETE") {
        Write-Info "Cancelled by user"
        exit 0
    }
}

# Step 5: Delete old backups
Write-Info "Step 4: Removing old backups..."
$deletedCount = 0

foreach ($backup in $toDelete) {
    $backupName = Split-Path -Leaf $backup

    if ($DryRun) {
        Write-Host "[DRY RUN] Would delete: $backupName" -ForegroundColor Yellow
    } else {
        try {
            Write-Info "Deleting $backupName..."
            ssh "$ServerUser@$ServerIP" "rm -rf '$backup'"
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "✓ Deleted $backupName"
                $deletedCount++
            } else {
                Write-Fail "✗ Failed to delete $backupName"
            }
        } catch {
            Write-Fail "✗ Error deleting $backupName: $($_.Exception.Message)"
        }
    }
}

Write-Host ""

# Step 6: Show results
Write-Info "================================================"
Write-Info "CLEANUP COMPLETE"
Write-Info "================================================"

if ($DryRun) {
    Write-Host "DRY RUN: Would have deleted $deleteCount directories" -ForegroundColor Yellow
    Write-Host ""
    Write-Info "To actually delete, run:"
    Write-Host "  .\deployment\cleanup-hetzner-backups.ps1" -ForegroundColor Cyan
} else {
    Write-Ok "Successfully deleted $deletedCount of $deleteCount directories"
    Write-Host ""

    # Show new disk usage
    Write-Info "Current disk usage after cleanup:"
    ssh "$ServerUser@$ServerIP" "df -h | grep -E '(Filesystem|/$)'" | Write-Host
    Write-Host ""

    Write-Info "Remaining backups:"
    ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -maxdepth 1 -name 'app.backup.*' -type d | sort -r" | Write-Host
}

Write-Host ""
Write-Ok "Done!"
