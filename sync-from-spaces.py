#!/usr/bin/env python3
"""
Download wp-content from DigitalOcean Spaces without needing s3cmd
Uses boto3 if available, otherwise provides manual download instructions
"""

import os
import sys

# Load environment variables
def load_env():
    env_file = '.env'
    env_vars = {}
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key] = value
    return env_vars

env = load_env()
bucket = env.get('DO_SPACES_BUCKET', 'everydaytech-wordpress')
region = env.get('DO_SPACES_REGION', 'syd1')
endpoint = env.get('DO_SPACES_ENDPOINT', 'syd1.digitaloceanspaces.com')
access_key = env.get('DO_SPACES_KEY', '')
secret_key = env.get('DO_SPACES_SECRET', '')
site_path = env.get('BUCKET_SITE_PATH', 'performwritecom')

print("=" * 50)
print("WordPress Content Sync from DO Spaces")
print("=" * 50)
print(f"Bucket: {bucket}")
print(f"Region: {region}")
print(f"Path: {site_path}/wp-content/")
print()

# Try to use boto3
try:
    import boto3
    from botocore.client import Config
    
    if not access_key or not secret_key or secret_key == 'YOUR_SECRET_KEY_HERE':
        print("❌ Missing DO Spaces credentials!")
        print("Please add DO_SPACES_SECRET to your .env file")
        print()
        print("You can find it in:")
        print("  - DigitalOcean Control Panel → API → Spaces Keys")
        print("  - Or from your app's environment variables")
        sys.exit(1)
    
    print("→ Using boto3 to download files...")
    print()
    
    # Configure boto3 for DO Spaces
    session = boto3.session.Session()
    client = session.client('s3',
                           region_name=region,
                           endpoint_url=f'https://{endpoint}',
                           aws_access_key_id=access_key,
                           aws_secret_access_key=secret_key)
    
    # List and download files
    prefix = f'{site_path}/wp-content/'
    
    print(f"Listing files in s3://{bucket}/{prefix}")
    paginator = client.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=bucket, Prefix=prefix)
    
    file_count = 0
    for page in pages:
        if 'Contents' not in page:
            continue
        
        for obj in page['Contents']:
            key = obj['Key']
            # Remove the site_path prefix to get local path
            local_path = key.replace(f'{site_path}/', '')
            
            # Skip if it's just a directory marker
            if key.endswith('/'):
                continue
            
            # Create local directory if needed
            local_dir = os.path.dirname(local_path)
            if local_dir and not os.path.exists(local_dir):
                os.makedirs(local_dir, exist_ok=True)
            
            # Download file
            print(f"  Downloading: {local_path}")
            client.download_file(bucket, key, local_path)
            file_count += 1
    
    print()
    print(f"✓ Downloaded {file_count} files!")
    print()
    print("Content is now in ./wp-content/")
    
except ImportError:
    print("❌ boto3 is not installed")
    print()
    print("To install boto3:")
    print("  pip3 install --user boto3")
    print()
    print("Or install s3cmd:")
    print("  sudo dnf install s3cmd")
    print()
    print("Then run this script again, or use:")
    print(f"  s3cmd sync s3://{bucket}/{site_path}/wp-content/ ./wp-content/")
    sys.exit(1)

except Exception as e:
    print(f"❌ Error: {e}")
    print()
    print("Manual download alternative:")
    print(f"1. Install s3cmd: sudo dnf install s3cmd")
    print(f"2. Configure: s3cmd --configure")
    print(f"3. Download: s3cmd sync s3://{bucket}/{site_path}/wp-content/ ./wp-content/")
    sys.exit(1)
