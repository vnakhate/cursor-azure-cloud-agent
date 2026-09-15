# cursor-azure-cloud-agent

Secure path from **Cursor managed Cloud Agents** (Firecracker on Cursor AWS) into a **private Azure** network — **without** a JWT gateway and **without** anything on a local Mac.

## Architecture

1. Agent VM mints Cursor OIDC with `sub_claim=team_id` → Entra federated credential
2. Agent calls Cloudflare Access–protected hostname with service token headers
3. `cloudflared` connector in Azure (outbound-only) reaches private origins
4. Cursor **Allowlist only** (locked) shapes egress

Do **not** use shared Cursor egress IPs as org isolation.

## Layout

| Path | Where it runs |
| --- | --- |
| `.cursor/` | Cursor Cloud Agent Build / boot |
| `azure/cloudflared-connector/` | Azure connector VM only |
| `CHECKLIST.md` | Your E2E test runbook |
| `docs/` | Visual explainer |

## Quick start

1. Follow `CHECKLIST.md` sections A–C
2. Point a Cloud Agent environment at this repo
3. Run section D tests on the agent

## Explicitly out of scope

- JWT-validating gateway (optional later for non-Entra HTTP)
- Classic Cisco AnyConnect on the Firecracker VM
- Files or installs on a developer laptop
