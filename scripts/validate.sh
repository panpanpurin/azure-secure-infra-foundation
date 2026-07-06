#!/usr/bin/env bash
# Infrastructure validation — phased checks aligned with deployment progress.
#
# Phase 1 (current): network (VNet B, NSG, peering) + private DNS zones/links.
# Phase 2 (later):   storage account/PE, Key Vault/PE, RBAC, data-plane tests.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

require_cmd az
require_cmd jq
require_cmd terraform

log_section "Azure Infrastructure & Identity Challenge — validation"
load_tf_outputs

RG="$(tf_output resource_group_name)"
VNET_A="$(tf_output vnet_a_name)"
VNET_B="$(tf_output vnet_b_name)"
VNET_A_ID="$(tf_output vnet_a_id)"
VNET_B_ID="$(tf_output vnet_b_id)"
STORAGE_SUBNET="$(tf_output storage_subnet_name)"
NSG_STORAGE="$(tf_output nsg_storage_name)"
PEERING_A_TO_B="$(tf_output peering_a_to_b_name)"
PEERING_B_TO_A="$(tf_output peering_b_to_a_name)"
DNS_ZONE_BLOB="$(tf_output dns_zone_blob)"
DNS_ZONE_VAULT="$(tf_output dns_zone_vault)"
BOOTSTRAP_CIDR="$(tf_output bootstrap_subnet_cidr)"

log_section "Peering (both directions must be Connected)"
peering_a_state="$(
  az network vnet peering show \
    --resource-group "${RG}" \
    --vnet-name "${VNET_A}" \
    --name "${PEERING_A_TO_B}" \
    --query peeringState -o tsv
)"
peering_b_state="$(
  az network vnet peering show \
    --resource-group "${RG}" \
    --vnet-name "${VNET_B}" \
    --name "${PEERING_B_TO_A}" \
    --query peeringState -o tsv
)"
assert_eq "VNet A → VNet B peering is Connected" "Connected" "${peering_a_state}"
assert_eq "VNet B → VNet A peering is Connected" "Connected" "${peering_b_state}"

log_section "VNet B and storage subnet"
vnet_b_prefix="$(
  az network vnet show \
    --resource-group "${RG}" \
    --name "${VNET_B}" \
    --query "addressSpace.addressPrefixes[0]" -o tsv
)"
assert_eq "VNet B address space is 10.20.0.0/16" "10.20.0.0/16" "${vnet_b_prefix}"

storage_subnet_prefix="$(
  az network vnet subnet show \
    --resource-group "${RG}" \
    --vnet-name "${VNET_B}" \
    --name "${STORAGE_SUBNET}" \
    --query addressPrefix -o tsv
)"
assert_eq "snet-storage CIDR is 10.20.1.0/24" "10.20.1.0/24" "${storage_subnet_prefix}"

pe_policies="$(
  az network vnet subnet show \
    --resource-group "${RG}" \
    --vnet-name "${VNET_B}" \
    --name "${STORAGE_SUBNET}" \
    --query privateEndpointNetworkPolicies -o tsv
)"
assert_eq "snet-storage private endpoint network policies enabled" "Enabled" "${pe_policies}"

subnet_nsg_id="$(
  az network vnet subnet show \
    --resource-group "${RG}" \
    --vnet-name "${VNET_B}" \
    --name "${STORAGE_SUBNET}" \
    --query "networkSecurityGroup.id" -o tsv
)"
nsg_id="$(
  az network nsg show \
    --resource-group "${RG}" \
    --name "${NSG_STORAGE}" \
    --query id -o tsv
)"
assert_eq "snet-storage is associated with project NSG" "${nsg_id}" "${subnet_nsg_id}"

log_section "NSG on snet-storage (tight rules, no 0.0.0.0/0 inbound allow)"
nsg_rules_json="$(
  az network nsg rule list \
    --resource-group "${RG}" \
    --nsg-name "${NSG_STORAGE}" \
    -o json
)"

rule_names="$(jq -r '.[].name' <<<"${nsg_rules_json}")"
assert_contains "NSG has Allow-App-to-PE-HTTPS rule" "Allow-App-to-PE-HTTPS" "${rule_names}"
assert_contains "NSG has Deny-All-Inbound rule" "Deny-All-Inbound" "${rule_names}"
assert_contains "NSG has Allow-Out-VNet rule" "Allow-Out-VNet" "${rule_names}"
assert_contains "NSG has Deny-Out-Internet rule" "Deny-Out-Internet" "${rule_names}"

https_rule="$(
  jq -c '.[] | select(.name == "Allow-App-to-PE-HTTPS")' <<<"${nsg_rules_json}"
)"
assert_eq "HTTPS allow rule direction is Inbound" "Inbound" "$(jq -r '.direction' <<<"${https_rule}")"
assert_eq "HTTPS allow rule protocol is Tcp" "Tcp" "$(jq -r '.protocol' <<<"${https_rule}")"
assert_eq "HTTPS allow rule port is 443" "443" "$(jq -r '.destinationPortRange' <<<"${https_rule}")"
assert_eq "HTTPS allow rule source is bootstrap CIDR" "${BOOTSTRAP_CIDR}" "$(jq -r '.sourceAddressPrefix' <<<"${https_rule}")"

inbound_allow_sources="$(
  jq -r '.[] | select(.direction == "Inbound" and .access == "Allow") | .sourceAddressPrefix' <<<"${nsg_rules_json}"
)"
assert_not_contains "No inbound allow rule uses 0.0.0.0/0 source" "0.0.0.0/0" "${inbound_allow_sources}"

log_section "Private DNS zones"
blob_zone_exists="$(
  az network private-dns zone show \
    --resource-group "${RG}" \
    --name "${DNS_ZONE_BLOB}" \
    --query name -o tsv 2>/dev/null || true
)"
vault_zone_exists="$(
  az network private-dns zone show \
    --resource-group "${RG}" \
    --name "${DNS_ZONE_VAULT}" \
    --query name -o tsv 2>/dev/null || true
)"
assert_eq "Blob private DNS zone exists" "${DNS_ZONE_BLOB}" "${blob_zone_exists}"
assert_eq "Vault private DNS zone exists" "${DNS_ZONE_VAULT}" "${vault_zone_exists}"

blob_link_vnet_ids="$(
  az network private-dns link vnet list \
    --resource-group "${RG}" \
    --zone-name "${DNS_ZONE_BLOB}" \
    --query "[].virtualNetwork.id" -o tsv | sort
)"
expected_blob_links="$(printf '%s\n%s' "${VNET_A_ID}" "${VNET_B_ID}" | sort)"
assert_eq "Blob DNS zone linked to VNet A and VNet B" "${expected_blob_links}" "${blob_link_vnet_ids}"

vault_link_vnet_ids="$(
  az network private-dns link vnet list \
    --resource-group "${RG}" \
    --zone-name "${DNS_ZONE_VAULT}" \
    --query "[].virtualNetwork.id" -o tsv
)"
assert_eq "Vault DNS zone linked to VNet A only" "${VNET_A_ID}" "${vault_link_vnet_ids}"
assert_not_contains "Vault DNS zone is not linked to VNet B" "${VNET_B_ID}" "${vault_link_vnet_ids}"

log_section "Storage (public access off, private endpoint, private DNS resolution)"
if skip_if_missing_output "storage_account_name" "Storage account output missing — implement storage.tf and apply"; then
  :
else
  STORAGE_ACCOUNT="$(tf_output storage_account_name)"
  STORAGE_BLOB_HOST="$(tf_output storage_blob_host)"

  public_network_access="$(
    az storage account show \
      --resource-group "${RG}" \
      --name "${STORAGE_ACCOUNT}" \
      --query publicNetworkAccess -o tsv
  )"
  allow_blob_public_access="$(
    az storage account show \
      --resource-group "${RG}" \
      --name "${STORAGE_ACCOUNT}" \
      --query allowBlobPublicAccess -o tsv
  )"
  assert_eq "Storage public network access is Disabled" "Disabled" "${public_network_access}"
  assert_eq "Storage anonymous blob access is disabled" "false" "${allow_blob_public_access}"

  resolved_ip="$(
    getent hosts "${STORAGE_BLOB_HOST}" 2>/dev/null | awk '{print $1; exit}' || true
  )"
  if [[ -z "${resolved_ip}" ]]; then
    resolved_ip="$(
      nslookup "${STORAGE_BLOB_HOST}" 2>/dev/null | awk '/^Address: / { print $2; exit }' || true
    )"
  fi

  if [[ -z "${resolved_ip}" ]]; then
    log_fail "Storage blob FQDN resolves to a private IP (no answer for ${STORAGE_BLOB_HOST})"
  elif [[ "${resolved_ip}" =~ ^10\. ]]; then
    log_pass "Storage blob FQDN resolves to private IP ${resolved_ip}"
  else
    log_fail "Storage blob FQDN resolves to non-private IP (got ${resolved_ip})"
  fi
fi

log_section "Key Vault (public access off, private endpoint, private DNS resolution)"
if skip_if_missing_output "key_vault_name" "Key Vault output missing — implement keyvault.tf and apply"; then
  :
else
  KEY_VAULT_NAME="$(tf_output key_vault_name)"
  KEY_VAULT_ID="$(tf_output key_vault_id)"
  KEY_VAULT_URI="$(tf_output key_vault_uri)"
  KEY_VAULT_PE_ID="$(tf_output key_vault_private_endpoint_id)"
  KEY_VAULT_HOST="${KEY_VAULT_URI#https://}"
  KEY_VAULT_HOST="${KEY_VAULT_HOST%/}"

  kv_show_json="$(az keyvault show --name "${KEY_VAULT_NAME}" -o json)"
  kv_public_network_access="$(jq -r '.properties.publicNetworkAccess' <<<"${kv_show_json}")"
  kv_rbac_authorization="$(jq -r '.properties.enableRbacAuthorization' <<<"${kv_show_json}")"
  kv_sku="$(jq -r '.properties.sku.name' <<<"${kv_show_json}")"
  kv_purge_protection="$(jq -r '.properties.enablePurgeProtection // false' <<<"${kv_show_json}")"
  kv_tag_keys="$(jq -r '.tags // {} | keys[]' <<<"${kv_show_json}")"

  assert_eq "Key Vault public network access is Disabled" "Disabled" "${kv_public_network_access}"
  assert_eq "Key Vault RBAC authorization is enabled" "true" "${kv_rbac_authorization}"
  assert_eq "Key Vault SKU is standard" "standard" "${kv_sku}"
  assert_eq "Key Vault purge protection is disabled" "false" "${kv_purge_protection}"
  assert_contains "Key Vault has Owner tag" "Owner" "${kv_tag_keys}"
  assert_contains "Key Vault has Environment tag" "Environment" "${kv_tag_keys}"
  assert_contains "Key Vault has Project tag" "Project" "${kv_tag_keys}"

  kv_resolved_ip="$(
    getent hosts "${KEY_VAULT_HOST}" 2>/dev/null | awk '{print $1; exit}' || true
  )"
  if [[ -z "${kv_resolved_ip}" ]]; then
    kv_resolved_ip="$(
      nslookup "${KEY_VAULT_HOST}" 2>/dev/null | awk '/^Address: / { print $2; exit }' || true
    )"
  fi

  if [[ -z "${kv_resolved_ip}" ]]; then
    log_fail "Key Vault FQDN resolves to a private IP (no answer for ${KEY_VAULT_HOST})"
  elif [[ "${kv_resolved_ip}" =~ ^10\. ]]; then
    log_pass "Key Vault FQDN resolves to private IP ${kv_resolved_ip}"
  else
    log_fail "Key Vault FQDN resolves to non-private IP (got ${kv_resolved_ip})"
  fi

  kv_pe_status="$(
    az network private-endpoint show \
      --ids "${KEY_VAULT_PE_ID}" \
      --query "privateLinkServiceConnections[0].privateLinkServiceConnectionState.status" -o tsv
  )"
  assert_eq "Key Vault private endpoint connection is Approved" "Approved" "${kv_pe_status}"

  id_manager_pid="$(tf_output id_manager_principal_id)"
  idmgr_kv_roles="$(
    az role assignment list \
      --scope "${KEY_VAULT_ID}" \
      --query "[?principalId=='${id_manager_pid}'].roleDefinitionName" -o tsv
  )"
  assert_contains "id-manager holds Key Vault Secrets Officer (seed grant)" "Key Vault Secrets Officer" "${idmgr_kv_roles}"

  log_skip "Dummy secret data-plane read deferred to RBAC phase (needs vm-mi's Key Vault Secrets User grant)"
fi

log_section "RBAC and data-plane (not deployed yet)"
if skip_if_missing_output "vm_mi_required_roles" "RBAC outputs missing — implement rbac.tf and apply"; then
  :
else
  log_skip "RBAC and positive/negative data-plane checks not implemented in this phase"
fi

print_summary