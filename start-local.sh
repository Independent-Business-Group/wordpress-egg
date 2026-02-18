#!/bin/bash
# Quick start script for local WordPress development

set -e

echo "=========================================="
echo "WordPress Docker Local Development Setup"
echo "=========================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo "→ Creating .env file from .env.example..."
    cp .env.example .env
    echo "✓ .env file created"
else
    echo "✓ .env file already exists"
fi

# Start the containers
echo ""
echo "→ Starting Docker containers..."
docker-compose up -d

# Wait for services to be healthy
echo ""
echo "→ Waiting for database to be ready..."
sleep 5

# Check container status
echo ""
echo "=========================================="
echo "Container Status:"
echo "=========================================="
docker-compose ps

echo ""
echo "=========================================="
echo "✓ WordPress Development Environment Ready!"
echo "=========================================="
echo ""
echo "📝 Access your services:"
echo "   WordPress:   http://localhost:8080"
echo "   phpMyAdmin:  http://localhost:8081"
echo ""
echo "🔐 Database Credentials:"
echo "   Host:        db (or localhost:3306 from host)"
echo "   Database:    wordpress"
echo "   Username:    wpuser"
echo "   Password:    wppassword"
echo ""
echo "📚 View logs:         docker-compose logs -f"
echo "⏹️  Stop containers:   docker-compose stop"
echo "🔄 Restart:           docker-compose restart"
echo "🗑️  Remove all:        docker-compose down -v"
echo ""
