variable "vpc_id" {}
variable "env_name" {}
variable "my_ip" {}
variable "redis_port" {
  type    = number
  default = 6379
  description = "Centralized port for Redis"
}