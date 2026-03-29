#!/usr/bin/env bash
set -e

if [ ! -d "/home/frappe/frappe-bench/sites/trial.local" ]; then
  echo "-> Create new site with ERPNext"
  bench new-site trial.local --admin-password="12345" --mariadb-user-host-login-scope="%" --db-root-username="root" --db-root-password="12345" --install-app="erpnext" --set-default
else
  echo "-> Site trial.local already exists, skipping creation"
fi

echo "-> Starting Sites"
bench start
