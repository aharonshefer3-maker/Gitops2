resource "aws_security_group" "k3s_sg" {
  vpc_id      = var.vpc_id
  name        = "sg_k3s_${var.env_name}"
  description = "Security group for K3s cluster with Ingress support"

  # --- Ingress Rules (Traffic Incoming) ---

  # 1. Standard Web Traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  # 2. Management & API
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Suggested: limit to your IP
    description = "SSH access"
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "K3s API Server"
  }

  # 3. Application Internal Ports (The fix for your issue)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    self        = true
    description = "QuakeWatch internal port"
  }

  ingress {
    from_port   = var.redis_port
    to_port     = var.redis_port
    protocol    = "tcp"
    self        = true
    description = "Redis internal port"
  }

  # 4. NodePorts (External Access)
  ingress {
    from_port   = 30007
    to_port     = 30007
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ArgoCD UI"
  }

  ingress {
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana Dashboards"
  }

  ingress {
    from_port   = 30002
    to_port     = 30002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus UI"
  }

  ingress {
    from_port   = 30085
    to_port     = 30085
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "QuakeWatch External Access"
  }

  # 5. Internal Cluster Networking (Flannel/VXLAN)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Allow all internal cluster traffic"
  }

  # Required for K3s multi-node networking
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
    description = "K3s Flannel VXLAN"
  }

  # --- Egress Rules (Traffic Outgoing) ---

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "sg-k3s-${var.env_name}"
  }
}

output "k3s_sg_id" {
  value       = aws_security_group.k3s_sg.id
  description = "The ID of the security group for use in the compute module"
}