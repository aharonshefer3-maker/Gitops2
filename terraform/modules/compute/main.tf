# IAM Role Definition for K3s Instance
resource "aws_iam_role" "k3s_role" {
  name = "k3s-access-role-${var.env_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach S3 Full Access Policy
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Attach SSM Managed Policy for AWS Systems Manager Session Access
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile Linking IAM Role to EC2
resource "aws_iam_instance_profile" "k3s_profile" {
  name = "k3s-instance-profile-${var.env_name}"
  role = aws_iam_role.k3s_role.name
}

# EC2 Compute Instance Resource
resource "aws_instance" "k3s_node" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name

  # Attach IAM instance profile
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    env_name      = var.env_name
    loki_url      = var.loki_url
    loki_user     = var.loki_user
    grafana_token = var.grafana_token
    argocd_node_port=var.argocd_node_port
  })

  tags = {
    Name = "k3s-${var.env_name}"
  }
}

# Output Node Public IP
output "public_ip" {
  value       = aws_instance.k3s_node.public_ip
  description = "Public IP of the provisioned K3s node"
}