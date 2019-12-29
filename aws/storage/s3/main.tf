provider "aws" {
  region = var.region
  version = "2.33"
}

terraform {
  backend "s3" {
    bucket = "runyourdinner-terraform-backend"
    key = "storage/s3/state.tfstate"
    region = "eu-central-1"
  }
}

data "aws_iam_user" "technical-user" {
  user_name = "technical-user"
}
data "aws_iam_user" "clemens-stich-dev" {
  user_name = "clemens-stich-dev"
}

resource "aws_s3_bucket" "runyourdinner-s3-bucket" {
  bucket = var.s3_bucket_name
  acl    = "private"
  tags = {
    Name = "runyourdinner-s3-bucket"
    Service = "runyourdinner"
  }

  policy = <<POLICY
{
  "Id": "Policy1572622065147",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1572622052716",
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${var.s3_bucket_name}/*",
      "Principal": {
        "AWS": [
          "${data.aws_iam_user.clemens-stich-dev.arn}",
          "${data.aws_iam_user.technical-user.arn}"
        ]
      }
    }
  ]
}
  POLICY
}
