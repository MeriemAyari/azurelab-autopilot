variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_address_space" { type = list(string) }
variable "subnet_configs" { type = map(object({ address_prefix = string })) }
variable "dns_servers" { type = list(string) }
variable "tags" { type = map(string) }