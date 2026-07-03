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

Before writing any YAML, gather three references **in this order** — each tells you what the next is
looking for (you can't pick the sibling until you know the app's shape):

1. **Upstream docs / chart values** (what it is, how it deploys). `helm show values <chart>` + the
   project's install/config docs: required vs optional settings, storage, database, ports, secrets,
   and **how its clients authenticate**. Decide the **minimal** values you actually need.
2. **A proven public deployment** (a complete, working config). Find the same app on our stack via
   **`gh search code`** and **kubesearch.dev** (indexes Flux/Argo HelmReleases across homelab repos);
   scan `onedr0p`, `bjw-s-labs`, `auricom`, `joryirving`. Prefer Flux HelmRelease + Envoy Gateway
   `HTTPRoute` + external-secrets/SOPS + CNPG/MariaDB.
3. **Nearest in-repo sibling** (house style). *Now* that you know the shape, find the local component
   that matches it (Helm vs raw, has `deps/`/`obs/` or not). `flux/apps/memos` (app + Postgres) is a
   good generic template. The sibling wins for *how we wire things here*.

**Done when** you can point to a concrete deployment you're basing this on and its minimal values,
sources, and dependencies — **and the user has _chosen_ on every fork the app opens**: database
engine, exposure/ingress, auth/SSO, replica count, storage class + size. These are the user's calls —
surface them and **wait; do not infer a default to keep moving**. (Fronting with SSO? Confirm how the
app's non-browser clients — API tokens, feeds, e-readers — authenticate; they can't follow a browser
redirect, so they need their own path.)

Then author by adapting: values from #1, completeness from #2, structure/wiring from #3.

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
Iterate on the **workload directly** — don't wait on the HelmRelease/Flux reconcile loop:
`kubectl apply -k <path>`, then `kubectl set env` / `kubectl edit` / `kubectl logs -f` for instant cycles.

- **New component** (not yet in the synced branch): Flux doesn't manage it and `prune` is disabled,
  so just apply it directly and iterate. **No suspend needed.**
- **Changing something Flux already manages:** suspend the **whole chain top-down** first, or each
  parent re-applies and un-suspends your target every interval (a leaf-only suspend gets reverted).
  Chain: FluxInstance `flux` → root ks `infra` → component.
  1. `kubectl annotate --overwrite fluxinstance/flux -n flux-system fluxcd.controlplane.io/reconcile=disabled`
  2. `flux suspend kustomization infra` (root ks) → `flux suspend kustomization <name>` (+ its `-deps`/`-obs`)
  3. Iterate; then codify and **resume bottom-up**: `flux resume kustomization <name>` →
     `flux resume kustomization infra` → re-enable the FluxInstance `reconcile` annotation.

Then run the Branch flow to confirm it reconciles cleanly from git.

## Finish
- Commit. Open a PR / merge **only when asked**.
- `main`'s `flux-instance.yml` must always read `refs/heads/main`.
