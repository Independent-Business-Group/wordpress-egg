# Quick Guide: Sync wp-content from DigitalOcean Spaces

## You Need the DO Spaces Secret Key

Your `.env` file has a placeholder:
```bash
DO_SPACES_SECRET=YOUR_SECRET_KEY_HERE
```

## Get the Secret Key

### Option 1: From DigitalOcean Control Panel
1. Go to https://cloud.digitalocean.com/account/api/spaces
2. Find the key: `DO003JUHBJDDCCF9D6MU`
3. Click to reveal the secret
4. Copy it

### Option 2: From an Existing App  
```bash
# List your apps
doctl apps list

# Get the app spec (if you know the app ID)
doctl apps spec get <app-id> | grep -A 2 DO_SPACES_SECRET
```

## Add to .env

Edit `/home/cw/Documents/Wordpress-Egg/.env` and replace:
```bash
DO_SPACES_SECRET=YOUR_SECRET_KEY_HERE
```

With the actual secret key.

## Then Run the Sync

```bash
cd /home/cw/Documents/Wordpress-Egg
./sync-from-spaces.py
```

This will download all wp-content files from:
- `s3://everydaytech-wordpress/performwritecom/wp-content/`

To your local:
- `./wp-content/`

## What You'll Get

- Themes
- Plugins
- Uploads (media files)
- Any custom wp-content files

Total download size depends on how much media is in the bucket.
