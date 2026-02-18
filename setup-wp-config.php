#!/usr/bin/env php
<?php
/**
 * WordPress Config Setup Script
 * Runs during build to generate wp-config.php from environment variables
 */

echo "🔧 Setting up WordPress configuration...\n";

// Get database configuration from environment
$db_name = getenv('DB_NAME');
$db_user = getenv('DB_USER');
$db_password = getenv('DB_PASSWORD');
$db_host = getenv('DB_HOST');
$db_port = getenv('DB_PORT') ?: '3306';
$db_charset = getenv('DB_CHARSET') ?: 'utf8mb4';
$db_collate = getenv('DB_COLLATE') ?: '';
$table_prefix = getenv('TABLE_PREFIX') ?: 'wp_';

if (!$db_name || !$db_user || !$db_password || !$db_host) {
    echo "❌ Missing required environment variables\n";
    echo "   Required: DB_NAME, DB_USER, DB_PASSWORD, DB_HOST\n";
    exit(1);
}

// Combine host and port for MySQL connection
$db_host_full = $db_host . ':' . $db_port;

echo "→ Database: {$db_name}@{$db_host}:{$db_port}\n";
echo "→ Table prefix: {$table_prefix}\n";

// Generate secure random keys
function generate_salt($length = 64) {
    return bin2hex(random_bytes($length / 2));
}

// Generate all WordPress security keys
$auth_key = generate_salt();
$secure_auth_key = generate_salt();
$logged_in_key = generate_salt();
$nonce_key = generate_salt();
$auth_salt = generate_salt();
$secure_auth_salt = generate_salt();
$logged_in_salt = generate_salt();
$nonce_salt = generate_salt();

// Build wp-config.php content
$wp_config = <<<CONFIG
<?php
/**
 * WordPress Configuration
 * Generated from environment variables
 */

// Database Configuration
define('DB_NAME', '$db_name');
define('DB_USER', '$db_user');
define('DB_PASSWORD', '$db_password');
define('DB_HOST', '$db_host_full');
define('DB_CHARSET', '$db_charset');
define('DB_COLLATE', '$db_collate');

// Force SSL for DigitalOcean Managed Database
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);

// Database Table Prefix
\$table_prefix = '$table_prefix';

// Security Keys and Salts
define('AUTH_KEY',         '$auth_key');
define('SECURE_AUTH_KEY',  '$secure_auth_key');
define('LOGGED_IN_KEY',    '$logged_in_key');
define('NONCE_KEY',        '$nonce_key');
define('AUTH_SALT',        '$auth_salt');
define('SECURE_AUTH_SALT', '$secure_auth_salt');
define('LOGGED_IN_SALT',   '$logged_in_salt');
define('NONCE_SALT',       '$nonce_salt');

// WordPress Debugging
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);

// Security Settings
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false);

// SSL/HTTPS Support (for reverse proxy)
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}

// Force WordPress to use the correct URL scheme
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO'])) {
    define('WP_HOME', \$_SERVER['HTTP_X_FORWARDED_PROTO'] . '://' . \$_SERVER['HTTP_HOST']);
    define('WP_SITEURL', \$_SERVER['HTTP_X_FORWARDED_PROTO'] . '://' . \$_SERVER['HTTP_HOST']);
}

// Performance Settings
define('WP_MEMORY_LIMIT', '512M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// Auto-save interval (5 minutes)
define('AUTOSAVE_INTERVAL', 300);

// Post revisions limit
define('WP_POST_REVISIONS', 5);

// Absolute path to WordPress directory
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

// Load WordPress
require_once ABSPATH . 'wp-settings.php';
CONFIG;

// Write wp-config.php to the root directory
$config_file = __DIR__ . '/wp-config.php';

if (file_put_contents($config_file, $wp_config) === false) {
    echo "❌ Failed to write wp-config.php\n";
    exit(1);
}

chmod($config_file, 0644);
echo "✅ wp-config.php generated successfully\n";
exit(0);
