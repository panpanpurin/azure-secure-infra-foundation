# Architecture

## Overview

The solution deploys a single-root Terraform stack from the bootstrap VM (`vm-vm-andressa`) inside the provided resource group `rg-interview-vm-andressa` (region `japaneast`). The design separates storage networking from the application network, enforces least-privilege RBAC across three managed identities, and routes all PaaS traffic through private endpoints and private DNS.

Candidate-managed resources stay inside the provided resource group. The provided VNet A, `snet-bootstrap`, bootstrap VM, and `nsg-vm-andressa` are consumed as data sources and are not destroyed by `terraform destroy`.

## Environment (recon)

| Item | Value |
| :--- | :--- |
| VNet A | `vnet-a-vm-andressa` — `10.10.0.0/16` |
| Bootstrap subnet | `snet-bootstrap` — `10.10.0.0/24` |
| VNet B (new) | `10.20.0.0/16` |
| Storage subnet (new) | `snet-storage` — `10.20.1.0/24` |
| Bootstrap VM | `vm-vm-andressa` |
| Provided NSG | `nsg-vm-andressa` on `snet-bootstrap` (permissive; not modified) |

## Components

| Component | Location | Access model |
| :--- | :--- | :--- |
| VNet B + `snet-storage` | New | Private storage connectivity; project-owned NSG |
| Storage account + blob PE | VNet B | Public network access disabled; blob via private endpoint only |
| Key Vault + secret + KV PE | `snet-bootstrap` (VNet A) | RBAC authorization; public access disabled; PE in workload subnet |
| Private DNS `privatelink.blob.core.windows.net` | Linked to VNet A and VNet B | Resolves storage FQDN to private IP in VNet B |
| Private DNS `privatelink.vaultcore.azure.net` | Linked to VNet A | Resolves vault FQDN to private IP in `snet-bootstrap` |
| Bidirectional peering | VNet A ↔ VNet B | VM in A reaches blob PE in B |

## Identity model

| Identity | Type | Responsibility |
| :--- | :--- | :--- |
| `id-manager` | User-assigned | Provisions infrastructure (default Terraform provider) |
| `access-manager` | User-assigned | Assigns RBAC only (`azurerm.rbac` provider) |
| `vm-mi` | System-assigned on VM | Runtime read access to vault secret and storage blob |

## Data flow

**Blob read (runtime)**

1. `vm-mi` requests an Entra ID token for `https://storage.azure.com`.
2. Private DNS resolves `<account>.blob.core.windows.net` to the storage private endpoint IP in VNet B.
3. Traffic crosses the VNet peering from `snet-bootstrap` to `snet-storage`.
4. `Storage Blob Data Reader` authorizes the read.

**Key Vault read (runtime)**

1. `vm-mi` requests an Entra ID token for `https://vault.azure.net`.
2. Private DNS resolves the vault FQDN to the Key Vault private endpoint IP in `snet-bootstrap`.
3. Traffic stays intra-subnet (no peering required).
4. `Key Vault Secrets User` authorizes the secret value read.

No public endpoints are used for storage or Key Vault data-plane access.

## Terraform providers

| Provider | MSI `client_id` | Creates |
| :--- | :--- | :--- |
| Default `azurerm` | `id-manager` | VNets, peering, DNS, storage, Key Vault, private endpoints, storage blob (seed) |
| `azurerm.rbac` | `access-manager` | All `azurerm_role_assignment` resources |
| `azapi` | `id-manager` | Key Vault dummy secret (ARM control-plane write; see [design-decisions.md](design-decisions.md#provisioning-seed-vs-runtime-roles)) |

Role definitions are resolved with the default provider; assignments are written through `azurerm.rbac`. The Key Vault secret is written through `azapi` rather than a role assignment — `access-manager`'s RBAC-assignment permission is restricted (by an ABAC condition) to granting only the three `vm-mi` runtime roles, so no role capable of writing a secret can be granted to `id-manager`.

## Validation

Active checks live in `scripts/validate.sh` (invoked via `make test`). The `tests/` directory is reserved for future automated suites (e.g. Terratest).

## Diagram

See [diagrams/architecture.mmd](../diagrams/architecture.mmd) and the Mermaid diagram in [README.md](../README.md).