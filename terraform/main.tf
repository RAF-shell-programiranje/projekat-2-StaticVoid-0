
# Osnovni resursi
#-----------------------
# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Generisanje SSH kljuca (privatni i javni kljuc)
resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Virtuelna mreza i subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "dummyapp-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "dummyapp-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Bezbednost
#----------------------

# Network security group sa pravilom da dozvoli SSH sa bilo koje adrese (ostali portovi zatvoreni)
resource "azurerm_network_security_group" "nsg" {
  name                = "dummyapp-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}



# App VM - networking
#---------------------

# Mrezni interfejs i javna IP za app VM
resource "azurerm_public_ip" "app_ip" {
  name                = "${var.vm_app_name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "app_nic" {
  name                = "${var.vm_app_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipv4"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app_ip.id
  }
}

# Asociranje nsg na app nic
resource "azurerm_network_interface_security_group_association" "app_nic_nsg" {
  network_interface_id      = azurerm_network_interface.app_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}



# Monitor VM - networking
#-------------------------

# Public ip za monitor VM
resource "azurerm_public_ip" "mon_ip" {
  name                = "${var.vm_mon_name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network interface za monitor VM
resource "azurerm_network_interface" "mon_nic" {
  name                = "${var.vm_mon_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipv4"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mon_ip.id
  }
}

# Nsg asocijacija za monitor nic
resource "azurerm_network_interface_security_group_association" "mon_nic_nsg" {
  network_interface_id      = azurerm_network_interface.mon_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}



# Virtualne masine
#---------------------------

# VM za aplikaciju
resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = var.vm_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.vm_key.public_key_openssh
  }

  # Koriscenje ubuntu 22.04 lts image
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = {
    project = "dummyapp"
    role    = "app"
  }
}


# Monitoring VM 
resource "azurerm_linux_virtual_machine" "mon_vm" {
  name                = var.vm_mon_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.mon_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.vm_key.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = {
    project = "dummyapp"
    role    = "monitor"
  }
}
