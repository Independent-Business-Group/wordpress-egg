# DigitalOcean Deployment - Action Items

## ✅ Fixed Issues

### 1. Updated `.do-post-build.sh`
**What changed:**
- Now downloads WordPress core during build (like Docker setup)
- Detects and removes placeholder `index.php` if it contains `phpinfo()`
- WordPress core files are downloaded fresh every time

**Why this matters:**
- Prevents the "PHP Version" page issue we saw locally
- Ensures WordPress core is always fresh and not from git repo
- Placeholder index.php won't overwrite WordPress's real index.php

### 2. Updated `.gitignore`
**What changed:**
- Explicitly excludes `index.php`
- Excludes Docker-specific files
- Excludes backup files (`*.bak`)

**Why this matters:**
- Keeps WordPress core files out of git
- Only custom configuration stays in repository
- Cleaner deployments

---

## 🔍 Key Differences: Local vs DigitalOcean

### Database Connection

| Setting | Local Docker | DigitalOcean |
|---------|-------------|--------------|
| **SSL** | Disabled (`--skip-ssl`) | **Required** (`MYSQLI_CLIENT_SSL`) |
| **Host** | `db` | Managed DB hostname |
| **Port** | `3306` | `25060` (SSL port) |

⚠️ **Important:** The `setup-wp-config.php` file has this line:
```php
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
```
**This is CORRECT for DigitalOcean and must NOT be changed!**

### WordPress Core Files

| Aspect | Local Docker | DigitalOcean (Fixed) |
|--------|-------------|---------------------|
| **Source** | Downloaded in Dockerfile | Downloaded in `.do-post-build.sh` |
| **index.php** | From WordPress core | From WordPress core (placeholder removed) |
| **When** | Container build time | App Platform build time |

---

## 📋 To Deploy to DigitalOcean

### 1. Remove Old Placeholder (Optional Cleanup)
```bash
cd /home/cw/Documents/Wordpress-Egg
git rm index.php.bak  # Remove the old placeholder
git commit -m "Remove placeholder index.php"
```

### 2. Commit the Fixes
```bash
git add .do-post-build.sh .gitignore
git commit -m "Fix: Download WordPress core during build, prevent index.php conflict"
git push origin main
```

### 3. Verify in DigitalOcean App Spec
Make sure `app-spec-php.yaml` has:
```yaml
build_command: chmod +x .do-post-build.sh && ./.do-post-build.sh
```

### 4. Required Environment Variables
In DigitalOcean App Platform settings, ensure these are set:
```yaml
DB_HOST: <your-managed-db-host>     # e.g., db-mysql-syd1-12345-do-user-67890-0.b.db.ondigitalocean.com
DB_PORT: "25060"                     # SSL port for managed DB
DB_NAME: <your-database-name>
DB_USER: <your-db-user>
DB_PASSWORD: <your-db-password>      # SECRET
DB_CHARSET: utf8mb4
TABLE_PREFIX: wp_
```

---

## 🧪 Testing Checklist

After deploying to DigitalOcean:

- [ ] Site loads WordPress installation page (not PHP info)
- [ ] Database connection works (no SSL errors)
- [ ] Can complete WordPress installation
- [ ] wp-config.php has `MYSQL_CLIENT_FLAGS` set for SSL
- [ ] WordPress core files present (check /wp-admin exists)

---

## 🚨 Common Issues & Solutions

### Issue: "PHP Version 8.1.34" page appears
**Cause:** Placeholder index.php from git overwrote WordPress's index.php  
**Solution:** ✅ Fixed! The updated `.do-post-build.sh` removes this automatically

### Issue: Database SSL errors
**Cause:** Missing SSL flag in wp-config.php  
**Solution:** ✅ Already correct! `setup-wp-config.php` includes `MYSQLI_CLIENT_SSL`

### Issue: WordPress files missing after deployment
**Cause:** WordPress not downloaded during build  
**Solution:** ✅ Fixed! `.do-post-build.sh` now downloads WordPress core

---

## 📝 Files Changed

1. **`.do-post-build.sh`** - Downloads WordPress and removes placeholder
2. **`.gitignore`** - Excludes WordPress core and Docker files
3. **`DOCKER-VS-DO-COMPARISON.md`** - Technical comparison document
4. **`Dockerfile`** - Don't copy index.php (local only)

---

## 🔒 Security Notes

- ✅ SSL enforced for database connections (DigitalOcean Managed DB)
- ✅ Unique security salts generated per deployment
- ✅ wp-config.php not stored in git (generated at build time)
- ✅ Database credentials from environment variables (not hardcoded)

---

## Next Steps

1. Review the changes in `.do-post-build.sh` and `.gitignore`
2. Test locally with `./start-local.sh` (already working ✅)
3. Commit and push changes
4. Deploy to DigitalOcean App Platform
5. Verify WordPress installation page loads correctly
