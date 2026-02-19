#!/bin/bash
# Test the plugin manifest system by building a minimal Docker image

set -e

echo "=========================================="
echo "Testing Plugin Manifest System"
echo "=========================================="
echo ""

# Count plugins in manifest
total_plugins=$(grep -v '^#' plugins.txt | grep -v '^$' | wc -l)
echo "📋 Plugins in manifest: $total_plugins"
echo ""

# Estimate build time
echo "⏱️  Estimated build time: ~2-3 minutes"
echo ""

# Show what will be installed
echo "🔌 Plugins to install:"
grep -v '^#' plugins.txt | grep -v '^$' | sed 's/^/   - /'
echo ""

read -p "Build Docker image? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Build cancelled"
    exit 0
fi

echo ""
echo "🏗️  Building Docker image..."
echo ""

# Build with progress
docker-compose build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 Image size:"
    docker images wordpress-egg-wordpress --format "{{.Size}}"
    echo ""
    echo "🔍 Plugins installed in image:"
    docker run --rm wordpress-egg-wordpress ls -1 /var/www/html/wp-content/plugins/ | grep -v '^$' | wc -l
    echo ""
    echo "Next: docker-compose up -d"
else
    echo ""
    echo "❌ Build failed"
    exit 1
fi
