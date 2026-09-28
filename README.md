# infra

## Open WebUI

The deployment lives in `flux/apps/open-webui`, in namespace `ai`, and
serves `https://chat.nahsi.dev` through the existing gateways.

It uses one WebUI replica, CNPG PostgreSQL with pgvector on a 10 GiB
`ceph-rbd-retain` volume, a private 50 GiB S3 bucket, and Valkey with a
1 GiB `ceph-rbd-retain` volume. Valkey uses append-only persistence with
one-second fsync and a `Recreate` rollout strategy. An abrupt crash can lose
the most recent writes. No database or bucket backups are configured for
this evaluation.

Chat and embeddings use the existing AI gateway. Web search uses SearXNG.
Speech uses `https://ai.nahsi.dev/v1` with STT model
`nvidia/nemotron-3.5-asr-streaming-0.6b`, TTS model `Qwen/Qwen3-TTS`, and
voice `polemist_v1`. Speech permissions are enabled. Open WebUI appears in
the `Productivity` group in Homepage and Authentik.

### Provisioning and credentials

The S3 bucket/user and Authentik application/group are managed by
`terraform/s3` and `terraform/authentik`. The application is allowed for
`operators` and `access:open-webui`, with callback
`https://chat.nahsi.dev/oauth/oidc/callback`.

`app/secret.yml` contains SOPS-encrypted WebUI signing, OIDC, and S3
credentials. The dedicated gateway credential is the `open-webui` entry
in `flux/apps/ai/gateway/app/apikeys.yml`. Never print decrypted secrets or
Terraform's sensitive outputs when rotating credentials.

Keep `WEBUI_SECRET_KEY` stable across restarts and restores. CNPG creates
the default `app` database and its `pg-open-webui-app` credential Secret;
a CNPG `Database` resource manages pgvector inside that existing database.

Keep the initial Authentik allowlist restricted to the intended administrator
until the first OIDC login is complete. Open WebUI makes its first account an
administrator. Invite other users afterward. Local password login and public
signup are disabled.

### Operation and verification

- Application settings can be changed in the admin UI. Persisted configuration
  may override environment defaults after first startup; review both when
  changing an existing installation.
- S3 holds uploads, PostgreSQL holds application and vector data, and the
  WebUI data directory is disposable scratch/cache. None of these replaces
  a backup.
- Local AI processing does not make web search private: search terms and
  fetched URLs leave the network. Web research is enabled by default by choice.
- Valkey preserves revocation markers across ordinary pod replacements.
  Open WebUI's revocation checks fail open during a Valkey outage.
- Sharing rules and library visibility remain application-level choices.

Local rendering does not apply resources or decrypt SOPS:

```sh
kubectl kustomize flux/apps/open-webui
kubectl kustomize flux/apps/open-webui/deps
kubectl kustomize flux/apps/open-webui/app
```

After an approved deployment, check OIDC admission and rejection, streaming
chat through the gateway, document upload/retrieval with S3 and pgvector,
SearXNG search, and persistence across a pod replacement. Voice end-to-end
testing is outside the initial deployment verification.
