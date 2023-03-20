# peer the wiki vnet to the database vnet



resource "azurerm_virtual_network_peering" "peerWiki2DB" {
  name                      = "peerWiki2DB"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.mediawiki_network.name
  remote_virtual_network_id = azurerm_virtual_network.mediawikidb.id
}

resource "azurerm_virtual_network_peering" "peerDB2Wiki" {
  name                      = "peerDB2Wiki"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.mediawikidb.name
  remote_virtual_network_id = azurerm_virtual_network.mediawiki_network.id
}
