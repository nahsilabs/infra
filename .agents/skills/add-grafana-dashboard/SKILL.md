---
name: add-grafana-dashboard
description: >-
  Ship a Grafana dashboard for an app as code via grafana-operator — import a published one by its
  grafana.com id, or author a custom one from the app's own metrics. Use whenever someone wants a
  dashboard for a service: "add a dashboard for X", "import the <id> dashboard", "build panels for
  <app>", "visualize <app>'s metrics" — even when they don't say "dashboard". To only enable a
  scrape target (no dashboard), use the scrape-app-metrics skill; for panel/variable/unit JSON field
  names, read the dashboarding skill.
---

# Add a Grafana dashboard

Two branches: if a good published dashboard exists, **import it by id** (the short path below);
otherwise **author a custom one** and commit it as code. Author by iterating on a **scratch** the
user can see — they catch unit mistakes, bad panel choices, and layout problems in seconds that take
many edit rounds to find in raw JSON. The loop:

**discover metrics → scratch → iterate → export → wire as code → delete scratch.**

Prereqs: the metrics are already scraped (the **scrape-app-metrics** skill gates the ServiceMonitor
first) and the **grafana MCP** is connected (`mcp__grafana__*` tools).

## First: does a dashboard already exist? (find → verify live → then decide)

Don't author blind — and don't wire a found one blind either.

**Find — search two places** (an empty result is often a wrong query, not "nothing exists"):

1. **grafana.com registry** — the search param is **`filter`**, not `search` (which errors
   `Unexpected parameter`). Sanity-check with a control term first:
   `curl -s 'https://grafana.com/api/dashboards?filter=<app>&orderBy=downloads&direction=desc' | jq '.items[] | {id,name,downloads,revision}'`
   (control `filter=node%20exporter` must return hits — if it doesn't, your call is wrong.)
2. **The app's own repo / GitHub** — upstream often ships a `grafana_dashboard.json` in-repo that
   was never published. Search by the **metric prefix** (surest signal):
   `gh search code '<metric_prefix>' --json repository,path` — e.g. `invidious_companion_` surfaces
   `iv-org/invidious-companion/grafana_dashboard.json`.

**Verify before wiring — load it into a scratch first.** Import the found JSON (or grafana.com id)
onto a throwaway scratch (step 2) and look at it against live data. Found dashboards routinely
reference metrics your scrape doesn't expose, assume a different datasource/label set, or need unit
fixes. If it renders clean and useful as-is, go straight to wire-as-code (step 4). If it needs
changes, drop into the scratch → iterate loop (step 2) using that JSON as the starting point.

## Import path: wire a grafana.com dashboard by id

Importing by id is far less work than authoring: a small `GrafanaDashboard` with
`grafanaCom: {id, revision}`, annotated `# renovate: depName="<name>"` so Renovate bumps the
revision (the `grafana-dashboards` datasource in `.github/renovate.json`; pin an initial revision
via `curl -s https://grafana.com/api/dashboards/<id> | jq '.revision'`). Template:
`assets/import-grafanadashboard.yml`. Wire it with the same dedicated `obs-<app>-dashboard`
Kustomization as step 4 — but `obs/kustomization.yml` just lists `dashboard.yml` (no
`configMapGenerator`, since there's no JSON file).

Author a custom dashboard (the rest of this skill) only when there's no good published one, or you
want it tailored to the app's exact metrics.

## 1. Discover the metrics

Query the live data before drawing anything. `list_prometheus_metric_names` (regex `<app>.*`) to
find the series, then an instant `query_prometheus` to read current values, every label, and the
unit the exporter emits. If the unit is ambiguous, check the exporter source — the wrong unit is the
most common cause of a nonsensical-looking panel.

## 2. Scratch, then iterate with the user

Create it live via `update_dashboard` under a **throwaway uid** (`<app>-scratch`, title
"<App> (scratch)") so it never collides with the provisioned dashboard. Hand the user the URL and
refine with `update_dashboard` `operations` (JSONPath patches) as they react — patches preserve the
edits they make in the UI, whereas a full-JSON replace discards them.

For panel types, `gridPos`, unit identifiers, template variables, and transformations, **read the
`dashboarding` skill** — don't guess the JSON schema. Repo conventions layered on top of it (the
reasoning matters — don't just copy):

- **One series per query.** Wrap exprs in `max(...)` / `max by (...)` so per-pod/instance label
  churn (restarts, changing labels) doesn't split a stat into a grid or a graph into duplicate lines.
- **Range-wide aggregates** (min/max/avg over the view) need an *outer* aggregation:
  `agg(agg_over_time(metric[$__range]))` — same single-series reasoning.
- **A `datasource` template variable is mandatory** — reference `${datasource}` in every target. A
  hardcoded datasource UID is environment-specific and breaks elsewhere.
- **Match the metric's real unit** so values render in the user's terms. If a metric is pre-scaled
  (e.g. a rate in a larger unit), convert to the base unit and let Grafana auto-scale.
- **state-timeline** for up/down states: drive colors/labels with value mappings, not threshold
  steps (which leak boundary labels into the legend).
- **No `tags`** unless asked — this repo organizes by folder, not tags.

## 3. Export and normalize

When the user approves, `get_dashboard_by_uid` the scratch (this captures their UI edits), then
write `flux/apps/<app>/obs/<app>.json`. Set `uid` and `title` to the real names, and drop the
runtime-only fields Grafana added: `id`, `version`, and `tags`.

## 4. Wire as code — generate the ConfigMap, don't inline

Keep the model as a real `.json` file and let kustomize build its ConfigMap — far more maintainable
than a giant inline `spec.json` blob (editor/jq support, readable diffs, no YAML escaping). Template:
`assets/dashboard-kustomization.yml`.

- `obs/kustomization.yml`: a `configMapGenerator` from `<app>.json` with
  `generatorOptions.disableNameSuffixHash: true`. The default content-hash suffix would rename the
  ConfigMap on every edit and break the CR's static `configMapRef`; disabling it keeps the name
  stable (the operator still re-reads content changes).
- `obs/dashboard.yml`: a `GrafanaDashboard` whose `configMapRef` points at that ConfigMap + key.
- A dedicated `obs-<app>-dashboard` Flux Kustomization appended to the component's `ks.yml` (after
  `---`), with `dependsOn: [infra-grafana-operator, obs-grafana]` and
  `targetNamespace: observability`. This keeps the dashboard's reconciliation independent of the
  workload's.

## 5. Validate, commit, clean up

- `jq . flux/apps/<app>/obs/<app>.json` and `kustomize build flux/apps/<app>/obs`, confirming the
  generated ConfigMap is named `<app>-dashboard` with **no hash suffix**.
- `kubectl explain` any CR field you're unsure of rather than guessing against the live CRD.
- Commit via git per `AGENTS.md` (short lowercase message, no `Co-Authored-By`).
- The operator re-asserts the dashboard every ~10m, so the committed JSON is the source of truth —
  edits made directly on the *provisioned* dashboard get reverted. That's the whole reason iteration
  happens on a separate scratch.
- Delete the scratch: `grafana_api_request` `DELETE /api/dashboards/uid/<app>-scratch`.
