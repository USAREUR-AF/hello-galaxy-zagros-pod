# main.tf — minimal IaC to stand up ONE Linux box that runs the Velmara moon-pod
# router and peers it into a live goatnet's fabric.
#
# Deliberately generic + partner-safe:
#   - no account id, VPC id, AMI id, subnet id, or region baked in (all data-sourced
#     or variables);
#   - no secrets anywhere (the signed bundle + mesh setup-key are delivered to the
#     instance out-of-band after apply, never through Terraform/state);
#   - state, tfvars, and the generated SSH key are gitignored.
#
# What it creates: one EC2 instance in the default VPC with an egress-open security
# group (the pod DIALS OUT to the fabric; it is never dialled into) and SSH limited
# to your IP. cloud-init installs docker + netbird + a Zenoh client. You then run
# pod-up.sh on the box to enroll + start the pod router. See README.md.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" {
  region = var.region
}

# --- generic, account-agnostic lookups (nothing hardcoded) ----------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Canonical Ubuntu 24.04 LTS, resolved per-region from the public SSM parameter —
# no AMI id committed.
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/${var.arch}/hvm/ebs-gp3/ami-id"
}

# --- an ephemeral SSH keypair, generated here (no pre-existing key needed) -------
# Private key is written to a gitignored local file; never committed.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  key_name_prefix = "${var.name_prefix}-"
  public_key      = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "ssh_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/.ssh/${var.name_prefix}.pem"
  file_permission = "0600"
}

# --- security group: egress-all (enrollment + fabric dial-out), SSH from you -----
resource "aws_security_group" "pod" {
  name_prefix = "${var.name_prefix}-"
  description = "moon-pod demo: egress all (dial-out to mesh + fabric); SSH from operator only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "all outbound (mesh enrollment via relays + fabric dial-out)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = var.name_prefix }
}

resource "aws_instance" "pod" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.pod.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/cloud-init.yaml")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = {
    Name    = var.name_prefix
    Purpose = "hello-galaxy-zagros-pod router-to-router demo (ephemeral; destroy after)"
  }
}
