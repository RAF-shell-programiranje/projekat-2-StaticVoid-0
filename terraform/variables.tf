# Naziv VM-a (monitoring)
variable "vm_mon_name" {
  type    = string
  default = "MonitorVM"
}
variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "dummyapp-rg"
}

variable "admin_username" {
  description = "Admin username for VM login"
  type        = string
  default     = "azureuser"
}

variable "vm_size" {
  description = "VM instance size"
  type        = string
  default     = "Standard_B2s_v2"
}

# Naziv VM-a (aplikacija)
variable "vm_app_name" {
  type    = string
  default = "AplikacijaVM"
}