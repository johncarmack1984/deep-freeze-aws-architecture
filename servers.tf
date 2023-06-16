resource "aws_instance" "dropvault" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = var.key_pair.name
  security_groups             = ["${aws_security_group.ingress-all-test.id}"]
  vpc_security_group_ids      = ["${aws_security_group.ingress-all-test.id}"]
  associate_public_ip_address = true

  provisioner "file" {
    source      = ".env"
    destination = "/home/ubuntu/.env"
    connection {
      type = "ssh"
      user = "ubuntu"
      host = self.public_ip
    }
  }
  provisioner "file" {
    source      = "pipeline.sh"
    destination = "/home/ubuntu/pipeline.sh"
    connection {
      type = "ssh"
      user = "ubuntu"
      host = self.public_ip
    }
  }

  root_block_device {
    volume_size = var.aws_config.volume_size
  }
  iam_instance_profile = aws_iam_instance_profile.s3_instance_profile.name
  tags = {
    Name = "ami-0f8e81a3da6e2510a"
  }
  subnet_id = aws_subnet.subnet-uno.id
}
