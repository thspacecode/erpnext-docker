###############################################
# More info on base image visit:
# https://spacecode.co.th/knowledge-base/p/erpnext-docker
###############################################

FROM frappe/build:version-16

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

COPY --chown=frappe:frappe --chmod=0755 ./cmd /home/frappe/frappe-bench/cmd

###############################################
# FINALIZED
###############################################

WORKDIR /home/frappe/frappe-bench
USER frappe
