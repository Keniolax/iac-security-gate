# Add the asset bucket. (This is the INSECURE version proposed in PR A; the
# gate should reject it.)

resource "aws_s3_bucket" "assets" {
  bucket = "${var.name_prefix}-assets-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.name_prefix}-assets"
  }
}

data "aws_caller_identity" "current" {}

# Public access block turned off.
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Anonymous read of every object.
resource "aws_s3_bucket_policy" "assets_public" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.assets.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.assets]
}
