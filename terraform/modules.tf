# azure-iot-location-monitoring\terraform\modules.tf  

module "monitoring" {
  source              = "./modules/monitoring"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  aks_cluster_id      = azurerm_kubernetes_cluster.iot_aks_cluster.id
  aks_cluster_name    = azurerm_kubernetes_cluster.iot_aks_cluster.name
  prefix              = var.prefix
  environment         = var.environment
  owner               = var.owner
  project             = var.project
}

module "databricks_iot" {
  source = "./modules/databricks"

  cosmos_db_endpoint = azurerm_cosmosdb_account.iot_cosmosdb_account.endpoint
  cosmos_db_key      = azurerm_cosmosdb_account.iot_cosmosdb_account.primary_key
  eventhub_connection_string = azurerm_eventhub_namespace_authorization_rule.iot_send_rule.primary_connection_string

  providers = {
    databricks = databricks.workspace
  }

  depends_on = [azurerm_databricks_workspace.iot_databricks_workspace]
}
