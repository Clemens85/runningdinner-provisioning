variable "instance_type" {
  type = "string"
  default = "t3.micro"
}

variable "region" {
  type = "string"
  default = "eu-central-1"
}

variable "az" {
  type = "list"
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "s3_bucket_name" {
  type = "string"
  default = "runyourdinner"
}
