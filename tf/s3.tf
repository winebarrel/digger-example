resource "aws_s3_bucket" "digger" {
  bucket = "winebarrel-digger-example"
}

resource "aws_s3_bucket_public_access_block" "digger" {
  bucket = aws_s3_bucket.digger.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "digger" {
  bucket = aws_s3_bucket.digger.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
