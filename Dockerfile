# WordPress Egg Template
# Production-ready WordPress container for multi-tenant deployment

FROM php:8.2-apache

# Install required PHP extensions and tools
RUN apt-get update && apt-get install -y \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    git \
    wget \
    curl \
    mariadb-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo_mysql \
    zip \
    exif \
    opcache \
    bcmath \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install rclone for DO Spaces sync
RUN curl https://rclone.org/install.sh | bash

# Enable Apache modules
RUN a2enmod rewrite expires headers

# Set recommended PHP settings
RUN { \
    echo 'memory_limit=512M'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'max_execution_time=300'; \
    echo 'max_input_time=300'; \
    echo 'max_input_vars=3000'; \
    } > /usr/local/etc/php/conf.d/wordpress.ini

# Download and install WordPress
WORKDIR /var/www/html
RUN curl -o wordpress.tar.gz https://wordpress.org/latest.tar.gz \
    && tar -xzf wordpress.tar.gz --strip-components=1 \
    && rm wordpress.tar.gz \
    && chown -R www-data:www-data /var/www/html

# Copy initialization scripts
COPY docker-entrypoint.sh /usr/local/bin/
COPY wp-config-generator.php /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
