# agentgateway — custom data-plane fork & version skew

## Why the data-plane is a custom build

Authentik OAuth for the **MCP servers** (`flux-mcp`, `grafana-mcp`, `victorialogs-mcp`,
`victoriametrics-mcp`) needs agentgateway's MCP authorization: `traffic.jwtAuthentication.mcp`
(`resourceMetadata` + the `.well-known/oauth-protected-resource` discovery and **Dynamic Client
Registration** wrapping Authentik). That wasn't in the tagged `v1.3.1` release, so the **proxy / data
plane** image is pinned to a custom build:

- `app/app/helmrelease.yml` → `values.proxy.image` = `docker.io/nahsilabs/agentgateway:v1.3.1-pr2016-dcr`
  (a local build of `v1.3.1` + DCR work, branched around upstream PR #2016), instead of the chart's
  default `v1.3.1` proxy.

**Upstream to watch (un-fork when merged + released):**
- https://github.com/agentgateway/agentgateway/pull/2016 — *"feat(mcp): add Amazon Cognito as a native
  MCP authentication provider"* — **OPEN** as of 2026-06-25.
- Note: PR #2016's title is *Cognito*, not Authentik/DCR. The tag references `pr2016` + `dcr`, so the
  Authentik-enabling change is the **DCR** work in the build branch — confirm the exact upstream PR(s)
  for DCR (and for the cost-catalog mount fix + `custom.providerOverride`) and track those too.

## The skew (current state)

| Component | Version | Source |
|---|---|---|
| **proxy / data-plane** | **`v1.3.1-pr2016-dcr` (fresh)** | `proxy.image` override in `app/app/helmrelease.yml` |
| controller | `cr.agentgateway.dev/controller:v1.3.1` | chart default (NOT overridden) — OCIRepository `agenticgateway` |
| CRDs | `v1.3.1` | OCIRepository `agenticgateway-crds` (`app/crds/helmrelease.yml`) |

Only the data-plane was forwarded; **controller + CRDs lag it.** The controller generates the gateway
Deployment (mounts/env) and the CRDs define the schema — both behind the data-plane.

## Consequences caused by the skew

1. **Realized cost catalog (modelCatalog) — REVERTED** (commit `fde087a`).
   The `v1.3.1` controller mounts the cost-catalog ConfigMap in a way the fresh data-plane can't read:
   - key = `<cm-name>` → ConfigMap mounts as a **directory** → data-plane logs `Is a directory (os error 21)`
     → `agentgateway_cost_catalog_lookups_total{status="NoCatalog"}`.
   - key aligned to `<cm-name>.json` → controller emits a **subPath file mount** the container runtime
     rejects (`not a directory`) → gateway pod **CrashLoopBackOff**, stuck rollout.
   So no realized per-request USD cost (`agw.ai.usage.cost.total` in logs / `llm.cost` in CEL) until
   controller + CRDs are aligned.

2. **Per-provider cost/metrics attribution (`custom.providerOverride`) — unavailable.**
   Not in the `v1.3.1` CRD (`kubectl apply` rejects `spec.ai.groups[].providers[].custom.providerOverride`
   as an unknown field; it exists in agentgateway `main`). Effect: external OpenAI-compatible providers all
   report `gen_ai_system="openai"`, and the cost lookup keys on `(provider-protocol, resolved-model)`
   (`llm/cost/mod.rs` `project()`), so the **same model on DeepInfra vs Groq can't be priced or attributed
   separately** — one price per resolved model id.

3. **General:** any data-plane capability that needs controller-generated config or a CRD field newer than
   `v1.3.1` will silently not work.

## To unblock (do this together)

1. **Align all three to a matching fresh build:** build/pin a controller image from the same source as the
   data-plane, and bump the `agenticgateway` + `agenticgateway-crds` OCIRepository chart versions so the
   controller and CRDs match `pr2016` (or whatever the data-plane tracks). Ideally also re-pin
   `proxy.image` to that same tag.
2. **Re-add the cost catalog** (content is in git history at `767a800` / parent of `fde087a`):
   - restore `flux/apps/ai/llm/gateway/costs.yml` (ConfigMap `llm-model-costs`, rates verified vs deepinfra.com),
   - re-add the `modelCatalog` block to
     `flux/infrastructure/configs/agenticgateway-gateway/app/agentgatewayparameters.yml`,
   - verify `agentgateway_cost_catalog_lookups_total{status="Exact"}` and `agw.ai.usage.cost.total` in VictoriaLogs.
3. **Per-provider differentiation** (after providerOverride is available): model DeepInfra/Groq as `custom`
   providers (`formats: [{ type: Completions }]`) with `providerOverride: deepinfra` / `groq`, and key the
   cost catalog by `providers.deepinfra` / `providers.groq` → distinct `gen_ai_system`, distinct prices.

## End state / exit criteria

Stop forking: once MCP DCR, the cost catalog mount, and `providerOverride` are all in a tagged agentgateway
release, drop the `proxy.image` override and pin controller + CRDs + proxy to that one release.

## Not affected by the skew (working today)

Model serving (KServe InferencePool/EPP), the `/v1` single front door + BBR model routing,
`apiKeyAuthentication`, Cilium network isolation, and token/usage metrics
(`agentgateway_gen_ai_client_token_usage`).
