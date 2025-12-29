output "app_port" {
  value = var.app_port
}

output "public_instance_id" {
  value = aws_instance.public.id
}

output "public_instance_arn" {
  value = aws_instance.public.arn
}

output "public_instance_public_ip" {
  value = aws_instance.public.public_ip
}

output "public_instance_private_ip" {
  value = aws_instance.public.private_ip
}

output "private_instance_id" {
  value = aws_instance.private.id
}

output "private_instance_arn" {
  value = aws_instance.private.arn
}

output "private_instance_private_ip" {
  value = aws_instance.private.private_ip
}

output "ssh_private_key_file" {
  value = local_file.private_key_pem.filename
}