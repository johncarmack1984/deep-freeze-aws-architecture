variable "aws_config" {
  type = object({
    region      = string
    bucket      = string
    volume_size = number
  })
}
variable "key_pair" {
  type = object({
    name       = string
    public_key = string
  })
}
variable "ami_name" {
  type    = string
  default = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}
variable "ami_id" {
  type    = string
  default = "ami-0f8e81a3da6e2510a"
}
