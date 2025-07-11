# azure-iot-location-monitoring\terraform\modules.tf  

module "monitoring_iot" {
  source              = "./modules/monitoring"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  resource_group_id   = azurerm_resource_group.iot_resource_group.id
  aks_cluster_id      = azurerm_kubernetes_cluster.iot_aks_cluster.id
  aks_cluster_name    = azurerm_kubernetes_cluster.iot_aks_cluster.name
  iot_hub_id          = azurerm_iothub.iot_hub.id
  cosmosdb_account_id = azurerm_cosmosdb_account.iot_cosmosdb_account.id

  prefix              = var.prefix
  environment         = var.environment
  owner               = var.owner
  project             = var.project
  grafana_admin_principal_id = var.grafana_admin_principal_id
}

module "databricks_iot" {
  source = "./modules/databricks"

  cosmos_db_endpoint         = azurerm_cosmosdb_account.iot_cosmosdb_account.endpoint
  cosmos_db_key              = azurerm_cosmosdb_account.iot_cosmosdb_account.primary_key
  cosmos_db_database         = var.cosmos_db_database_name
  cosmos_db_container        = var.cosmos_db_sql_container_name

  eventhub_connection_string_incl_entity = "${azurerm_eventhub_namespace_authorization_rule.iot_send_rule.primary_connection_string};EntityPath=${var.eventhub_instance_name}"
  databricks_workspace_url   = azurerm_databricks_workspace.iot_databricks_workspace.workspace_url

  providers = {
    databricks = databricks.workspace
  }

  depends_on = [
    azurerm_databricks_workspace.iot_databricks_workspace,
    azurerm_cosmosdb_account.iot_cosmosdb_account,
    azurerm_cosmosdb_sql_database.iot_cosmosdb_database,        # Add dependency on database
    azurerm_cosmosdb_sql_container.iot_cosmosdb_sql_container   # Add dependency on container
  ]
}
