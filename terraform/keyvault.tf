# Key Vault + Private Endpoint
#
# Standard + RBAC + public access disabled (PE is required when public access is off).
# Purge protection disabled; provider features handle soft-delete on re-apply.
# PE placed in existing snet-bootstrap (intra-subnet resolution, no extra peering needed).
#
# Secret seeding: access-manager's own RBAC-assignment permission carries an ABAC
# condition (verified at apply time) that hard-restricts it to granting only
# Reader, Key Vault Secrets User, and Storage Blob Data Reader, the three vm-mi
# runtime roles. It cannot grant Key Vault Secrets Officer or any other role, so
# id-manager can never receive vault data-plane access via a role assignment.
# The dummy secret is instead written via azapi_resource (provider "azapi",
# authenticated as id-manager, providers.tf): Microsoft.KeyVault/vaults/secrets
# is authorized by the ARM control-plane action
# Microsoft.KeyVault/vaults/secrets/write, which Contributor already grants,
# no Key Vault RBAC or access policy needed for id-manager at all.

resource "random_string" "kv_suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  # Key Vault names: alphanumeric + hyphens, 3-24 characters, globally unique.
  key_vault_name    = lower("${var.name_prefix}-kv-${random_string.kv_suffix.result}")
  dummy_secret_name = "dummy-secret"
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

# Written by id-manager via the ARM control plane (azapi).
resource "azapi_resource" "kv_secret_seed" {
  type      = "Microsoft.KeyVault/vaults/secrets@2023-07-01"
  name      = local.dummy_secret_name
  parent_id = azurerm_key_vault.app.id
  location  = local.location
  tags      = local.tags

  body = {
    properties = {
      value = random_password.dummy_secret.result
    }
  }

  depends_on = [
    azurerm_private_endpoint.vault,
    azurerm_private_dns_zone_virtual_network_link.vault_vnet_a,
  ]
}
