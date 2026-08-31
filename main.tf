terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Look up the latest official Ubuntu 22.04 AMI instead of hardcoding an ID
# that will eventually go stale or not exist in this region.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (official Ubuntu publisher)

  filter {
    name   = "name"
    values = [var.ubuntu_ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Both ingress rules below deliberately allow 0.0.0.0/0:
#   - HTTP (80): this is a public web server by design — that's correct,
#     not a misconfiguration.
#   - SSH (22): defaults open for zero-friction first-time use in a demo
#     repo. Restrict it via `allowed_ssh_cidr` in terraform.tfvars for
#     anything beyond a throwaway exercise (see README "Security notes").
#trivy:ignore:AVD-AWS-0107
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH and HTTP access"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress is intentionally unrestricted: the instance needs outbound
  # internet access during boot to run `apt-get update`/`apt-get install
  # docker.io` and to pull the app image from GHCR via user_data. Narrowing
  # this would require a curated allowlist of package-mirror and registry
  # IPs, which is impractical and fragile for a demo.
  #trivy:ignore:AVD-AWS-0104
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_instance" "demo_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Require IMDSv2 (session-token-based metadata access) instead of the
  # optional v1 default — closes a well-known SSRF-to-credential-theft path.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  # Encrypt the root EBS volume at rest.
  root_block_device {
    encrypted = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    project_name = var.project_name
    docker_image = var.docker_image
    app_api_key  = var.app_api_key
  })

  tags = {
    Name = "${var.project_name}-instance"
  }
}
