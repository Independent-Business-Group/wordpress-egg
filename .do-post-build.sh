#!/bin/bash
# Post-build script to set up WordPress from git repo

set -e

echo "=========================================="
echo "WordPress PHP Setup - Post Build"
echo "=========================================="

# WordPress installation comes from the git repo itself
# No need to download - files are already cloned

# Generate wp-config.php from environment variables
echo "→ Generating wp-config.php..."
php setup-wp-config.php

echo "=========================================="
echo "WordPress Setup Complete!"
echo "=========================================="
