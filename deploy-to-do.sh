#!/bin/bash
# Quick deployment script for DigitalOcean App Platform
# This creates the app with placeholders and shows you how to set secrets

set -e

echo "=================================================="
echo "WordPress DigitalOcean Deployment"
echo "=================================================="
echo ""

# Check if doctl is installed
if ! command -v doctl &> /dev/null; then
    echo "❌ doctl is not installed"
    echo ""
    echo "Install it with:"
    echo "  brew install doctl   (macOS)"
    echo "  snap install doctl   (Linux)"
    echo ""
    echo "Or follow: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi

# Check if authenticated
if ! doctl account get &> /dev/null; then
    echo "❌ Not authenticated with DigitalOcean"
    echo ""
    echo "Authenticate with:"
    echo "  doctl auth init"
    exit 1
fi

echo "✅ doctl is installed and authenticated"
echo ""

# Show app spec overview
echo "📋 Deployment Configuration:"
echo "   - Docker-based deployment (Dockerfile)"
echo "   - Database: performwritecom_wp (xfwlw_ prefix)"
echo "   - Spaces CDN: everydaytech-wordpress"
echo "   - Region: syd1 (Sydney)"
echo "   - Instance: basic-xxs ($5/month)"
echo ""

# Ask if user wants to proceed
read -p "Create WordPress app on DigitalOcean? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🚀 Creating app..."
echo ""

# Create the app
APP_ID=$(doctl apps create --spec app-spec-docker.yaml --format ID --no-header)

if [ -z "$APP_ID" ]; then
    echo "❌ Failed to create app"
    exit 1
fi

echo "✅ App created: $APP_ID"
echo ""

# Get app info
APP_INFO=$(doctl apps get "$APP_ID" --format DefaultIngress,LiveURL --no-header)

echo "=================================================="
echo "⚠️  IMPORTANT: Set Secrets Before First Deploy" 
echo "=================================================="
echo ""
echo "The app was created with placeholder values for secrets."
echo "You need to update these in the DigitalOcean Dashboard:"
echo ""
echo "1. Go to: https://cloud.digitalocean.com/apps/$APP_ID/settings"
echo ""
echo "2. Click 'Edit' next to 'App-Level Environment Variables'"
echo ""
echo "3. Update these SECRET values:"
echo "   - DB_PASSWORD"
echo "   - DO_SPACES_KEY"
echo "   - DO_SPACES_SECRET"
echo ""
echo "4. Click 'Save' and wait for redeploy"
echo ""
echo "📝 Actual credential values are in DO-SECRETS.md (local only)"
echo ""
echo "=================================================="
echo "Deployment Status"
echo "=================================================="
echo ""

# Show deployment status
doctl apps list --format ID,Spec.Name,DefaultIngress,ActiveDeployment.Phase

echo ""
echo "📊 Watch logs:"
echo "   doctl apps logs $APP_ID --follow"
echo ""
echo "🔗 View app:"
echo "   https://cloud.digitalocean.com/apps/$APP_ID"
echo ""

# Offer to tail logs
read -p "Watch deployment logs now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📜 Streaming logs (Ctrl+C to exit)..."
    echo ""
    doctl apps logs "$APP_ID" --follow
fi
