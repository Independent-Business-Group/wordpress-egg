#!/bin/bash

# Fix wp-content permissions after Docker creates files as www-data
# This script removes Docker-created files and allows the sync to complete

echo "Fixing wp-content permissions..."
echo "This requires sudo to remove files created by Docker."
echo ""

# Stop Docker container if running
if docker ps | grep -q wp-app; then
    echo "→ Stopping Docker container..."
    docker-compose down
fi

# Remove wp-content with sudo
echo "→ Removing Docker-created files..."
sudo rm -rf wp-content

# Create fresh wp-content directory
echo "→ Creating fresh wp-content directory..."
mkdir -p wp-content
chmod 755 wp-content

echo "✅ Permissions fixed!"
echo ""
echo "Now run the sync:"
echo "  python3 ./sync-from-spaces.py"
