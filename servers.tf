resource "aws_instance" "dropvault" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_pair.name
  security_groups        = ["${aws_security_group.ingress-all-test.id}"]
  vpc_security_group_ids = ["${aws_security_group.ingress-all-test.id}"]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y w3m xdg-tools mailcap www-browser
              EOF

  # provisioner "file" {
  #   source      = "~/.aws/config"
  #   destination = "/home/ubuntu/.aws/config"
  # }
  # provisioner "file" {
  #   source      = "~/.aws/credentials"
  #   destination = "/home/ubuntu/.aws/credentials"
  # }
  provisioner "file" {
    source      = "pipeline.sh"
    destination = "/home/ubuntu/pipeline.sh"
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
