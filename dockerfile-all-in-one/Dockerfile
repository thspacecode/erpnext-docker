###############################################
# All-in-one Docker image
# -
# Could be used for
# * Quick trial setup
# * Railway setup (Sleep-able)
# * Dokploy preview deployment
###############################################

ARG BASE_IMAGE=thspacecode/erpnext-docker:16-F12.2_E11.0
FROM ${BASE_IMAGE}

###############################################
# Add services missing from the base
# -
# These are service that usually used external container
# * Supervisor
# * Nginx
# * Redis
# * MariaDB
###############################################

USER root

RUN apt-get update \
    # [Hotfix]: https://github.com/moby/moby/issues/27988
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    nginx \
    redis-server \
    supervisor \
    gettext-base \
    && curl -LsSO https://downloads.mariadb.com/MariaDB/mariadb_repo_setup \
    && bash mariadb_repo_setup --mariadb-server-version="mariadb-11.8" \
    && rm mariadb_repo_setup \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    mariadb-server \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

###############################################
# COPY FILES
###############################################

COPY --chown=frappe:frappe --chmod=0755 ./conf/setup.sh /usr/local/bin/setup.sh
COPY --chown=frappe:frappe ./conf/supervisord.conf /etc/supervisor/conf.d/frappe.conf
COPY --chown=frappe:frappe ./conf/nginx.conf /etc/nginx/frappe.conf.template
