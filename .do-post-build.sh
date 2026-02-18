#!/bin/bash
# Post-build script to set up WordPress from downloaded core

set -e

echo "=========================================="
echo "WordPress PHP Setup - Post Build"
echo "=========================================="

# Check if WordPress core is already present
if [ ! -f "wp-config-sample.php" ]; then
    echo "→ Downloading WordPress core..."
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz --strip-components=1
    rm latest.tar.gz
    echo "✓ WordPress core downloaded"
else
    echo "✓ WordPress core already present"
fi

# Remove placeholder index.php if it exists (from git repo)
# WordPress provides its own index.php
if [ -f "index.php" ]; then
    # Check if it's the placeholder version (contains phpinfo)
    if grep -q "phpinfo" index.php 2>/dev/null; then
        echo "→ Removing placeholder index.php..."
        rm -f index.php
        echo "✓ Placeholder removed, WordPress will use its own index.php"
    fi
fi

# Generate wp-config.php from environment variables
echo "→ Generating wp-config.php..."
php setup-wp-config.php

echo "=========================================="
echo "WordPress Setup Complete!"
echo "=========================================="
