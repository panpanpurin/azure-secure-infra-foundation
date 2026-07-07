# --- Environment / provided infra (used by validation scripts) ---

output "location" {
  description = "Azure region (from provided resource group)."
  value       = local.location
}

output "resource_group_name" {
  description = "Provided resource group name."
  value       = data.azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Provided resource group resource ID (vm-mi Reader scope)."
  value       = data.azurerm_resource_group.this.id
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

# --- Storage (storage.tf) ---

output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.app.name
}

output "storage_account_id" {
  description = "Storage account resource ID."
  value       = azurerm_storage_account.app.id
}

output "storage_blob_host" {
  description = "Blob service FQDN (resolves to private IP via privatelink zone)."
  value       = azurerm_storage_account.app.primary_blob_host
}

output "storage_container_name" {
  description = "Container holding the dummy blob."
  value       = azurerm_storage_container.data.name
}

output "storage_container_id" {
  description = "Storage container resource ID (vm-mi Storage Blob Data Reader scope)."
  value       = azurerm_storage_container.data.id
}

output "storage_blob_name" {
  description = "Dummy blob object name."
  value       = azurerm_storage_blob.dummy.name
}

output "storage_private_endpoint_id" {
  description = "Blob private endpoint resource ID."
  value       = azurerm_private_endpoint.storage_blob.id
}

# --- Key Vault (keyvault.tf) ---

output "key_vault_name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.app.name
}

output "key_vault_id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.app.id
}

output "key_vault_uri" {
  description = "Key Vault URI (resolves to private IP via privatelink zone)."
  value       = azurerm_key_vault.app.vault_uri
}

output "key_vault_private_endpoint_id" {
  description = "Key Vault private endpoint resource ID."
  value       = azurerm_private_endpoint.vault.id
}

output "key_vault_secret_name" {
  description = "Dummy secret name."
  value       = local.dummy_secret_name
}

output "key_vault_secret_id" {
  description = "Dummy secret resource ID (vm-mi Key Vault Secrets User scope)."
  value       = azapi_resource.kv_secret_seed.id
}

# --- RBAC (rbac.tf) ---

output "vmmi_reader_assignment_id" {
  description = "vm-mi Reader role assignment ID (resource group scope)."
  value       = azurerm_role_assignment.vmmi_reader.id
}

output "vmmi_kv_secrets_user_assignment_id" {
  description = "vm-mi Key Vault Secrets User role assignment ID (single secret scope)."
  value       = azurerm_role_assignment.vmmi_kv_secrets_user.id
}

output "vmmi_storage_blob_reader_assignment_id" {
  description = "vm-mi Storage Blob Data Reader role assignment ID (container scope)."
  value       = azurerm_role_assignment.vmmi_storage_blob_reader.id
}
