# Storage account, blob private endpoint (VNet B), and dummy blob seed.
#
# STRATEGY
#   - Standard / LRS / StorageV2; public network access disabled; anonymous blob off.
#   - shared_access_key_enabled = true: seed dummy blob via account key over the PE
#     (no RBAC grant for id-manager).
#   - An Entra-ID-only variant (disable shared keys, seed via Storage Blob Data
#     Contributor) is NOT offered here: access-manager's RBAC-assignment
#     permission carries an ABAC condition restricting it to exactly Reader,
#     Key Vault Secrets User, and Storage Blob Data Reader (please see rbac.tf), the
#     same restriction that forced the Key Vault secret onto azapi_resource.
#     Storage Blob Data Contributor is outside that allow-list and unlike the
#     Key Vault secret, blob content has no ARM control-plane write to fall
#     back on, so the account-key seed is the only working path here.
#   - Apply order: account → PE + DNS zone group → container → blob (key auth).
#   - Blob PE lives in snet-storage; VM in VNet A resolves FQDN over peering via
#     privatelink.blob.core.windows.net (linked in dns.tf).

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  # Storage account names: lowercase alphanumeric only, max 24 characters.
  storage_account_name = lower("${var.name_prefix}st${random_string.storage_suffix.result}")
}

resource "azurerm_storage_account" "app" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  min_tls_version                 = "TLS1_2"

  tags = local.tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${var.name_prefix}-pe-storage-blob"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.storage.id

  private_service_connection {
    name                           = "${var.name_prefix}-psc-storage-blob"
    private_connection_resource_id = azurerm_storage_account.app.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = local.tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.blob_vnet_a,
    azurerm_private_dns_zone_virtual_network_link.blob_vnet_b,
  ]
}

resource "azurerm_storage_container" "data" {
  name                  = local.storage_container_name
  storage_account_id    = azurerm_storage_account.app.id
  container_access_type = "private"

  depends_on = [azurerm_private_endpoint.storage_blob]
}

resource "azurerm_storage_blob" "dummy" {
  name                 = local.storage_blob_name
  storage_container_id = azurerm_storage_container.data.id
  type                 = "Block"
  source_content       = local.storage_blob_content

  depends_on = [
    azurerm_private_endpoint.storage_blob,
    azurerm_private_dns_zone_virtual_network_link.blob_vnet_a,
    azurerm_private_dns_zone_virtual_network_link.blob_vnet_b,
  ]
}