provider "aws" {
  region = "us-west-1"
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
        "arn:aws:s3:::vegify-dropbox-archive/*"
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
    volume_size = 3000 # 3TB
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
  bucket = "vegify-dropbox-archive"
}

resource "aws_s3_bucket_acl" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}
