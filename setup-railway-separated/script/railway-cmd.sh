#!/bin/bash
set -e

if [ -z "$RFP_DOMAIN_NAME" ]; then
    echo "ERROR: RFP_DOMAIN_NAME is not set" >&2
    exit 1
fi

if [ -z "$FRAPPE_DB_HOST" ]; then
    echo "ERROR: FRAPPE_DB_HOST is not set" >&2
    exit 1
fi

SITES_DIR="/home/frappe/frappe-bench/sites"

# Frappe derives the database name from the site name by replacing
# hyphens and dots with underscores.
_db_name() {
    echo "${RFP_DOMAIN_NAME}" | tr '.-' '_'
}

# Returns 0 (true) if the site directory, site_config.json, AND the
# MariaDB database (tabDocType table) are all present — meaning
# `bench new-site` completed successfully on a previous run.
is_site_initialized() {
    local site_config="${SITES_DIR}/${RFP_DOMAIN_NAME}/site_config.json"
    local db_name
    db_name=$(_db_name)

    if [ ! -d "${SITES_DIR}/${RFP_DOMAIN_NAME}" ] || [ ! -f "${site_config}" ]; then
        return 1
    fi

    if mysql -h "${FRAPPE_DB_HOST}" -P "${FRAPPE_DB_PORT:-3306}" \
             -u root -p"${FRAPPE_DB_PASSWORD}" \
             --connect-timeout=10 --silent --skip-column-names \
             -e "SELECT 1 FROM information_schema.tables
                 WHERE table_schema = '${db_name}'
                   AND table_name   = 'tabDocType'
                 LIMIT 1;" 2>/dev/null | grep -q "1"; then
        return 0
    fi

    echo "-> Site directory exists but database '${db_name}' is not initialized" >&2
    return 1
}

if ! is_site_initialized; then
    echo "-> Site not fully initialized, running setup"
    /home/frappe/frappe-bench/railway-setup.sh
else
    echo "-> Site already initialized, ensuring HRMS is installed"
    su frappe -c "bench get-app hrms https://github.com/frappe/hrms --branch version-16" 2>&1 || echo "HRMS app already exists or fetch failed"
    su frappe -c "bench --site ${RFP_DOMAIN_NAME} install-app hrms" 2>&1 || echo "HRMS installation completed or already installed"
fi

echo "-> Clearing cache"
su frappe -c "cd /home/frappe/frappe-bench && bench --site ${RFP_DOMAIN_NAME} execute frappe.cache_manager.clear_global_cache"

echo "-> Resolving paths"
BENCH_PATH=$(su frappe -c "which bench")
NODE_PATH=$(su frappe -c "which node")
export BENCH_PATH NODE_PATH

echo "-> Bursting env into config"
envsubst '$RFP_DOMAIN_NAME' < /home/frappe/temp_nginx.conf > /etc/nginx/conf.d/default.conf
envsubst '$BENCH_PATH,$NODE_PATH' < /home/frappe/temp_supervisor.conf > /home/frappe/supervisor.conf

echo "-> Starting nginx"
nginx

echo "-> Starting supervisor"
/usr/bin/supervisord -c /home/frappe/supervisor.conf

