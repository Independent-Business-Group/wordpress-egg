#!/bin/bash
# WordPress Egg - Build and Deploy to DO Container Registry

set -e

echo "============================================="
echo "WordPress Egg - Build & Deploy"
echo "============================================="
echo ""

REGISTRY_NAME="wordpress-registry"
IMAGE_NAME="wordpress-egg"
VERSION="latest"

# Check if doctl is installed
if ! command -v doctl &> /dev/null; then
    echo "❌ doctl not found. Please install: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi

# Check if logged in
if ! doctl registry login &> /dev/null; then
    echo "→ Logging into DigitalOcean Container Registry..."
    doctl registry login
fi

# Check if registry exists, create if not
if ! doctl registry get &> /dev/null; then
    echo "→ Creating container registry: $REGISTRY_NAME"
    doctl registry create $REGISTRY_NAME --subscription-tier basic
else
    echo "✓ Registry exists"
fi

REGISTRY_URL=$(doctl registry get --format Registry -t)
FULL_IMAGE_NAME="${REGISTRY_URL}/${IMAGE_NAME}:${VERSION}"

echo ""
echo "→ Building Docker image..."
docker build -t ${IMAGE_NAME}:${VERSION} .

echo ""
echo "→ Tagging image for registry..."
docker tag ${IMAGE_NAME}:${VERSION} ${FULL_IMAGE_NAME}

echo ""
echo "→ Pushing to DigitalOcean Container Registry..."
docker push ${FULL_IMAGE_NAME}

echo ""
echo "✅ Build & Deploy Complete!"
echo "============================================="
echo ""
echo "Image: ${FULL_IMAGE_NAME}"
echo ""
echo "To use this image in App Platform:"
echo "1. Create a new app or update existing app"
echo "2. Use 'Docker Hub Registry' as source"
echo "3. Set image: ${REGISTRY_URL}/${IMAGE_NAME}"
echo "4. Set tag: ${VERSION}"
echo "5. Configure environment variables (DB_*, DO_SPACES_*)"
echo ""
echo "Or use the App spec generator:"
echo "./generate-app-spec.sh <sitename>"
echo ""
