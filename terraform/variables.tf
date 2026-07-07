# --- Azure subscription / tenant ---

variable "subscription_id" {
  type        = string
  description = "Target subscription ID (Telexistence Retail interview subscription)."
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID."
}

# --- Managed identities (MSI client IDs for provider auth) ---

variable "id_manager_client_id" {
  type        = string
  description = "Client ID of the id-manager user-assigned managed identity (default Terraform provider)."
}

variable "access_manager_client_id" {
  type        = string
  description = "Client ID of the access-manager user-assigned managed identity (azurerm.rbac provider)."
}

variable "vm_mi_principal_id" {
  type        = string
  description = "Principal (object) ID of the bootstrap VM system-assigned managed identity (vm-mi)."
}

# --- Provided infrastructure (data sources — not managed) ---

variable "resource_group_name" {
  type        = string
  description = "Provided resource group hosting all challenge resources."
  default     = "rg-interview-vm-andressa"
}

variable "vnet_a_name" {
  type        = string
  description = "Provided VNet A name."
  default     = "vnet-a-vm-andressa"
}

variable "bootstrap_subnet_name" {
  type        = string
  description = "Provided subnet hosting the bootstrap VM and Key Vault private endpoint."
  default     = "snet-bootstrap"
}

variable "bootstrap_nsg_name" {
  type        = string
  description = "Provided NSG on snet-bootstrap (read-only reference; never modified)."
  default     = "nsg-vm-andressa"
}

variable "vm_name" {
  type        = string
  description = "Provided bootstrap VM name."
  default     = "vm-vm-andressa"
}

variable "id_manager_name" {
  type        = string
  description = "Provided id-manager user-assigned identity name."
  default     = "id-manager-vm-andressa"
}

variable "access_manager_name" {
  type        = string
  description = "Provided access-manager user-assigned identity name."
  default     = "access-manager-vm-andressa"
}

# --- Candidate-managed network (created in network.tf) ---

variable "vnet_b_address_space" {
  type        = list(string)
  description = "Address space for new VNet B (must not overlap VNet A)."
  default     = ["10.20.0.0/16"]
}

variable "storage_subnet_name" {
  type        = string
  description = "Subnet in VNet B hosting the storage private endpoint."
  default     = "snet-storage"
}

variable "storage_subnet_address_prefixes" {
  type        = list(string)
  description = "CIDR for snet-storage."
  default     = ["10.20.1.0/24"]
}

variable "bootstrap_subnet_cidr" {
  type        = string
  description = "CIDR of snet-bootstrap; used as NSG source for storage PE inbound."
  default     = "10.10.0.0/24"
}

# --- Naming / provisioning options ---

variable "name_prefix" {
  type        = string
  description = "Short lowercase prefix for globally unique resource names (storage account, Key Vault)."
  default     = "aiic"
}

# --- Mandatory tags (Azure Policy) ---

variable "tag_owner" {
  type        = string
  description = "Owner tag value applied to all taggable resources."
}

variable "tag_environment" {
  type        = string
  description = "Environment tag value applied to all taggable resources."
  default     = "interview"
}

variable "tag_project" {
  type        = string
  description = "Project tag value applied to all taggable resources."
  default     = "azure-infra-identity-challenge"
}