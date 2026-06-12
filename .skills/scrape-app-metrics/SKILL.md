---
name: scrape-app-metrics
description: >-
  Enable Prometheus metrics scraping for an app in the nahsilabs observability stack
  (VictoriaMetrics + vm-operator). Use whenever someone wants an app's metrics collected or
  monitored — "scrape X", "enable metrics for X", "add a ServiceMonitor", "why isn't X being
  scraped", "get X into VictoriaMetrics", even phrased casually as "monitor this app". This
  only gets the metrics flowing; for a dashboard use the add-grafana-dashboard skill, and
  for alerting rules use the alerts skill.
---

# Scrape an app's metrics

Metrics collection here is **opt-in and gated**: the in-cluster VMAgent only scrapes scrape
objects labeled **`obs.nahsilabs/metrics: "true"`** (the vm-operator converts each
`ServiceMonitor` into a `VMServiceScrape`, inheriting its labels). So onboarding a service means
emitting a ServiceMonitor *and* giving it that gate label — without the label, a perfectly valid
ServiceMonitor is simply never scraped.

## Enable the ServiceMonitor

The chart almost always emits the ServiceMonitor — enable it in `app/release.yml` and add the gate
label. The value path varies by chart:

- prometheus-community charts: `prometheus.monitor.enabled: true` + `additionalLabels`.
- bjw-s **app-template**: `serviceMonitor.<name>.enabled: true` + `labels` + `endpoints` (it
  auto-detects the Service; the SM lands in the app's namespace).

Only a genuinely chart-less (raw-manifest) app needs a hand-written ServiceMonitor.

Because `ServiceMonitor` is a CRD kind, the Kustomization that creates it must
`dependsOn: infra-prometheus-operator-crds` — otherwise it races the CRD install and fails to apply.

## Verify

Confirm the target is up in vmui at `obs.nahsi.dev`, or query VMSingle for `up{job="<app>"}`. A
series that exists and reads `1` means it's being scraped; absent or `0` points at the gate label,
the endpoint path, or auth being wrong.

## Before committing

`kustomize build` the touched dir, and `kubectl explain` the ServiceMonitor against the live CRD
rather than guessing fields. Follow `AGENTS.md` — change via git, no forced reconciles, short
lowercase commit messages, no `Co-Authored-By`.
