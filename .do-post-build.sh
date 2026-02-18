#!/bin/bash
# Post-build script to download WordPress core and initialize config

set -e

echo "=========================================="
echo "WordPress PHP Setup - Post Build"
echo "=========================================="

# Download WordPress if not already present
if [ ! -f "wp-load.php" ]; then
    echo "→ Downloading WordPress core..."
    curl -o wordpress.tar.gz https://wordpress.org/latest.tar.gz
    tar -xzf wordpress.tar.gz --strip-components=1
    rm wordpress.tar.gz
    echo "✅ WordPress downloaded"
else
    echo "✅ WordPress already present"
fi

# Generate wp-config.php from environment variables
echo "→ Generating wp-config.php..."
php setup-wp-config.php

# Clean up setup files
rm -f setup-wp-config.php .do-post-build.sh

echo "=========================================="
echo "WordPress Setup Complete!"
echo "=========================================="
