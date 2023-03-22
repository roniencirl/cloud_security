

resource "azurerm_public_ip" "mediawikiAGPublicIP" {
  name                = "mediawikiAGPublicIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  domain_name_label   = "mediawiki2023"
  allocation_method   = "Static"
  sku                 = "Standard"

}

resource "azurerm_subnet" "mediawikiAGSubnet" {
  name                 = "mediawikiAGSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mediawiki_network.name
  address_prefixes     = ["10.0.2.0/24"]

}

# https://github.com/aztfm/terraform-azurerm-application-gateway/blob/v1.2.0/examples/application-gateway-with-basic-http-configuration/main.tf
/*
module "application-gateway" {
  source                    = "aztfm/application-gateway/azurerm"
  version                   = "1.0.0"
  name                      = "medaiwikiAG"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  sku                       = { tier = "WAF_v2", size = "WAF_v2", capacity = 2 }
  subnet_id                 = azurerm_subnet.mediawikiAGSubnet.id
  frontend_ip_configuration = { public_ip_address_id = azurerm_public_ip.mediawikiAGPublicIP.id }
  backend_address_pools = [
    { name = "backend-address-pool", ip_addresses = join(",", azurerm_linux_virtual_machine.mediawiki_vm.private_ip_addresses) },
  ]
  http_listeners        = [{ name = "http-listener", frontend_ip_configuration = "Public", port = 80, protocol = "http" }]
  backend_http_settings = [{ name = "backend-http-setting", port = 80, protocol = "http", request_timeout = 20 }]
  request_routing_rules = [
    {
      name                       = "request-routing-rule-1"
      http_listener_name         = "http-listener"
      backend_address_pool_name  = "backend-address-pool"
      backend_http_settings_name = "backend-http-setting"
    }
  ]
}
*/

resource "azurerm_application_gateway" "mediawikigateway" {
  enable_http2                      = false
  fips_enabled                      = false
  force_firewall_policy_association = false
  location                          = "eastus"
  name                              = "medaiwikiAG"
  resource_group_name               = "rg-definite-tetra"
  tags                              = {}
  zones                             = []

  backend_address_pool {
    fqdns = []
    ip_addresses = [
      "10.0.1.4",
    ]
    name = "backend-address-pool"
  }

  backend_http_settings {
    cookie_based_affinity               = "Disabled"
    name                                = "backend-http-setting"
    pick_host_name_from_backend_address = false
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
  }

  frontend_ip_configuration {
    name                          = "Public-frontend-ip-configuration"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "/subscriptions/5e9bbbd4-9116-4cff-b4e0-3ea563490470/resourceGroups/rg-definite-tetra/providers/Microsoft.Network/publicIPAddresses/mediawikiAGPublicIP"
  }

  frontend_port {
    name = "443"
    port = 443
  }
  frontend_port {
    name = "80"
    port = 80
  }

  gateway_ip_configuration {
    name      = "medaiwikiAG-configuration"
    subnet_id = "/subscriptions/5e9bbbd4-9116-4cff-b4e0-3ea563490470/resourceGroups/rg-definite-tetra/providers/Microsoft.Network/virtualNetworks/mediawikiVnet/subnets/mediawikiAGSubnet"
  }

  http_listener {
    frontend_ip_configuration_name = "Public-frontend-ip-configuration"
    frontend_port_name             = "80"
    host_names                     = []
    name                           = "http-listener"
    protocol                       = "Http"
    require_sni                    = false
  }
  http_listener {
    frontend_ip_configuration_name = "Public-frontend-ip-configuration"
    frontend_port_name             = "443"
    host_names                     = []
    name                           = "https-listener"
    protocol                       = "Https"
    require_sni                    = false
    ssl_certificate_name           = "mediawiki"
  }
 # manually uploaded
  identity {
    identity_ids = [
      "/subscriptions/5e9bbbd4-9116-4cff-b4e0-3ea563490470/resourceGroups/rg-definite-tetra/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mediawikikeyvaulttls",
    ]
    type = "UserAssigned"
  }

  request_routing_rule {
    backend_address_pool_name  = "backend-address-pool"
    backend_http_settings_name = "backend-http-setting"
    http_listener_name         = "http-listener"
    name                       = "request-routing-rule-1"
    priority                   = 10010
    rule_type                  = "Basic"
  }
  request_routing_rule {
    backend_address_pool_name  = "backend-address-pool"
    backend_http_settings_name = "backend-http-setting"
    http_listener_name         = "https-listener"
    name                       = "request-routing-rule-2"
    priority                   = 1002
    rule_type                  = "Basic"
  }

  sku {
    capacity = 2
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }

  ssl_certificate {
    key_vault_secret_id = "https://tlsmediawiki.vault.azure.net/secrets/mediawiki"
    name                = "mediawiki"
  }

  ssl_policy {
    cipher_suites      = []
    disabled_protocols = []
    policy_name        = "AppGwSslPolicy20150501"
    policy_type        = "Predefined"
  }

  timeouts {}
}
