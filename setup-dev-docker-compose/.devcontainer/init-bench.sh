#!/bin/bash
set -e

SITE_NAME=${1:-"site1.localhost"}

echo ">>> Initializing frappe-bench..."
bench init --no-backups --skip-redis-config-generation --verbose . --ignore-exist

echo ">>> Creating new site: $SITE_NAME ..."
bench new-site "$SITE_NAME" \
  --admin-password="12345" \
  --mariadb-user-host-login-scope="%" \
  --db-root-username="root" \
  --db-root-password="12345" \
  --set-default

echo ">>> Enabling developer mode..."
bench set-config developer_mode 1

echo ">>> Installation complete!"
echo ">"
echo "> You can now start the development server with: 'bench start'"
echo ">"
echo "> To access the site, open your browser and navigate to: http://localhost:8000"
echo ">"
echo "> Default credentials:"
echo "> Username: Administrator"
echo "> Password: 12345"
echo ">"
echo "> Happy coding! 🚀"