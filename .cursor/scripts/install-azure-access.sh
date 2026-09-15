#!/usr/bin/env bash
# Cloud Agent Build (Firecracker disk prep). Idempotent. Do not mint OIDC here.
set -euo pipefail
echo "[azure-access] installing tools for Cursor Firecracker → Azure path"
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends curl ca-certificates jq unzip
fi
if ! command -v cloudflared >/dev/null 2>&1; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) CF_ARCH=amd64 ;;
    aarch64|arm64) CF_ARCH=arm64 ;;
    *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
  esac
  TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o "$TMP/cloudflared"
  sudo install -m 0755 "$TMP/cloudflared" /usr/local/bin/cloudflared
  rm -rf "$TMP"
fi
if ! command -v az >/dev/null 2>&1; then
  curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi
cloudflared --version
az version --output table || true
echo "[azure-access] install complete"
