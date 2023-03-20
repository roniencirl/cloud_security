data "azurerm_client_config" "current" {}



resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}
# Create virtual network
resource "azurerm_virtual_network" "mediawiki_network" {
  name                = "mediawikiVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "mediawiki_subnet" {
  name                 = "mediawikiSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mediawiki_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "mediawiki_public_ip" {
  name                = "mediawikiPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "mediawiki_nsg" {
  name                = "mediawikiNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "mediawiki_nic" {
  name                = "mediawikiNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mediawiki_nic_configuration"
    subnet_id                     = azurerm_subnet.mediawiki_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mediawiki_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.mediawiki_nic.id
  network_security_group_id = azurerm_network_security_group.mediawiki_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mediawiki_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Accept Bitnami agreement 
resource "azurerm_marketplace_agreement" "mediawiki_bitnami" {
  publisher = "bitnami"
  offer     = "mediawiki"
  plan      = "hourly"
}
# Create virtual machine
resource "azurerm_linux_virtual_machine" "mediawiki_vm" {
  name                  = "mediawikiVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.mediawiki_nic.id]
  size                  = "Standard_B1ls"

  os_disk {
    name                 = "mediawikiOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  /*
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
*/
  source_image_reference {
    publisher = "bitnami"
    offer     = "mediawiki"
    sku       = "1-26"
    version   = "latest"
  }
  plan {
    name      = "1-26"
    publisher = "bitnami"
    product   = "mediawiki"
  }

  computer_name                   = "mediawikivm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }
  depends_on = [
    azurerm_marketplace_agreement.mediawiki_bitnami
  ]

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mediawiki_storage_account.primary_blob_endpoint
  }

}


# database

/*
resource "azurerm_mysql_server" "mediawiki" {
  name                = "mediawiki-mysqlserver"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = "dbadmin"
  administrator_login_password = azurerm_key_vault_secret.mediawikidb.value

  sku_name   = "B_Gen4_1"
  storage_mb = 20480
  version    = "5.7"

  auto_grow_enabled                 = false
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false # not supported on basic tier
  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"

  # TODO: Threat detection policy
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mysql_server
  # threat_detection_policy {
  #   enabled = true
  #}

}

resource "azurerm_subnet" "mysqldbsubnet" {
  name                 = "mysqldbsubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mediawiki_network.name
  address_prefixes     = ["10.1.0.0/24"]
  service_endpoints = []
}

*/