---
name: add-component
description: >-
  Add or change a component in this Flux GitOps repo — a new app or infra
  controller, its HelmRelease/Kustomization and chart source, plus ingress,
  database, or secret wiring — and test it on the cluster. Reach for this to
  deploy or modify anything in the repo: "add <app>", "create a component for
  X", "wire up ingress / a database / a secret for <app>", "get X running on
  the cluster", "change <component>", or "test this before merging".
---

# Add / change a component

This repo is heavily patterned. **The fastest correct path is to copy an existing, proven
deployment and adapt it** — don't compose from memory. Do the research below first.

## Research first

Before writing any YAML, gather three references and reconcile them:

1. **Nearest in-repo sibling** (house style). Find the local component that most resembles the
   target — same shape (Helm vs raw, has `deps/`/`obs/` or not). `flux/apps/memos` (app + Postgres)
   is a good generic template. The sibling wins for *how we wire things here*.
2. **A proven public deployment** (full example). Search popular homelab repos for the same app on
   our stack — use exa/web search (`<app> HelmRelease`, or scan `onedr0p`, `bjw-s-labs`, `auricom`,
   `joryirving` home-ops on GitHub). Prefer one already using Flux HelmRelease + Envoy Gateway
   `HTTPRoute` + external-secrets/SOPS + CNPG/MariaDB. It shows *what a complete, working config looks like*.
3. **Upstream docs / chart values** (correct settings). Read what the component is and how it's
   configured: `helm show values <chart>`, the project's install/config docs, required vs optional
   settings. Decide the **minimal** values we actually need and why.

**Done when:** you can point to a concrete deployment you're basing this on and list the minimal
values, sources, and dependencies it needs. Then author by adapting it — structure/wiring from #1,
completeness from #2, correct values from #3.

## Anatomy

A component is a directory in a group — `flux/infrastructure/{controllers,configs,crds}`,
`flux/observability/{collect,server}`, or `flux/apps/[<group>/]<name>`:

```
<name>/
  namespace.yml      the Namespace
  kustomization.yml  kustomize list: namespace.yml + ks.yml
  ks.yml             the Flux Kustomization(s) — one per path (app/, plus <name>-deps, <name>-obs for deps/, obs/)
  app/               workload: release.yml (HelmRelease) or raw manifests + kustomization.yml
  deps/              optional: databases / secrets (its own -deps Kustomization)
  obs/               optional: the app's own observability — scrape configs / dashboards (its own -obs Kustomization)
```

Flux Kustomizations are prefixed **`infra-` / `app-` / `obs-`** by group.

## ks.yml pattern

One Flux Kustomization per path; `sourceRef` is always `GitRepository/infra` (ns `flux-system`).
Example (memos — an app that needs a DB):

- `app-memos-deps` → `path: ./flux/apps/memos/deps`, `dependsOn: [infra-cloudnative-pg]`, `wait: true`
- `app-memos`      → `path: ./flux/apps/memos/app`,  `dependsOn: [app-memos-deps]`

Rules:
- `wait: true` when something else `dependsOn` this Kustomization.
- Emitting a CRD kind (`Certificate`, `HTTPRoute`, `ExternalSecret`, CNPG `Cluster`, `MariaDB`,
  `ServiceMonitor`, `VM*`, …)? `dependsOn` the ks that installs it — **copy the `dependsOn` from an
  existing consumer**: `grep -rl "kind: <Kind>" flux` and read a sibling's `ks.yml`.
- Inline SOPS secret in the component? add the `decryption` block (`provider: sops`,
  `secretRef.name: sops-age`) — mirror a neighbor.

## Steps

1. Copy the closest sibling into a new `<name>/` dir; rename everything (namespace, ks names, paths).
2. Chart source: ensure a `HelmRepository`/`OCIRepository` exists in `flux/repositories/{helm,oci}/`
   (add if missing, reuse if present); point `app/release.yml` at it.
3. Fill `app/` — keep values minimal, mirror the neighbor. Add `deps/` only if it needs a DB/secret.
4. Fix `ks.yml` names/paths/`dependsOn` per the pattern above; wire the component into the parent
   group's `kustomization.yml`.
5. **Validate before proposing:**
   - `kubectl kustomize flux/.../<name>/app` — renders? (doesn't decrypt SOPS)
   - `helm template` the chart if unsure of values; `kubectl explain <kind>.<field>` for CRD fields.

## Test on the cluster

### Branch — change is basically done
1. `git push -u origin <branch>`
2. Point Flux at it (the FluxInstance is applied out-of-band, so this patch is **not** reverted):
   `kubectl patch fluxinstance flux -n flux-system --type=merge -p '{"spec":{"sync":{"ref":"refs/heads/<branch>"}}}'`
3. `flux reconcile source git infra` (or wait ~1m); watch it reconcile, fix, commit, repeat.
4. Done → patch `sync.ref` back to `refs/heads/main`.

### Prototype — still figuring it out
Suspend the **whole chain top-down** — each parent re-applies and un-suspends its child every
interval, so a leaf-only suspend gets reverted. Chain: FluxInstance `flux` → root ks `infra` → component.
1. `kubectl annotate --overwrite fluxinstance/flux -n flux-system fluxcd.controlplane.io/reconcile=disabled`
   — stops flux-operator re-applying the root Kustomization.
2. `flux suspend kustomization infra` — the root Kustomization (created by the FluxInstance).
3. `flux suspend kustomization <name>` — the component (and its `<name>-deps` / `<name>-obs` if you touch those).
4. Iterate imperatively (`kubectl apply`/`edit`, `helm install`) until it works.
5. Codify into manifests, then **resume bottom-up**:
   `flux resume kustomization <name>` → `flux resume kustomization infra` →
   `kubectl annotate --overwrite fluxinstance/flux -n flux-system fluxcd.controlplane.io/reconcile=enabled`.
6. Run the Branch flow to confirm it reconciles cleanly from git.

## Finish
- Commit. Open a PR / merge **only when asked**.
- `main`'s `flux-instance.yml` must always read `refs/heads/main`.
