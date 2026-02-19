FROM php:8.1-apache

# Install system dependencies and PHP extensions required by WordPress
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    default-mysql-client \
    unzip \
    wget \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    opcache \
    mbstring \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache modules
RUN a2enmod rewrite expires headers

# Configure Apache to listen on port 8080
RUN sed -i 's/80/8080/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf

# Configure PHP for better WordPress performance
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Set working directory
WORKDIR /var/www/html

# Download and install WordPress
RUN wget -q https://wordpress.org/latest.tar.gz \
    && tar -xzf latest.tar.gz --strip-components=1 \
    && rm latest.tar.gz

# Copy plugin manifest
COPY plugins.txt /tmp/plugins.txt

# Download and install plugins from manifest
RUN mkdir -p /var/www/html/wp-content/plugins && \
    cd /var/www/html/wp-content/plugins && \
    while IFS= read -r plugin || [ -n "$plugin" ]; do \
    # Skip empty lines and comments
    plugin=$(echo "$plugin" | sed 's/#.*//' | xargs); \
    if [ -n "$plugin" ]; then \
    echo "Installing plugin: $plugin"; \
    wget -q "https://downloads.wordpress.org/plugin/${plugin}.latest.zip" -O "${plugin}.zip" && \
    unzip -q "${plugin}.zip" && \
    rm "${plugin}.zip" || echo "Warning: Failed to install ${plugin}"; \
    fi \
    done < /tmp/plugins.txt && \
    rm /tmp/plugins.txt

# Create uploads directory (will be served from DO Spaces, not local)
RUN mkdir -p /var/www/html/wp-content/uploads

# Note: We don't copy index.php as WordPress provides its own
# The local index.php is just a placeholder for non-Docker deployments

# Create entrypoint script
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database to be ready..."
echo "Connecting to: ${DB_HOST}:${DB_PORT} as ${DB_USER}"
export MYSQL_OPT="--ssl --skip-ssl-verify-server-cert"
until mysql $MYSQL_OPT -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
sleep 2
done
echo "Database is ready!"

# Generate wp-config.php if it doesn't exist
if [ ! -f /var/www/html/wp-config.php ]; then
echo "Generating wp-config.php..."
cat > /var/www/html/wp-config.php << 'WPCONFIG'
<?php
/**
* WordPress Configuration File
* Generated automatically for Docker environment
*/

// ** Database settings ** //
define('DB_NAME', getenv('DB_NAME') ?: 'wordpress');
define('DB_USER', getenv('DB_USER') ?: 'wpuser');
define('DB_PASSWORD', getenv('DB_PASSWORD') ?: 'wppassword');
define('DB_HOST', getenv('DB_HOST') . ':' . getenv('DB_PORT'));
define('DB_CHARSET', getenv('DB_CHARSET') ?: 'utf8mb4');
define('DB_COLLATE', getenv('DB_COLLATE') ?: '');

// ** Authentication Unique Keys and Salts ** //
define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');

// ** WordPress Database Table prefix ** //
$table_prefix = getenv('TABLE_PREFIX') ?: 'wp_';

// ** MySQL SSL Configuration for DigitalOcean Managed Database ** //
define('MYSQL_SSL_CA', '/etc/ssl/certs/ca-certificate.crt');
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);

// ** WordPress debugging mode ** //
define('WP_DEBUG', getenv('WP_DEBUG') === 'true');
define('WP_DEBUG_LOG', getenv('WP_DEBUG_LOG') === 'true');
define('WP_DEBUG_DISPLAY', getenv('WP_DEBUG_DISPLAY') === 'true');

// ** Site URL ** //
if (getenv('WORDPRESS_SITE_URL')) {
define('WP_HOME', getenv('WORDPRESS_SITE_URL'));
define('WP_SITEURL', getenv('WORDPRESS_SITE_URL'));
}

// ** WP Offload Media Configuration for DigitalOcean Spaces ** //
// This serves uploads directly from DO Spaces instead of syncing
define('AS3CF_SETTINGS', serialize([
'provider' => 'do',
'access-key-id' => getenv('DO_SPACES_KEY'),
'secret-access-key' => getenv('DO_SPACES_SECRET'),
'bucket' => getenv('DO_SPACES_BUCKET'),
'region' => getenv('DO_SPACES_REGION'),
'domain' => 'path',  // Use bucket path-style URLs
'cloudfront' => getenv('DO_SPACES_ENDPOINT'),
'copy-to-s3' => true,
'serve-from-s3' => true,
'remove-local-file' => true,
'object-prefix' => getenv('BUCKET_SITE_PATH') . '/wp-content/uploads/',
]));

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if (!defined('ABSPATH')) {
define('ABSPATH', __DIR__ . '/');
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
WPCONFIG
chown www-data:www-data /var/www/html/wp-config.php
echo "wp-config.php created successfully"
fi

# Set proper permissions
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Start Apache
echo "Starting Apache..."
exec apache2-foreground
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
