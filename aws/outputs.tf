output "public_ip" {
  value       = aws_instance.runyourdinner-appserver.public_ip
  description = "The public IP of the app server"
}

output "elastic_ip" {
  value       = aws_eip.runyourdinner-eip.public_ip
  description = "The elastic ip"
}
