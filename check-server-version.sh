#!/bin/bash
echo "🔍 Checking Hetzner server version..."

# Check Git status and file content
ssh root@159.69.242.154 << 'ENDSSH'
echo "📍 Current directory:"
pwd

echo ""
echo "📂 Finding app directory..."
if [ -d "/opt/flipnosis/app" ]; then
    cd /opt/flipnosis/app
    echo "✅ Found: /opt/flipnosis/app"
elif [ -d "/root/flipnosis-digitalocean" ]; then
    cd /root/flipnosis-digitalocean
    echo "✅ Found: /root/flipnosis-digitalocean"
else
    echo "❌ Could not find app directory!"
    exit 1
fi

echo ""
echo "🌿 Current Git branch:"
git branch --show-current

echo ""
echo "📝 Latest commit:"
git log -1 --oneline

echo ""
echo "🔍 Checking if fix is present in coin-manager.js:"
if grep -q "The shatterGlass function will set the isShattered flag itself" public/js/systems/coin-manager.js; then
    echo "✅ FIX IS PRESENT - Glass shatter fix found!"
else
    echo "❌ FIX NOT FOUND - Old code still present"
fi

echo ""
echo "📄 Showing the fix (lines 118-131):"
sed -n '118,131p' public/js/systems/coin-manager.js

echo ""
echo "🔄 Server process status:"
ps aux | grep -E 'node.*server|pm2' | grep -v grep

echo ""
echo "📊 PM2 status (if available):"
pm2 list 2>/dev/null || echo "PM2 not running or not installed"

echo ""
echo "🌐 Dist folder check:"
ls -lh dist/js/systems/coin-manager.js 2>/dev/null || echo "dist/js/systems/coin-manager.js not found"

ENDSSH

