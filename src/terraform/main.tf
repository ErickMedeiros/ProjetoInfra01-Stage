#Arquivo de provisionamento de recursos no azure ---
#Estudo de Terraform - Erick Medeiros ---
#Projeto Stage 

# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.32"
    }
  }

  required_version = ">= 0.12.13"
}

provider "azurerm" {
  features {}

}

#backup do estado 

terraform {
  backend "azurerm" {
    resource_group_name  = "RG-STO-BK"
    storage_account_name = "stobackupterraform"
    container_name       = "tfstate"
    key                  = "staging.terraform.tfstate"
  }
}


# Deploy de Recursos
# Deploy Resource Group

resource "azurerm_resource_group" "RG" {
  name     = "RG-TESTE"
  location = "eastus"
  tags = {
    "env"     = "staging"
    "project" = "estudo"
  }
}

# Deploy Storage Account
resource "azurerm_storage_account" "sto" {
  name                     = "stotestezafitec001"
  resource_group_name      = azurerm_resource_group.RG.name
  location                 = azurerm_resource_group.RG.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Deploy Azure Files
resource "azurerm_storage_share" "share" {
  name                 = "files-prd"
  storage_account_name = azurerm_storage_account.sto.name
  quota                = 10

}

# Deploy VNET
resource "azurerm_virtual_network" "vnet" {
  name                = "VNET-01"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  address_space       = ["10.10.0.0/16"]
}

# Deploy Subnet
resource "azurerm_subnet" "sub1" {
  name                 = "SUB-LAN01"
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.0.0/24"]
}

# Deploy Subnet - 02
resource "azurerm_subnet" "sub2" {
  name                 = "SUB-LAN02"
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Deploy NSG1
resource "azurerm_network_security_group" "nsg1" {
  name                = "NSG-VMs"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "10.10.0.0/24"
  }
}

# Deploy NSG2
resource "azurerm_network_security_group" "nsg2" {
  name                = "NSG-DB"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  security_rule {
    name                       = "Allow-MSSQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "*"
    destination_address_prefix = "10.11.0.0/24"
  }
}

# Associar NSG Subnet01
resource "azurerm_subnet_network_security_group_association" "nsg1" {
  subnet_id                 = azurerm_subnet.sub1.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

# Associar NSG Subnet02
resource "azurerm_subnet_network_security_group_association" "nsg2" {
  subnet_id                 = azurerm_subnet.sub2.id
  network_security_group_id = azurerm_network_security_group.nsg2.id
}

# Deploy Public IP - SRV 01
resource "azurerm_public_ip" "PIP01" {
  name                = "PIP-VM-SRV01"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  allocation_method   = "Dynamic"
}

# Deploy Public IP - SRV 02
resource "azurerm_public_ip" "PIP02" {
  name                = "PIP-VM-SRV02"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  allocation_method   = "Dynamic"
}

# Deploy NIC - SRV 01
resource "azurerm_network_interface" "vnic01" {
  name                = "nic-vm-srv01"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PIP01.id
  }
}

# Deploy NIC - SRV 02
resource "azurerm_network_interface" "vnic02" {
  name                = "nic-vm-srv02"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PIP02.id
  }
}

# Deploy VM - SRV 01
resource "azurerm_windows_virtual_machine" "vm01" {
  name                = "VM-SRV01-APP"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_B2S"
  admin_username      = "adminuser"
  admin_password      = "A1qa2ws3ed4rf5tg"
  network_interface_ids = [
    azurerm_network_interface.vnic01.id,
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

#Deploy VM - SRV 02
resource "azurerm_windows_virtual_machine" "vm02" {
  name                = "VM-SRV02-DB"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_B2S"
  admin_username      = "adminuser"
  admin_password      = "A1qa2ws3ed4rf5tg"
  network_interface_ids = [
    azurerm_network_interface.vnic02.id,
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}


