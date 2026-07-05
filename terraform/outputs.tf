# --- Environment / provided infra (used by validation scripts) ---

output "location" {
  description = "Azure region (from provided resource group)."
  value       = local.location
}

output "resource_group_name" {
  description = "Provided resource group name."
  value       = data.azurerm_resource_group.this.name
}

output "vnet_a_name" {
  description = "Provided VNet A name."
  value       = data.azurerm_virtual_network.vnet_a.name
}

output "vnet_a_id" {
  description = "Provided VNet A resource ID."
  value       = data.azurerm_virtual_network.vnet_a.id
}

output "bootstrap_subnet_id" {
  description = "Provided snet-bootstrap subnet ID (Key Vault PE target)."
  value       = data.azurerm_subnet.bootstrap.id
}

output "bootstrap_subnet_cidr" {
  description = "CIDR of snet-bootstrap (NSG source for storage PE)."
  value       = var.bootstrap_subnet_cidr
}

output "vm_name" {
  description = "Provided bootstrap VM name."
  value       = var.vm_name
}

# --- Identity references ---

output "vm_mi_principal_id" {
  description = "Principal ID of vm-mi (from tfvars; used for RBAC assignments)."
  value       = var.vm_mi_principal_id
}

output "id_manager_principal_id" {
  description = "Principal ID of id-manager (from data source)."
  value       = data.azurerm_user_assigned_identity.id_manager.principal_id
}

output "access_manager_principal_id" {
  description = "Principal ID of access-manager (from data source)."
  value       = data.azurerm_user_assigned_identity.access_manager.principal_id
}

# --- Candidate-managed network (network.tf / dns.tf) ---

output "vnet_b_name" {
  description = "VNet B name."
  value       = azurerm_virtual_network.vnet_b.name
}

output "vnet_b_id" {
  description = "VNet B resource ID."
  value       = azurerm_virtual_network.vnet_b.id
}

output "storage_subnet_name" {
  description = "Storage subnet name in VNet B."
  value       = azurerm_subnet.storage.name
}

output "storage_subnet_id" {
  description = "Storage subnet ID (blob private endpoint target)."
  value       = azurerm_subnet.storage.id
}

output "nsg_storage_name" {
  description = "NSG attached to snet-storage."
  value       = azurerm_network_security_group.storage.name
}

output "peering_a_to_b_name" {
  description = "VNet A to VNet B peering resource name."
  value       = azurerm_virtual_network_peering.a_to_b.name
}

output "peering_b_to_a_name" {
  description = "VNet B to VNet A peering resource name."
  value       = azurerm_virtual_network_peering.b_to_a.name
}

output "dns_zone_blob" {
  description = "Private DNS zone name for blob private endpoints."
  value       = azurerm_private_dns_zone.blob.name
}

output "dns_zone_blob_id" {
  description = "Private DNS zone ID for blob private endpoints."
  value       = azurerm_private_dns_zone.blob.id
}

output "dns_zone_vault" {
  description = "Private DNS zone name for Key Vault private endpoints."
  value       = azurerm_private_dns_zone.vault.name
}

output "dns_zone_vault_id" {
  description = "Private DNS zone ID for Key Vault private endpoints."
  value       = azurerm_private_dns_zone.vault.id
}