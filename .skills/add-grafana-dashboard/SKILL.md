---
name: add-grafana-dashboard
description: >-
  Add a Grafana dashboard for an app and commit it as code via grafana-operator — either import a
  published dashboard by its grafana.com id, or author a custom one from the app's own metrics. Use
  whenever someone wants a dashboard for a service: "add a dashboard for X", "build/design panels
  for <app>", "visualize these metrics in grafana", "import the <id> dashboard", "graph <app>'s
  prometheus metrics" — even when they don't say the word "dashboard". To only enable a scrape
  target (no dashboard), use the scrape-app-metrics skill instead.
---

# Add a Grafana dashboard

If a good published dashboard exists on grafana.com, import it by id (the short path below).
Otherwise author a custom one against the app's metrics and commit it as code. Iterating on a
scratch dashboard the user
can actually see beats hand-writing panel JSON blind — they catch unit mistakes, bad panel
choices, and layout problems in seconds that take many edit rounds to find in raw JSON. The loop:

**discover metrics → scratch → iterate → export → wire as code → delete scratch.**

Prereqs: the metrics are already scraped (use the **scrape-app-metrics** skill first to gate the
ServiceMonitor), and the **grafana MCP** is connected (`mcp__grafana__*` tools).

## First: is there a published dashboard?

If the app has a community dashboard on grafana.com, importing it by id is far less work than
authoring one — a small `GrafanaDashboard` with `grafanaCom: {id, revision}`, annotated
`# renovate: depName="<name>"` so Renovate bumps the revision (the `grafana-dashboards` datasource
in `.github/renovate.json`; pin an initial revision via
`curl -s https://grafana.com/api/dashboards/<id> | jq '.revision'`). Template:
`assets/import-grafanadashboard.yml`. Wire it with the same dedicated `obs-<app>-dashboard`
Kustomization as step 4 — but the `obs/kustomization.yml` just lists `dashboard.yml` (no
`configMapGenerator`, since there's no JSON file). Author a custom dashboard (the rest of this
skill) only when there's no good published one, or you want it tailored to the app's exact metrics.

## 1. Discover the metrics

Query the live data before drawing anything — you can't design good panels for metrics you're
guessing at. `list_prometheus_metric_names` (regex `<app>.*`) to find the series, then an instant
`query_prometheus` to read current values, every label, and the unit the exporter emits. If the
unit is ambiguous, check the exporter source; the wrong unit is the most common cause of a
nonsensical-looking panel.

## 2. Scratch, then iterate with the user

Create it live via `update_dashboard` under a **throwaway uid** (`<app>-scratch`, title
"<App> (scratch)") so it never collides with the eventual provisioned dashboard. Hand the user
the URL and refine with `update_dashboard` `operations` (JSONPath patches) as they react —
patches preserve the edits they make in the UI, whereas a full-JSON replace discards them. This
writes to live Grafana, but a scratch is disposable, so that's fine.

Conventions that keep panels readable (the reasoning matters — don't just copy them):
- **One series per query.** Wrap exprs in `max(...)` / `max by (...)` so per-pod/instance label
  churn (restarts, changing labels) doesn't split a stat into a grid of numbers or a graph into
  duplicate lines.
- **Range-wide aggregates** (min/max/avg over the view) need an *outer* aggregation:
  `agg(agg_over_time(metric[$__range]))` — same single-series reasoning.
- **Datasource:** add a `datasource` template variable (type `datasource`, query `prometheus`)
  and reference `${datasource}` in every target. It auto-resolves to the default; a hardcoded
  datasource UID is environment-specific and breaks elsewhere.
- **Units:** set Grafana's field unit to the metric's real unit so values render in the user's
  terms instead of raw numbers. If a metric is already pre-scaled (e.g. a rate expressed in a
  larger unit), convert it to the base unit and let Grafana's auto-scaling format it.
- **Panel fit:** `stat` for single current values, `timeseries` for trends, `state-timeline`
  for up/down states (drive the colors/labels with value mappings rather than threshold steps,
  which leak boundary labels into the legend).
- Leave off `tags` unless the user asks — this repo organizes by folder, not tags.

## 3. Export and normalize

When the user approves, `get_dashboard_by_uid` the scratch (this captures their UI edits), then
write `flux/apps/<app>/obs/<app>.json`. Set `uid` and `title` to the real names, and drop the
runtime-only fields Grafana added: `id`, `version`, and (per above) `tags`.

## 4. Wire as code — generate the ConfigMap, don't inline

Keep the model as a real `.json` file and let kustomize build its ConfigMap; that's far more
maintainable than a giant inline `spec.json` blob (editor/jq support, readable diffs, no YAML
escaping). Template: `assets/dashboard-kustomization.yml`.

- `obs/kustomization.yml`: a `configMapGenerator` from `<app>.json` with
  `generatorOptions.disableNameSuffixHash: true`. The default content-hash suffix would rename
  the ConfigMap on every dashboard edit and break the CR's static `configMapRef`; disabling it
  keeps the name stable (the operator still re-reads content changes).
- `obs/dashboard.yml`: a `GrafanaDashboard` whose `configMapRef` points at that ConfigMap + key.
- A dedicated `obs-<app>-dashboard` Flux Kustomization appended to the component's `ks.yml`
  (after `---`), with `dependsOn: [infra-grafana-operator, obs-grafana]` and
  `targetNamespace: observability`. This keeps the dashboard's reconciliation independent of the
  workload's.

## 5. Validate, commit, clean up

- `jq . flux/apps/<app>/obs/<app>.json` and `kustomize build flux/apps/<app>/obs`, confirming the
  generated ConfigMap is named `<app>-dashboard` with **no hash suffix**.
- `kubectl explain` any CR field you're unsure of rather than guessing against the live CRD.
- Commit via git per `AGENTS.md` (short lowercase message, no `Co-Authored-By`).
- The operator re-asserts the dashboard every ~10m, so the committed JSON is the source of
  truth — edits made directly on the *provisioned* dashboard get reverted. That's the whole
  reason iteration happens on a separate scratch.
- Delete the scratch: `grafana_api_request` `DELETE /api/dashboards/uid/<app>-scratch`.
