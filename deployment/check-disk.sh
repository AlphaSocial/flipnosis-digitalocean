#!/bin/bash
# Quick disk usage check for Hetzner server
# Run this directly on the server: bash check-disk.sh

echo "================================================"
echo "HETZNER SERVER DISK USAGE ANALYSIS"
echo "================================================"
echo ""

echo "1. Overall Disk Usage"
echo "----------------------------------------"
df -h | grep -E "(Filesystem|/dev/sda1)"
echo ""

echo "2. Largest Directories in /"
echo "----------------------------------------"
du -h --max-depth=1 / 2>/dev/null | sort -hr | head -15
echo ""

echo "3. What's inside /opt/flipnosis?"
echo "----------------------------------------"
du -h --max-depth=1 /opt/flipnosis 2>/dev/null | sort -hr
echo ""

echo "4. Looking for backup directories..."
echo "----------------------------------------"
find /opt/flipnosis -maxdepth 1 -name '*backup*' -type d -exec du -sh {} \; 2>/dev/null
BACKUP_COUNT=$(find /opt/flipnosis -maxdepth 1 -name '*backup*' -type d 2>/dev/null | wc -l)
echo "Total backup directories: $BACKUP_COUNT"
echo ""

echo "5. Node modules directories"
echo "----------------------------------------"
find /opt/flipnosis -name 'node_modules' -type d -exec du -sh {} \; 2>/dev/null
echo ""

echo "6. PM2 Logs"
echo "----------------------------------------"
du -sh ~/.pm2/logs 2>/dev/null || echo "No PM2 logs directory"
ls -lh ~/.pm2/logs/*.log 2>/dev/null | tail -10
echo ""

echo "7. Large files in /opt/flipnosis (> 100MB)"
echo "----------------------------------------"
find /opt/flipnosis -type f -size +100M -exec ls -lh {} \; 2>/dev/null
echo ""

echo "8. Database files"
echo "----------------------------------------"
find /opt/flipnosis -name '*.sqlite' -o -name '*.db' -exec ls -lh {} \; 2>/dev/null
echo ""

echo "9. Log files (> 10MB)"
echo "----------------------------------------"
find /opt/flipnosis -name '*.log' -size +10M -exec ls -lh {} \; 2>/dev/null
echo ""

echo "10. /tmp directory usage"
echo "----------------------------------------"
du -sh /tmp 2>/dev/null
echo ""

echo "================================================"
echo "QUICK CLEANUP COMMANDS"
echo "================================================"
echo ""
echo "To remove ALL backup directories:"
echo "  rm -rf /opt/flipnosis/app.backup.*"
echo ""
echo "To keep only last 3 backups:"
echo "  cd /opt/flipnosis && ls -dt app.backup.* | tail -n +4 | xargs rm -rf"
echo ""
echo "To flush PM2 logs:"
echo "  pm2 flush"
echo ""
echo "To clean /tmp:"
echo "  find /tmp -type f -mtime +1 -delete"
echo ""
