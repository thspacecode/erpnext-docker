#!/bin/sh
set -e

if [ -z "$RFP_DOMAIN_NAME" ]; then
    echo "ERROR: RFP_DOMAIN_NAME is not set" >&2
    exit 1
fi

SITE_CONFIG="/home/frappe/frappe-bench/sites/${RFP_DOMAIN_NAME}/site_config.json"

if [ ! -f "$SITE_CONFIG" ]; then
    echo "-> Site config not found, running setup"
    /home/frappe/frappe-bench/railway-setup.sh
fi

echo "-> Clearing cache"
su frappe -c "bench execute frappe.cache_manager.clear_global_cache"

echo "-> Bursting env into config"
envsubst '$RFP_DOMAIN_NAME' < /home/frappe/temp_nginx.conf > /etc/nginx/conf.d/default.conf
envsubst '$PATH,$HOME' < /home/frappe/temp_supervisor.conf > /home/frappe/supervisor.conf

echo "-> Starting nginx"
nginx

echo "-> Starting supervisor"
/usr/bin/supervisord -c /home/frappe/supervisor.conf
