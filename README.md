# WordPress Egg - PHP Buildpack Template

Clean WordPress deployment using DigitalOcean App Platform PHP buildpack.

## Features

- ✅ Automatic CDN URL rewriting for uploads (no database changes required)
- ✅ Plugin/theme manifest system for reproducible builds
- ✅ Environment-based configuration (no secrets in code)
- ✅ DigitalOcean Spaces integration with CDN support
- ✅ Local Docker development matching production
- ✅ Permalink support with .htaccess auto-generation
- ✅ Must-use plugins for automatic CDN rewriting

## How It Works

1. **Build Phase**
   - `.do-post-build.sh` downloads latest WordPress core
   - `setup-wp-config.php` generates wp-config.php from environment variables
   
2. **Runtime**
   - Standard PHP buildpack serves WordPress
   - Connects to existing MySQL database
   - Uses environment variables for all configuration

## Required Environment Variables

Configure these in DigitalOcean App Platform:

### Database (RUN_AND_BUILD_TIME scope)
- `DB_HOST` - MySQL hostname
- `DB_PORT` - MySQL port (default: 3306)
- `DB_NAME` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password (SECRET)
- `TABLE_PREFIX` - WordPress table prefix (default: wp_)
- `DB_CHARSET` - Database charset (default: utf8mb4)

### CDN / DigitalOcean Spaces (RUN_TIME scope)
- `DO_SPACES_BUCKET` - Spaces bucket name
- `DO_SPACES_ENDPOINT` - Spaces origin endpoint
- `DO_SPACES_CDN_ENDPOINT` - Spaces CDN endpoint
- `DO_SPACES_REGION` - Spaces region
- `DO_SPACES_KEY` - Spaces access key (SECRET)
- `DO_SPACES_SECRET` - Spaces secret key (SECRET)
- `BUCKET_SITE_PATH` - Path within bucket for this site

**Note:** See [CDN-URL-REWRITE.md](CDN-URL-REWRITE.md) for how upload URLs are automatically rewritten to use the CDN.

## Deployment

App Platform will auto-deploy on push to main branch.

## What Gets Deployed

- `index.php` - Placeholder for initial deployment
- `.do-post-build.sh` - Build script
- `setup-wp-config.php` - Config generator
- `.slugignore` - Build exclusions

**WordPress core is downloaded during build**, not committed to git.

## App Platform Configuration

- **Environment**: `php`
- **Build Command**: `chmod +x .do-post-build.sh && ./.do-post-build.sh`
- **HTTP Port**: `8080` (PHP buildpack default)
- **Instance Size**: `basic-s` (2GB) or larger recommended
