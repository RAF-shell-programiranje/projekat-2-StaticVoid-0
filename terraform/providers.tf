
# Terraform / provider setup
#-----------------------------

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}


# AzureRM provider
#-------------------

provider "azurerm" {
  features {}
  # autentikacija se vrsi preko Azure CLI ili env varijabli (ARM_CLIENT_ID, ARM_TENANT_ID)
}
