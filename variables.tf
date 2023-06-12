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
  type = string
}
variable "ami_id" {
  type = string
}
