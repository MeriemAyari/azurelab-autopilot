variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "admin_username" {
  type      = string
  sensitive = true
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
}

variable "vm_config" {
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