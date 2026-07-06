# All role assignments, executed via the access-manager provider alias.
# id-manager is barred from creating azurerm_role_assignment resources by the
# challenge's separation-of-duties rule, so every grant here runs on
# provider = azurerm.rbac.
#
# access-manager's own RBAC-assignment permission carries an environment-enforced
# ABAC condition (confirmed at apply time via `az role assignment list`): it can
# only grant Reader, Key Vault Secrets User, or Storage Blob Data Reader, and only
# to a ServicePrincipal. Those are exactly the three vm-mi runtime roles below —
# no other role, including a Key Vault data-plane seed role for id-manager, is
# assignable through access-manager in this environment. (The Key Vault dummy
# secret is seeded via an ARM control-plane write instead)
#
# vm-mi (runtime) has exactly three assignments, no more:
#   1. Reader on the resource group (control-plane metadata only).
#   2. Key Vault Secrets User on the single dummy secret (data-plane read of its value).
#   3. Storage Blob Data Reader on the container (data-plane read of blob content).
# Control-plane Reader does not grant data-plane access, which is why (2) and (3)
# are needed in addition to (1) rather than a single broader role. (2) and (3) are
# both scoped to the tightest resource available (single secret, single container)
# rather than the whole vault/account, for consistent least-privilege scoping.

resource "azurerm_role_assignment" "vmmi_reader" {
  provider           = azurerm.rbac
  scope              = data.azurerm_resource_group.this.id
  role_definition_id = data.azurerm_role_definition.reader.role_definition_id
  principal_id       = var.vm_mi_principal_id
  description        = "Runtime: vm-mi reads resource group metadata (control-plane only)."
}

resource "azurerm_role_assignment" "vmmi_kv_secrets_user" {
  provider           = azurerm.rbac
  scope              = azapi_resource.kv_secret_seed.id
  role_definition_id = data.azurerm_role_definition.kv_secrets_user.role_definition_id
  principal_id       = var.vm_mi_principal_id
  description        = "Runtime: vm-mi reads the dummy secret value (data-plane, scoped to the single secret)."
}

resource "azurerm_role_assignment" "vmmi_storage_blob_reader" {
  provider           = azurerm.rbac
  scope              = azurerm_storage_container.data.id
  role_definition_id = data.azurerm_role_definition.storage_blob_reader.role_definition_id
  principal_id       = var.vm_mi_principal_id
  description        = "Runtime: vm-mi reads blob content in the container (data-plane, least privilege)."
}
