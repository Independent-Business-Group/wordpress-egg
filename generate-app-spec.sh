#!/bin/bash
# Generate App Platform spec for a new WordPress site using the Egg template

if [ -z "$1" ]; then
    echo "Usage: ./generate-app-spec.sh <sitename>"
    echo "Example: ./generate-app-spec.sh client1"
    exit 1
fi

SITE_NAME="$1"
REGISTRY_URL=$(doctl registry get --format Registry -t 2>/dev/null || echo "registry.digitalocean.com/wordpress-registry")

cat > "wordpress-${SITE_NAME}-spec.yaml" << EOF
name: wordpress-${SITE_NAME}
region: syd

features:
- buildpack-stack=ubuntu-22

ingress:
  rules:
  - component:
      name: web
    match:
      path:
        prefix: /

services:
- name: web
  instance_count: 1
  instance_size_slug: basic-xxs
  http_port: 80
  
  # Docker Image
  image:
    registry_type: DOCR
    repository: wordpress-egg
    tag: latest
  
  # Health Check
  health_check:
    http_path: /
    initial_delay_seconds: 60
    period_seconds: 10
    timeout_seconds: 5
    success_threshold: 1
    failure_threshold: 3
  
  # Environment Variables
  envs:
  # Database Configuration (UPDATE THESE!)
  - key: DB_HOST
    value: your-mysql-cluster.db.ondigitalocean.com
    scope: RUN_TIME
  - key: DB_PORT
    value: "25060"
    scope: RUN_TIME
  - key: DB_NAME
    value: ${SITE_NAME}_wp
    scope: RUN_TIME
  - key: DB_USER
    value: ${SITE_NAME}_user
    scope: RUN_TIME
  - key: DB_PASSWORD
    value: CHANGE_THIS_PASSWORD
    type: SECRET
    scope: RUN_TIME
  
  # DO Spaces Configuration (OPTIONAL - for wp-content CDN)
  - key: DO_SPACES_BUCKET
    value: your-wordpress-bucket
    scope: RUN_TIME
  - key: DO_SPACES_ENDPOINT
    value: syd1.digitaloceanspaces.com
    scope: RUN_TIME
  - key: DO_SPACES_REGION
    value: syd1
    scope: RUN_TIME
  - key: DO_SPACES_KEY
    value: YOUR_SPACES_KEY
    scope: RUN_TIME
  - key: DO_SPACES_SECRET
    value: YOUR_SPACES_SECRET
    type: SECRET
    scope: RUN_TIME
  - key: BUCKET_SITE_PATH
    value: ${SITE_NAME}
    scope: RUN_TIME
  
  # WordPress Configuration (OPTIONAL)
  - key: TABLE_PREFIX
    value: wp_
    scope: RUN_TIME
  - key: DB_CHARSET
    value: utf8mb4
    scope: RUN_TIME
EOF

echo "✅ Generated: wordpress-${SITE_NAME}-spec.yaml"
echo ""
echo "Next steps:"
echo "1. Edit the file and update database credentials"
echo "2. Update DO Spaces credentials (or remove if not using)"
echo "3. Deploy: doctl apps create --spec wordpress-${SITE_NAME}-spec.yaml"
echo ""
