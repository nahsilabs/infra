# TODO

## SSO / OAuth (deferred — Stage 2)

Readeck is currently deployed with its **built-in local auth** (create the admin
user on first run). Findings from designing SSO, to implement later:

- Readeck has **no native OIDC** — only *forwarded-header auth*
  (`READECK_AUTH_FORWARDED_*`; headers `Remote-User` / `Remote-Email` /
  `Remote-Groups`, where `Remote-Groups` must be one of `user`/`staff`/`admin`).
  Enable with `READECK_AUTH_FORWARDED_ENABLED=true` +
  `READECK_AUTH_FORWARDED_PROVISIONING=true`.
- **OPDS/API cannot use OIDC.** Kobo/KOReader reads the OPDS feed at `/opds` with a
  Readeck **API token** (generated in the UI) and cannot follow a browser OIDC
  redirect. So auth must be **path-split** on `readeck.nahsi.dev`:
  - `/opds`, `/api` → no gateway auth; Readeck's native API-token auth.
  - `/` (web UI) → OIDC at the gateway → inject `Remote-User`/`Remote-Email`.
  Implement as **two HTTPRoutes** (same host, different path matches); the
  `SecurityPolicy` `targetRefs` only the UI route.
- **Mechanism options** (Envoy Gateway `SecurityPolicy`):
  1. Envoy built-in **`oidc`** (reuse the terraform `oidc_app` module + add
     `terraform/authentik/oidc/readeck.yml`) — but `oidc` alone does **not**
     inject identity headers; add a **`jwt` provider** with `claimToHeaders`
     (`preferred_username → Remote-User`, `email → Remote-Email`) +
     `forwardAccessToken` (mind version schema caveats).
  2. Authentik **proxy provider + outpost** via `extAuth` (`headersToBackend`) —
     cleaner header injection, but net-new (repo has no proxy/forward-auth yet).
- **Security requirement:** only the gateway may reach Readeck and set the
  `Remote-*` headers (else spoofing). Add a **NetworkPolicy** limiting ingress to
  Envoy Gateway, and set `READECK_TRUSTED_PROXIES` to the gateway.
- **Unknown to verify (prototype):** with forwarded-auth enabled, does Readeck
  still honor API-token auth on `/opds`+`/api` for requests without `Remote-User`,
  or reject them globally? If it rejects, prefer option 2.
