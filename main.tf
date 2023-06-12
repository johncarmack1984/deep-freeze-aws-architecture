terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.52.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.1.0"

  cloud {
    organization = "john-carmack"

    workspaces {
      name = "migrate-to-s3-deep-storage-for-business"
    }
  }
}

# resource "aws_iam_role" "s3_role" {
#   name = "S3FullAccessRole"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy" "s3_policy" {
#   name = "S3FullAccessPolicy"
#   role = aws_iam_role.s3_role.id

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": [
#         "s3:*"
#       ],
#       "Resource": [
#         "arn:aws:s3:::${var.aws_config.bucket}/*"
#       ]
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_instance_profile" "s3_instance_profile" {
#   name = "S3InstanceProfile"
#   role = aws_iam_role.s3_role.name
# }

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_pair.name
  public_key = var.key_pair.public_key
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# resource "aws_instance" "web" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = "t2.micro"
#   vpc_security_group_ids      = [aws_security_group.web-sg.id]
#   key_name                    = aws_key_pair.key_pair.key_name
#   associate_public_ip_address = true

#   root_block_device {
#     volume_size = var.aws_config.volume_size
#   }

#   iam_instance_profile = aws_iam_instance_profile.s3_instance_profile.name

#   user_data = <<-EOF
#                 #!/bin/bash
#                 apt-get update
#                 apt-get install -y apache2
#                 sed -i -e 's/80/8080/' /etc/apache2/ports.conf
#                 echo "Hello World" > /var/www/html/index.html
#                 systemctl restart apache2                
#                 EOF

# }

# resource "aws_s3_bucket" "bucket" {
#   bucket = var.aws_config.bucket
# }
