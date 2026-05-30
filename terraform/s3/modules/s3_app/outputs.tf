output "bucket" {
  description = "Bucket name"
  value       = minio_s3_bucket.this.bucket
}

output "arn" {
  description = "Bucket ARN"
  value       = minio_s3_bucket.this.arn
}

output "access_key" {
  description = "Access key (IAM username)"
  value       = minio_iam_user.this.name
}

output "secret_key" {
  description = "Secret key"
  value       = minio_iam_user.this.secret
  sensitive   = true
}
