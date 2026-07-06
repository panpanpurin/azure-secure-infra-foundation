# Key Vault + Private Endpoint
#
# Standard + RBAC + public access disabled (PE is required when public access is off).
# Purge protection disabled; provider features handle soft-delete on re-apply.
# PE placed in existing snet-bootstrap (intra-subnet resolution, no extra peering needed).
# id-manager gets (Key Vault Secrets Officer) via access-manager + time_sleep for RBAC propagation.
# RBAC mode has no key-based shortcut for secret creation.

resource "random_string" "kv_suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  # Key Vault names: alphanumeric + hyphens, 3-24 characters, globally unique.
  key_vault_name = lower("${var.name_prefix}-kv-${random_string.kv_suffix.result}")
}

resource "azurerm_key_vault" "app" {
  name                = local.key_vault_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = false

  tags = local.tags
}

resource "azurerm_private_endpoint" "vault" {
  name                = "${var.name_prefix}-pe-vault"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.bootstrap.id

  private_service_connection {
    name                           = "${var.name_prefix}-psc-vault"
    private_connection_resource_id = azurerm_key_vault.app.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }

  tags = local.tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.vault_vnet_a,
  ]
}

resource "random_password" "dummy_secret" {
  length  = 24
  special = true
}

# Written by id-manager over the vault PE (intra-subnet, no peering wait),
# once the Key Vault Secrets Officer grant (rbac.tf) has propagated.
resource "azurerm_key_vault_secret" "dummy" {
  name         = "dummy-secret"
  value        = random_password.dummy_secret.result
  key_vault_id = azurerm_key_vault.app.id

  depends_on = [
    azurerm_private_endpoint.vault,
    azurerm_private_dns_zone_virtual_network_link.vault_vnet_a,
    time_sleep.wait_kv_rbac,
  ]
}
