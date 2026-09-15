#!/usr/bin/env bash
set -euo pipefail
if [[ "$(id -u)" -ne 0 ]]; then echo "sudo bash $0" >&2; exit 1; fi
: "${KEYVAULT_NAME:?set KEYVAULT_NAME}"
SECRET_NAME="${SECRET_NAME:-cloudflared-tunnel-token}"
AE=$(curl -fsS -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https://vault.azure.net" | jq -r .access_token)
TUNNEL_TOKEN=$(curl -fsS -H "Authorization: Bearer $AE" "https://${KEYVAULT_NAME}.vault.azure.net/secrets/${SECRET_NAME}?api-version=7.4" | jq -r .value)
[[ -n "$TUNNEL_TOKEN" && "$TUNNEL_TOKEN" != null ]] || { echo empty secret >&2; exit 1; }
install -d -m 0750 -o root -g cloudflared /etc/cloudflared
umask 077
printf 'TUNNEL_TOKEN=%s\n' "$TUNNEL_TOKEN" > /etc/cloudflared/env
chown root:cloudflared /etc/cloudflared/env
chmod 0640 /etc/cloudflared/env
systemctl restart cloudflared.service
echo "[kv] restarted cloudflared"
