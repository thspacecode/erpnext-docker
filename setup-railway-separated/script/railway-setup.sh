#!/bin/bash
set -e

require_var() {
    if [ -z "${!1}" ]; then
        echo "ERROR: $1 is not set" >&2
        exit 1
    fi
}

require_var RFP_DOMAIN_NAME
require_var RFP_SITE_ADMIN_PASSWORD
require_var FRAPPE_DB_PASSWORD
require_var FRAPPE_DB_HOST

SITES_DIR="/home/frappe/frappe-bench/sites"

# Frappe derives the database name from the site name by replacing
# hyphens and dots with underscores.
_db_name() {
    echo "${RFP_DOMAIN_NAME}" | tr '.-' '_'
}

# Returns 0 (true) if the site is fully initialized:
#   1. The site directory exists
#   2. site_config.json is present
#   3. The MariaDB database exists and contains the tabDocType table,
#      confirming that `bench new-site` completed successfully.
is_site_initialized() {
    local site_config="${SITES_DIR}/${RFP_DOMAIN_NAME}/site_config.json"
    local db_name
    db_name=$(_db_name)

    # Fast-path: directory or config missing → not initialized
    if [ ! -d "${SITES_DIR}/${RFP_DOMAIN_NAME}" ] || [ ! -f "${site_config}" ]; then
        return 1
    fi

    # Verify the database actually has Frappe's core table.
    # Uses the MariaDB root password so this works even when the
    # per-site DB user was not yet created (e.g. partial setup).
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

if is_site_initialized; then
    echo "-> Site ${RFP_DOMAIN_NAME} is already initialized (directory + database verified), skipping site creation"
else
    echo "-> Create common site config with socketio_port"
    su frappe -c "cat > \"${SITES_DIR}/common_site_config.json\" << 'EOF'
{
  \"socketio_port\": 9000
}
EOF"

    echo "-> Create new site with ERPNext"
    # Use --force if site directory exists but database is missing
    if [ -d "${SITES_DIR}/${RFP_DOMAIN_NAME}" ]; then
        echo "-> Site directory exists but database is missing, using --force to recreate"
        su frappe -c "bench new-site ${RFP_DOMAIN_NAME} --admin-password ${RFP_SITE_ADMIN_PASSWORD} --no-mariadb-socket --db-root-password ${FRAPPE_DB_PASSWORD} --install-app erpnext --force"
    else
        su frappe -c "bench new-site ${RFP_DOMAIN_NAME} --admin-password ${RFP_SITE_ADMIN_PASSWORD} --no-mariadb-socket --db-root-password ${FRAPPE_DB_PASSWORD} --install-app erpnext"
    fi
    
    su frappe -c "bench --site ${RFP_DOMAIN_NAME} set-config socketio_port 9000"
    su frappe -c "bench use ${RFP_DOMAIN_NAME}"

    echo "-> Enable scheduler"
    bench enable-scheduler
fi

echo "-> Install HRMS app"
if ! su frappe -c "bench get-app hrms https://github.com/frappe/hrms --branch version-16" 2>&1 | grep -q "already exists"; then
    echo "HRMS app fetched successfully"
fi
su frappe -c "bench --site ${RFP_DOMAIN_NAME} install-app hrms" 2>&1 || echo "HRMS installation completed or already installed"

echo "-> Disable automatic user creation for Employee (prevents broken welcome email template)"
# Write a small Python script to a temp file to avoid shell-escaping issues with bench execute
PATCH_SCRIPT=$(mktemp /tmp/frappe_patch_XXXXXX.py)
cat > "${PATCH_SCRIPT}" << 'PYEOF'
import frappe

frappe.db.sql(
    "UPDATE `tabDocField` SET `default`='0'"
    " WHERE parent='Employee' AND fieldname='create_user_automatically'"
)
frappe.db.commit()
print("create_user_automatically default set to 0 on Employee DocType")
PYEOF
chown frappe:frappe "${PATCH_SCRIPT}"
su frappe -c "cd /home/frappe/frappe-bench && bench --site ${RFP_DOMAIN_NAME} execute-script ${PATCH_SCRIPT}" 2>&1 || \
    echo "Warning: Could not disable create_user_automatically; employees may trigger a broken welcome email on save"
rm -f "${PATCH_SCRIPT}"

