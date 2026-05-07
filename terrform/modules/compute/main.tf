# 1. IAM Role -
#  ל-S3 ) ול-SSM
resource "aws_iam_role" "k3s_role" {
  name = "k3s-access-role-${var.env_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# -S3 -
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# -SSM - מאפשרת לך להיכנס לשרת דרך הדפדפן גם כשה-IP שלך משתנה
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "k3s-instance-profile-${var.env_name}"
  role = aws_iam_role.k3s_role.name
}

# 2. (EC2)
resource "aws_instance" "k3s_node" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name

  #
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y unzip curl

    # ---  Promtail ( ---
    PROM_VERSION="2.9.4"
    wget https://github.com/grafana/loki/releases/download/v$${PROM_VERSION}/promtail-linux-amd64.zip
    unzip promtail-linux-amd64.zip
    mv promtail-linux-amd64 /usr/local/bin/promtail

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

    cat <<EOT > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail
[Service]
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yaml
Restart=always
[Install]
WantedBy=multi-user.target
EOT
    systemctl daemon-reload
    systemctl enable promtail
    systemctl start promtail

    # --- התקנת K3s ---
    curl -sfL https://get.k3s.io | sh -s -
  EOF

  tags = {
    Name = "k3s-${var.env_name}"
  }
}

output "public_ip" {
  value = aws_instance.k3s_node.public_ip
}
