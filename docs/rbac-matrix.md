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
| Resource group | **Reader** | Contributor *(pre-granted)* | Role Based Access Control Administrator *(pre-granted; confirmed via `az role assignment list`)* |
| Key Vault secret | **Key Vault Secrets User** *(scoped to the single dummy secret)* | None — secret seeded via `azapi_resource` (ARM control-plane) | Creates role assignments |
| Storage container | **Storage Blob Data Reader** | Account-key blob seed *(only working path)* | Creates role assignments |

All `azurerm_role_assignment` resources use `provider = azurerm.rbac` (`access-manager`).

`access-manager`'s `Role Based Access Control Administrator` grant carries an ABAC condition, confirmed by reading the assignment directly:

```bash
az role assignment list --assignee <access-manager-principal-id> -o json \
  --query "[].{role:roleDefinitionName, condition:condition}"
```

The condition restricts `access-manager` to creating (or deleting) role assignments only for `Reader`, `Key Vault Secrets User`, or `Storage Blob Data Reader`, and only when the target principal type is `ServicePrincipal`, exactly the three `vm-mi` rows above, nothing more. This is why the Key Vault seed could not use a role assignment: no role capable of writing a secret is assignable through `access-manager` in this environment, for any principal, including `id-manager`.

## Runtime identity (`vm-mi`) — exactly three assignments

| # | Role | GUID | Scope | Purpose |
| :-- | :--- | :--- | :--- | :--- |
| 1 | Reader | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Resource group | Challenge requirement; control-plane metadata |
| 2 | Key Vault Secrets User | `4633458b-17de-408a-b874-0445c86b69e6` | Single secret (`dummy-secret`) | Data-plane read of the secret **value** |
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

### Scope choices

Both data-plane roles are scoped to the tightest resource available, not the parent container:

- Key Vault Secrets User is scoped to the **single secret** (`dummy-secret`), not the whole vault.
- Storage Blob Data Reader is scoped to the **container**, not the whole storage account.

A further, unused option is scoping Storage Blob Data Reader to the individual blob rather than the container — omitted here since the container holds only the one dummy blob and Azure RBAC's blob-level scoping is less commonly supported by tooling than container-level.

## Provisioning seed roles (`id-manager`)

`id-manager` receives **no additional role assignment** for either seed, neither goes through `access-manager`'s ABAC-restricted role-assignment path at all:

| Artifact | Seed method | `id-manager` grant |
| :--- | :--- | :--- |
| Key Vault secret | `azapi_resource` (ARM control-plane write to `Microsoft.KeyVault/vaults/secrets`) | None — covered by existing `Contributor` |
| Storage blob | Account key over the blob private endpoint | None — `shared_access_key_enabled = true` |

An Entra-ID-only blob seed (disabling shared keys, granting `id-manager` `Storage Blob Data Contributor`) is **not offered, not merely unused by default**: that role sits outside the three-role allow-list enforced by `access-manager`'s ABAC condition above, the identical restriction that ruled out `Key Vault Secrets Officer` for the secret seed. Unlike the Key Vault secret, blob content has no ARM control-plane write to fall back on, `azapi_resource` works for the secret because `Microsoft.KeyVault/vaults/secrets` is an ARM-modeled resource, blob bytes are a pure data-plane write with no ARM proxy resource, so the account-key seed is the only working path here. See [design-decisions.md](design-decisions.md#provisioning-seed-vs-runtime-roles) for the full reasoning please.

## Role definition resolution pattern

`access-manager` may lack permission to read role definitions. The pattern used:

1. `data "azurerm_role_definition"` — resolved with default provider (`id-manager`)
2. `azurerm_role_assignment` — created with `provider = azurerm.rbac`

## Validation expectations

`scripts/validate.sh` asserts:

- The provided resource group, VNet A, `snet-bootstrap`, its NSG, and the bootstrap VM are all still intact (never destroyed or modified by this deployment)
- `vm-mi` holds exactly the three runtime roles above (no extras)
- Forbidden roles are absent
- `vm-mi` can read secret and blob (positive)
- `vm-mi` receives `403` on write attempts (negative)