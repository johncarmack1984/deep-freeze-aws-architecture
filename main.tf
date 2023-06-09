variable "aws_config" {
  type = object({
    region      = string
    bucket      = string
    volume_size = number
  })
}

terraform {
  cloud {
    organization = "john-carmack"
    workspaces {
      name = "migrate-to-s3-deep-storage-for-business"
    }
  }
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_config.region
}

resource "aws_iam_role" "s3_role" {
  name = "S3FullAccessRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "S3FullAccessPolicy"
  role = aws_iam_role.s3_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${var.aws_config.bucket}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "s3_instance_profile" {
  name = "S3InstanceProfile"
  role = aws_iam_role.s3_role.name
}

resource "aws_instance" "ec2_instance" {
  ami           = "ami-0a91cd140a1fc148a" # Ubuntu Server 18.04 LTS AMI
  instance_type = "t2.micro"

  root_block_device {
    volume_size = var.aws_config.volume_size
  }

  iam_instance_profile = aws_iam_instance_profile.s3_instance_profile.name

  user_data = <<-EOF
                #!/bin/bash
                apt-get update
                apt-get install -y jq
                apt-get install -y apache2
                sed -i -e 's/80/8080/' /etc/apache2/ports.conf
                echo "Hello World" > /var/www/html/index.html
                systemctl restart apache2                
                EOF

  tags = {
    Name = "ec2-dropbox-sync"
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.aws_config.bucket
}

resource "aws_s3_bucket_acl" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}
