#!/usr/bin/env bash
set -euo pipefail
if [[ "$(id -u)" -ne 0 ]]; then echo "sudo -E bash $0" >&2; exit 1; fi
: "${TUNNEL_TOKEN:?export TUNNEL_TOKEN or use keyvault-inject.sh}"
ARCH="$(uname -m)"; case "$ARCH" in x86_64|amd64) CF_ARCH=amd64;; aarch64|arm64) CF_ARCH=arm64;; *) exit 1;; esac
id cloudflared >/dev/null 2>&1 || useradd --system --home /var/lib/cloudflared --shell /usr/sbin/nologin cloudflared
install -d -m 0755 -o cloudflared -g cloudflared /var/lib/cloudflared /var/log/cloudflared
install -d -m 0750 -o root -g cloudflared /etc/cloudflared
TMP="$(mktemp -d)"
curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o "$TMP/cloudflared"
install -m 0755 "$TMP/cloudflared" /usr/local/bin/cloudflared
rm -rf "$TMP"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
install -m 0644 "$SCRIPT_DIR/cloudflared.service" /etc/systemd/system/cloudflared.service
umask 077
printf 'TUNNEL_TOKEN=%s\n' "$TUNNEL_TOKEN" > /etc/cloudflared/env
chown root:cloudflared /etc/cloudflared/env
chmod 0640 /etc/cloudflared/env
systemctl daemon-reload
systemctl enable --now cloudflared.service
systemctl --no-pager --full status cloudflared.service || true
