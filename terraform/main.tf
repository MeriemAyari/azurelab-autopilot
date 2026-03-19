terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  common_tags = {
    Project     = "AzureLab-Autopilot"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "MeriemAyari"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.location
  vnet_address_space  = var.vnet_address_space
  subnet_configs      = var.subnet_configs
  dns_servers         = var.dns_servers
  tags                = local.common_tags
}

module "vm_test" {
  source              = "./modules/vm-test"
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.location
  subnet_id           = module.networking.subnet_ids["snet-test"]

  vm_config      = var.test_vm_config
  admin_username = var.admin_username
  admin_password = var.admin_password
  tags           = local.common_tags
}