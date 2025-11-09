# Investigation Script - Check Hetzner Server Folder Structure
# This script checks both /root and /opt for Flipnosis deployments
# DO NOT DELETE ANYTHING - just gather information

$ServerIP = "159.69.242.154"
$ServerUser = "root"

function Write-Section([string]$title) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

Write-Host "`n" -NoNewline
Write-Host "HETZNER SERVER INVESTIGATION" -ForegroundColor Green
Write-Host "Server: $ServerUser@$ServerIP" -ForegroundColor Yellow
Write-Host "Purpose: Identify all deployments and which one is active" -ForegroundColor Yellow

# Section 1: Check /root directory for Flipnosis files
Write-Section "1. CHECKING /root DIRECTORY"
Write-Host "Looking for flipnosis-related folders in /root..." -ForegroundColor White
ssh ${ServerUser}@${ServerIP} @"
echo "Contents of /root:"
ls -lah /root | grep -i flipnosis || echo "No flipnosis folders found in /root"
echo ""
echo "All folders in /root:"
ls -lh /root | grep '^d'
"@

# Section 2: Check /opt directory structure
Write-Section "2. CHECKING /opt DIRECTORY"
Write-Host "Looking for flipnosis-related folders in /opt..." -ForegroundColor White
ssh ${ServerUser}@${ServerIP} @"
echo "Contents of /opt:"
ls -lah /opt | grep -i flipnosis || echo "No flipnosis folders found in /opt"
echo ""
if [ -d "/opt/flipnosis" ]; then
    echo "Contents of /opt/flipnosis:"
    ls -lah /opt/flipnosis
fi
"@

# Section 3: Detailed check of /root/flipnosis-digitalocean if it exists
Write-Section "3. DETAILED CHECK: /root/flipnosis-digitalocean"
ssh ${ServerUser}@${ServerIP} @"
if [ -d "/root/flipnosis-digitalocean" ]; then
    echo "FOLDER EXISTS: /root/flipnosis-digitalocean"
    echo ""
    echo "Size:"
    du -sh /root/flipnosis-digitalocean
    echo ""
    echo "Contents:"
    ls -lah /root/flipnosis-digitalocean | head -30
    echo ""
    echo "Last modified:"
    ls -ldt /root/flipnosis-digitalocean/* | head -5
else
    echo "FOLDER DOES NOT EXIST: /root/flipnosis-digitalocean"
fi
"@

# Section 4: Detailed check of /opt/flipnosis/app if it exists
Write-Section "4. DETAILED CHECK: /opt/flipnosis/app"
ssh ${ServerUser}@${ServerIP} @"
if [ -d "/opt/flipnosis/app" ]; then
    echo "FOLDER EXISTS: /opt/flipnosis/app"
    echo ""
    echo "Size:"
    du -sh /opt/flipnosis/app
    echo ""
    echo "Contents:"
    ls -lah /opt/flipnosis/app | head -30
    echo ""
    echo "Last modified:"
    ls -ldt /opt/flipnosis/app/* | head -5
else
    echo "FOLDER DOES NOT EXIST: /opt/flipnosis/app"
fi
"@

# Section 5: Check which one PM2 is using
Write-Section "5. PM2 CONFIGURATION - Which folder is active?"
Write-Host "Checking PM2 to see which deployment is running..." -ForegroundColor White
ssh ${ServerUser}@${ServerIP} @"
echo "PM2 processes:"
pm2 list
echo ""
echo "PM2 flipnosis-app details:"
pm2 info flipnosis-app || echo "flipnosis-app not found in PM2"
echo ""
echo "PM2 working directory:"
pm2 describe flipnosis-app | grep -E '(cwd|script)' || echo "Could not determine PM2 working directory"
"@

# Section 6: Check Nginx configuration
Write-Section "6. NGINX CONFIGURATION - What paths are configured?"
ssh ${ServerUser}@${ServerIP} @"
echo "Nginx configuration for flipnosis:"
if [ -f "/etc/nginx/sites-enabled/flipnosis" ]; then
    cat /etc/nginx/sites-enabled/flipnosis | grep -E '(root|proxy_pass|location)'
elif [ -f "/etc/nginx/sites-available/flipnosis" ]; then
    cat /etc/nginx/sites-available/flipnosis | grep -E '(root|proxy_pass|location)'
else
    echo "Looking for any nginx config mentioning flipnosis..."
    grep -r "flipnosis" /etc/nginx/sites-enabled/ 2>/dev/null || echo "No flipnosis nginx config found"
fi
"@

# Section 7: Check database locations
Write-Section "7. DATABASE LOCATIONS"
ssh ${ServerUser}@${ServerIP} @"
echo "Looking for database.sqlite files..."
find /root -name "database.sqlite" -o -name "*.db" 2>/dev/null | head -10
find /opt -name "database.sqlite" -o -name "*.db" 2>/dev/null | head -10
echo ""
echo "Database file details:"
if [ -f "/root/flipnosis-digitalocean/server/database.sqlite" ]; then
    ls -lh /root/flipnosis-digitalocean/server/database.sqlite
fi
if [ -f "/opt/flipnosis/app/server/database.sqlite" ]; then
    ls -lh /opt/flipnosis/app/server/database.sqlite
fi
"@

# Section 8: Check for .env files
Write-Section "8. ENVIRONMENT FILES"
ssh ${ServerUser}@${ServerIP} @"
echo "Looking for .env files..."
if [ -f "/root/flipnosis-digitalocean/.env" ]; then
    echo "FOUND: /root/flipnosis-digitalocean/.env"
    ls -lh /root/flipnosis-digitalocean/.env
fi
if [ -f "/opt/flipnosis/app/.env" ]; then
    echo "FOUND: /opt/flipnosis/app/.env"
    ls -lh /opt/flipnosis/app/.env
fi
if [ -f "/opt/flipnosis/shared/.env" ]; then
    echo "FOUND: /opt/flipnosis/shared/.env"
    ls -lh /opt/flipnosis/shared/.env
fi
"@

# Section 9: Summary and recommendations
Write-Section "9. SUMMARY"
Write-Host @"

INTERPRETATION GUIDE:
====================

1. If PM2 is running from /opt/flipnosis/app:
   - This is the ACTIVE deployment
   - /root/flipnosis-digitalocean is likely OLD and can be archived

2. If PM2 is running from /root/flipnosis-digitalocean:
   - This is the ACTIVE deployment
   - /opt/flipnosis/app might be a failed migration or duplicate

3. Check the database locations:
   - The folder with the most recent database.sqlite is likely active
   - DO NOT delete any folder with database files without backup

4. Check .env files:
   - Active deployment should have .env with credentials
   - /opt/flipnosis/shared/.env suggests centralized config

NEXT STEPS:
===========
Review the output above to determine which deployment is active.
DO NOT delete anything until we confirm which is which!

"@ -ForegroundColor Yellow

Write-Host "`nInvestigation Complete!" -ForegroundColor Green
Write-Host "Review the output above to understand your server structure.`n" -ForegroundColor White
