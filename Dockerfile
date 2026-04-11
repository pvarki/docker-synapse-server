FROM python:3.11-slim AS osdeps
# Install OS-level packages
# FIXME: Are vim, jq and netcat *really* needed for production ? Add a separate devel/debug target
RUN apt-get update && apt-get install -y \
      ca-certificates \
      curl \
      gettext \
      openssl \
      tini \
      vim \
      jq \
      netcat-openbsd \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -o /usr/bin/wait-for-it.sh \
    && chmod a+x /usr/bin/wait-for-it.sh \
    && true

# Install synapse and scripts
FROM osdeps AS install
# Install python packages
COPY ./requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt
WORKDIR /opt/synapse
COPY scripts ./scripts
COPY templates ./templates
RUN chmod +x /opt/synapse/scripts/*.sh

FROM install AS run
WORKDIR /opt/synapse
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/synapse/scripts/synapse-entrypoint.sh"]
