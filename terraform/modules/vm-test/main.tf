resource "azurerm_public_ip" "vm" {
  count               = var.vm_config.enable_public_ip ? 1 : 0
  name                = "pip-${var.vm_config.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.vm_config.name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig-01"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm_config.private_ip
    public_ip_address_id          = var.vm_config.enable_public_ip ? azurerm_public_ip.vm[0].id : null
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = var.vm_config.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_config.size

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [azurerm_network_interface.vm.id]

  os_disk {
    name                 = "osdisk-${var.vm_config.name}"
    caching              = "ReadWrite"
    storage_account_type = var.vm_config.os_disk_type
    disk_size_gb         = var.vm_config.os_disk_size
  }

  source_image_reference {
    publisher = var.vm_config.image.publisher
    offer     = var.vm_config.image.offer
    sku       = var.vm_config.image.sku
    version   = var.vm_config.image.version
  }

  enable_automatic_updates = false
  patch_mode               = "Manual"
  tags                     = var.tags
}

resource "azurerm_managed_disk" "data" {
  count                = var.vm_config.data_disk_size > 0 ? 1 : 0
  name                 = "datadisk-${var.vm_config.name}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.vm_config.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.vm_config.data_disk_size
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count              = var.vm_config.data_disk_size > 0 ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.data[0].id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = 0
  caching            = "None"
}