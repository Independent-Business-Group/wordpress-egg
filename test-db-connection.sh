#!/bin/bash
# Simple test script to verify database connection

echo "=========================================="
echo "Testing DO Database Connection"
echo "=========================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo ""
echo "Testing connection..."

mysql --ssl \
    -h "${DB_HOST}" \
    -P "${DB_PORT}" \
    -u "${DB_USER}" \
    -p"${DB_PASSWORD}" \
    "${DB_NAME}" \
    -e "SELECT 'Connection successful!' as status; SHOW TABLES LIMIT 10;"

echo ""
echo "✓ Connection test complete!"
