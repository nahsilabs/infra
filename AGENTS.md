# nahsilabs

Single-cluster, Flux (**flux-operator**) GitOps homelab. **Public repo.**

When adding or changing anything, **mirror the nearest existing component** — the repo is heavily patterned.

## Skills

- GitOps troubleshooting — something not syncing/reconciling, a stuck HelmRelease or
  Kustomization, the FluxInstance or controllers → **`flux`** (`skill://flux`).
- Logs — check / tail / grep logs, find errors → **`victorialogs`** (`skill://victorialogs`).

## Stack

| Layer | Tool |
|---|---|
| GitOps | Flux, via flux-operator |
| Node OS / provisioning | Talos Linux (`terraform/talos`) |
| Cloud / external IaC | Terraform (`dns`, `s3`, `authentik`, `ntfy`, `stalwart`) |
| CNI / networking | Cilium (eBPF) + BGP |
| Ingress | Envoy Gateway (Gateway API) |
| AI / GPU | agenticgateway (`agentgateway` — AI/MCP gateway); KServe (model serving); NVIDIA + Intel device plugins |
| DNS | external-dns → Cloudflare |
| TLS | cert-manager (Cloudflare DNS-01) |
| Secrets | SOPS (`sops-age`) + external-secrets |
| Databases | CloudNativePG (Postgres), mariadb-operator (MariaDB) |
| Storage | Ceph CSI RBD, NFS CSI (+ snapshot-controller) |
| Metrics | VictoriaMetrics (`vm-operator` + vmagent) |
| Logs | VictoriaLogs (vlagent) |
| Dashboards | Grafana (grafana-operator) |

## Layout

```
flux/                  Cluster state — the GitRepository/infra sync root
  clusters/nahsilabs/  FluxInstance + root kustomization (sync entrypoint)
  repositories/        Helm + OCI chart sources
  infrastructure/      controllers/ + configs/ + crds/
  observability/       collect/ (agents, exporters) + server/ (VM stack, Grafana)
  apps/                per-app dirs, some grouped (ai/, arr/, matrix/, downloads/, ntfy/, youtube/); each: app/ + optional deps/
terraform/             Talos cluster + cloud/external resources
```

## Architecture

- flux-operator-managed; **`FluxInstance/flux`** owns `GitRepository/infra` and the root Kustomization, synced from `flux/clusters/nahsilabs`.
- Group dirs (`repositories`, `infrastructure`, `observability`, `apps`) are kustomize organization that apply the per-component Flux Kustomizations (`ks.yml`) + Helm/OCI sources (`repositories/`).
- Components reconcile independently; ordering is the explicit `dependsOn` graph between Kustomizations (it crosses group boundaries), not directory order.

## Commands

- `kubectl kustomize <dir>` — render / validate a component (kustomize ships in kubectl; doesn't decrypt SOPS).
- `helm template …` — render a chart's output.
- `kubectl explain <kind>.<field>` — verify CRD field names.

## Secrets & safety

- **Public repo** — never commit plaintext secrets, real emails/tokens, or private domains/IPs;
  use SOPS or external-secrets.
- **Never decrypt SOPS** — it spills plaintext into the model's context.
