# syntax=docker/dockerfile:1
###############################################
# ERPNext image - single multi-stage source
# -
# Three chained stages, each published as its own tag:
#   base        -> version-16-latest
#   all-in-one  -> ALL-version-16-latest
#   pre-install -> PRE-version-16-latest
#
# Build a specific tag with --target, e.g.:
#   docker buildx build --target base        -t repo:version-16-latest      .
#   docker buildx build --target all-in-one  -t repo:ALL-version-16-latest  .
#   docker buildx build --target pre-install -t repo:PRE-version-16-latest  .
#
# More info on the base image:
# https://spacecode.co.th/knowledge-base/p/erpnext-docker
###############################################


###############################################
# Stage 1: base
# -
# Bench + ERPNext bundled on top of frappe/build.
###############################################
FROM frappe/build:version-16 AS base

###############################################
# Adding Dependencies
###############################################

USER root

RUN apt-get update \
    # [Hotfix]: https://github.com/moby/moby/issues/27988
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -q \
    # Adding sudo
    sudo \
    && echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    # Cleanup install
    && apt-get autoremove --purge -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

###############################################
# Init Bench
# -
# (copied from builder section of production image)
# https://github.com/frappe/frappe_docker/blob/d1289a860493df9726938535f5e26088e4f83496/images/production/Containerfile#L115-L126
###############################################

USER frappe

ARG FRAPPE_REPO=https://github.com/frappe/frappe
ARG FRAPPE_BRANCH=version-16
ARG ERPNEXT_REPO=https://github.com/frappe/erpnext
ARG ERPNEXT_BRANCH=version-16

RUN bench init \
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_REPO} \
    --no-backups \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench && \
    cd /home/frappe/frappe-bench && \
    bench get-app --branch=${ERPNEXT_BRANCH} --resolve-deps erpnext ${ERPNEXT_REPO} && \
    echo "{}" > sites/common_site_config.json

###############################################
# COPY FILES
###############################################

COPY --chown=frappe:frappe --chmod=0755 ./base/cmd /home/frappe/frappe-bench/cmd

###############################################
# FINALIZED
###############################################

WORKDIR /home/frappe/frappe-bench
USER frappe


###############################################
# Stage 2: all-in-one
# -
# Could be used for
# * Quick trial setup
# * Railway setup (Sleep-able)
# * Dokploy preview deployment
#
# Add services missing from the base. These are
# services that usually run in external containers:
# * Supervisor
# * Nginx
# * Redis
# * MariaDB
###############################################
FROM base AS all-in-one

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

COPY --chown=frappe:frappe --chmod=0755 ./all-in-one/conf/setup.sh /usr/local/bin/setup.sh
COPY --chown=frappe:frappe ./all-in-one/conf/supervisord.conf /etc/supervisor/conf.d/frappe.conf
COPY --chown=frappe:frappe ./all-in-one/conf/nginx.conf /etc/nginx/frappe.conf.template


###############################################
# Stage 3: pre-install
# -
# Same batteries as the all-in-one image, but the
# site is created and ERPNext is installed at BUILD
# time (see pre-install/conf/init.sh) instead of on
# first boot.
#
# The container therefore starts straight into a
# ready-to-use site - nginx, supervisor, MariaDB,
# Redis and all the frappe processes - with no
# lengthy first-run setup.
###############################################
FROM all-in-one AS pre-install

USER root

###############################################
# Build-time site configuration
# -
# Override with --build-arg to change the baked-in
# site name / credentials.
###############################################

ARG SITE_NAME=default.site
ARG ADMIN_PASSWORD=admin
ARG DB_ROOT_PASSWORD=admin

# Persist the site name so the runtime entrypoint
# can inject it into the nginx config.
ENV SITE_NAME=${SITE_NAME}

###############################################
# COPY FILES
###############################################

COPY --chown=frappe:frappe --chmod=0755 ./pre-install/conf/init.sh /usr/local/bin/init.sh
COPY --chown=frappe:frappe --chmod=0755 ./pre-install/conf/start.sh /usr/local/bin/start.sh

###############################################
# Pre-install: create the site + install ERPNext
# at build time and bake it into the image.
###############################################

RUN SITE_NAME="${SITE_NAME}" \
    ADMIN_PASSWORD="${ADMIN_PASSWORD}" \
    DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD}" \
    /usr/local/bin/init.sh

EXPOSE 80

CMD ["/usr/local/bin/start.sh"]
