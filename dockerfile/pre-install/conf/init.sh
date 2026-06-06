#!/usr/bin/env bash

###############################################
# Build-time initialization
# -
# Runs ONCE during `docker build` (not at runtime).
# Creates the site and installs ERPNext so the
# resulting image boots straight into a ready site.
#
# Brings up MariaDB and Redis temporarily, does the
# heavy setup, then shuts them down cleanly so the
# committed layer holds a consistent data directory.
###############################################

set -euo pipefail

BENCH_DIR=/home/frappe/frappe-bench
INIT_MARKER=/home/frappe/.bench_initialized
CREDENTIALS_FILE="${BENCH_DIR}/sites/credentials.txt"

SITE_NAME=${SITE_NAME:-default.site}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}

log() { echo "$(date '+%H:%M:%S') -> $*"; }
die() { echo "$(date '+%H:%M:%S') [FATAL] $*" >&2; exit 1; }

###############################################
# Saving credentials
###############################################

printf "SITE_NAME=%s\nDB_ROOT_PASSWORD=%s\nADMIN_PASSWORD=%s\n" \
  "${SITE_NAME}" \
  "${DB_ROOT_PASSWORD}" \
  "${ADMIN_PASSWORD}" \
  > "${CREDENTIALS_FILE}"
chown frappe:frappe "${CREDENTIALS_FILE}"
log "Credentials saved to ${CREDENTIALS_FILE}"

###############################################
# Setting up dependencies
###############################################

log "Initializing MariaDB data directory..."
if [ ! -d /var/lib/mysql/mysql ]; then
  mariadb-install-db \
  --user=mysql \
  --datadir=/var/lib/mysql \
  --skip-test-db \
  >/dev/null \
  || die "mariadb-install-db failed"
fi
mkdir -p /run/mysqld
chown -R mysql:mysql /var/lib/mysql /run/mysqld

log "Starting MariaDB..."
/usr/sbin/mariadbd \
  --user=mysql \
  --skip-name-resolve \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci \
  --skip-innodb-read-only-compressed \
  &

log "Waiting for MariaDB to be ready..."
timeout=60
until [ -S /run/mysqld/mysqld.sock ]; do
  timeout=$((timeout - 1))
  log "Checking MariaDB..."
  [ $timeout -le 0 ] && die "MariaDB did not start in time"
  sleep 1
done
log "MariaDB is ready."

log "Switch root from unix_socket to password auth."
mariadb -u root <<-SQL
  CREATE OR REPLACE USER 'root'@'127.0.0.1'
    IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_ROOT_PASSWORD}');

  GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1'
    WITH GRANT OPTION;

  FLUSH PRIVILEGES;
SQL

log "Starting Redis cache and queue..."
redis-server --port 6379 --bind 127.0.0.1 --daemonize yes \
  --logfile /var/log/redis/cache.log
redis-server --port 6380 --bind 127.0.0.1 --daemonize yes \
  --logfile /var/log/redis/queue.log

###############################################
# App setup
###############################################

log "Configuring Redis endpoints..."
sudo -Hu frappe bash -c "
  cd '${BENCH_DIR}'
  bench set-config -g redis_cache 'redis://127.0.0.1:6379'
  bench set-config -g redis_queue 'redis://127.0.0.1:6380'
  bench set-config -g redis_socketio 'redis://127.0.0.1:6380'
  bench set-config -g socketio_port 9000
"

log "Creating site: ${SITE_NAME}..."
sudo -Hu frappe bash -c "
  cd '${BENCH_DIR}'
  bench new-site \
    --db-root-password '${DB_ROOT_PASSWORD}' \
    --admin-password '${ADMIN_PASSWORD}' \
    '${SITE_NAME}'
"

log "Installing erpnext..."
sudo -Hu frappe bash -c "
  cd '${BENCH_DIR}'
  bench --site '${SITE_NAME}' install-app erpnext
"

log "SETTING DEFAULT SITE"
sudo -Hu frappe bash -c "
  cd '${BENCH_DIR}'
  bench use '${SITE_NAME}'
"

touch "${INIT_MARKER}"
chown frappe:frappe "${INIT_MARKER}"
log "Pre-install complete."

###############################################
# Tear down temporary services
###############################################

log "Stopping temporary MariaDB and Redis processes..."
mariadb-admin -u root -p"${DB_ROOT_PASSWORD}" shutdown 2>/dev/null || true
redis-cli -p 6379 shutdown nosave 2>/dev/null || true
redis-cli -p 6380 shutdown nosave 2>/dev/null || true
sleep 2

log "Build-time initialization finished."
