# VNet B, storage subnet, NSG, and bidirectional peering with provided VNet A.

resource "azurerm_virtual_network" "vnet_b" {
  name                = local.vnet_b_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = var.vnet_b_address_space
  tags                = local.tags
}

resource "azurerm_network_security_group" "storage" {
  name                = local.nsg_storage_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "storage_allow_app_https" {
  name                        = "Allow-App-to-PE-HTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.bootstrap_subnet_cidr
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.storage.name
}

resource "azurerm_network_security_rule" "storage_deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.storage.name
}

resource "azurerm_network_security_rule" "storage_allow_out_vnet" {
  name                        = "Allow-Out-VNet"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.storage.name
}

resource "azurerm_network_security_rule" "storage_deny_out_internet" {
  name                        = "Deny-Out-Internet"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = data.azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.storage.name
}

# Subnets do not support tags in the azurerm provider (or Azure Policy for this
# resource type). Governance tags are applied on the parent VNet and NSG instead.
resource "azurerm_subnet" "storage" {
  name                 = var.storage_subnet_name
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet_b.name
  address_prefixes     = var.storage_subnet_address_prefixes

  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet_network_security_group_association" "storage" {
  subnet_id                 = azurerm_subnet.storage.id
  network_security_group_id = azurerm_network_security_group.storage.id
}

resource "azurerm_virtual_network_peering" "a_to_b" {
  name                      = "${var.name_prefix}-peer-a-to-b"
  resource_group_name       = data.azurerm_resource_group.this.name
  virtual_network_name      = data.azurerm_virtual_network.vnet_a.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_b.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "b_to_a" {
  name                      = "${var.name_prefix}-peer-b-to-a"
  resource_group_name       = data.azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.vnet_b.name
  remote_virtual_network_id = data.azurerm_virtual_network.vnet_a.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}