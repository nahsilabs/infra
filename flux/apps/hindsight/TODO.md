# TODO

## SSO / OIDC (deferred — Stage 2)

Stage 1 ships Hindsight **unauthenticated** behind the **private gateway** only
(trusted LAN). The Control Plane UI at `hindsight.nahsi.dev` and the API
(ClusterIP) have no auth. To close the gap later:

- Front the UI route with an Envoy Gateway `SecurityPolicy` + Authentik
  (this repo uses **Envoy Gateway, not Traefik**, and Hindsight has no native
  OIDC). Reuse the terraform `oidc_app` module + add an Authentik app, mirroring
  the deferred readeck SSO notes.
- The Control Plane → API call is in-cluster (`HINDSIGHT_CP_DATAPLANE_API_URL`),
  so only the UI route needs fronting.

## External `/api` exposure (deferred — integration effort)

The API stays ClusterIP-internal in Stage 1. Exposing `/api` for external agent
connectivity depends on how agents will connect (the Claude/MCP integration),
so it is deferred to that PRD.

## Grafana dashboards (quick follow-up)

The vendor ships Grafana dashboards (Operations / LLM Metrics / API Service).
The API `/metrics` scrape is live (`obs/`); importing the dashboards via
grafana-operator is a small follow-up.
