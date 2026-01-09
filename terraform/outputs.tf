
output "vm_app_ip" {
  description = "Javna IP adresa aplikacione VM instance"
  value       = azurerm_public_ip.app_ip.ip_address
}

output "vm_monitor_ip" {
  description = "Javna IP adresa monitoring VM instance"
  value       = azurerm_public_ip.mon_ip.ip_address
}

output "vm_admin_username" {
  description = "Admin username za SSH pristup"
  value       = var.admin_username
}



# SSH key material 
#--------------------------------------------

output "vm_ssh_public_key" {
  description = "Javni SSH kljuc (OpenSSH format) koji je upisan na VM-ove"
  value       = tls_private_key.vm_key.public_key_openssh
}

output "vm_ssh_private_key" {
  description = "Privatni SSH kljuc za pristup VM-ovima"
  value       = tls_private_key.vm_key.private_key_pem
  sensitive   = true
}



# Convenience output-i

output "ansible_inventory_ini" {
  description = "Ansible inventory (INI format) za app VM"
  value       = <<-EOT
    [app]
    ${azurerm_public_ip.app_ip.ip_address} ansible_user=${var.admin_username}

    [monitor]
    ${azurerm_public_ip.mon_ip.ip_address} ansible_user=${var.admin_username}
    EOT
}



