# Hindsight with HindClaw

The Hindsight API image includes HindClaw's tenant, operation-validator, and HTTP
extensions. HindClaw runs inside the API process, not as a separate Deployment.
The upstream Hindsight control-plane image supplies the browser UI.

## Versions and image builds

- Hindsight API and control plane: `1.0.0`.
- HindClaw extension: `0.5.0`, unmodified.
- Custom image: `docker.io/nahsilabs/hindsight:1.0.0-hindclaw-0.5.0`.

Build from the repository root, then publish explicitly:

```bash
docker build --platform linux/amd64 \
  -t docker.io/nahsilabs/hindsight:1.0.0-hindclaw-0.5.0 containers/hindsight
docker push docker.io/nahsilabs/hindsight:1.0.0-hindclaw-0.5.0
```

Pin the published digest in `app/release.yml`. When upgrading Hindsight, update
both the API base image in `containers/hindsight/Dockerfile` and the control-plane
image. The Dockerfile installs only HindClaw; its dependencies are already in the
pinned upstream API image.

## Authentication

`deps/hindclaw-secret.yml` contains two SOPS-encrypted values in `hindclaw-auth`:

| Key | Purpose |
| --- | --- |
| `token` | Root API credential for administrator `nahsi`; also used by the UI server for backend requests |
| `ui-access-key` | Separate shared browser-login key, configured as `HINDSIGHT_CP_ACCESS_KEY` |

Retrieve these locally for a password vault. These commands print secrets to your
terminal; do not paste their output into chat or logs.

```bash
# Browser login key
kubectl -n hindsight get secret hindclaw-auth \
  -o jsonpath='{.data.ui-access-key}' | base64 --decode; printf '\n'

# Administrator API key
kubectl -n hindsight get secret hindclaw-auth \
  -o jsonpath='{.data.token}' | base64 --decode; printf '\n'
```

The browser key gates the UI; it does not create individual user identities or
provide SSO. After login, UI backend requests use the `nahsi` administrator key.
Direct API callers must supply a HindClaw credential independently of UI login.

HindClaw registers the root user/key when its database pool first initializes.
Changing the root Secret and restarting does **not** rotate an existing database
key record. Rotate registered keys through HindClaw before changing consumers.
Future dedicated UI, automation, and agent credentials will be managed through
the HindClaw Terraform provider. JWT authentication is not configured.

## Runtime dependencies and routes

The deployment retains the existing CNPG PostgreSQL database, S3 file storage,
remote inference/embedding/reranker providers, and private gateway. HindClaw uses
`HINDSIGHT_API_DATABASE_URL` and the existing PostgreSQL credentials. It opens an
additional connection pool with minimum 2 and maximum 10 connections per process.

On the existing private hostname, `/` routes to the UI; `/v1` and `/ext/hindclaw`
route to the API. The API exposes `/health/live`, `/health`, and `/metrics`
internally for probes and monitoring. No separate HindClaw service or PVC exists.

## Accepted upstream behavior

HindClaw 0.5.0 unconditionally recreates `template_sources` when its database pool
initializes. Process restarts can therefore erase registered template catalog
sources. This statement does not delete retained memories or the separate
`bank_templates` table. Source registrations are treated as disposable here.

The published installation documentation names `HINDSIGHT_API_TENANT_JWT_SECRET`,
but 0.5.0 reads `HINDCLAW_JWT_SECRET`. If JWT clients are enabled later, use the
implementation's setting and keep the signing secret limited to trusted clients.

Hindsight 1.0.0 rejects tag-scoped callers on bank-wide operations. Review that
behavior when defining agent permissions; HindClaw's policy tag enrichment is not
a substitute for checking the upstream tag-scope contract.

## Operator reading

- [Hindsight 1.0.0 release notes](https://github.com/vectorize-io/hindsight/releases/tag/v1.0.0)
- [HindClaw installation](https://hindclaw.pro/docs/getting-started/installation/)
- [HindClaw access control](https://hindclaw.pro/docs/guides/access-control/)
- [HindClaw configuration reference](https://hindclaw.pro/docs/reference/configuration/)
- [HindClaw Terraform provider guide](https://hindclaw.pro/docs/guides/terraform/)

Banks, policy design, templates, agent onboarding, SSO, and Langfuse integration
are separate work. This deployment does not configure them.
