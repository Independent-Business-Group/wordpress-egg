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

# Sync wp-content from DO Spaces if configured
if [ -n "$DO_SPACES_BUCKET" ] && [ -n "$BUCKET_SITE_PATH" ]; then
    echo "→ Syncing wp-content from DO Spaces..."
    echo "   Bucket: ${DO_SPACES_BUCKET}/${BUCKET_SITE_PATH}"
    
    # Install rclone
    echo "   Installing rclone..."
    curl -sL https://rclone.org/install.sh | bash
    
    # Configure rclone for DO Spaces
    mkdir -p ~/.config/rclone
    cat > ~/.config/rclone/rclone.conf << EOF
[dospaces]
type = s3
provider = DigitalOcean
access_key_id = ${DO_SPACES_KEY}
secret_access_key = ${DO_SPACES_SECRET}
endpoint = ${DO_SPACES_ENDPOINT}
region = ${DO_SPACES_REGION}
acl = public-read
EOF
    
    # Download wp-content from bucket (if exists)
    if rclone lsd dospaces:${DO_SPACES_BUCKET}/${BUCKET_SITE_PATH}/wp-content &>/dev/null; then
        echo "   Downloading wp-content (themes, plugins, uploads)..."
        rclone sync dospaces:${DO_SPACES_BUCKET}/${BUCKET_SITE_PATH}/wp-content ./wp-content \
            --transfers 8 \
            --checkers 8 \
            --exclude "cache/**" \
            --exclude "upgrade/**" \
            --exclude "*.log" \
            --progress
        echo "✅ wp-content synced from bucket"
    else
        echo "⚠ No wp-content found in bucket (using fresh WordPress)"
    fi
else
    echo "⚠ DO Spaces not configured - using default wp-content"
fi

# Clean up setup files
rm -f setup-wp-config.php .do-post-build.sh

echo "=========================================="
echo "WordPress Setup Complete!"
echo "=========================================="
