output "instance-id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "public-ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "web-address" {
  value = "${aws_instance.app_server.public_dns}:8080"
}
