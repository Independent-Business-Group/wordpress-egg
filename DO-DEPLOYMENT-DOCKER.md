# DigitalOcean Deployment Guide

## Prerequisites

Before deploying to DigitalOcean App Platform:

✅ **GitHub Repository**: Code pushed to `main` branch
✅ **DigitalOcean Managed Database**: MySQL database accessible
✅ **DigitalOcean Spaces**: Bucket with existing uploads (performwritecom/)
✅ **CDN Endpoint**: CDN configured for Spaces bucket

## Deployment Method

This deployment uses **Docker** (not PHP buildpack) to ensure all features work identically to local development:
- ✅ Plugin/theme manifests
- ✅ CDN URL rewriting mu-plugin
- ✅ WP-CLI integration
- ✅ Automatic .htaccess generation
- ✅ SSL database connection

## Step-by-Step Deployment

### 1. Set Secrets First

⚠️ **IMPORTANT**: The app-spec-docker.yaml contains placeholders for sensitive values. You need to set these before or immediately after creating the app.

**See [DO-SECRETS.md](DO-SECRETS.md) (not in git) for actual credential values and multiple methods to set them.**

**Quick method via Dashboard**:
1. Create the app (step 2 below)
2. Go to App Settings > Environment Variables
3. Update these SECRET values:
   - `DB_PASSWORD` - Database password
   - `DO_SPACES_KEY` - Spaces access key
   - `DO_SPACES_SECRET` - Spaces secret key
4. Redeploy the app

### 2. Create App on DigitalOcean

```bash
# Option A: Use doctl CLI
doctl apps create --spec app-spec-docker.yaml

# Option B: Use DigitalOcean Dashboard
# - Go to App Platform > Create App
# - Select GitHub repo: Independent-Business-Group/wordpress-egg
# - Choose branch: main
# - Import app-spec-docker.yaml
```

### 3. Verify Environment Variables

The `app-spec-docker.yaml` contains all required environment variables. **Verify these are correct**:

#### Database Configuration
- `DB_HOST`: wordpress-mysql-cluster-do-user-28531160-0.i.db.ondigitalocean.com
- `DB_PORT`: 25060
- `DB_NAME`: performwritecom_wp
- `DB_USER`: doadmin
- `DB_PASSWORD`: ⚠️ **SECRET** (set via Dashboard or doctl - see [DO-SECRETS.md](DO-SECRETS.md))
- `TABLE_PREFIX`: xfwlw_

#### Spaces/CDN Configuration
- `DO_SPACES_BUCKET`: everydaytech-wordpress
- `DO_SPACES_ENDPOINT`: syd1.digitaloceanspaces.com
- `DO_SPACES_CDN_ENDPOINT`: everydaytech-wordpress.syd1.cdn.digitaloceanspaces.com
- `DO_SPACES_REGION`: syd1
- `DO_SPACES_KEY`: ⚠️ **SECRET** (set via Dashboard or doctl - see [DO-SECRETS.md](DO-SECRETS.md))
- `DO_SPACES_SECRET`: ⚠️ **SECRET** (set via Dashboard or doctl - see [DO-SECRETS.md](DO-SECRETS.md))
- `BUCKET_SITE_PATH`: performwritecom

#### WordPress Configuration
- `WORDPRESS_SITE_URL`: ${APP_URL} (automatically set by App Platform)
- `WP_DEBUG`: false (production)

### 4. Deploy

```bash
# If using doctl:
doctl apps create --spec app-spec-docker.yaml

# Then set secrets (see DO-SECRETS.md)

# Watch deployment progress:
doctl apps list
doctl apps logs <APP_ID> --follow
```

### 5. Post-Deployment Verification

Once deployed, verify:

**1. Site loads**
```bash
curl -I https://your-app.ondigitalocean.app/
# Expected: HTTP/2 200
```

**2. Database connection works**
- Visit homepage - should show WordPress content
- Check for database connection errors in logs

**3. CDN URLs are working**
```bash
curl -s https://your-app.ondigitalocean.app/ | grep -o "https://everydaytech[^\"]*" | head -3
# Expected: CDN URLs for images
```

**4. Permalinks work**
```bash
curl -I https://your-app.ondigitalocean.app/contact-us/
# Expected: HTTP/2 200 (not 404)
```

**5. Plugins installed**
- Check logs for plugin installation messages
- Should see 11 plugins installed automatically

## What Gets Deployed

From the Dockerfile:
- ✅ **WordPress Latest** - Downloaded during build
- ✅ **11 Plugins** - From plugins.txt manifest
- ✅ **Astra Theme** - From themes.txt manifest
- ✅ **CDN Rewrite mu-plugin** - Built into image
- ✅ **WP-CLI** - For automation
- ✅ **SSL Certificate** - For DO database connection

## Build Process

1. **Docker build phase**:
   - Install PHP 8.1 + Apache
   - Download WordPress core
   - Install WP-CLI
   - Download plugins from manifest
   - Download themes from manifest
   - Create CDN rewrite mu-plugin
   - Set up entrypoint script

2. **Container startup (entrypoint.sh)**:
   - Wait for database connection
   - Generate wp-config.php from environment variables
   - Create .htaccess for permalinks
   - Activate WP Offload Media plugin
   - Start Apache

## Expected Build Time

- **First build**: ~3-5 minutes
  - WordPress download: ~30s
  - Plugin downloads: ~2-3 minutes
  - Theme download: ~30s
  - Docker layer caching: ~1 minute

- **Subsequent builds** (with cache): ~1-2 minutes

## Troubleshooting

### Build fails during plugin download

**Symptom**: Plugin download 404 errors

**Solution**: Check plugins.txt for invalid plugin slugs
```bash
# Test plugin URL:
wget https://downloads.wordpress.org/plugin/amazon-s3-and-cloudfront.zip
```

### Database connection errors

**Symptom**: "Error establishing database connection"

**Check**:
1. Database credentials in app-spec-docker.yaml
2. Database firewall allows App Platform IPs
3. SSL certificate (ca-certificate.crt) exists in repo

```bash
# Test from local:
mysql -h wordpress-mysql-cluster-do-user-28531160-0.i.db.ondigitalocean.com \
  -P 25060 -u doadmin -p --ssl
```

### Images not loading from CDN

**Symptom**: Images show 404 or local URLs

**Check**:
1. CDN endpoint in app-spec-docker.yaml
2. Bucket path: performwritecom/wp-content/uploads/
3. Check mu-plugin in logs:
```bash
doctl apps logs <APP_ID> | grep "mu-plugins"
```

### Permalinks return 404

**Symptom**: Pages show 404, only homepage works

**Check**:
1. .htaccess created in logs
2. Apache mod_rewrite enabled (it is in Dockerfile)
3. AllowOverride All set (it is in Dockerfile)

### Health check failing

**Symptom**: App shows unhealthy

**Adjust** in app-spec-docker.yaml:
```yaml
health_check:
  initial_delay_seconds: 180  # Increase if build is slow
  timeout_seconds: 10
  failure_threshold: 5  # Allow more failures during startup
```

## Monitoring

### View logs
```bash
# Real-time logs
doctl apps logs <APP_ID> --follow

# Recent logs
doctl apps logs <APP_ID> --tail 100
```

### Check container status
```bash
doctl apps get <APP_ID>
```

### View deployed environment variables
```bash
doctl apps spec get <APP_ID>
```

## Updating

### Code changes
```bash
git add .
git commit -m "Update feature"
git push origin main
# Auto-deploys via GitHub integration
```

### Update environment variables
```bash
# Edit app-spec-docker.yaml
doctl apps update <APP_ID> --spec app-spec-docker.yaml
```

### Update plugins/themes
Edit `plugins.txt` or `themes.txt`, commit, and push.
Rebuild will automatically download updated manifests.

## Rollback

If deployment fails:

```bash
# List deployments
doctl apps list-deployments <APP_ID>

# Rollback to previous
doctl apps create-deployment <APP_ID> --deployment-id <PREVIOUS_DEPLOYMENT_ID>
```

## Performance Optimization

### Current Setup
- Instance: basic-xxs ($5/month)
- PHP OPcache: Enabled
- CDN: All uploads served from Spaces CDN
- Apache: mod_expires, mod_headers enabled

### Scaling
If needed, upgrade instance size in app-spec-docker.yaml:
```yaml
instance_size_slug: basic-xs  # $12/month
# or
instance_size_slug: basic-s   # $24/month
```

## Cost Estimate

- **App Platform**: $5/month (basic-xxs)
- **Managed Database**: ~$15/month (shared CPU)
- **Spaces + CDN**: ~$5/month (250GB storage, 1TB transfer)
- **Total**: ~$25/month

## Security Notes

⚠️ **Secrets in app-spec-docker.yaml**

The app-spec file contains:
- Database password
- Spaces API keys

**Before committing changes**: 
```bash
# Mark secrets as SECRET type in app-spec
type: SECRET

# Or use doctl to set secrets without committing:
doctl apps update <APP_ID> --spec app-spec-docker.yaml
```

## Custom Domain

Once deployed:

1. **Get app URL**: `https://wordpress-performwritecom-xxxxx.ondigitaloceanspaces.com`
2. **Add custom domain** in App Platform dashboard
3. **Update WORDPRESS_SITE_URL**:
   ```yaml
   - key: WORDPRESS_SITE_URL
     value: https://performwrite.com
   ```
4. **Update DNS**:
   - Type: CNAME
   - Name: @ (or www)
   - Value: wordpress-performwritecom-xxxxx.ondigitalocean.app

## Next Steps After Deployment

1. ✅ Verify site loads
2. ✅ Test permalink structure
3. ✅ Verify CDN images load
4. ✅ Check all pages render correctly
5. ⚠️ Update WordPress core/plugins via WP Admin (not auto-update)
6. ⚠️ Configure custom domain
7. ⚠️ Set up SSL (automatic with App Platform)
8. ⚠️ Configure caching plugin if needed

## Support Resources

- [App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
- [Docker Builds](https://docs.digitalocean.com/products/app-platform/reference/dockerfile/)
- [Environment Variables](https://docs.digitalocean.com/products/app-platform/how-to/use-environment-variables/)

## Related Documentation

- [CDN-URL-REWRITE.md](CDN-URL-REWRITE.md) - How CDN URL rewriting works
- [MANIFEST-SYSTEM.md](MANIFEST-SYSTEM.md) - Plugin/theme manifest system
- [README-DOCKER.md](README-DOCKER.md) - Local Docker development
