# Plugin & Theme Manifest System

## Overview

WordPress **plugins and themes** are now **managed via manifest files** (`plugins.txt` and `themes.txt`) instead of being committed to git. This keeps the repository small while ensuring all required components are installed during Docker build.

## How It Works

### 1. Manifests

**`plugins.txt`:**
```txt
# WordPress Plugin Manifest
amazon-s3-and-cloudfront
contact-form-7
woocommerce
wordpress-seo
```

**`themes.txt`:**
```txt
# WordPress Theme Manifest
astra
```

- One slug per line
- Comments start with `#`
- Slugs match the WordPress.org directory

### 2. Docker Build Process

During `docker build`:
1. Copies manifest files into build context
2. Downloads each plugin/theme from wordpress.org using their slugs
3. Installs into `/var/www/html/wp-content/plugins/` and `/themes/`
4. Removes temporary files

**Download URLs**:
- Plugins: `https://downloads.wordpress.org/plugin/{slug}.zip`
- Themes: `https://downloads.wordpress.org/theme/{slug}.zip`

**Result**: Self-contained Docker image with all components included

### 3. Git Tracking

```gitignore
# .gitignore
wp-content/plugins/    # Excluded from git
wp-content/themes/     # Excluded from git (except default themes from core)
!plugins.txt           # Manifest tracked in git
!themes.txt            # Manifest tracked in git
```

Only the **manifest files** are in git, not the actual plugin/theme files (300MB+)

## Benefits

| Before | After |
|--------|-------|
| 300MB+ of plugins/themes in git | ~1KB manifest files |
| Manual plugin/theme management | Declarative manifests |
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

### Add a Theme

1. **Find theme slug** from wordpress.org URL:
   ```
   https://wordpress.org/themes/astra/
                                 ^^^^^
                                 theme slug
   ```

2. **Add to `themes.txt`**:
   ```txt
   echo "astra" >> themes.txt
   ```

3. **Commit and push**:
   ```bash
   git add themes.txt
   git commit -m "Add Astra theme"
   git push
   ```

4. **Deploy**:
   - DigitalOcean rebuilds image with new theme
   - Theme installed automatically

### Remove a Plugin/Theme

1. **Comment out or delete** from manifest:
   ```txt
   # contact-form-7
   ```

2. **Commit and push**:
   ```bash
   git add plugins.txt  # or themes.txt
   git commit -m "Remove Contact Form 7"
   git push
   ```

### Update Plugins/Themes

Plugins and themes are downloaded as "latest" from wordpress.org during each build.

To force update:
```bash
git commit --allow-empty -m "Rebuild to update plugins & themes"
git push
```

## Testing Locally

### Test Build
```bash
./test-build.sh
```

This will:
- Show plugins & themes to be installed
- Build Docker image
- Report build success/failure
- Show image size and counts

### Manual Build
```bash
# Build image
docker-compose build

# Start WordPress
docker-compose up -d

# Check installed plugins
docker exec wp-app ls /var/www/html/wp-content/plugins/

# Check installed themes
docker exec wp-app ls /var/www/html/wp-content/themes/
```

## Build Time

- **Without manifests**: ~30 seconds
- **With manifests (11 plugins + 1 theme)**: ~2-3 minutes
- **Old method (sync 300MB)**: 5+ minutes (timeout)

Still **much faster** than runtime sync and **won't timeout** on DigitalOcean!

## Current Manifest Contents

### Plugins
See [`plugins.txt`](plugins.txt) for the current manifest.

Active plugins from production:
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
- yoast-seo

### Themes
See [`themes.txt`](themes.txt) for the current manifest.

Active theme from production:
- **astra** (currently active)

**Note**: Default WordPress themes (twentytwentyfive, twentytwentyfour, etc.) are included in WordPress core.

## Deployment Flow

```
Developer                    GitHub                  DigitalOcean
---------                    ------                  ------------
Edit manifests       →       Push code        →      Build image
(plugins.txt/                                              ↓
themes.txt)                                                Download from
                                                           wordpress.org
                                                           ↓
                                                           Create image
                                                           ↓
                                                           Deploy container
                                                           ↓
                                                           WordPress ready! ✅
```

**Total time**: ~3-5 minutes (vs timeout before)

## Advanced: Custom Plugins/Themes

For premium/custom components not on wordpress.org:

### Option A: Download URL
```txt
# plugins.txt
# Format: slug|download-url
my-custom-plugin|https://example.com/plugins/my-custom-plugin.zip

# themes.txt
my-premium-theme|https://example.com/themes/my-theme.zip
```

(Requires Dockerfile modification to support URL syntax)

### Option B: Build-time script
Create `install-custom.sh`:
```bash
#!/bin/bash
# Install custom plugins
cd /var/www/html/wp-content/plugins
wget https://example.com/my-plugin.zip
unzip my-plugin.zip && rm my-plugin.zip

# Install custom themes
cd /var/www/html/wp-content/themes
wget https://example.com/my-theme.zip
unzip my-theme.zip && rm my-theme.zip
```

Add to Dockerfile:
```dockerfile
COPY install-custom.sh /tmp/
RUN bash /tmp/install-custom.sh
```

### Option C: Environment variable
```dockerfile
ARG CUSTOM_PLUGIN_URL
ARG CUSTOM_THEME_URL
RUN wget "$CUSTOM_PLUGIN_URL" -O plugin.zip && ...
RUN wget "$CUSTOM_THEME_URL" -O theme.zip && ...
```

## Troubleshooting

### Plugin/Theme fails to install

**Error**: `Warning: Failed to install plugin-name`

**Causes**:
1. Slug incorrect
2. Not available on wordpress.org (premium/custom)
3. Network issue during build

**Fix**:
- Verify slug at https://wordpress.org/plugins/ or /themes/
- Check build logs: `docker-compose build 2>&1 | tee build.log`
- For custom components, use advanced methods above

### Build is slow

**Normal**: 2-3 minutes for 11 plugins + 1 theme

**If slower**:
- Check network connection
- Reduce items in manifests
- Use Docker build cache (don't use `--no-cache` unless needed)

### Plugins/Themes not activated

The manifests **install** components but don't **activate** them.

**Activate plugin** in WordPress admin or via WP-CLI:
```bash
docker exec wp-app wp plugin activate plugin-slug --allow-root
```

**Activate theme** in WordPress admin or via WP-CLI:
```bash
docker exec wp-app wp theme activate theme-slug --allow-root
```

### Blank Page After Deploy

If WordPress shows a blank page:

1. **Check active theme** in database:
   ```sql
   SELECT option_value FROM wp_options WHERE option_name = 'template';
   ```

2. **Ensure theme is in manifest**:
   - Add missing theme slug to `themes.txt`
   - Rebuild: `docker-compose build`

3. **Or switch to default theme**:
   ```bash
   docker exec wp-app wp theme activate twentytwentyfive --allow-root
   ```

## Migration Guide

From old method (plugins/themes in git) to manifest:

```bash
# 1. List current plugins
ls wp-content/plugins/ > plugins.txt.new

# 2. List current themes (excluding WordPress defaults)
ls wp-content/themes/ | grep -v "^twenty" > themes.txt.new

# 3. Clean up the lists (remove index.php, .old files, etc)
# Edit plugins.txt.new and themes.txt.new manually

# 4. Replace manifests
mv plugins.txt.new plugins.txt
mv themes.txt.new themes.txt

# 5. Remove from git
git rm -r wp-content/plugins/ wp-content/themes/

# 6. Update .gitignore (already done)

# 7. Commit
git add plugins.txt themes.txt .gitignore
git commit -m "Switch to manifest system for plugins & themes"
git push
```

## Summary

✅ **Small git repo** (2KB manifests vs 300MB+ plugins/themes)  
✅ **Fast deployments** (3-5 min vs timeout)  
✅ **Easy management** (edit two files)  
✅ **Always up-to-date** (latest from wordpress.org)  
✅ **Reproducible builds** (same manifests = same components)  
✅ **No blank pages** (all themes installed during build)  

This is a **best practice** for WordPress in Docker! 🎉

## Manifest Files

- [`plugins.txt`](plugins.txt) - Plugin manifest
- [`themes.txt`](themes.txt) - Theme manifest
- [`test-build.sh`](test-build.sh) - Interactive build tester
- [`quick-test.sh`](quick-test.sh) - Non-interactive build tester
