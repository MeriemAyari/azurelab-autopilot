output "location" {
  value = var.location
}

output "resource_group_name" {
  value = var.resource_group_name
}

output "environment" {
  value = var.environment
}

output "vm_name" {
  value = var.test_vm_config.name
}

output "vm_private_ip" {
  value = var.test_vm_config.private_ip
}

output "vm_size" {
  value = var.test_vm_config.size
}