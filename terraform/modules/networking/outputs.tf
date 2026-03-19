output "subnet_ids" {
  value = { for k, s in azurerm_subnet.subnets : k => s.id }
}