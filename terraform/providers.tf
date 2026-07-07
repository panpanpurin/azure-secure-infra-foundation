# Default provider: id-manager (infrastructure provisioning)
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  use_msi                         = true
  client_id                       = var.id_manager_client_id
  subscription_id                 = var.subscription_id
  tenant_id                       = var.tenant_id
  resource_provider_registrations = "none"
}

# Aliased provider: access-manager (RBAC assignments only)
provider "azurerm" {
  alias = "rbac"

  features {}

  use_msi                         = true
  client_id                       = var.access_manager_client_id
  subscription_id                 = var.subscription_id
  tenant_id                       = var.tenant_id
  resource_provider_registrations = "none"
}

# azapi, authenticated as id-manager (same identity as the default azurerm
# provider). Used only to seed the Key Vault dummy secret via the ARM
# control-plane action Microsoft.KeyVault/vaults/secrets/write, which
# Contributor already grants

provider "azapi" {
  use_msi         = true
  client_id       = var.id_manager_client_id
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}