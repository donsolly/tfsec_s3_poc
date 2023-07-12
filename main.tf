# AWS Provider Configuration
provider "aws" {
  region     = "us-west-2"
  access_key = secrets.AWS_ACCESS_KEY_ID
  secret_key = secrets.AWS_SECRET_ACCESS_KEY
}

# Retrieve the identity of the account
data "aws_caller_identity" "current" {}

# Create the primary S3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "donsolly-tfsec-bucket"
  acl    = "private"

  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.mykey.arn
      }
    }
  }

  # Enable logging
  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "log/"
  }

  # Enable versioning
  versioning {
    enabled = true
  }
}

# Create the logging S3 bucket
# Ignore the tfsec rule "aws-s3-enable-bucket-logging" for this resource
# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "log_bucket" {
  bucket = "donsolly-tfsec-log-bucket"
  acl    = "private"

  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.mykey.arn
      }
    }
  }

  # Enable versioning
  versioning {
    enabled = true
  }
}

# Block public access to the primary bucket
resource "aws_s3_bucket_public_access_block" "bucket_access_block" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}

# Block public access to the logging bucket
resource "aws_s3_bucket_public_access_block" "log_bucket_access_block" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}

# KMS key to use for server-side encryption
resource "aws_kms_key" "mykey" {
  description             = "mykey"
  deletion_window_in_days = 10
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "key-default-1",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
POLICY
}
