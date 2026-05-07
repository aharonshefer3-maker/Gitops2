module "network" {
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  source   = "../../modules/vpc"
  env_name = var.env_name
  availability_zone = var.availability_zone
}

module "security" {
  source   = "../../modules/security"
  vpc_id   = module.network.vpc_id
  env_name = var.env_name
  my_ip    = var.my_ip
}

module "compute" {
  source         = "../../modules/compute"
  env_name       = var.env_name
  vpc_id         = module.network.vpc_id
  subnet_id      = module.network.public_subnet_id
  sg_id          = module.security.k3s_sg_id
  key_name       = var.key_name
  ami_id         = var.ami_id
  instance_type  = "c7i-flex.large" # חזק בלי סוואפ

  s3_bucket_name = "as-bucket3b1111"

  # משתנים עבור לוגים ב-User Data
  loki_url       = var.loki_url
  loki_user      = var.loki_user
  grafana_token  = var.grafana_token
}
