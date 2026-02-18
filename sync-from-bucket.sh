#!/bin/bash
# Sync wp-content FROM DigitalOcean Spaces bucket to local

set -e

echo "=========================================="
echo "Syncing wp-content from DO Spaces"
echo "=========================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check required variables
if [ -z "$DO_SPACES_BUCKET" ] || [ -z "$DO_SPACES_ENDPOINT" ] || [ -z "$DO_SPACES_KEY" ] || [ -z "$BUCKET_SITE_PATH" ]; then
    echo "❌ Missing required environment variables:"
    echo "   DO_SPACES_BUCKET, DO_SPACES_ENDPOINT, DO_SPACES_KEY, BUCKET_SITE_PATH"
    exit 1
fi

# Install s3cmd if not present
if ! command -v s3cmd &> /dev/null; then
    echo "→ Installing s3cmd..."
    sudo apt-get update && sudo apt-get install -y s3cmd
fi

# Configure s3cmd
echo "→ Configuring s3cmd..."
cat > ~/.s3cfg << EOF
[default]
access_key = ${DO_SPACES_KEY}
secret_key = ${DO_SPACES_SECRET:-}
host_base = ${DO_SPACES_ENDPOINT}
host_bucket = %(bucket)s.${DO_SPACES_ENDPOINT}
use_https = True
EOF

# Create wp-content directory if it doesn't exist
mkdir -p wp-content

# Sync from bucket
echo "→ Syncing from s3://${DO_SPACES_BUCKET}/${BUCKET_SITE_PATH}/wp-content/ to ./wp-content/"
s3cmd sync --delete-removed \
    "s3://${DO_SPACES_BUCKET}/${BUCKET_SITE_PATH}/wp-content/" \
    ./wp-content/

# Set permissions
echo "→ Setting permissions..."
sudo chown -R $(whoami):$(whoami) wp-content/
chmod -R 755 wp-content/

echo "=========================================="
echo "✓ Sync complete!"
echo "=========================================="
echo ""
echo "Synced content:"
du -sh wp-content/
echo ""
echo "Files in wp-content:"
ls -lh wp-content/
