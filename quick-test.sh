#!/bin/bash
# Quick test build - non-interactive

cd /home/cw/Documents/Wordpress-Egg

echo "=========================================="
echo "Quick Plugin & Theme Manifest Test"
echo "=========================================="
echo ""

# Show plugins and themes to install
echo "📋 Plugins in manifest:"
grep -v '^#' plugins.txt | grep -v '^$' | wc -l
echo "🎨 Themes in manifest:"
grep -v '^#' themes.txt | grep -v '^$' | wc -l
echo ""

# Build image (this may take 2-3 minutes)
echo "🏗️  Building Docker image..."
echo "   (This downloads plugins & themes from wordpress.org)"
echo ""

docker-compose build > /tmp/wp-build.log 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "📦 Image details:"
    docker images wordpress-egg-wordpress --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    echo ""
    
    # Start container to test
    echo "🚀 Starting WordPress..."
    docker-compose up -d
    
    sleep 8
    
    echo "🔍 Installed plugins:"
    docker exec wp-app ls -1 /var/www/html/wp-content/plugins/ 2>/dev/null | wc -l
    echo "🎨 Installed themes:"
    docker exec wp-app ls -1 /var/www/html/wp-content/themes/ 2>/dev/null | wc -l
    echo ""
    
    echo "🌐 Testing WordPress..."
    curl -s -I http://localhost:8080/ | grep -E "(HTTP|Location)" || echo "WordPress not responding yet, wait 10 more seconds..."
    
    echo ""
    echo "✅ Test complete!"
    echo "   View at: http://localhost:8080"
    echo "   Logs: docker logs wp-app"
    echo "   Stop: docker-compose down"
else
    echo "❌ Build failed!"
    echo "   Check log: cat /tmp/wp-build.log"
    exit 1
fi
