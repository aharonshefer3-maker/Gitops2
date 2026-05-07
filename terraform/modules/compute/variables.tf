variable "env_name" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "sg_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "ami_id" {}
variable "loki_user" {}
variable "grafana_token" {}
variable "loki_url" {}
variable "s3_bucket_name" {
  type        = string
  description = "The name of the existing S3 bucket"
}