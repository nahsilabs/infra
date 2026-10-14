# Hindsight

Hindsight 1.0.0 uses the upstream static-key tenant extension. The custom API
image copies the extension from the immutable v1.0.0 release commit. HindClaw
and its management API are no longer used. The upstream control-plane image
provides the browser UI.

## Memory layout

Tenant `nahsi` uses PostgreSQL schema `user_nahsi` and initially has two banks:

| Bank | Client |
| --- | --- |
| `oh-my-pi` | oh-my-pi |
| `hermes-proba` | Hermes proba |

The clients have separate API keys mapped to the same tenant. Both can access
all banks in that tenant. Their configured bank IDs select normal destinations;
they are not authorization boundaries. Adding another bank does not require a
new tenant or API key.

The previous `public` schema is left untouched. Switching tenant authentication
does not migrate memories from it. No memory migration was needed for this cutover.

## Authentication

`deps/auth-secret.yml` contains SOPS-encrypted `hindsight-auth` credentials:

| Key | Purpose |
| --- | --- |
| `tenant-users` | Three `nahsi:key` entries consumed by the tenant extension |
| `ui-api-key` | UI backend access to the `nahsi` tenant |
| `oh-my-pi-api-key` | oh-my-pi client access |
| `hermes-proba-api-key` | Hermes proba client access |
| `ui-access-key` | Existing shared browser login key, preserved during cutover |

Retrieve a key locally for your password vault. These commands print secrets;
do not paste their output into chat or logs.

```bash
kubectl -n hindsight get secret hindsight-auth \
  -o jsonpath='{.data.ui-access-key}' | base64 --decode; printf '\n'
kubectl -n hindsight get secret hindsight-auth \
  -o jsonpath='{.data.oh-my-pi-api-key}' | base64 --decode; printf '\n'
kubectl -n hindsight get secret hindsight-auth \
  -o jsonpath='{.data.hermes-proba-api-key}' | base64 --decode; printf '\n'
```

The proba key is also encrypted in its overlay's `hindsight-secret.yml` as
`proba-hindsight-auth`, with the environment variable `HINDSIGHT_API_KEY`.
Keep both encrypted copies consistent when rotating that key.

Keys are configured at process startup, not registered in a users table. To
rotate or revoke a key, update the SOPS values and restart the API. Update the
client credential too. Restart the UI when changing its backend or login key.
The API's embedded worker uses the same tenant configuration for background work.

## Clients

Both clients use `https://hindsight.nahsi.dev`.

For oh-my-pi, configure `hindsight.apiUrl`, `hindsight.apiToken`, and
`hindsight.bankId = oh-my-pi`. Keep `hindsight.scoping = per-project-tagged`
to organize projects within that one bank. Saving workstation settings requires
local approval; the Kubernetes deployment does not configure the workstation.

Hermes proba uses the external Hindsight memory plugin and bank `hermes-proba`.
Its native `MEMORY.md` and `USER.md` features remain disabled. Other Hermes
agents do not inherit this plugin configuration.

## Image builds

```bash
docker build --platform linux/amd64 \
  -t docker.io/nahsilabs/hindsight:1.0.0-static-keys containers/hindsight
docker push docker.io/nahsilabs/hindsight:1.0.0-static-keys
```

Pin the published digest in `app/release.yml`. When upgrading Hindsight, update
the API base image, extension source commit, and control-plane image together.
The build checks that the server interpreter can import the extension.

## Runtime and routes

The deployment keeps the existing PostgreSQL cluster, S3 storage, remote model
providers, and private gateway. `/` routes to the UI and `/v1` routes to the API.
Health and metrics endpoints remain available internally. The tenant extension
lazily initializes its schema on the first authenticated request.

No Terraform provider, groups, scope policies, bank templates, or identity
provider are required. The static-key extension does not provide selective
cross-tenant access or a universal administrator API key.

## Operator reading

- [Static-key tenant extension at v1.0.0](https://github.com/vectorize-io/hindsight/tree/v1.0.0/hindsight-extensions/static-keys-tenant)
- [Hindsight extension interfaces](https://hindsight.vectorize.io/developer/extensions)
- [Memory banks](https://hindsight.vectorize.io/developer/api/memory-banks)
- [Hermes Hindsight plugin](https://hermes-agent.nousresearch.com/docs/plugins/hindsight)
