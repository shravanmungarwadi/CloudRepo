output "ec2_public_ip" {
  value = aws_eip.app.public_ip
}

output "ssh_user" {
  value = "ubuntu"
}
