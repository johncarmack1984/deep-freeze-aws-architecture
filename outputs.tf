output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.dropvault.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.dropvault.public_ip
}

output "instance_public_dns" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.dropvault.public_dns
}

output "ssh_command" {
  description = "Command to use to SSH to the instance"
  value       = "ssh -i <path-to-private-ssh-key> ubuntu@${aws_instance.dropvault.public_dns}"
}
