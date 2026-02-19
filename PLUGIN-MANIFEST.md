# Plugin Manifest System

## Overview

WordPress plugins are now **managed via `plugins.txt` manifest** instead of being committed to git. This keeps the repository small while ensuring all required plugins are installed during Docker build.

## How It Works

### 1. Plugin Manifest (`plugins.txt`)

```txt
# WordPress Plugin Manifest
amazon-s3-and-cloudfront
contact-form-7
woocommerce
wordpress-seo
```

- One plugin slug per line
- Comments start with `#`
- Plugin slugs match the WordPress.org plugin directory

### 2. Docker Build Process

During `docker build`:
1. Copies `plugins.txt` into build context
2. Downloads each plugin from wordpress.org
3. Installs plugins into `/var/www/html/wp-content/plugins/`
4. Removes temporary files

**Result**: Self-contained Docker image with all plugins included

### 3. Git Tracking

```gitignore
# .gitignore
wp-content/plugins/    # Excluded from git
!plugins.txt           # Manifest tracked in git
```

Only the **plugin list** is in git, not the actual plugin files (303MB+)

## Benefits

| Before | After |
|--------|-------|
| 303MB of plugins in git | ~1KB manifest file |
| Manual plugin management | Declarative manifest |
| Slow git operations | Fast commits/clones |
| Version conflicts | Always latest from WP.org |

## Usage

### Add a Plugin

1. **Find plugin slug** from wordpress.org URL:
   ```
   https://wordpress.org/plugins/contact-form-7/
                                  ^^^^^^^^^^^^^^
                                  plugin slug
   ```

2. **Add to `plugins.txt`**:
   ```txt
   echo "contact-form-7" >> plugins.txt
   ```

3. **Commit and push**:
   ```bash
   git add plugins.txt
   git commit -m "Add Contact Form 7 plugin"
   git push
   ```

4. **Deploy**:
   - DigitalOcean rebuilds image with new plugin
   - Plugin installed automatically

### Remove a Plugin

1. **Comment out or delete** from `plugins.txt`:
   ```txt
   # contact-form-7
   ```

2. **Commit and push**:
   ```bash
   git add plugins.txt
   git commit -m "Remove Contact Form 7"
   git push
   ```

### Update Plugins

Plugins are downloaded as "latest" from wordpress.org during each build.

To force update:
```bash
git commit --allow-empty -m "Rebuild to update plugins"
git push
```

## Testing Locally

### Test Build
```bash
./test-build.sh
```

This will:
- Show plugins to be installed
- Build Docker image
- Report build success/failure
- Show image size

### Manual Build
```bash
# Build image
docker-compose build

# Start WordPress
docker-compose up -d

# Check installed plugins
docker exec wp-app ls /var/www/html/wp-content/plugins/
```

## Build Time

- **Without plugins**: ~30 seconds
- **With manifest (10 plugins)**: ~2-3 minutes
- **Old method (sync 303MB)**: 5+ minutes (timeout)

Still **much faster** than runtime sync and **won't timeout** on DigitalOcean!

## Current Plugins

See [`plugins.txt`](plugins.txt) for the current manifest.

Active plugins synced from production database:
- amazon-s3-and-cloudfront (WP Offload Media)
- contact-form-7
- disable-comments
- health-check
- log-cleaner-for-ithemes-security
- woo-order-export-lite
- woocommerce-autocomplete-order
- woocommerce
- wordpress-seo
- wp-mail-smtp

## Deployment Flow

```
Developer                    GitHub                  DigitalOcean
---------                    ------                  ------------
Edit plugins.txt     →       Push code        →      Build image
                                                      ↓
                                                      Download plugins
                                                      from wordpress.org
                                                      ↓
                                                      Create image
                                                      ↓
                                                      Deploy container
                                                      ↓
                                                      WordPress ready! ✅
```

**Total time**: ~3-5 minutes (vs timeout before)

## Advanced: Custom Plugins

For premium/custom plugins not on wordpress.org:

### Option A: Download URL
```txt
# plugins.txt
# Format: slug|download-url
my-custom-plugin|https://example.com/plugins/my-custom-plugin.zip
```

(Requires Dockerfile modification to support URL syntax)

### Option B: Build-time script
Create `install-custom-plugins.sh`:
```bash
#!/bin/bash
cd /var/www/html/wp-content/plugins
wget https://example.com/my-plugin.zip
unzip my-plugin.zip && rm my-plugin.zip
```

Add to Dockerfile:
```dockerfile
COPY install-custom-plugins.sh /tmp/
RUN bash /tmp/install-custom-plugins.sh
```

### Option C: Environment variable
```dockerfile
ARG CUSTOM_PLUGIN_URL
RUN wget "$CUSTOM_PLUGIN_URL" -O plugin.zip && ...
```

## Troubleshooting

### Plugin fails to install

**Error**: `Warning: Failed to install plugin-name`

**Causes**:
1. Plugin slug incorrect
2. Plugin not on wordpress.org
3. Network issue during build

**Fix**:
- Verify slug at https://wordpress.org/plugins/
- Check build logs: `docker-compose build 2>&1 | tee build.log`
- For custom plugins, use advanced methods above

### Build is slow

**Normal**: 2-3 minutes for 10 plugins

**If slower**:
- Check network connection
- Reduce plugins in manifest
- Use Docker build cache (don't use `--no-cache`)

### Plugins not activated

The manifest **installs** plugins but doesn't **activate** them.

Activate in WordPress admin or via WP-CLI:
```bash
docker exec wp-app wp plugin activate plugin-slug --allow-root
```

## Migration Guide

From old method (plugins in git) to manifest:

```bash
# 1. List current plugins
ls wp-content/plugins/ > plugins.txt.new

# 2. Clean up the list (remove .old, index.php, etc)
# 3. Replace plugins.txt with the new list
# 4. Remove plugins from git
git rm -r wp-content/plugins/

# 5. Update .gitignore (already done)
# 6. Commit
git add plugins.txt .gitignore
git commit -m "Switch to plugin manifest system"
git push
```

## Summary

✅ **Small git repo** (1KB manifest vs 303MB plugins)  
✅ **Fast deployments** (3-5 min vs timeout)  
✅ **Easy management** (edit one file)  
✅ **Always up-to-date** (latest from wordpress.org)  
✅ **Reproducible builds** (same manifest = same plugins)  

This is a **best practice** for WordPress in Docker! 🎉
