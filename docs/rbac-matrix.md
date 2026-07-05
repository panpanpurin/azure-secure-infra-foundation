# RBAC matrix

## Identity responsibilities

| Capability | `vm-mi` | `id-manager` | `access-manager` |
| :--- | :---: | :---: | :---: |
| Deploy infrastructure | No | Yes | No |
| Assign RBAC | No | No | Yes |
| Used at VM runtime | Yes | No | No |

`id-manager` and `access-manager` are pre-provisioned. Baseline grants on the resource group are not recreated by this deployment.

## Assignments by resource

| Resource / scope | `vm-mi` (runtime) | `id-manager` (provision) | `access-manager` |
| :--- | :--- | :--- | :--- |
| Resource group | **Reader** | Contributor *(pre-granted)* | User Access Administrator or RBAC Administrator *(pre-granted)* |
| Key Vault | **Key Vault Secrets User** | Key Vault Secrets Officer *(seed only)* | Creates role assignments |
| Storage container | **Storage Blob Data Reader** | Account-key blob seed *(default)* or Blob Data Contributor *(AAD-only path)* | Creates role assignments |

All `azurerm_role_assignment` resources use `provider = azurerm.rbac` (`access-manager`).

## Runtime identity (`vm-mi`) — exactly three assignments

| # | Role | GUID | Scope | Purpose |
| :-- | :--- | :--- | :--- | :--- |
| 1 | Reader | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Resource group | Challenge requirement; control-plane metadata |
| 2 | Key Vault Secrets User | `4633458b-17de-408a-b874-0445c86b69e6` | Key Vault | Data-plane read of secret **values** |
| 3 | Storage Blob Data Reader | `2a2b9908-6ea1-4ae2-8e65-a410df84e7d1` | Container | Data-plane read/list of blob content |

### Why three roles

Control-plane **Reader** does not grant data-plane access. Secret values and blob bytes require separate data roles:

- `Key Vault Reader` reads vault metadata only — insufficient for secret values.
- `Reader` on the resource group does not authorize blob content reads.

Three narrow roles replace a single broad role such as Contributor.

### Forbidden on `vm-mi`

Never assign:

- Contributor
- Owner
- User Access Administrator
- Role Based Access Control Administrator
- Any `*Contributor` or `*Owner` data-plane role

### Optional tightening

Scopes can be narrowed further:

- Key Vault Secrets User on a **single secret** instead of the whole vault
- Storage Blob Data Reader on a **single container** (default) vs whole account

## Provisioning seed roles (`id-manager`)

Created via `access-manager` for initial dummy content only — not runtime grants.

| Role | GUID | Scope | When used |
| :--- | :--- | :--- | :--- |
| Key Vault Secrets Officer | `b86a8fe4-44ce-4948-aab7-e0022e6c4653` | Key Vault | Always (RBAC-auth vault has no key shortcut) |
| Storage Blob Data Contributor | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` | Container | AAD-only storage seed path only |

On the **default path**, blob upload uses the storage account key over the private endpoint; the Blob Data Contributor assignment is omitted.

## Role definition resolution pattern

`access-manager` may lack permission to read role definitions. The pattern used:

1. `data "azurerm_role_definition"` — resolved with default provider (`id-manager`)
2. `azurerm_role_assignment` — created with `provider = azurerm.rbac`

## Validation expectations

`scripts/validate.sh` asserts:

- `vm-mi` holds exactly the three runtime roles above (no extras)
- Forbidden roles are absent
- `vm-mi` can read secret and blob (positive)
- `vm-mi` receives `403` on write attempts (negative)