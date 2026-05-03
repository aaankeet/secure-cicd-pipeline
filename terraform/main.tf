terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Example of a BAD BUCKET, NO VERSIOING & NO BLOCK PUBLIC ACCESS
# resource "aws_s3_bucket" "bad" {
#   bucket = "my-public-bucket"
# }

# Example of a Secure Bucket
resource "aws_s3_bucket" "secured_s3" {
  bucket = "secured-s3-bucket"
}
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.secured_s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
