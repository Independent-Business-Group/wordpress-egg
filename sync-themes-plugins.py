#!/usr/bin/env python3
"""
Sync WordPress themes and plugins from DO Spaces
(Excludes uploads - those will be served directly from Spaces)
"""

import os
import sys
from pathlib import Path

# Load environment variables from .env file
env = {}
env_file = Path('.env')
if env_file.exists():
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                env[key] = value

bucket = env.get('DO_SPACES_BUCKET', 'everydaytech-wordpress')
region = env.get('DO_SPACES_REGION', 'syd1')
endpoint = env.get('DO_SPACES_ENDPOINT', 'syd1.digitaloceanspaces.com')
access_key = env.get('DO_SPACES_KEY', '')
secret_key = env.get('DO_SPACES_SECRET', '')
site_path = env.get('BUCKET_SITE_PATH', 'performwritecom')

print("=" * 60)
print("WordPress Themes & Plugins Sync from DO Spaces")
print("=" * 60)
print(f"Bucket: {bucket}")
print(f"Region: {region}")
print(f"Path: {site_path}/wp-content/")
print(f"Downloading: themes/ and plugins/ ONLY")
print(f"Excluding: uploads/ (served from Spaces)")
print()

if not access_key or not secret_key:
    print("❌ Error: Missing DO Spaces credentials")
    print("Please add DO_SPACES_KEY and DO_SPACES_SECRET to your .env file")
    sys.exit(1)

try:
    import boto3
    from botocore.exceptions import ClientError
    
    print("→ Using boto3 to download files...")
    print()
    
    # Create S3 client for DO Spaces
    client = boto3.client(
        's3',
        region_name=region,
        endpoint_url=f'https://{endpoint}',
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key
    )
    
    # List and download files
    prefix = f'{site_path}/wp-content/'
    print(f"Listing files in s3://{bucket}/{prefix}")
    
    paginator = client.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=bucket, Prefix=prefix)
    
    downloaded = 0
    skipped = 0
    
    for page in pages:
        if 'Contents' not in page:
            continue
            
        for obj in page['Contents']:
            key = obj['Key']
            
            # Skip if not themes or plugins
            relative_path = key.replace(f'{site_path}/wp-content/', '')
            
            # Only download themes/ and plugins/
            if not (relative_path.startswith('themes/') or 
                    relative_path.startswith('plugins/') or
                    relative_path in ['index.php']):
                skipped += 1
                continue
            
            # Skip directories
            if key.endswith('/'):
                continue
            
            # Create local path
            local_path = f'wp-content/{relative_path}'
            local_dir = os.path.dirname(local_path)
            
            # Skip if file already exists
            if os.path.exists(local_path):
                skipped += 1
                continue
            
            # Create directory if needed
            if local_dir and not os.path.exists(local_dir):
                os.makedirs(local_dir, exist_ok=True)
            
            # Download file
            print(f"  Downloading: {local_path}")
            try:
                client.download_file(bucket, key, local_path)
                downloaded += 1
            except Exception as e:
                print(f"    ❌ Error downloading {local_path}: {e}")
    
    print()
    print("=" * 60)
    print(f"✅ Sync complete!")
    print(f"   Downloaded: {downloaded} files")
    print(f"   Skipped: {skipped} files (uploads or already exists)")
    print()
    print("Next steps:")
    print("1. Install WP Offload Media plugin")
    print("2. Update Dockerfile to include themes/plugins")
    print("3. Configure wp-config.php for Spaces")
    print("=" * 60)
    
except ImportError:
    print("❌ Error: boto3 not available")
    print()
    print("Install with: pip install boto3")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
