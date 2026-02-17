# WordPress Egg Template

A production-ready, multi-tenant WordPress Docker container designed for rapid deployment via DigitalOcean App Platform or any container orchestration system.

## Features

- **Pre-installed WordPress** (latest version)
- **Automatic configuration** from environment variables
- **DO Spaces integration** for wp-content storage (CDN-ready)
- **Database connection verification** before startup
- **Secure random security keys** generated per deployment
- **HTTPS/SSL support** via reverse proxy
- **Production-optimized** PHP settings
- **Zero-downtime deployments** ready

## Quick Start

### Required Environment Variables

```bash
DB_HOST=your-database-host.db.ondigitalocean.com
DB_PORT=25060
DB_NAME=wordpress_db
DB_USER=wordpress_user
DB_PASSWORD=your-secure-password
```

### Optional Environment Variables

```bash
# DO Spaces Configuration (for wp-content CDN)
DO_SPACES_BUCKET=your-bucket-name
DO_SPACES_ENDPOINT=syd1.digitaloceanspaces.com
DO_SPACES_KEY=your-spaces-key
DO_SPACES_SECRET=your-spaces-secret
DO_SPACES_REGION=syd1
BUCKET_SITE_PATH=sitename

# Database Options
DB_CHARSET=utf8mb4
DB_COLLATE=
TABLE_PREFIX=wp_
```

## Deployment Options

### Option 1: DigitalOcean App Platform

1. Push this repo to GitHub
2. Create new App Platform app from repo
3. Set environment variables in App Platform dashboard
4. Deploy!

### Option 2: DigitalOcean Container Registry

```bash
# Build and push
docker build -t wordpress-egg .
doctl registry login
docker tag wordpress-egg registry.digitalocean.com/your-registry/wordpress-egg:latest
docker push registry.digitalocean.com/your-registry/wordpress-egg:latest

# Deploy via App Platform using container registry
```

### Option 3: Docker Hub

```bash
docker build -t yourusername/wordpress-egg .
docker push yourusername/wordpress-egg
```

## How It Works

1. **Container starts** → Entrypoint script runs
2. **Database check** → Waits for MySQL to be available
3. **wp-config.php** → Generated from environment variables with secure keys
4. **wp-content sync** → Downloads existing content from DO Spaces (if configured)
5. **Apache starts** → WordPress ready to serve requests

## Multi-Tenant Usage

This template is designed for deploying multiple WordPress sites with isolation:

```bash
# Site 1
DB_NAME=client1_wp
BUCKET_SITE_PATH=client1

# Site 2  
DB_NAME=client2_wp
BUCKET_SITE_PATH=client2
```

Each deployment gets:
- Isolated database
- Isolated wp-content in bucket (via BUCKET_SITE_PATH)
- Unique security keys
- Independent scaling

## PSA/RMM Integration

Perfect for programmatic WordPress provisioning:

```python
# Your PSA/RMM dashboard can provision new WordPress sites:

1. Create database (via DigitalOcean API)
2. Create DO Spaces bucket path
3. Deploy this container via App Platform API
4. Set env vars programmatically
5. WordPress site is live!
```

## File Structure

```
wordpress-egg/
├── Dockerfile              # Container definition
├── docker-entrypoint.sh    # Startup script
├── wp-config-generator.php # Config generator
└── README.md              # This file
```

## Production Checklist

- [x] WordPress core included
- [x] PHP 8.2 with all required extensions
- [x] Apache with mod_rewrite enabled
- [x] Database connection verification
- [x] Secure key generation
- [x] HTTPS/SSL support
- [x] DO Spaces integration
- [x] Proper file permissions
- [x] Production PHP settings
- [x] Error handling

## Next Steps

1. **Build the image**: `docker build -t wordpress-egg .`
2. **Test locally**: `docker-compose up` (create docker-compose.yml)
3. **Push to registry**: DigitalOcean Container Registry or Docker Hub
4. **Deploy**: Use App Platform or your orchestration system
5. **Integrate**: Connect to your PSA/RMM dashboard API

## License

MIT - Use this for your multi-tenant WordPress hosting platform!
