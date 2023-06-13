resource "aws_instance" "test-ec2-instance" {
  ami             = var.ami_id
  instance_type   = "t2.micro"
  key_name        = var.key_pair.name
  security_groups = ["${aws_security_group.ingress-all-test.id}"]
  tags = {
    Name = "ami-0f8e81a3da6e2510a"
  }
  subnet_id = aws_subnet.subnet-uno.id
}
