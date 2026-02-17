#!/bin/bash
# WordPress Egg - Container Entrypoint
# Generates wp-config.php from environment variables and starts Apache

set -e

echo "========================================"
echo "WordPress Egg Template - Starting"
echo "========================================"

# Required environment variables
: ${DB_HOST:?DB_HOST is required}
: ${DB_NAME:?DB_NAME is required}
: ${DB_USER:?DB_USER is required}
: ${DB_PASSWORD:?DB_PASSWORD is required}

# Optional environment variables with defaults
DB_PORT=${DB_PORT:-3306}
DB_CHARSET=${DB_CHARSET:-utf8mb4}
DB_COLLATE=${DB_COLLATE:-}
TABLE_PREFIX=${TABLE_PREFIX:-wp_}

# DO Spaces configuration (optional)
DO_SPACES_BUCKET=${DO_SPACES_BUCKET:-}
DO_SPACES_ENDPOINT=${DO_SPACES_ENDPOINT:-}
DO_SPACES_KEY=${DO_SPACES_KEY:-}
DO_SPACES_SECRET=${DO_SPACES_SECRET:-}
DO_SPACES_REGION=${DO_SPACES_REGION:-syd1}
BUCKET_SITE_PATH=${BUCKET_SITE_PATH:-}

echo "→ Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
echo "→ User: ${DB_USER}"

# Wait for database to be ready
echo "→ Waiting for database connection to ${DB_NAME}..."
MAX_TRIES=30
COUNT=0
until mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" --ssl "${DB_NAME}" -e "SELECT 1" &>/dev/null || [ $COUNT -eq $MAX_TRIES ]; do
    COUNT=$((COUNT + 1))
    echo "   Database not ready, waiting... (${COUNT}/${MAX_TRIES})"
    sleep 2
done

if [ $COUNT -eq $MAX_TRIES ]; then
    echo "❌ Database connection failed after ${MAX_TRIES} attempts"
    echo "   Ensure database '${DB_NAME}' exists and user '${DB_USER}' has access"
    exit 1
fi

echo "✓ Database '${DB_NAME}' connected"

# Generate wp-config.php using PHP script
echo "→ Generating wp-config.php..."
php /usr/local/bin/wp-config-generator.php

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "❌ Failed to generate wp-config.php"
    exit 1
fi

echo "✓ wp-config.php created"

# Sync wp-content from DO Spaces if configured
if [ -n "$DO_SPACES_BUCKET" ] && [ -n "$BUCKET_SITE_PATH" ]; then
    echo "→ Syncing wp-content from bucket: ${DO_SPACES_BUCKET}/${BUCKET_SITE_PATH}"
    
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
        echo "   Downloading existing wp-content..."
        rclone sync dospaces:${DO_SPACES_BUCKET}/${BUCKET_SITE_PATH}/wp-content /var/www/html/wp-content \
            --transfers 8 \
            --checkers 8 \
            --exclude "cache/**" \
            --exclude "upgrade/**" \
            --exclude "*.log"
        echo "✓ wp-content synced from bucket"
    else
        echo "   No existing wp-content in bucket (fresh install)"
    fi
else
    echo "⚠ DO Spaces not configured - using local wp-content only"
fi

# Set proper permissions
chown -R www-data:www-data /var/www/html
echo "✓ Permissions set"

echo "========================================"
echo "WordPress Ready!"
echo "========================================"

# Execute the main container command
exec "$@"
