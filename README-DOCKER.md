# Local WordPress Development with Docker

This setup provides a complete local WordPress development environment using Docker with MariaDB.

## What's Included

- **MariaDB 10.11**: Database server
- **WordPress (Latest)**: Running on PHP 8.1 with Apache
- **phpMyAdmin**: Database management interface

## Quick Start

### 1. Setup Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` if you want to customize database credentials or other settings.

### 2. Start the Containers

```bash
docker-compose up -d
```

This will:
- Download the necessary Docker images
- Create and start the MariaDB container
- Build and start the WordPress container
- Start phpMyAdmin

### 3. Access Your Site

- **WordPress**: http://localhost:8080
- **phpMyAdmin**: http://localhost:8081

### 4. Complete WordPress Installation

1. Open http://localhost:8080 in your browser
2. Follow the WordPress installation wizard
3. Create your admin account

## Container Management

### View Logs

```bash
# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f wordpress
docker-compose logs -f db
```

### Stop Containers

```bash
docker-compose stop
```

### Start Containers

```bash
docker-compose start
```

### Restart Containers

```bash
docker-compose restart
```

### Stop and Remove Containers

```bash
docker-compose down
```

### Remove Everything (including database)

```bash
docker-compose down -v
```

## Database Access

### Via phpMyAdmin

Open http://localhost:8081 and login with:
- **Server**: db
- **Username**: root
- **Password**: (value from DB_ROOT_PASSWORD in .env, default: rootpassword)

### Via MySQL Client

```bash
docker exec -it wp-mariadb mysql -u wpuser -p
# Enter password: wppassword (or your DB_PASSWORD from .env)
```

### Backup Database

```bash
docker exec wp-mariadb mysqldump -u wpuser -pwppassword wordpress > backup.sql
```

### Restore Database

```bash
docker exec -i wp-mariadb mysql -u wpuser -pwppassword wordpress < backup.sql
```

## Development

### WordPress Content

The `wp-content` directory is mounted as a volume, so any changes you make to themes and plugins will persist.

### File Permissions

If you encounter permission issues:

```bash
docker exec -it wp-app chown -R www-data:www-data /var/www/html
```

### PHP Configuration

Edit `uploads.ini` to change PHP upload limits, memory limits, etc. Then restart:

```bash
docker-compose restart wordpress
```

## Troubleshooting

### WordPress can't connect to database

1. Check if database is healthy:
   ```bash
   docker-compose ps
   ```

2. Check database logs:
   ```bash
   docker-compose logs db
   ```

3. Restart the database:
   ```bash
   docker-compose restart db
   ```

### Port already in use

If port 8080 or 3306 is already in use, edit `docker-compose.yml` and change the port mapping:

```yaml
ports:
  - "8090:8080"  # Change 8080 to 8090 for WordPress
  - "3307:3306"  # Change 3306 to 3307 for MariaDB
```

### Reset WordPress Installation

```bash
# This will delete the database and start fresh
docker-compose down -v
docker-compose up -d
```

## Production Deployment

This setup is for local development only. For production deployment to DigitalOcean App Platform, use the `app-spec-php.yaml` configuration.

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| DB_ROOT_PASSWORD | rootpassword | MariaDB root password |
| DB_NAME | wordpress | WordPress database name |
| DB_USER | wpuser | WordPress database user |
| DB_PASSWORD | wppassword | WordPress database password |
| TABLE_PREFIX | wp_ | WordPress table prefix |
| WP_DEBUG | true | Enable WordPress debug mode |
| WP_DEBUG_LOG | true | Log errors to file |
| WP_DEBUG_DISPLAY | false | Display errors on screen |
| SITE_URL | http://localhost:8080 | WordPress site URL |
