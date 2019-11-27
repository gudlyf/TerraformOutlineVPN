output "public_ip" {
  value = "VPN IP Address: ${aws_instance.outline-server.public_ip}"
}

