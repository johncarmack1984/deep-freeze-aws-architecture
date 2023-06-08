variable "organization_name" {
  description = "Name of the organization in Terraform Cloud"
  type        = string
  default     = "john-carmack"
}

variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ExampleAppServerInstance"
}
