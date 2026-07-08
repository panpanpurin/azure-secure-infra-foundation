locals {
  location = data.azurerm_resource_group.this.location

  tags = {
    Owner       = var.tag_owner
    Environment = var.tag_environment
    Project     = var.tag_project
  }

  # Candidate-managed resource names (suffix will be added in later modules)
  vnet_b_name      = "${var.name_prefix}-vnet-b"
  nsg_storage_name = "${var.name_prefix}-nsg-storage"

  # Storage (storage.tf) — container/blob names are fixed; account name is suffixed globally.
  storage_container_name = "data"
  storage_blob_name      = "dummy.txt"
  storage_blob_content   = "azure-infra-identity-challenge"

  # Private DNS zone names (fixed Azure suffixes)
  dns_zone_blob  = "privatelink.blob.core.windows.net"
  dns_zone_vault = "privatelink.vaultcore.azure.net"

  # Runtime RBAC role names (resolved via id-manager; assigned via access-manager)
  role_reader              = "Reader"
  role_kv_secrets_user     = "Key Vault Secrets User"
  role_storage_blob_reader = "Storage Blob Data Reader"
}