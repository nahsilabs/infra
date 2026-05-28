# oidc_app module

## Known issue: empty grant_types

Authentik 2026.5 added a `grant_types` field to OAuth2 providers. New providers
default to empty (no grants allowed). The Terraform provider (2026.2.0) doesn't
support this field yet.

After creating a new OIDC app, patch via API:

```sh
curl -X PATCH \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"grant_types":["authorization_code"]}' \
  "https://auth.nahsi.dev/api/v3/providers/oauth2/<provider_pk>/"
```

Get `<provider_pk>` from:

```sh
curl -s -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  "https://auth.nahsi.dev/api/v3/providers/oauth2/" | jq '.results[] | {name, pk}'
```

Remove this workaround when the Terraform provider adds `grant_types` support.
