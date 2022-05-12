terraform {

   required_version = ">=0.12"

   required_providers {
     azurerm = {
       source = "hashicorp/azurerm"
       version = "~>2.0"
     }
   }
 }

 provider "azurerm" {
   features {}
 }

data "azurerm_client_config" "current" {}

data "azurerm_policy_set_definition" "enable_azure_monitor" {
  display_name = "Enable Azure Monitor for VMs"
}

 resource "azurerm_resource_group" "test" {
   name     = "rg-winvm-demo"
   location = "East US 2"
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

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "test" {
  name                = "bastion-winvm-demo"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

 resource "azurerm_network_interface" "test" {
   count               = 2
   name                = "nic-winvm-demo-${count.index}"
   location            = azurerm_resource_group.test.location
   resource_group_name = azurerm_resource_group.test.name

   ip_configuration {
     name                          = "testConfiguration"
     subnet_id                     = azurerm_subnet.test.id
     private_ip_address_allocation = "dynamic"
   }
 }

 resource "azurerm_managed_disk" "test" {
   count                = 2
   name                 = "datadisk_existing_${count.index}"
   location             = azurerm_resource_group.test.location
   resource_group_name  = azurerm_resource_group.test.name
   storage_account_type = "Premium_LRS"
   create_option        = "Empty"
   disk_size_gb         = "1023"
 }

 resource "azurerm_availability_set" "avset" {
   name                         = "avset"
   location                     = azurerm_resource_group.test.location
   resource_group_name          = azurerm_resource_group.test.name
   platform_fault_domain_count  = 2
   platform_update_domain_count = 2
   managed                      = true
 }

 resource "azurerm_virtual_machine" "test" {
   count                 = 2
   name                  = "vm-win-demo-${count.index}"
   location              = azurerm_resource_group.test.location
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = azurerm_resource_group.test.name
   network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
   vm_size               = "Standard_DS2_v2"

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
     managed_disk_type = "Premium_LRS"
   }

   storage_data_disk {
     name            = element(azurerm_managed_disk.test.*.name, count.index)
     managed_disk_id = element(azurerm_managed_disk.test.*.id, count.index)
     create_option   = "Attach"
     lun             = 1
     disk_size_gb    = element(azurerm_managed_disk.test.*.disk_size_gb, count.index)
   }

   os_profile {
     computer_name  = "hostname"
     admin_username = "testadmin"
     admin_password = "Password1234!"
   }

   os_profile_windows_config {
     provision_vm_agent = true
   }

   tags = {
     environment = "staging"
   }
 }

 resource "azurerm_key_vault" "test" {
    name                = "kv-winvm-demo"
    location            = azurerm_resource_group.test.location
    resource_group_name = azurerm_resource_group.test.name
    sku_name            = "standard"
    tenant_id           = "${data.azurerm_client_config.current.tenant_id}"
    enabled_for_disk_encryption = true
    purge_protection_enabled = true
 }

resource "azurerm_log_analytics_workspace" "test" {
  name                = "workspace-winvm-demo"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_resource_group_policy_assignment" "test" {
  name                 = "${data.azurerm_policy_set_definition.enable_azure_monitor.display_name}"
  resource_group_id    = azurerm_resource_group.test.id
  policy_definition_id = "${data.azurerm_policy_set_definition.enable_azure_monitor.id}"

  parameters = <<PARAMS
    {
      "logAnalytics_1": {
        "value": "${azurerm_log_analytics_workspace.test.id}"
      }
    }
PARAMS
}