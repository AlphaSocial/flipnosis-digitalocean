# Comprehensive cleanup of Hetzner server disk space
# Usage: .\deployment\cleanup-hetzner-full.ps1 [-DryRun]

param(
    [string]$ServerIP = "159.69.242.154",
    [string]$ServerUser = "root",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

Write-Info "================================================"
Write-Info "Hetzner Server Full Cleanup"
Write-Info "================================================"
Write-Host "Server: $ServerUser@$ServerIP" -ForegroundColor Yellow
if ($DryRun) {
    Write-Warn "DRY RUN MODE - No changes will be made"
}
Write-Host ""

# 1. Show current disk usage
Write-Info "Current Disk Usage"
Write-Host "----------------------------------------"
ssh "$ServerUser@$ServerIP" "df -h | grep -E '(Filesystem|/$)'" | Write-Host
Write-Host ""

# 2. Clean old backup directories (keep last 3)
Write-Info "Cleaning old backup directories..."
$backupCount = ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -maxdepth 1 -name 'app.backup.*' -type d | wc -l"
Write-Host "Found $backupCount backup directories"

if ([int]$backupCount -gt 3) {
    if ($DryRun) {
        Write-Warn "[DRY RUN] Would keep 3 most recent backups and delete $([int]$backupCount - 3) old ones"
    } else {
        Write-Info "Keeping 3 most recent backups, deleting $([int]$backupCount - 3) old ones..."
        ssh "$ServerUser@$ServerIP" @"
cd /opt/flipnosis
ls -dt app.backup.* | tail -n +4 | xargs -r rm -rf
"@
        Write-Ok "✓ Deleted old backups"
    }
} else {
    Write-Ok "Only $backupCount backups found, keeping all"
}
Write-Host ""

# 3. Clean PM2 logs
Write-Info "Cleaning PM2 logs..."
$pm2LogSize = ssh "$ServerUser@$ServerIP" "du -sh ~/.pm2/logs 2>/dev/null | cut -f1"
Write-Host "Current PM2 log size: $pm2LogSize"

if ($DryRun) {
    Write-Warn "[DRY RUN] Would flush PM2 logs"
} else {
    ssh "$ServerUser@$ServerIP" "pm2 flush"
    Write-Ok "✓ Flushed PM2 logs"
}
Write-Host ""

# 4. Clean /tmp directory (files older than 7 days)
Write-Info "Cleaning old /tmp files..."
$tmpFiles = ssh "$ServerUser@$ServerIP" "find /tmp -type f -mtime +7 2>/dev/null | wc -l"
Write-Host "Found $tmpFiles files older than 7 days in /tmp"

if ([int]$tmpFiles -gt 0) {
    if ($DryRun) {
        Write-Warn "[DRY RUN] Would delete $tmpFiles old files from /tmp"
    } else {
        ssh "$ServerUser@$ServerIP" "find /tmp -type f -mtime +7 -delete 2>/dev/null"
        Write-Ok "✓ Deleted old /tmp files"
    }
} else {
    Write-Ok "No old /tmp files to clean"
}
Write-Host ""

# 5. Clean npm cache
Write-Info "Cleaning npm cache..."
if ($DryRun) {
    Write-Warn "[DRY RUN] Would clean npm cache"
} else {
    ssh "$ServerUser@$ServerIP" "npm cache clean --force 2>/dev/null"
    Write-Ok "✓ Cleaned npm cache"
}
Write-Host ""

# 6. Clean apt cache (if applicable)
Write-Info "Cleaning apt cache..."
if ($DryRun) {
    Write-Warn "[DRY RUN] Would clean apt cache"
} else {
    ssh "$ServerUser@$ServerIP" "apt-get clean 2>/dev/null || true"
    Write-Ok "✓ Cleaned apt cache"
}
Write-Host ""

# 7. Remove old log files
Write-Info "Cleaning large log files..."
$largeLogsCount = ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.log' -size +50M 2>/dev/null | wc -l"
Write-Host "Found $largeLogsCount log files larger than 50MB"

if ([int]$largeLogsCount -gt 0) {
    Write-Info "Large log files:"
    ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.log' -size +50M -exec ls -lh {} \; 2>/dev/null" | Write-Host

    if ($DryRun) {
        Write-Warn "[DRY RUN] Would truncate large log files"
    } else {
        ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.log' -size +50M -exec truncate -s 0 {} \; 2>/dev/null"
        Write-Ok "✓ Truncated large log files"
    }
}
Write-Host ""

# 8. Check for duplicate node_modules
Write-Info "Checking for duplicate node_modules..."
$nodeModulesCount = ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name 'node_modules' -type d 2>/dev/null | wc -l"
Write-Host "Found $nodeModulesCount node_modules directories"

if ([int]$nodeModulesCount -gt 1) {
    ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name 'node_modules' -type d -exec du -sh {} \; 2>/dev/null" | Write-Host
    Write-Warn "Multiple node_modules found - this is normal if you have backup directories"
}
Write-Host ""

# 9. Show final disk usage
Write-Info "================================================"
Write-Info "FINAL DISK USAGE"
Write-Info "================================================"
ssh "$ServerUser@$ServerIP" "df -h | grep -E '(Filesystem|/$)'" | Write-Host
Write-Host ""

if ($DryRun) {
    Write-Warn "DRY RUN COMPLETE - No changes were made"
    Write-Info "To perform actual cleanup, run:"
    Write-Host "  .\deployment\cleanup-hetzner-full.ps1" -ForegroundColor Cyan
} else {
    Write-Ok "CLEANUP COMPLETE!"
}

Write-Host ""
Write-Info "For more detailed analysis, run:"
Write-Host "  .\deployment\check-hetzner-disk-usage.ps1" -ForegroundColor Cyan
