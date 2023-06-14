resource "aws_key_pair" "key_pair" {
  key_name   = var.key_pair.name
  public_key = var.key_pair.public_key
}

