data "azurerm_client_config" "current" {}

# --- Provided infrastructure (never destroyed) ---

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "vnet_a" {
  name                = var.vnet_a_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_subnet" "bootstrap" {
  name                 = var.bootstrap_subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet_a.name
  resource_group_name  = data.azurerm_resource_group.this.name
}

data "azurerm_network_security_group" "bootstrap" {
  name                = var.bootstrap_nsg_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_user_assigned_identity" "id_manager" {
  name                = var.id_manager_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_user_assigned_identity" "access_manager" {
  name                = var.access_manager_name
  resource_group_name = data.azurerm_resource_group.this.name
}

# --- Role definitions (read with id-manager; assignments use access-manager) ---

data "azurerm_role_definition" "reader" {
  name = local.role_reader
}

data "azurerm_role_definition" "kv_secrets_user" {
  name = local.role_kv_secrets_user
}

data "azurerm_role_definition" "storage_blob_reader" {
  name = local.role_storage_blob_reader
}