#!/usr/bin/env bash
set -euo pipefail

# Resolve our magic names to docker internal ip
GW_IP=$(getent ahostsv4 host.docker.internal | grep RAW | awk '{ print $1 }')
echo "GW_IP=$GW_IP"
grep -v -F -e "localmaeher"  -- /etc/hosts >/etc/hosts.new && cat /etc/hosts.new >/etc/hosts
echo "$GW_IP kc.localmaeher.dev.pvarki.fi" >>/etc/hosts
echo "*** BEGIN /etc/hosts ***"
cat /etc/hosts
echo "*** END /etc/hosts ***"

if [[ -d "/ca_public" ]]; then
  echo "Installing custom CAs from /ca_public into OS trust store..."
  mkdir -p /usr/local/share/ca-certificates/

  for pem in /ca_public/*.pem; do
    [[ -f "$pem" ]] || continue
    base=$(basename "$pem" .pem)
    echo "  -> installing $pem as ${base}.crt"
    cp "$pem" "/usr/local/share/ca-certificates/${base}.crt"
  done

  update-ca-certificates --fresh

  echo "CA store updated."
else
  echo "WARNING: /ca_public directory not found."
fi

export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

DATA_DIR="/data"
CERT_DIR="$DATA_DIR/certs"
CONFIG_TEMPLATE="/opt/synapse/templates/homeserver.yaml"
CONFIG_FILE="$DATA_DIR/homeserver.yaml"

/opt/synapse/scripts/init_certs.sh

OIDC_FILE="/config/registration.json"
echo "Waiting for $OIDC_FILE to be generated..."
until [[ -f "$OIDC_FILE" ]]; do
  sleep 2
done

export CLIENT_ID=$(jq -r '.client_id' /config/registration.json)
export CLIENT_SECRET=$(jq -r '.client_secret' /config/registration.json)

if [ "${NGINX_HTTPS_PORT}" == "443" ]; then
  export SYNAPSE_PUBLIC_BASEURL="https://synapse.${SERVER_DOMAIN}"
else
  export SYNAPSE_PUBLIC_BASEURL="https://synapse.${SERVER_DOMAIN}:${NGINX_HTTPS_PORT}"
fi

export DEPLOYMENT_NAME="${SERVER_DOMAIN%%.*}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Creating homeserver.yaml..."

  # Compute the federation config block injected as ${SYNAPSE_FEDERATION_CONFIG}.
  # SYNAPSE_FEDERATION controls the mode:
  #   *  (default) — open federation with any server
  #   off / false / no — fully disabled
  #   domain1.tld,domain2.tld — allowlist specific servers only
  case "${SYNAPSE_FEDERATION:-*}" in
    off|false|no)
      echo "Federation: disabled"
      export SYNAPSE_FEDERATION_CONFIG="# Federation disabled — no server-to-server traffic allowed.
federation_domain_whitelist: []"
      ;;
    "*"|"")
      echo "Federation: open (all servers)"
      export SYNAPSE_FEDERATION_CONFIG="# Federation open — this server can communicate with any Matrix server."
      ;;
    *)
      echo "Federation: allowlist — ${SYNAPSE_FEDERATION}"
      DOMAIN_LINES=$(echo "${SYNAPSE_FEDERATION}" | tr ',' '\n' | sed 's/^[[:space:]]*/  - /' | sed 's/[[:space:]]*$//')
      export SYNAPSE_FEDERATION_CONFIG="# Federation restricted to listed servers only.
federation_domain_whitelist:
${DOMAIN_LINES}"
      ;;
  esac

  mkdir -p "$DATA_DIR"
  envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_FILE"
  chown -R 991:991 "$DATA_DIR"
  chmod 777 "$DATA_DIR"
  chmod 666 "$CONFIG_FILE"
fi

wait-for-it.sh postgres:5432 --timeout=30 -- echo "Postgres is up!"

echo "Starting Synapse..."
python -m synapse.app.homeserver --config-path "$CONFIG_FILE"
