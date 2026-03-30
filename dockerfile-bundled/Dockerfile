###############################################
# Base Image
###############################################

FROM frappe/build:version-16

###############################################
# Adding Dependencies
###############################################

RUN apt-get update \
    && apt-get install -y -q \
    # [fix] "debconf: delaying package configuration, since apt-utils is not installed"
    apt-utils \
    # [fix] "debconf: unable to initialize frontend: Dialog"
    # https://github.com/moby/moby/issues/27988
    && echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections \
    ###############################################
    # add sudo
    ###############################################
    && apt-get install -y -q sudo \
    && echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    ###############################################
    # add supervisor
    ###############################################
    && apt-get install -y -q \
    supervisor \
    ###############################################
    # clean-up
    ###############################################
    && apt-get autoremove --purge -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

###############################################
# Init Bench (run as frappe user — bench creates files in /home/frappe)
# (copied from builder section of production image)
# https://github.com/frappe/frappe_docker/blob/d1289a860493df9726938535f5e26088e4f83496/images/production/Containerfile#L115-L126
###############################################

ARG FRAPPE_REPO=https://github.com/frappe/frappe
ARG FRAPPE_BRANCH=version-16
ARG ERPNEXT_REPO=https://github.com/frappe/erpnext
ARG ERPNEXT_BRANCH=version-16

USER frappe

RUN bench init \
    --frappe-branch=${APP_BRANCH} \
    --frappe-path=${FRAPPE_REPO} \
    --no-backups \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench && \
    cd /home/frappe/frappe-bench && \
    bench get-app --branch=${APP_BRANCH} --resolve-deps erpnext ${ERPNEXT_REPO} && \
    echo "{}" > sites/common_site_config.json

###############################################
# COPY cmd
###############################################

COPY --chown=frappe:frappe --chmod=0755 ./cmd /home/frappe/frappe-bench/cmd

###############################################
# FINALIZED
###############################################

WORKDIR /home/frappe/frappe-bench
