# One S3 bucket for application assets. It is private: a public access block
# refuses any public ACL or policy, objects are encrypted and versioned, and a
# bucket policy denies any request that does not use TLS.

# Accepted-risk suppressions for a single throwaway lab bucket. Each would need
# extra infrastructure that is disproportionate here; the bucket is still
# private, encrypted, versioned and TLS-only.
# trivy:ignore:AVD-AWS-0089 access logging needs a separate log bucket (which then needs its own logging); out of scope for the lab
resource "aws_s3_bucket" "assets" {
  # checkov:skip=CKV_AWS_18:Access logging needs a separate log bucket (which then needs its own logging); out of scope for a lab asset bucket.
  # checkov:skip=CKV_AWS_145:SSE-S3 is used instead of a customer-managed KMS key to avoid the ~$1/month key cost; objects are still encrypted at rest.
  # checkov:skip=CKV_AWS_144:Cross-region replication is disproportionate for a single-region throwaway lab bucket.
  # checkov:skip=CKV2_AWS_62:No event consumers (Lambda/SQS/SNS) exist in this lab, so event notifications have nowhere to go.
  bucket = "${var.name_prefix}-assets-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.name_prefix}-assets"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with an S3-managed key (SSE-S3). See the skip on the
# bucket resource for why SSE-S3 is used instead of a customer-managed KMS key.
# trivy:ignore:AVD-AWS-0132 SSE-S3 is used instead of a customer-managed KMS key to avoid the key's monthly cost; objects are still encrypted at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Deny every request that does not arrive over TLS.
data "aws_iam_policy_document" "assets_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.assets.arn, "${aws_s3_bucket.assets.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

# Clean up incomplete multipart uploads and old object versions so the bucket
# does not accumulate cost or stale data.
resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "abort-incomplete-and-expire-noncurrent"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  depends_on = [aws_s3_bucket_versioning.assets]
}

output "assets_bucket" {
  description = "Name of the S3 assets bucket."
  value       = aws_s3_bucket.assets.id
}
