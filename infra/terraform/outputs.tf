output "ec2_public_ip" {
  value = var.enable_eip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip
}

output "ssh_user" {
  value = "ubuntu"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app_storage.bucket
}