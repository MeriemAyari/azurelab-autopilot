location            = "westeurope"
resource_group_name = "azurelab-rg"
environment         = "lab"
admin_username      = "xxxxxxxxxxxxx"
admin_password      = "xxxxxxxxxxxxxxxxxx"

vnet_address_space = ["10.0.0.0/16"]
subnet_configs = {
  snet-test = {
    address_prefix = "10.0.1.0/24"
  }
}

dns_servers = ["10.0.1.10", "168.63.129.16"]

test_vm_config = {
  name             = "vm-test01"
  size             = "Standard_B1s"
  private_ip       = "10.0.1.10"
  os_disk_size     = 128
  os_disk_type     = "Standard_LRS"
  data_disk_size   = 0
  data_disk_type   = "Standard_LRS"
  enable_public_ip = true
  image = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}
