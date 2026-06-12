---
name: add-service-to-obs
description: >-
  Onboard a service into the nahsilabs observability stack (VictoriaMetrics +
  grafana-operator). Use whenever someone wants to add metrics/monitoring for an
  app, expose or gate a ServiceMonitor scrape target, or add a Grafana dashboard
  (including importing one by grafana.com id) — even phrased casually as "add obs",
  "enable metrics", "scrape this", or "add a dashboard for X".
---

# Add a service to observability

Metrics collection is **opt-in and gated**: the in-cluster VMAgent only scrapes scrape objects
labeled **`obs.nahsilabs/metrics: "true"`** (the vm-operator converts each `ServiceMonitor` into a
`VMServiceScrape`, inheriting its labels). So onboarding a service means labeling its
ServiceMonitor — and, optionally, adding a dashboard.

A component's observability lives in a sibling **`obs/`** dir (mirroring `deps/`), reconciled by its
own Flux Kustomization. Metrics and dashboards are independent; do only what was asked.

## Metrics

The chart almost always emits the ServiceMonitor — enable it in `app/release.yml` and give it the
gate label `obs.nahsilabs/metrics: "true"`. The value path varies by chart:

- prometheus-community charts: `prometheus.monitor.enabled: true` + `additionalLabels`.
- bjw-s **app-template**: `serviceMonitor.<name>.enabled: true` + `labels` + `endpoints` (it
  auto-detects the Service; the SM lands in the app's namespace).

Only a genuinely chart-less (raw-manifest) app needs a hand-written ServiceMonitor. Either way, the
Kustomization that creates the ServiceMonitor must `dependsOn: infra-prometheus-operator-crds`
(it's a CRD kind). Verify in vmui at `obs.nahsi.dev`, or query VMSingle for `up`.

## Dashboard

Add a `GrafanaDashboard` CR in the component's `obs/` dir — template: `assets/grafanadashboard.yml`.
Prefer importing a published dashboard by its grafana.com id (niche apps often have none — then
author inline JSON, or skip):

- Annotate it `# renovate: depName="<name>"` above `id:` so Renovate bumps the `revision` (the
  `grafana-dashboards` datasource in `.github/renovate.json`). Pin an initial revision:
  `curl -s https://grafana.com/api/dashboards/<id> | jq '.revision'`.
- The datasource resolves to the default (VictoriaMetrics) via the dashboard's datasource variable;
  only old `__inputs`-style dashboards need explicit `spec.datasources`.
- Don't set `resyncPeriod` — the operator re-asserts every ~10m, so edits made in the Grafana UI
  get reverted. The CR is the source of truth.

Wire the `obs/` dir as a dedicated Kustomization in the component's `ks.yml` (template:
`assets/obs-kustomization.yml`): `dependsOn: [infra-grafana-operator, obs-grafana]`,
`targetNamespace: observability`.

## Before committing

`kustomize build` the touched dirs and `kubectl explain` any CR against the live CRD — don't guess
fields. Follow the repo guardrails in `AGENTS.md` (change via git, no forced reconciles; short
lowercase commit messages, no `Co-Authored-By`).
