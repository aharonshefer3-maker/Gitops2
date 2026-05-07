variable "aws_region" {
  default = "us-east-1"
}

variable "env_name" {
  default = "test"
}

variable "ami_id" {
  default = "ami-053b0d53c279acc90" # Ubuntu 22.04
}

variable "key_name" {
  type = string
}

variable "my_ip" {
  type = string
}

variable "loki_url" {
  type = string
}

variable "loki_user" {
  type = string
}

variable "grafana_token" {
  type      = string
  sensitive = true
}
variable "availability_zone" {
  type      = string
  sensitive = true
  default     = "us-east-1a"
}