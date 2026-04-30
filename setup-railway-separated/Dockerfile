FROM thspacecode/erpnext-docker:version-16-latest

USER root

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
    nginx \
    ###############################################
    # clean-up
    ###############################################
    && apt-get autoremove --purge -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# copy template
COPY ./template/temp_nginx.conf /home/frappe/temp_nginx.conf
COPY ./template/temp_supervisor.conf /home/frappe/temp_supervisor.conf

# copy script
COPY --chown=frappe --chmod=0755 ./script/railway-setup.sh /home/frappe/frappe-bench/railway-setup.sh
COPY --chown=frappe --chmod=0755 ./script/railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY --chown=frappe --chmod=0755 ./script/railway-cmd.sh /usr/local/bin/railway-cmd.sh

USER root

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["/usr/local/bin/railway-cmd.sh"]

EXPOSE 80
