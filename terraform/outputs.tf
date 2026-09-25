output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "frontend_url" {
  value = "http://${aws_instance.app_server.public_ip}:3000"
}

output "backend_url" {
  value = "http://${aws_instance.app_server.public_ip}:5000"
}

output "jenkins_url" {
  value = "http://${aws_instance.app_server.public_ip}:8080"
}
