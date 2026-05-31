terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
    }
  }
}

# ---------------------------------------------------------------------------
# Bucket
# ---------------------------------------------------------------------------

resource "minio_s3_bucket" "this" {
  bucket        = var.bucket
  acl           = local.acl
  force_destroy = local.force_destroy
}

resource "minio_s3_bucket_versioning" "this" {
  count  = local.versioning ? 1 : 0
  bucket = minio_s3_bucket.this.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "minio_s3_bucket_quota" "this" {
  count  = local.quota_gib > 0 ? 1 : 0
  bucket = minio_s3_bucket.this.bucket
  quota  = local.quota_gib * 1073741824
  type   = "hard"
}

resource "minio_s3_bucket_lifecycle" "this" {
  count  = length(local.lifecycle_rules) > 0 ? 1 : 0
  bucket = minio_s3_bucket.this.bucket

  dynamic "rule" {
    for_each = local.lifecycle_rules
    content {
      id = rule.value.id

      dynamic "filter" {
        for_each = lookup(rule.value, "prefix", "") != "" ? [rule.value.prefix] : []
        content {
          prefix = filter.value
        }
      }

      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration_days", 0) > 0 ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = lookup(rule.value, "abort_incomplete_days", 0) > 0 ? [rule.value.abort_incomplete_days] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# IAM: user + policy scoped to this bucket
# ---------------------------------------------------------------------------

resource "minio_iam_user" "this" {
  name          = var.bucket
  force_destroy = true
}

resource "minio_iam_policy" "this" {
  name = var.bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
        ]
        Resource = minio_s3_bucket.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = "${minio_s3_bucket.this.arn}/*"
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "this" {
  user_name   = minio_iam_user.this.name
  policy_name = minio_iam_policy.this.id
}
