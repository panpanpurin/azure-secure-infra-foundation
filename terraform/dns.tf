# Private DNS zones for blob and Key Vault private endpoints.
#
# STRATEGY
#
#   privatelink.blob.core.windows.net
#     - Linked to VNet A AND VNet B (challenge requirement).
#     - VNet B: the blob private endpoint lives in snet-storage; the zone must
#       be linked so azurerm_private_dns_zone_group can register the PE A-record.
#     - VNet A: the bootstrap VM resolves <account>.blob.core.windows.net to the
#       private IP in VNet B over the peering (no public DNS path).
#
#   privatelink.vaultcore.azure.net
#     - Linked to VNet A ONLY (design decision).
#     - The Key Vault private endpoint and the bootstrap VM both sit in
#       snet-bootstrap (VNet A), resolution stays on the application network.
#     - VNet B is scoped for storage isolation only. Linking the vault zone there
#       would let the storage network resolve application secrets without need.
#
# registration_enabled = false on every link: A-records come from private endpoint
# zone groups at deploy time, not from VM auto-registration.

resource "azurerm_private_dns_zone" "blob" {
  name                = local.dns_zone_blob
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

# Bootstrap VM (VNet A) must resolve storage to the private IP in VNet B.
resource "azurerm_private_dns_zone_virtual_network_link" "blob_vnet_a" {
  name                  = "${var.name_prefix}-blob-link-vnet-a"
  resource_group_name   = data.azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = data.azurerm_virtual_network.vnet_a.id
  registration_enabled  = false
  tags                  = local.tags
}

# Blob PE in snet-storage (VNet B) registers its A-record in this zone.
resource "azurerm_private_dns_zone_virtual_network_link" "blob_vnet_b" {
  name                  = "${var.name_prefix}-blob-link-vnet-b"
  resource_group_name   = data.azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet_b.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone" "vault" {
  name                = local.dns_zone_vault
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

# Key Vault PE and VM share snet-bootstrap — no VNet B link required.
resource "azurerm_private_dns_zone_virtual_network_link" "vault_vnet_a" {
  name                  = "${var.name_prefix}-vault-link-vnet-a"
  resource_group_name   = data.azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = data.azurerm_virtual_network.vnet_a.id
  registration_enabled  = false
  tags                  = local.tags
}