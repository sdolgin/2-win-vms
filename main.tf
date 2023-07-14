terraform {
  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.5.0"
    }
  }
 }

 provider "azurerm" {
   features {}
   subscription_id = var.subscription_id
 }

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "test" {
  name     = "rg-winvm-demo"
  location = "North Central US"
}

resource "azurerm_virtual_network" "test" {
  name                = "vnet-winvm-demo"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_subnet" "test" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "bastion" {
  name               = "AzureBastionSubnet"  
  resource_group_name = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_network_interface" "test" {
  count               = 2
  name                = "nic-winvm-demo-${count.index}"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                          = "primaryIp"
    subnet_id                     = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
  }
 }

resource "azurerm_virtual_machine" "test" {
  count                 = 2
  name                  = "vm-win-demo-${count.index}"
  location              = azurerm_resource_group.test.location
  resource_group_name   = azurerm_resource_group.test.name
  network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
  vm_size               = "Standard_B2s"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "staging"
  }
}