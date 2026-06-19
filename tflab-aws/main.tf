terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = {
    owner = var.participant_name
    lab   = "ailab"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "vpc-ailab"
  })
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "snet-app"
  })
}

resource "aws_subnet" "db" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "snet-db"
  })
}

resource "aws_subnet" "access" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.3.0/27"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "snet-access"
  })
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "igw-ailab"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "eip-nat-ailab"
  })
}

resource "aws_nat_gateway" "lab" {
  subnet_id     = aws_subnet.access.id
  allocation_id = aws_eip.nat.id

  tags = merge(local.common_tags, {
    Name = "nat-ailab"
  })

  depends_on = [aws_internet_gateway.lab]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = merge(local.common_tags, {
    Name = "rt-public"
  })
}

resource "aws_route_table_association" "access" {
  subnet_id      = aws_subnet.access.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab.id
  }

  tags = merge(local.common_tags, {
    Name = "rt-private"
  })
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "eic_endpoint" {
  name        = "sg-eic-endpoint"
  description = "Access to EC2 Instance Connect Endpoint"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH via EIC endpoint"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  ingress {
    description = "RDP tunnel via EIC endpoint"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "sg-eic-endpoint"
  })
}

resource "aws_ec2_instance_connect_endpoint" "lab" {
  subnet_id          = aws_subnet.access.id
  security_group_ids = [aws_security_group.eic_endpoint.id]

  tags = merge(local.common_tags, {
    Name = "eice-ailab"
  })
}

resource "aws_security_group" "app" {
  name        = "sg-app"
  description = "App Linux access from EIC endpoint"
  vpc_id      = aws_vpc.lab.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.eic_endpoint.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "sg-app"
  })
}

resource "aws_security_group" "db" {
  name        = "sg-db"
  description = "DB access from app subnet"
  vpc_id      = aws_vpc.lab.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.eic_endpoint.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "sg-db"
  })
}

resource "aws_security_group" "win" {
  name        = "sg-win"
  description = "Windows VM access from EIC endpoint"
  vpc_id      = aws_vpc.lab.id

  ingress {
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [aws_security_group.eic_endpoint.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "sg-win"
  })
}

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["801119661308"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.app.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  private_ip                  = "10.0.1.10"
  associate_public_ip_address = false

  user_data = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - ec2-instance-connect
    users:
      - default
      - name: labadmin
        groups: [sudo]
        lock_passwd: false
        shell: /bin/bash
        sudo: ["ALL=(ALL) NOPASSWD:ALL"]
        plain_text_passwd: "${var.admin_password}"
    ssh_pwauth: true
  EOT

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "vm-app"
  })
}

resource "aws_instance" "db" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.db.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  private_ip                  = "10.0.2.10"
  associate_public_ip_address = false
  user_data                   = file("${path.module}/cloud-init-db.yaml")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "vm-db"
  })
}

resource "aws_instance" "win" {
  ami                         = data.aws_ami.windows_2022.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.app.id
  vpc_security_group_ids      = [aws_security_group.win.id]
  private_ip                  = "10.0.1.20"
  associate_public_ip_address = false

  user_data = <<-EOT
    <powershell>
      net user Administrator "${var.admin_password}"
      Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
    </powershell>
  EOT

  root_block_device {
    volume_size = 128
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "vm-win"
  })
}

resource "aws_s3_bucket" "lab" {
  bucket        = "stailab-${var.participant_name}-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "stailab"
  })
}

resource "aws_s3_bucket_versioning" "lab" {
  bucket = aws_s3_bucket.lab.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lab" {
  bucket = aws_s3_bucket.lab.id

  rule {
    id     = "retention"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
