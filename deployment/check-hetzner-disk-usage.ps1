# Check Hetzner server disk usage and identify space hogs
# Usage: .\deployment\check-hetzner-disk-usage.ps1

param(
    [string]$ServerIP = "159.69.242.154",
    [string]$ServerUser = "root"
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

Write-Info "================================================"
Write-Info "Hetzner Server Disk Usage Analysis"
Write-Info "================================================"
Write-Host "Server: $ServerUser@$ServerIP" -ForegroundColor Yellow
Write-Host ""

# 1. Overall disk usage
Write-Info "1. Overall Disk Usage"
Write-Host "----------------------------------------"
ssh "$ServerUser@$ServerIP" "df -h" | Write-Host
Write-Host ""

# 2. Identify largest directories in root
Write-Info "2. Largest Directories in /"
Write-Host "----------------------------------------"
ssh "$ServerUser@$ServerIP" "du -h --max-depth=1 / 2>/dev/null | sort -hr | head -20" | Write-Host
Write-Host ""

# 3. Check /opt/flipnosis specifically
Write-Info "3. Disk Usage in /opt/flipnosis"
Write-Host "----------------------------------------"
ssh "$ServerUser@$ServerIP" "du -h --max-depth=2 /opt/flipnosis 2>/dev/null | sort -hr | head -30" | Write-Host
Write-Host ""

# 4. Look for backup files
Write-Info "4. Backup Files and Directories"
Write-Host "----------------------------------------"
Write-Info "Looking for .backup directories..."
ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.backup*' -type d -exec du -sh {} \; 2>/dev/null" | Write-Host
Write-Host ""
Write-Info "Looking for .tar.gz and .zip files..."
ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.tar.gz' -o -name '*.zip' -exec ls -lh {} \; 2>/dev/null" | Write-Host
Write-Host ""
Write-Info "Looking for backup files in /tmp..."
ssh "$ServerUser@$ServerIP" "find /tmp -name '*backup*' -o -name '*.tar.gz' -exec ls -lh {} \; 2>/dev/null" | Write-Host
Write-Host ""

# 5. Check for large image files
Write-Info "5. Large Image Files"
Write-Host "----------------------------------------"
Write-Info "Looking for images > 1MB in /opt/flipnosis..."
ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' \) -size +1M -exec ls -lh {} \; 2>/dev/null | head -50" | Write-Host
Write-Host ""

# 6. Check node_modules
Write-Info "6. Node Modules Directories"
Write-Host "----------------------------------------"
ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name 'node_modules' -type d -exec du -sh {} \; 2>/dev/null" | Write-Host
Write-Host ""

# 7. Check database size
Write-Info "7. Database Files"
Write-Host "----------------------------------------"
ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.sqlite' -o -name '*.db' -exec ls -lh {} \; 2>/dev/null" | Write-Host
Write-Host ""

# 8. Check log files
Write-Info "8. Large Log Files"
Write-Host "----------------------------------------"
Write-Info "Looking for logs > 10MB..."
ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.log' -size +10M -exec ls -lh {} \; 2>/dev/null" | Write-Host
ssh "$ServerUser@$ServerIP" "find /var/log -name '*.log' -size +10M -exec ls -lh {} \; 2>/dev/null" | Write-Host
Write-Host ""

# 9. Check PM2 logs
Write-Info "9. PM2 Log Files"
Write-Host "----------------------------------------"
ssh "$ServerUser@$ServerIP" "du -sh ~/.pm2/logs 2>/dev/null" | Write-Host
ssh "$ServerUser@$ServerIP" "ls -lh ~/.pm2/logs/*.log 2>/dev/null | head -20" | Write-Host
Write-Host ""

# 10. Count backup directories
Write-Info "10. Counting Backup Directories"
Write-Host "----------------------------------------"
$backupCount = ssh "$ServerUser@$ServerIP" "find /opt/flipnosis -name '*.backup*' -type d 2>/dev/null | wc -l"
Write-Host "Total backup directories found: $backupCount"
Write-Host ""

# Summary
Write-Info "================================================"
Write-Info "SUMMARY & RECOMMENDATIONS"
Write-Info "================================================"
Write-Host ""
Write-Warn "If you have many backup directories, you can clean them with:"
Write-Host "  ssh $ServerUser@$ServerIP 'rm -rf /opt/flipnosis/app.backup.*'" -ForegroundColor Cyan
Write-Host ""
Write-Warn "If PM2 logs are large, you can clear them with:"
Write-Host "  ssh $ServerUser@$ServerIP 'pm2 flush'" -ForegroundColor Cyan
Write-Host ""
Write-Warn "If /tmp has old files, you can clean them with:"
Write-Host "  ssh $ServerUser@$ServerIP 'find /tmp -type f -mtime +7 -delete'" -ForegroundColor Cyan
Write-Host ""
