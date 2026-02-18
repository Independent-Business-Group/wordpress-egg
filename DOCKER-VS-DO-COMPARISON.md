# WordPress Docker vs DigitalOcean Deployment - Key Differences

## Issue Found: index.php Conflict

### The Problem
The `index.php` file in the Wordpress-Egg repository is a **placeholder** that just shows `phpinfo()`:
```php
<?php
// Placeholder index.php for initial deployment
// This will be replaced by WordPress core during post-build
phpinfo();
```

This file was overwriting WordPress's real index.php, causing the site to only show PHP info instead of WordPress.

---

## Local Docker Setup (What We Fixed)

### 1. **Don't Copy index.php**
```dockerfile
# Download and install WordPress
RUN wget -q https://wordpress.org/latest.tar.gz \
    && tar -xzf latest.tar.gz --strip-components=1 \
    && rm latest.tar.gz

# Note: We don't copy index.php as WordPress provides its own
# The local index.php is just a placeholder for non-Docker deployments
```

### 2. **MySQL Connection - No SSL Required**
Local MariaDB container doesn't use SSL:
```bash
mysql --skip-ssl -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}"
```

In wp-config.php:
```php
// No SSL flags needed for local development
define('DB_HOST', 'db:3306');
```

---

## DigitalOcean Deployment (What Needs Checking)

### 1. **index.php Must Not Be Copied/Committed**

**Current Status:** The `index.php` in the git repo will be deployed to DO.

**Action Needed:**
- Either DELETE `index.php` from the repository
- Or modify `.do-post-build.sh` to remove it after cloning
- Or ensure WordPress download/extraction OVERWRITES it

### 2. **MySQL Connection - SSL REQUIRED**
DigitalOcean Managed Databases require SSL:

In `setup-wp-config.php` (line 63):
```php
// Force SSL for DigitalOcean Managed Database
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
```

This is **CORRECT** and must stay for DO deployments.

### 3. **WordPress Core Files**

**Current DO Setup:**
```bash
# .do-post-build.sh
# WordPress installation comes from the git repo itself
# No need to download - files are already cloned
```

**Question:** Does the git repo contain full WordPress core files? Or just wp-content?

If the repo doesn't have WordPress core:
- Need to download WordPress like we do in Docker
- Then copy wp-content over it
- Make sure index.php from git doesn't overwrite WordPress's

---

## Required Actions for DigitalOcean

### Option A: Clean Repository (Recommended)
1. Remove `index.php` from Wordpress-Egg repository
2. Add to `.gitignore`:
   ```
   # WordPress core files (downloaded during build)
   index.php
   wp-*.php
   readme.html
   license.txt
   ```
3. Modify `.do-post-build.sh` to download WordPress:
   ```bash
   #!/bin/bash
   set -e
   
   echo "Downloading WordPress core..."
   wget -q https://wordpress.org/latest.tar.gz
   tar -xzf latest.tar.gz --strip-components=1
   rm latest.tar.gz
   
   echo "Generating wp-config.php..."
   php setup-wp-config.php
   ```

### Option B: Overwrite After Clone
Keep current setup but explicitly remove the placeholder:
```bash
#!/bin/bash
set -e

# Remove placeholder index.php (WordPress provides its own)
rm -f index.php

echo "Generating wp-config.php..."
php setup-wp-config.php
```

---

## Environment Variables Comparison

### Local Docker (.env)
```bash
DB_HOST=db                    # Container name
DB_PORT=3306
DB_NAME=wordpress
DB_USER=wpuser
DB_PASSWORD=wppassword
```

### DigitalOcean (app-spec-php.yaml)
```yaml
- key: DB_HOST
  value: YOUR_DB_HOST         # Managed DB hostname
- key: DB_PORT
  value: "25060"              # Managed DB SSL port
- key: DB_NAME
  value: YOUR_DB_NAME
- key: DB_USER
  value: YOUR_DB_USER
- key: DB_PASSWORD
  type: SECRET
  value: YOUR_DB_PASSWORD
```

---

## Key Differences Summary

| Aspect | Local Docker | DigitalOcean |
|--------|-------------|--------------|
| **MySQL SSL** | Disabled (`--skip-ssl`) | Required (`MYSQLI_CLIENT_SSL`) |
| **DB Host** | `db` (container) | Managed DB hostname |
| **DB Port** | 3306 | 25060 (SSL port) |
| **index.php** | From WordPress core | ⚠️ Currently from git (wrong!) |
| **WordPress Download** | In Dockerfile | Should be in .do-post-build.sh |
| **Config Generation** | Entrypoint script | setup-wp-config.php |

---

## Recommended Fix for wordpress-performwritecom

The `wordpress-performwritecom` repository has the correct approach in `docker-init.sh`:

```bash
# Step 1: Download fresh WordPress core if not already present
if [ ! -f "wp-config-sample.php" ]; then
    echo "→ Downloading latest WordPress core..."
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz --strip-components=1
    rm latest.tar.gz
    echo "✓ WordPress core downloaded"
else
    echo "✓ WordPress core already present"
fi
```

This should be adapted for the `.do-post-build.sh` script in Wordpress-Egg.
