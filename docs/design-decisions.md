# Design decisions

## Key Vault private endpoint in `snet-bootstrap`

After evaluating the challenge requirements and the provided infrastructure, the Key Vault private endpoint is placed in the existing `snet-bootstrap` subnet in VNet A.

The challenge instructs use of the provided VNet A as the application-side network. The Key Vault serves the workload on the bootstrap VM, so co-locating the endpoint in the same subnet keeps the application and its secrets on the application network. The subnet currently hosts only the bootstrap VM, has sufficient address space, and recon confirmed a permissive provided NSG (`nsg-vm-andressa`) with no restrictive outbound rules that would block intra-subnet or peering paths.

Placing the Key Vault private endpoint in VNet B was rejected. VNet B is scoped for storage isolation; moving application secrets into that network would blur the separation between the storage layer and the application layer.

Creating a new dedicated private-endpoint subnet in VNet A was also rejected. A private endpoint is a NIC that consumes one IP; it does not require a dedicated subnet when a single consumer (the bootstrap VM) already lives in `snet-bootstrap`. A new subnet would add an NSG obligation, extra address planning, and more teardown surface without isolation benefit in this single-VM scenario.

The provided subnet resource is never modified. The private endpoint references the subnet by ID; `destroy` removes only the endpoint.

Key Vault `public_network_access_enabled = false` is paired with the private endpoint. Disabling public access without a private path would leave no route to create or read secrets.

## Storage private endpoint in VNet B

Blob storage lives behind a private endpoint in `snet-storage` (VNet B `10.20.1.0/24`). Public network access and anonymous blob access are disabled. This matches the challenge requirement that storage connectivity stays on an isolated network reachable only through private endpoints.

Private DNS zone `privatelink.blob.core.windows.net` is linked to **both** VNet A and VNet B so the bootstrap VM resolves the storage FQDN to the private IP in VNet B over the peering.

## Provided NSG (`nsg-vm-andressa`)

Recon attached `nsg-vm-andressa` to `snet-bootstrap`. Rules are permissive. The project does **not** create, modify, or delete this NSG.

The only NSG owned by this deployment is on `snet-storage` in VNet B. If platform rules on `nsg-vm-andressa` change later, connectivity should be re-checked for:

- Outbound HTTPS from the VM to `10.20.0.0/16` (blob over peering)
- Intra-subnet HTTPS to the Key Vault private endpoint

## NSG on `snet-storage`

Every subnet created by this project must have an NSG. `snet-storage` is the only created subnet.

| Priority | Rule | Direction | Source | Action |
| :-- | :--- | :--- | :--- | :--- |
| 100 | Allow-App-to-PE-HTTPS | Inbound | `10.10.0.0/24` | Allow TCP 443 |
| 4000 | Deny-All-Inbound | Inbound | * | Deny |
| 100 | Allow-Out-VNet | Outbound | VirtualNetwork | Allow |
| 4000 | Deny-Out-Internet | Outbound | Internet | Deny |

No `0.0.0.0/0` inbound source is used. Only HTTPS from the known bootstrap subnet reaches the storage private endpoint.

## Identity separation (dual provider)

Strict separation of provisioning and RBAC assignment is enforced in Terraform, not by creating new identities:

- **Default provider (`id-manager`)** — all infrastructure resources. Assigning RBAC through this identity returns `403 Forbidden` (expected).
- **Aliased provider `azurerm.rbac` (`access-manager`)** — every `azurerm_role_assignment`, nothing else.

Both user-assigned identities are pre-provisioned by the challenge. Their baseline grants (Contributor, RBAC-assign role) are not recreated.

## Provisioning seed vs runtime roles

Dummy secret and blob content must be created after private endpoints and DNS are live.

**Default path (recommended for apply reliability)**

| Artifact | Method | `id-manager` grant |
| :--- | :--- | :--- |
| Key Vault secret | Entra ID over KV private endpoint | `Key Vault Secrets Officer` (no key-based alternative on RBAC-auth vault) |
| Storage blob | Account key over blob private endpoint | None — `shared_access_key_enabled = true` |

RBAC propagation is eventually consistent. The default path avoids a second propagation gate (`Storage Blob Data Contributor`) for blob upload. `shared_access_key_enabled = true` does not enable public network access; public access remains disabled.

A `time_sleep` (or retry loop) after the Key Vault seed assignment reduces flaky secret creation.

**Hardening path (optional)**

Disable shared keys, seed the blob via Entra ID, and add `Storage Blob Data Contributor` for `id-manager`. This adds a second propagation dependency and longer apply times.

`vm-mi` always reads the blob with `Storage Blob Data Reader` (Entra ID) regardless of how the blob was uploaded.

## SKUs and region

| Resource | Choice | Rationale |
| :--- | :--- | :--- |
| Storage | Standard / LRS / StorageV2 | Lowest practical cost; challenge-aligned |
| Key Vault | Standard, RBAC mode | Premium HSM not required |
| Region | `data.azurerm_resource_group.this.location` | Matches provided RG (`japaneast`); avoids provider default region drift |
| Tags | `Owner`, `Environment`, `Project` on all taggable resources | Azure Policy requirement |

## Multi-environment scaling

This repository intentionally uses one root module and local state for challenge scope.

A production layout would introduce:

- `envs/dev` and `envs/prod` (or workspaces) with separate `*.tfvars`
- Remote `azurerm` backend with locking and versioning
- Shared modules for network, identity, and data-plane resources
- Distinct subscriptions and deployment identities per environment

Local state is acceptable here because the environment is ephemeral and single-operator; state files must never be committed (they contain the generated secret value).