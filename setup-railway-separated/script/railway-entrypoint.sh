#!/bin/sh
set -e

echo "-> Set ownership of sites folder"
chown frappe:frappe /home/frappe/frappe-bench/sites

echo "-> Set permission of site config"
chown frappe:frappe /home/frappe/frappe-bench/sites/common_site_config.json

echo "-> Linking assets"
su frappe -c "ln -sf /home/frappe/frappe-bench/built_sites/assets /home/frappe/frappe-bench/sites/assets"
su frappe -c "ln -sf /home/frappe/frappe-bench/built_sites/apps.json /home/frappe/frappe-bench/sites/apps.json"
su frappe -c "ln -sf /home/frappe/frappe-bench/built_sites/apps.txt /home/frappe/frappe-bench/sites/apps.txt"

exec "$@"
