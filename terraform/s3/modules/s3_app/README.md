# s3_app module

Creates an S3 bucket with a dedicated IAM user that has RW access scoped to
that bucket.

Uses the [aminueza/minio](https://registry.terraform.io/providers/aminueza/minio/latest)
provider in `s3_compat_mode` for RustFS compatibility.

## Resources created

| Resource | Name | Purpose |
|---|---|---|
| `minio_s3_bucket` | `<bucket>` | the bucket |
| `minio_s3_bucket_versioning` | `<bucket>` | versioning (if enabled) |
| `minio_s3_bucket_quota` | `<bucket>` | hard quota (if set) |
| `minio_s3_bucket_lifecycle` | `<bucket>` | lifecycle rules (if any) |
| `minio_iam_user` | `<bucket>` | dedicated IAM user |
| `minio_iam_policy` | `<bucket>` | RW policy scoped to bucket |
| `minio_iam_user_policy_attachment` | — | binds policy to user |

## Variables

| Name | Type | Description |
|---|---|---|
| `bucket` | `string` | Bucket name (required) |
| `config` | `any` | App configuration from YAML |

### YAML config options

| Field | Type | Default | Description |
|---|---|---|---|
| `acl` | `string` | `"private"` | `private` or `public` |
| `versioning` | `bool` | `false` | Enable versioning |
| `force_destroy` | `bool` | `false` | Allow destroying bucket with objects |
| `quota_gib` | `number` | `0` | Hard quota in GiB (0 = no quota) |
| `lifecycle_rules` | `list` | `[]` | Object expiration rules |

### lifecycle_rules fields

| Field | Type | Default | Description |
|---|---|---|---|
| `id` | `string` | — | Unique rule ID (required) |
| `prefix` | `string` | `""` | Object prefix filter (empty = all objects) |
| `expiration_days` | `number` | `0` | Delete objects after N days |
| `abort_incomplete_days` | `number` | `0` | Clean up incomplete multipart uploads after N days |

## Outputs

| Name | Description |
|---|---|
| `bucket` | Bucket name |
| `arn` | Bucket ARN |
| `access_key` | IAM username (use as S3 access key) |
| `secret_key` | IAM user secret (sensitive) |
