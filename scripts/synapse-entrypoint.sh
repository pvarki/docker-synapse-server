#!/usr/bin/env bash
set -euo pipefail

# Resolve our magic names to docker internal ip
GW_IP=$(getent ahostsv4 host.docker.internal | grep RAW | awk '{ print $1 }')
echo "GW_IP=$GW_IP"
KC_IP=$(getent ahostsv4 keycloak | awk '{ print $1; exit }')
echo "KC_IP=${KC_IP:-<unresolved, using GW_IP>}"
grep -v -F -e "localmaeher"  -- /etc/hosts >/etc/hosts.new && cat /etc/hosts.new >/etc/hosts
echo "${KC_IP:-$GW_IP} kc.localmaeher.dev.pvarki.fi" >>/etc/hosts
echo "*** BEGIN /etc/hosts ***"
cat /etc/hosts
echo "*** END /etc/hosts ***"

DATA_DIR="/data"
CERT_DIR="$DATA_DIR/certs"
CONFIG_TEMPLATE="/opt/synapse/templates/homeserver.yaml"
CONFIG_FILE="$DATA_DIR/homeserver.yaml"

/opt/synapse/scripts/init_certs.sh

: "${SYNAPSE_PUBLIC_BASEURL:?SYNAPSE_PUBLIC_BASEURL must be set}"
: "${DEPLOYMENT_NAME:?DEPLOYMENT_NAME must be set}"
: "${MAS_ENDPOINT:?MAS_ENDPOINT must be set}"

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
  chmod 600 "$CONFIG_FILE"
fi

wait-for-it.sh "${POSTGRES_HOST}:5432" --timeout=30 -- echo "Postgres is up!"

echo "Starting Synapse..."
python -m synapse.app.homeserver --config-path "$CONFIG_FILE"
