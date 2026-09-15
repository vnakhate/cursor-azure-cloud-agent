# Citations — Cursor Firecracker → Azure design

Primary sources for claims in this repo’s architecture, CHECKLIST, and diagrams.
Vendor docs are authoritative; this package is an integration pattern on top of them.

## Cursor

| Claim in our work | Source |
| --- | --- |
| Cloud Agents run as isolated **Firecracker** microVMs on Cursor AWS | [Security overview](https://cursor.com/docs/cloud-agent/security) |
| Agents can mint short-lived **OIDC JWTs**; verifier uses `https://api.cursor.com` / JWKS; authorize on `sub`, `team_id`, `cloud_agent_id` | [OIDC tokens](https://cursor.com/docs/cloud-agent/identity) |
| Mint via local socket (`CURSOR_AGENT_SOCKET` / `/run/cursor/api.sock`); `sub_claim` can project `team_id` into `sub` | [OIDC tokens](https://cursor.com/docs/cloud-agent/identity) |
| OIDC works with **Azure** (and AWS/GCP/Vault) as verifier | [OIDC tokens](https://cursor.com/docs/cloud-agent/identity) · [Cloud Environment Setup](https://cursor.com/docs/cloud-agent/setup) |
| Reach private VPC/intranet via **Cloudflare Tunnel** or Tailscale userspace; no inbound to private services required | [Secrets & Network](https://cursor.com/docs/cloud-agent/security-network) · [Running Cloudflare Tunnel](https://cursor.com/docs/cloud-agent/setup#running-cloudflare-tunnel) |
| Store CF Access Client ID/Secret as Cursor Secrets; call hostname with `CF-Access-Client-Id` / `CF-Access-Client-Secret`; allowlist the hostname | [Running Cloudflare Tunnel](https://cursor.com/docs/cloud-agent/setup#running-cloudflare-tunnel) |
| Optional `cloudflared access tcp` for private TCP | [Running Cloudflare Tunnel](https://cursor.com/docs/cloud-agent/setup#running-cloudflare-tunnel) |
| Network modes: Allow all / Default+allowlist / **Allowlist only**; Enterprise can **lock** policy | [Secrets & Network](https://cursor.com/docs/cloud-agent/security-network) · [Cloud Agents settings](https://cursor.com/docs/cloud-agent/settings) |
| Published Cloud Agent egress IP ranges (shared; not org isolation by themselves) | [ips.json](https://cursor.com/docs/ips.json) · [Secrets & Network — Egress IP ranges](https://cursor.com/docs/cloud-agent/security-network) |
| `.cursor/environment.json` install/start scripts; install can mint OIDC on the same socket | [Cloud Environment Setup](https://cursor.com/docs/cloud-agent/setup) |
| Trust model: any process on the agent VM can mint for **that** run | [OIDC tokens — Trust model](https://cursor.com/docs/cloud-agent/identity) |

Discovery / JWKS (for Entra federation setup):

- Issuer: `https://api.cursor.com`
- Discovery: `https://api.cursor.com/.well-known/openid-configuration`
- JWKS: `https://api.cursor.com/keys`

## Cloudflare

| Claim in our work | Source |
| --- | --- |
| **Cloudflare Tunnel** publishes private origins without inbound firewall holes; `cloudflared` dials out | [Cloudflare Tunnel (connect networks)](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) |
| Protect published apps with **Cloudflare Access** | [Self-hosted public app / Tunnel + Access](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/) |
| **Service tokens** authenticate automation without browser login | [Service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/) · [Authenticate coding agents](https://developers.cloudflare.com/cloudflare-one/access-controls/authenticate-agents/) |
| Send `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers | [Authenticate coding agents — Use service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/authenticate-agents/) |
| Use a **Service Auth** policy for service tokens (not only Allow + token) | [Access policies — Service Auth](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/) · [Authenticate coding agents](https://developers.cloudflare.com/cloudflare-one/access-controls/authenticate-agents/) |
| `cloudflared` downloads / install | [Tunnel downloads](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) |

## Azure / Microsoft Entra

| Claim in our work | Source |
| --- | --- |
| **Workload identity federation** / federated credentials trust an external OIDC issuer | [Workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation) |
| Create federated credential: `issuer`, `subject`, `audiences` (recommended `api://AzureADTokenExchange`) | [Create trust with external IdP](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust) · [Federated identity credentials overview](https://learn.microsoft.com/en-us/graph/api/resources/federatedidentitycredentials-overview) |
| Match is case-sensitive on issuer / subject / audience | [Federated identity credentials overview](https://learn.microsoft.com/en-us/graph/api/resources/federatedidentitycredentials-overview) |
| Exchange external JWT via `client_credentials` + `client_assertion` (`urn:ietf:params:oauth:client-assertion-type:jwt-bearer`) | [OAuth 2.0 client credentials](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow) |
| **Private Endpoint** keeps PaaS off the public internet | [Private Endpoint](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview) |
| Key Vault access with **Managed Identity** + RBAC (e.g. Key Vault Secrets User) | [Azure RBAC for Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide) · [Managed identities](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) |
| NSG / network security for subnets | [Network security groups](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview) |

## How this maps to our components

| Repo artifact | Grounded in |
| --- | --- |
| `.cursor/scripts/start-azure-access.sh` (OIDC mint + Entra exchange + Access headers) | Cursor [identity](https://cursor.com/docs/cloud-agent/identity) + [setup Cloudflare](https://cursor.com/docs/cloud-agent/setup#running-cloudflare-tunnel) + Entra [federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust) |
| `azure/cloudflared-connector/` | Cloudflare [Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) + Azure [Key Vault RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide) |
| Allowlist-only / Lock Network Access in CHECKLIST | Cursor [security-network](https://cursor.com/docs/cloud-agent/security-network) |
| “Don’t use ips.json as org isolation” | Cursor [ips.json](https://cursor.com/docs/ips.json) + multi-tenant egress model in [security-network](https://cursor.com/docs/cloud-agent/security-network) |
| Diagrams under `docs/` | Same sources; diagrams are explanatory, not a product commitment |

## Disclaimer

Vendor pages can change. Prefer the linked docs over this file when configuring production. This CITATIONS.md documents *why* the pattern is designed this way, not a support contract from Cursor, Cloudflare, or Microsoft.
