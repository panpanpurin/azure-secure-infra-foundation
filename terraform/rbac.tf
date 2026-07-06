# All role assignments, executed via the access-manager provider alias.
# id-manager is barred from creating azurerm_role_assignment resources by the
# challenge's separation-of-duties rule, so every grant here runs on
# provider = azurerm.rbac.
#
# Runtime vm-mi assignments (Reader@RG, Key Vault Secrets User@KV,
# Storage Blob Data Reader@container) are a separate deliverable and are not
# added yet.
