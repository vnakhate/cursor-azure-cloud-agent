#!/usr/bin/env bash
# Every Cloud Agent boot on Cursor AWS Firecracker.
set -euo pipefail
SOCKET="${CURSOR_AGENT_SOCKET:-/run/cursor/api.sock}"
TEAM_ID="${CURSOR_TEAM_ID:?Set CURSOR_TEAM_ID as an Environment Variable}"
AZURE_TENANT_ID="${AZURE_TENANT_ID:?Set AZURE_TENANT_ID}"
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:?Set AZURE_CLIENT_ID}"
OIDC_AUD="${CURSOR_AZURE_OIDC_AUD:-api://AzureADTokenExchange}"
CF_HOST="${AZURE_CF_TUNNEL_HOST:-}"

echo "[azure-access] waiting for identity socket"
for _ in $(seq 1 30); do
  [[ -S "$SOCKET" ]] && break
  sleep 1
done
if [[ ! -S "$SOCKET" ]]; then
  echo "[azure-access] missing $SOCKET — not a Cursor Cloud Agent VM?" >&2
  exit 1
fi

mint_oidc() {
  curl -fsS --unix-socket "$SOCKET" \
    -H 'Content-Type: application/json' \
    -d "{\"aud\":\"${1}\",\"sub_claim\":\"team_id\"}" \
    http://cursor-agent/v1/tokens/oidc | jq -r .token
}

echo "[azure-access] minting Cursor OIDC with sub_claim=team_id"
CURSOR_JWT="$(mint_oidc "$OIDC_AUD")"
HDR="$(printf '%s' "$CURSOR_JWT" | cut -d. -f2 | tr '_-' '/+')"
PAD=$(( (4 - ${#HDR} % 4) % 4 ))
[[ "$PAD" -gt 0 ]] && HDR="${HDR}$(printf '%*s' "$PAD" '' | tr ' ' '=')"
SUB="$(printf '%s' "$HDR" | base64 -d 2>/dev/null | jq -r .sub || true)"
EXPECTED_SUB="team_id:${TEAM_ID}"
if [[ "$SUB" != "$EXPECTED_SUB" ]]; then
  echo "[azure-access] refusing: JWT sub='$SUB' expected '$EXPECTED_SUB'" >&2
  exit 1
fi

echo "[azure-access] exchanging OIDC for Azure access token"
TOKEN_RESP="$(curl -fsS -X POST \
  "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
  --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=${CURSOR_JWT}" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "scope=${AZURE_TOKEN_SCOPE:-https://management.azure.com/.default}")"
AZURE_ACCESS_TOKEN="$(printf '%s' "$TOKEN_RESP" | jq -r .access_token)"
if [[ -z "$AZURE_ACCESS_TOKEN" || "$AZURE_ACCESS_TOKEN" == null ]]; then
  echo "[azure-access] Entra token exchange failed: $TOKEN_RESP" >&2
  exit 1
fi

mkdir -p "$HOME/.cursor-azure"
umask 077
printf '%s' "$AZURE_ACCESS_TOKEN" > "$HOME/.cursor-azure/access_token"
{
  echo "export AZURE_ACCESS_TOKEN=$(printf '%q' "$AZURE_ACCESS_TOKEN")"
  echo "export CURSOR_AZURE_TEAM_BOUND=1"
} > "$HOME/.cursor-azure/env"

if [[ -n "$CF_HOST" ]]; then
  : "${CF_ACCESS_CLIENT_ID:?Set CF_ACCESS_CLIENT_ID Runtime Secret}"
  : "${CF_ACCESS_CLIENT_SECRET:?Set CF_ACCESS_CLIENT_SECRET Runtime Secret}"
  cat >> "$HOME/.cursor-azure/env" <<ENV
export AZURE_CF_TUNNEL_HOST=$(printf '%q' "$CF_HOST")
export CF_ACCESS_CLIENT_ID=$(printf '%q' "$CF_ACCESS_CLIENT_ID")
export CF_ACCESS_CLIENT_SECRET=$(printf '%q' "$CF_ACCESS_CLIENT_SECRET")
ENV
  echo "[azure-access] Cloudflare Access credentials loaded for $CF_HOST"
fi

if [[ -n "${AZURE_CF_TCP_TARGET:-}" ]]; then
  : "${CF_ACCESS_CLIENT_ID:?}"
  : "${CF_ACCESS_CLIENT_SECRET:?}"
  LOCAL_PORT="${AZURE_CF_TCP_LOCAL_PORT:-15432}"
  nohup cloudflared access tcp \
    --hostname "$AZURE_CF_TCP_TARGET" \
    --url "localhost:${LOCAL_PORT}" \
    --id "$CF_ACCESS_CLIENT_ID" \
    --secret "$CF_ACCESS_CLIENT_SECRET" \
    >/tmp/cloudflared-tcp.log 2>&1 &
  echo "export AZURE_CF_TCP_LOCAL=localhost:${LOCAL_PORT}" >> "$HOME/.cursor-azure/env"
fi

echo "[azure-access] ready — org-bound Azure path for team_id=${TEAM_ID}"
echo "[azure-access] source $HOME/.cursor-azure/env in shells that need Azure"
