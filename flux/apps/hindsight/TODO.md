# TODO

## SSO / OIDC (deferred — Stage 2)

Stage 1 ships Hindsight **unauthenticated** behind the **private gateway** only
(trusted LAN). On `hindsight.nahsi.dev` the route is path-split: `/` → Control
Plane UI, and `/mcp` `/v1` `/docs` `/redoc` `/openapi.json` → the API (for MCP
agent clients such as omp). None of it is authenticated. To close the gap later:

- Front the route with an Envoy Gateway `SecurityPolicy` + Authentik (this repo
  uses **Envoy Gateway, not Traefik**, and Hindsight has no native OIDC). Reuse
  the terraform `oidc_app` module + add an Authentik app, mirroring the deferred
  readeck SSO notes.
- **Auth must be path-split**, like readeck: browser OIDC on the `/` UI route,
  but MCP/REST clients (omp, agents) can't follow a browser redirect — the
  `/mcp` + `/v1` paths need their own scheme (API token / mTLS), or stay
  private-LAN-only.
- The Control Plane → API call is in-cluster (`HINDSIGHT_CP_DATAPLANE_API_URL`),
  so it is unaffected by gateway auth.

## Grafana dashboards (quick follow-up)

The vendor ships Grafana dashboards (Operations / LLM Metrics / API Service).
The API `/metrics` scrape is live (`obs/`); importing the dashboards via
grafana-operator is a small follow-up.
