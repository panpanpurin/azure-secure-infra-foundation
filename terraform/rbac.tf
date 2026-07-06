# All role assignments, executed via the access-manager provider alias.
# id-manager is barred from creating azurerm_role_assignment resources by the
# challenge's separation-of-duties rule, so every grant here runs on
# provider = azurerm.rbac.
#
# Runtime vm-mi assignments (Reader@RG, Key Vault Secrets User@KV,
# Storage Blob Data Reader@container) are a separate deliverable and are not
# added yet.
#
# The grant below is provisioning-only, not vm-mi leakage (it lets id-manager
# seed the dummy Key Vault secret). RBAC-authorized Key Vaults have no
# key-based shortcut, and id-manager cannot self-assign the role, so
# access-manager grants this narrow, vault-scoped permission instead.

resource "azurerm_role_assignment" "idmgr_kv_secrets_officer" {
  provider           = azurerm.rbac
  scope              = azurerm_key_vault.app.id
  role_definition_id = data.azurerm_role_definition.kv_secrets_officer.role_definition_id
  principal_id       = data.azurerm_user_assigned_identity.id_manager.principal_id
  description        = "Provisioning-only: allows id-manager to seed the dummy Key Vault secret (no key-based shortcut for RBAC-auth Key Vault)."
}

resource "time_sleep" "wait_kv_rbac" {
  create_duration = "180s"

  depends_on = [azurerm_role_assignment.idmgr_kv_secrets_officer]
}
