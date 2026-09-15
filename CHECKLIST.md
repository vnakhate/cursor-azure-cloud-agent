# Test checklist — Cursor Firecracker → Azure (no JWT gateway)

Goal: one Cloud Agent reaches a private Azure origin via Cloudflare Tunnel + Access, and gets an Entra token bound to `team_id`.

Nothing runs on a developer Mac. Targets: **Cursor Cloud Agent VM** + **Azure connector VM**.

## A. Cloudflare + Azure connector (once)

- [ ] A1. Create Cloudflared tunnel; store token in Key Vault (`cloudflared-tunnel-token`)
- [ ] A2. Hostname e.g. `azure-internal.example.com` → private origin only
- [ ] A3. Access app + Service Token (for Cursor Runtime Secrets)
- [ ] A4. Private Azure VM + MI read on that secret; NSG deny Internet inbound
- [ ] A5. Install connector (`azure/cloudflared-connector/`); tunnel Healthy

**Gate A**
```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
  -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
  "https://azure-internal.example.com/health"
```

## B. Entra (once)

- [ ] B1. Federated credential: issuer `https://api.cursor.com`, subject `team_id:<TEAM_ID>`, audience `api://AzureADTokenExchange`
- [ ] B2. Least-privilege roles on target Azure resources
- [ ] B3. Record `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `CURSOR_TEAM_ID`

See `azure/entra-federated-credential.example.json`.

## C. Cursor Cloud environment (once)

- [ ] C1. This repo’s `.cursor/` is what the Cloud Agent environment uses
- [ ] C2. Secrets: `CURSOR_TEAM_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CF_TUNNEL_HOST`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET` (last two Runtime)
- [ ] C3. Lock Network Access → Allowlist only → tunnel host(s) + `login.microsoftonline.com`
- [ ] C4. Rebuild until Build is green

## D. Run tests on the Cloud Agent

```bash
source ~/.cursor-azure/env

# 1 tunnel + Access
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
  -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
  "https://${AZURE_CF_TUNNEL_HOST}/health"

# 2 Entra token
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $AZURE_ACCESS_TOKEN" \
  "https://management.azure.com/subscriptions?api-version=2020-01-01"

# 3 egress lock
curl -sS -m 10 https://example.com/ || echo blocked_ok

# 4 Access required
curl -sS -o /dev/null -w '%{http_code}\n' \
  "https://${AZURE_CF_TUNNEL_HOST}/health"
```

## Pass criteria

| Check | Pass |
| --- | --- |
| Tunnel + Access | 200 |
| Tunnel without Access | 302/403 |
| Entra | not 401 |
| Start script | refuses wrong `team_id` sub |
| Allowlist | random host blocked |
