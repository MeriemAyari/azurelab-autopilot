output "vm_name" { value = azurerm_windows_virtual_machine.vm.name }
output "private_ip" { value = azurerm_network_interface.vm.private_ip_address }
output "public_ip" { value = var.vm_config.enable_public_ip ? azurerm_public_ip.vm[0].ip_address : null }