output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.demo_server.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.demo_server.public_ip
}

output "test_url" {
  description = "URL to open once the instance has finished booting (allow ~30-60s for user_data to run)"
  value       = "http://${aws_instance.demo_server.public_ip}"
}
