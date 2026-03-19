variable "location" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "lab"
}

variable "admin_username" {
  type      = string
  sensitive = true
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnet_configs" {
  type = map(object({
    address_prefix = string
  }))
}

variable "dns_servers" {
  type    = list(string)
  default = ["168.63.129.16"]
}

variable "test_vm_config" {
  type = object({
    name             = string
    size             = string
    private_ip       = string
    os_disk_size     = number
    os_disk_type     = string
    data_disk_size   = number
    data_disk_type   = string
    enable_public_ip = bool
    image = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
  })
}