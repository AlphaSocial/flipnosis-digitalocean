Write-Host "🔍 Checking Hetzner Server Deployment..." -ForegroundColor Cyan

$commands = @"
echo '📂 Finding app directory...'
if [ -d '/opt/flipnosis/app' ]; then
    cd /opt/flipnosis/app
    echo '✅ Found: /opt/flipnosis/app'
elif [ -d '/root/flipnosis-digitalocean' ]; then
    cd /root/flipnosis-digitalocean
    echo '✅ Found: /root/flipnosis-digitalocean'
else
    echo '❌ Could not find app directory!'
    exit 1
fi

echo ''
echo '🌿 Current Git branch:'
git branch --show-current

echo ''
echo '📝 Latest commit:'
git log -1 --oneline

echo ''
echo '🔍 Checking if fix is present in coin-manager.js:'
if grep -q 'The shatterGlass function will set the isShattered flag itself' public/js/systems/coin-manager.js; then
    echo '✅ FIX IS PRESENT - Glass shatter fix found!'
else
    echo '❌ FIX NOT FOUND - Old code still present'
fi

echo ''
echo '📄 Showing the fix (lines 118-131):'
sed -n '118,131p' public/js/systems/coin-manager.js

echo ''
echo '🔄 Server process status:'
ps aux | grep -E 'node.*server|pm2' | grep -v grep

echo ''
echo '📊 PM2 status:'
pm2 list 2>/dev/null || echo 'PM2 not running'

echo ''
echo '🌐 Checking dist folder:'
if [ -f 'dist/js/systems/coin-manager.js' ]; then
    echo '✅ dist/js/systems/coin-manager.js exists'
    echo 'Checking if dist has the fix:'
    if grep -q 'The shatterGlass function will set the isShattered flag itself' dist/js/systems/coin-manager.js; then
        echo '✅ FIX IS IN DIST - Production build has the fix!'
    else
        echo '⚠️ FIX NOT IN DIST - Need to rebuild!'
    fi
else
    echo '❌ dist/js/systems/coin-manager.js not found'
fi
"@

ssh root@159.69.242.154 $commands

Write-Host "`n✅ Check complete!" -ForegroundColor Green
