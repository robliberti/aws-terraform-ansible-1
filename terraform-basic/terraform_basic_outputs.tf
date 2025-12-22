# Root outputs to support Ansible inventory generation.
# Place this file in terraform-basic/outputs.tf

output "public_instance_public_ip" {
  value = module.compute.public_instance_public_ip
}

output "public_instance_private_ip" {
  value = module.compute.public_instance_private_ip
}

output "private_instance_private_ip" {
  value = module.compute.private_instance_private_ip
}

output "ssh_private_key_file" {
  value     = module.compute.ssh_private_key_file
  sensitive = true
}
