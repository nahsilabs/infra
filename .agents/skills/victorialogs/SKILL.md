---
name: victorialogs
description: >-
  Search, tail, and investigate the cluster's logs — they live in VictoriaLogs, queried
  via the victorialogs MCP tools using LogsQL. Reach for this on ANY task that touches
  logs: "check the logs", "something's wrong — look at the logs", "find
  errors/anomalies", "grep the logs", "tail <pod>", "why is <app> logging …", log stats,
  or discovering log fields/streams.
---

# VictoriaLogs Query

The victorialogs MCP ships tool schemas and a `documentation` tool holding the full
LogsQL manual. This skill does NOT repeat LogsQL — on any query parse error, call
`documentation`, fix the syntax, and retry; don't keep guessing. What follows is only
where the MCP's schemas mislead, plus discovery order.

## MCP traps — schema says one thing, tool does another

- **Relative time works.** `start`/`end`/`time` accept durations (`5m`, `1h`, `now-1h`)
  and unix seconds — not only the RFC3339 the schema `pattern` implies. Don't shell out
  to `date`. Pass a tight `start` like `1h` to keep the scan cheap.
- **`hits` and `stats_query_range` require `step`** (e.g. `5m`). Omit it and the call
  errors `cannot parse duration 'step='` — the schema's `1d` default is never applied.
- **`stats_query` requires `time`** — errors `time param is required`, though the schema
  marks it optional.
- **`stats_query` / `stats_query_range` need a `| stats` pipe** in the query, else 422.
- **`query` returns JSON Lines** (one JSON object per line), not a JSON array.

## Discovery order

Don't guess field names or values — discover them:

1. `facets` — field/value distributions in one call.
2. `field_names` / `stream_field_names` — list available fields.
3. `field_values` / `stream_field_values` — values for a field (e.g. `level`, which apps
   log in mixed case: `ERROR`/`error`/`err`).
4. `query` with the discovered filters. To find where errors concentrate, one
   `stats by (kubernetes.pod_namespace, level) count()` beats a query per suspected term.
