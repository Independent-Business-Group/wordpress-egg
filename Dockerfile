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

# Enable .htaccess support for WordPress permalinks
RUN echo '<Directory /var/www/html/>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
    </Directory>' >> /etc/apache2/sites-available/000-default.conf

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

# Install WP-CLI for plugin management
RUN wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copy plugin and theme manifests
COPY plugins.txt /tmp/plugins.txt
COPY themes.txt /tmp/themes.txt

# Download and install plugins from manifest
RUN mkdir -p /var/www/html/wp-content/plugins && \
    cd /var/www/html/wp-content/plugins && \
    while IFS= read -r plugin || [ -n "$plugin" ]; do \
    # Skip empty lines and comments
    plugin=$(echo "$plugin" | sed 's/#.*//' | xargs); \
    if [ -n "$plugin" ]; then \
    echo "Installing plugin: $plugin"; \
    wget -q "https://downloads.wordpress.org/plugin/${plugin}.zip" -O "${plugin}.zip" && \
    unzip -q "${plugin}.zip" && \
    rm "${plugin}.zip" || echo "Warning: Failed to install ${plugin}"; \
    fi \
    done < /tmp/plugins.txt && \
    rm /tmp/plugins.txt

# Download and install themes from manifest
RUN mkdir -p /var/www/html/wp-content/themes && \
    cd /var/www/html/wp-content/themes && \
    while IFS= read -r theme || [ -n "$theme" ]; do \
    # Skip empty lines and comments
    theme=$(echo "$theme" | sed 's/#.*//' | xargs); \
    if [ -n "$theme" ]; then \
    echo "Installing theme: $theme"; \
    wget -q "https://downloads.wordpress.org/theme/${theme}.zip" -O "${theme}.zip" && \
    unzip -q "${theme}.zip" && \
    rm "${theme}.zip" || echo "Warning: Failed to install ${theme}"; \
    fi \
    done < /tmp/themes.txt && \
    rm /tmp/themes.txt

# Create mu-plugins directory and install CDN URL rewrite plugin
RUN mkdir -p /var/www/html/wp-content/mu-plugins && \
    cat > /var/www/html/wp-content/mu-plugins/cdn-url-rewrite.php << 'MUPLUGIN'
<?php
/**
 * Plugin Name: CDN URL Rewrite
 * Description: Rewrites upload URLs to use DigitalOcean Spaces CDN
 * Version: 1.0
 * Author: Auto-generated
 */

function cdn_rewrite_upload_urls($content) {
    $cdn_url = 'https://' . getenv('DO_SPACES_CDN_ENDPOINT') . '/' . getenv('BUCKET_SITE_PATH') . '/wp-content/uploads';
    $local_url = 'http://localhost:8080/wp-content/uploads';
    
    // Also handle other local URLs
    $site_url = get_option('home');
    $site_upload_url = $site_url . '/wp-content/uploads';
    
    $content = str_replace($local_url, $cdn_url, $content);
    $content = str_replace($site_upload_url, $cdn_url, $content);
    
    return $content;
}

// Apply to various filters
add_filter('the_content', 'cdn_rewrite_upload_urls', 100);
add_filter('the_excerpt', 'cdn_rewrite_upload_urls', 100);
add_filter('widget_text', 'cdn_rewrite_upload_urls', 100);
add_filter('wp_get_attachment_url', 'cdn_rewrite_upload_urls', 100);
add_filter('wp_calculate_image_srcset', function($sources) {
    foreach ($sources as &$source) {
        $source['url'] = cdn_rewrite_upload_urls($source['url']);
    }
    return $sources;
}, 100);

// Add header output buffering to catch all output
function cdn_buffer_start() { ob_start('cdn_rewrite_upload_urls'); }
function cdn_buffer_end() { if (ob_get_length()) ob_end_flush(); }
add_action('wp_head', 'cdn_buffer_start', 0);
add_action('wp_footer', 'cdn_buffer_end', 999);
MUPLUGIN

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
// This serves uploads directly from DO Spaces CDN instead of syncing
define('AS3CF_SETTINGS', serialize([
'provider' => 'do',
'access-key-id' => getenv('DO_SPACES_KEY'),
'secret-access-key' => getenv('DO_SPACES_SECRET'),
'bucket' => getenv('DO_SPACES_BUCKET'),
'region' => getenv('DO_SPACES_REGION'),
'domain' => 'cloudfront',  // Use CDN endpoint
'cloudfront' => getenv('DO_SPACES_CDN_ENDPOINT'),
'copy-to-s3' => true,
'serve-from-s3' => true,
'remove-local-file' => true,
'object-prefix' => getenv('BUCKET_SITE_PATH') . '/wp-content/uploads/',
'enable-object-prefix' => true,
'force-https' => true,
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

# Create .htaccess for WordPress permalinks if it doesn't exist
if [ ! -f /var/www/html/.htaccess ]; then
echo "Creating .htaccess for WordPress permalinks..."
cat > /var/www/html/.htaccess << 'HTACCESS'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS
chown www-data:www-data /var/www/html/.htaccess
chmod 644 /var/www/html/.htaccess
echo "✅ .htaccess created"
fi

# Activate WP Offload Media plugin (if WordPress tables exist)
echo "Activating WP Offload Media plugin..."
if wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
wp plugin activate amazon-s3-and-cloudfront --path=/var/www/html --allow-root 2>/dev/null && \
    echo "✅ WP Offload Media activated" || \
    echo "⚠️  Plugin activation will happen after WordPress installation"
else
echo "⏭️  WordPress not yet installed, skipping plugin activation"
fi

# Start Apache
echo "Starting Apache..."
exec apache2-foreground
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
