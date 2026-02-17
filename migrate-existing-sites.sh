#!/bin/bash
# Migrate existing WordPress sites to use the Egg template

set -e

echo "============================================="
echo "WordPress Egg Migration Script"
echo "============================================="
echo ""

# Container image (update this after you push to registry)
DOCKER_IMAGE="registry.digitalocean.com/wordpress-registry/wordpress-egg:latest"

# Sites to migrate
SITES=(
    "performwritecom"
    "sfnm"
    "redheale"
    "path2ucom"
    "outdoor1"
    "murwillu"
    "murbahmowers"
    "laserxperts"
    "kandudeliveriesc"
    "corne582"
)

# Database cluster info
DB_HOST="wordpress-mysql-cluster-do-user-28531160-0.i.db.ondigitalocean.com"
DB_PORT="25060"

# DO Spaces info
SPACES_BUCKET="everydaytech-wordpress"
SPACES_ENDPOINT="syd1.digitaloceanspaces.com"
SPACES_REGION="syd1"

echo "This script will:"
echo "1. Update each App Platform app to use the Docker image"
echo "2. Configure environment variables"
echo "3. Trigger new deployments"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

for site in "${SITES[@]}"; do
    echo ""
    echo "=========================================="
    echo "Migrating: $site"
    echo "=========================================="
    
    # Get the app spec
    APP_ID=$(doctl apps list --format ID,Spec.Name | grep "wordpress-${site}" | awk '{print $1}')
    
    if [ -z "$APP_ID" ]; then
        echo "⚠ App not found for $site, skipping..."
        continue
    fi
    
    echo "→ App ID: $APP_ID"
    
    # Create new spec using Docker image
    cat > "/tmp/${site}-docker-spec.yaml" << EOF
features:
- buildpack-stack=ubuntu-22
ingress:
  rules:
  - component:
      name: web
    match:
      path:
        prefix: /
name: wordpress-${site}
region: syd
services:
- environment_slug: php
  envs:
  - key: DB_HOST
    scope: RUN_TIME
    value: ${DB_HOST}
  - key: DB_PORT
    scope: RUN_TIME
    value: "${DB_PORT}"
  - key: DB_NAME
    scope: RUN_TIME
    value: ${site}_wp
  - key: DB_USER
    scope: RUN_TIME
    value: ${site}_user
  - key: DB_PASSWORD
    scope: RUN_TIME
    type: SECRET
    value: EV[1:encrypted-password-here]
  - key: DO_SPACES_BUCKET
    scope: RUN_TIME
    value: ${SPACES_BUCKET}
  - key: DO_SPACES_ENDPOINT
    scope: RUN_TIME
    value: ${SPACES_ENDPOINT}
  - key: DO_SPACES_KEY
    scope: RUN_TIME
    value: DO003JUHBJDDCCF9D6MU
  - key: DO_SPACES_SECRET
    scope: RUN_TIME
    type: SECRET
    value: EV[1:encrypted-secret-here]
  - key: DO_SPACES_REGION
    scope: RUN_TIME
    value: ${SPACES_REGION}
  - key: BUCKET_SITE_PATH
    scope: RUN_TIME
    value: ${site}
  http_port: 80
  instance_count: 1
  instance_size_slug: basic-xxs
  name: web
  image:
    registry_type: DOCR
    repository: wordpress-egg
    tag: latest
  health_check:
    http_path: /
EOF
    
    echo "✓ Spec created: /tmp/${site}-docker-spec.yaml"
    echo ""
    echo "To update this app, run:"
    echo "doctl apps update $APP_ID --spec /tmp/${site}-docker-spec.yaml"
    echo ""
done

echo ""
echo "============================================="
echo "Migration prep complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "1. Build and push the WordPress egg image to DO Container Registry"
echo "2. Review the generated specs in /tmp/*-docker-spec.yaml"
echo "3. Update each app using the doctl commands shown above"
echo ""
