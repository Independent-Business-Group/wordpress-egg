# WordPress on DigitalOcean: Architecture Options

## The Problem You've Identified

The wp-content sync is **too slow** for DigitalOcean deployments:
- Syncing 55MB+ of files takes several minutes
- DO healthchecks timeout waiting for container to be ready
- Deployment rolls back before WordPress can start
- This prevents successful deployments from git pushes

## Your Options (Ranked Best to Worst)

### ✅ **OPTION 1: Serve Media from DO Spaces Directly** (RECOMMENDED)

**How it works:**
- Themes & plugins → Included in Docker image (from git)
- Uploads/media → Served directly from DO Spaces via WordPress plugin
- No sync needed at container startup
- Fast deployments, infinitely scalable storage

**Implementation:**
1. Install WordPress plugin: **WP Offload Media Lite** (free) or **WP Offload Media** (paid)
2. Configure to use DO Spaces (S3-compatible)
3. Keep `wp-content/uploads/` in Spaces only
4. Include themes/plugins in git repo or Docker image

**Pros:**
- ✅ Instant container startup (no sync)
- ✅ Scalable - no storage limits in container
- ✅ CDN-ready - DO Spaces has built-in CDN
- ✅ Industry standard approach
- ✅ Works perfectly with Docker/Kubernetes

**Cons:**
- ❌ Requires WordPress plugin
- ❌ Slightly more complex setup

**DO Deployment Changes Needed:**
```dockerfile
# In Dockerfile - just WordPress + themes/plugins
COPY wp-content/themes /var/www/html/wp-content/themes
COPY wp-content/plugins /var/www/html/wp-content/plugins
# uploads/ NOT copied - served from Spaces
```

---

### ✅ **OPTION 2: Pre-built Docker Image in Container Registry**

**How it works:**
- Build Docker image WITH all wp-content included
- Push to DO Container Registry
- Deploy pre-built image (no build on deployment)

**Implementation:**
1. GitHub Actions workflow builds image on git push
2. Includes wp-content sync during build (not runtime)
3. Pushes to `registry.digitalocean.com/your-registry/wordpress`
4. DO App deploys pre-built image

**Pros:**
- ✅ Fast deployments (image already built)
- ✅ wp-content included in image
- ✅ No runtime sync needed

**Cons:**
- ❌ Large image size (100MB+ with media)
- ❌ More complex CI/CD pipeline
- ❌ Media changes require new image build
- ❌ Not scalable for large media libraries

**DO Deployment Changes Needed:**
```yaml
# .github/workflows/deploy.yml
- Build Docker image
- Sync wp-content during build
- Push to DO Container Registry
- Deploy from registry
```

---

### ⚠️ **OPTION 3: Lazy Loading with Progress Page**

**How it works:**
- Container starts with minimal wp-content
- Shows "Building site..." page via index.html
- Background process syncs wp-content
- Redirects to WordPress when ready

**Implementation:**
1. Entrypoint serves static HTML initially
2. Background task syncs from Spaces
3. Switches to WordPress when complete
4. Health check passes immediately

**Pros:**
- ✅ Container starts quickly (passes healthcheck)
- ✅ User sees progress instead of error
- ✅ Eventually shows full site

**Cons:**
- ❌ Site unavailable during sync (1-5 minutes)
- ❌ Bad user experience for visitors
- ❌ Still slow on every deployment
- ❌ Doesn't solve the fundamental problem

---

### ❌ **OPTION 4: Sync at Runtime** (CURRENT APPROACH - NOT RECOMMENDED)

**Why it fails:**
- Takes 2-5 minutes to sync
- DO healthcheck timeout is usually 60 seconds
- Deployment rolls back before sync completes
- Not scalable for production

---

## Recommended Implementation: Option 1

### Step 1: Install WP Offload Media Plugin

```bash
# Add to your WordPress plugins
cd /path/to/wp-content/plugins
wget https://downloads.wordpress.org/plugin/amazon-s3-and-cloudfront.latest.zip
unzip amazon-s3-and-cloudfront.latest.zip
```

### Step 2: Configure for DO Spaces

Add to wp-config.php:
```php
// DigitalOcean Spaces configuration for media offload
define('AS3CF_SETTINGS', serialize([
    'provider' => 'do',
    'access-key-id' => getenv('DO_SPACES_KEY'),
    'secret-access-key' => getenv('DO_SPACES_SECRET'),
    'bucket' => getenv('DO_SPACES_BUCKET'),
    'region' => getenv('DO_SPACES_REGION'),
    'cloudfront' => getenv('DO_SPACES_ENDPOINT'),
    'copy-to-s3' => true,
    'serve-from-s3' => true,
]));
```

### Step 3: Update Dockerfile

```dockerfile
# Copy themes and plugins from git (NOT uploads)
COPY wp-content/themes /var/www/html/wp-content/themes
COPY wp-content/plugins /var/www/html/wp-content/plugins

# Create uploads directory (empty - served from Spaces)
RUN mkdir -p /var/www/html/wp-content/uploads
```

### Step 4: Update .gitignore

```gitignore
# wp-content/uploads stays in DO Spaces
wp-content/uploads/

# Include themes and plugins in git
!wp-content/themes/
!wp-content/plugins/
```

### Step 5: Deploy

```bash
git add .
git commit -m "Configure WP Offload Media for DO Spaces"
git push origin main
```

**Result:**
- Container builds in ~30 seconds
- Starts in ~5 seconds
- All media served from DO Spaces
- Fast, scalable, production-ready

---

## Local Development with Option 1

For local dev, you can still sync (it's local, no timeout):
```bash
# One-time sync for local development
python3 sync-from-spaces.py

# Or mount as read-only reference
docker-compose.yml:
volumes:
  - ./wp-content-synced:/var/www/html/wp-content:ro
```

---

## Comparison Table

| Feature | Option 1 (Spaces) | Option 2 (Registry) | Option 3 (Progress) | Option 4 (Sync) |
|---------|-------------------|---------------------|---------------------|-----------------|
| Deploy Speed | ⚡ <30s | ⚡ <30s | 🐌 2-5min | ❌ Fails |
| Scalability | ✅ Unlimited | ❌ Limited | ❌ Limited | ❌ Limited |
| User Experience | ✅ Instant | ✅ Instant | ⚠️ Wait screen | ❌ Error |
| Complexity | ⚠️ Plugin setup | ⚠️ CI/CD setup | ⚠️ Custom code | ✅ Simple |
| Cost | ✅ Low (Spaces) | ⚠️ Medium | ✅ Low | ✅ Low |
| **Recommended** | **YES** | Maybe | No | No |

---

## Next Steps

1. **For Production:** Implement Option 1 (WP Offload Media)
2. **For Testing:** Try Option 2 if you want to test pre-built images
3. **For Local Dev:** Keep using sync (it works locally)

Let me know which option you'd like to implement and I can help set it up!
