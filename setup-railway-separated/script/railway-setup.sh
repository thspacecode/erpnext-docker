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

SITES_DIR="/home/frappe/frappe-bench/sites"

if [ -d "${SITES_DIR}/${RFP_DOMAIN_NAME}" ]; then
    echo "-> Site ${RFP_DOMAIN_NAME} already exists, skipping setup"
    exit 0
fi

echo "-> Create empty common site config"
su frappe -c "echo '{}' > \"${SITES_DIR}/common_site_config.json\""

echo "-> Create new site with ERPNext"
su frappe -c "bench new-site ${RFP_DOMAIN_NAME} --admin-password ${RFP_SITE_ADMIN_PASSWORD} --no-mariadb-socket --db-root-password ${FRAPPE_DB_PASSWORD} --install-app erpnext"
su frappe -c "bench set-config socketio_port 9000"
su frappe -c "bench get-app hrms https://github.com/frappe/hrms"
su frappe -c "bench install-app hrms --site ${RFP_DOMAIN_NAME}"
su frappe -c "bench use ${RFP_DOMAIN_NAME}"

echo "-> Enable scheduler"
bench enable-scheduler
