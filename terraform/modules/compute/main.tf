# IAM Role for K3s Instance (S3 and SSM Access)
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

# Attach S3 Full Access Policy to IAM Role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Attach SSM Core Managed Policy for Session Manager Access
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance Profile linking to IAM Role
resource "aws_iam_instance_profile" "k3s_profile" {
  name = "k3s-instance-profile-${var.env_name}"
  role = aws_iam_role.k3s_role.name
}

# EC2 Instance Resource Definition
resource "aws_instance" "k3s_node" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name

  # Attach IAM instance profile for S3 & SSM
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system packages and install base utilities
    apt-get update -y
    apt-get install -y unzip curl wget

    # --- Install K3s Service ---
    curl -sfL https://get.k3s.io | sh -s -
    systemctl enable --now k3s

    # --- Install & Configure Promtail ---
    PROM_VERSION="2.9.4"
    wget -q "https://github.com/grafana/loki/releases/download/v\${PROM_VERSION}/promtail-linux-amd64.zip"
    unzip -o promtail-linux-amd64.zip
    mv promtail-linux-amd64 /usr/local/bin/promtail
    chmod +x /usr/local/bin/promtail

    # Generate Promtail Configuration
    mkdir -p /etc/promtail
    cat <<EOT > /etc/promtail/config.yaml
server:
  http_listen_port: 9080
clients:
  - url: ${var.loki_url}
    basic_auth:
      username: "${var.loki_user}"
      password: "${var.grafana_token}"
scrape_configs:
- job_name: system
  static_configs:
  - targets: [localhost]
    labels:
      job: varlogs
      env: ${var.env_name}
      __path__: /var/log/*.log
EOT

    # Create Promtail systemd unit
    cat <<EOT > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail Log Collector Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOT

    # Load and start Promtail service
    systemctl daemon-reload
    systemctl enable --now promtail
  EOF

  tags = {
    Name = "k3s-${var.env_name}"
  }
}

# Output EC2 Public IP
output "public_ip" {
  value       = aws_instance.k3s_node.public_ip
  description = "Public IP address of the K3s server"
}