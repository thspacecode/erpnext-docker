#!/usr/bin/env bash

###############################################
# Runtime entrypoint
# -
# The site is already created and ERPNext already
# installed at build time (see init.sh), so this
# just wires up nginx and hands off to supervisord
# which starts MariaDB, Redis, nginx and all the
# frappe processes.
###############################################

set -euo pipefail

SITE_NAME=${SITE_NAME:-default.site}

log() { echo "$(date '+%H:%M:%S') -> $*"; }

###############################################
# Ensure runtime directories exist
# -
# /run is often a fresh tmpfs on container start,
# so recreate the MariaDB socket directory.
###############################################

log "Preparing runtime directories..."
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

###############################################
# Inject variables into nginx
###############################################

log "Injecting variables into nginx..."
export SITE_NAME
envsubst '${SITE_NAME}' < /etc/nginx/frappe.conf.template \
    > /etc/nginx/sites-enabled/default

###############################################
# Starting server
###############################################

log "Handing off to supervisord (production mode)..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/frappe.conf
