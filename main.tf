terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.98.0"
    }
  }
  required_version = ">= 1.12.0"
}

provider "aws" {
  region = "ap-northeast-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cnd-handson-vpc"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.16.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cnd-handson-public-subnet"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cnd-handson-igw"
  }
}

# ルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "cnd-handson-public-rt"
  }
}

# ルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# セキュリティグループ
resource "aws_security_group" "allow_ports" {
  name        = "cnd-handson-secgroup"
  description = "CND handson security group"
  vpc_id      = aws_vpc.main.id

  # 必要なポートを開放
  dynamic "ingress" {
    for_each = [22, 80, 443, 8080, 8443, 18080, 18443, 28080, 28443]
    content {
      description = "Allow port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cnd-handson-secgroup"
  }
}

# キーペア
resource "tls_private_key" "main" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "main" {
  key_name   = "cnd-handson-key"
  public_key = tls_private_key.main.public_key_openssh
}

resource "local_file" "main" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${path.module}/cnd-handson-key.pem"
  file_permission = "0600"
}

# EC2インスタンス
resource "aws_instance" "main" {
  ami           = "ami-0162fe8bfebb6ea16"
  instance_type = "t2.xlarge"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 50
  }

  vpc_security_group_ids = [aws_security_group.allow_ports.id]

  tags = {
    Name = "cnd-handson-vm"
  }
}

# 出力
output "public_ip" {
  value       = aws_instance.main.public_ip
  description = "The public IP address of the instance"
}
