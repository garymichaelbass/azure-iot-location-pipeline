# azure-iot-location-monitoring\terraform\outputs.tf

output "resource_group_name" {
  value = azurerm_resource_group.iot_resource_group.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.iot_aks_cluster.name
}

output "aks_kube_config" {
  value     = azurerm_kubernetes_cluster.iot_aks_cluster.kube_config_raw
  sensitive = true
}

output "acr_login_server" {
  description = "Login server URL for the Azure Container Registry"
  value       = azurerm_container_registry.iot_acr.login_server
}

output "iot_simulator_device_name" {
  description = "Name of the IoT simulator device"
  value       = var.iot_device_name
  sensitive   = false
}

output "iot_hub_name" {
  value = azurerm_iothub.iot_hub.name
}

output "iot_hub_connection_string" {
  description = "Primary connection string for the IoT Hub"
  value       = azurerm_iothub_shared_access_policy.iot_hub_connection_policy.primary_connection_string
  sensitive   = true
}

output "eventhub_namespace" {
  value = azurerm_eventhub_namespace.iot_eventhub_namespace.name
}

output "eventhub_connection_string_incl_entity" {
  description = "The Event Hub connection string used by the Databricks pipeline (sensitive)."
  value       = "${azurerm_eventhub_namespace_authorization_rule.iot_send_rule.primary_connection_string};EntityPath=${var.eventhub_instance_name}"
  sensitive   = true # VERY IMPORTANT for security
}

output "databricks_workspace_url" {
  value = azurerm_databricks_workspace.iot_databricks_workspace.workspace_url
}

output "databricks_workspace_url_value" {
  value = azurerm_databricks_workspace.iot_databricks_workspace.workspace_url
}

output "databricks_notebook_path" {
  value       = module.databricks_iot.databricks_notebook_path
  description = "Confirms the notebook was uploaded successfully."
}

output "databricks_job_id" {
  value = module.databricks_iot.databricks_job_id
}

output "databricks_job_run_url" {
  description = "URL to monitor the Databricks job"
  value       = "${azurerm_databricks_workspace.iot_databricks_workspace.workspace_url}#job/${module.databricks_iot.databricks_job_id}"
}

output "cosmos_db_endpoint" {
  description = "Database endpoint"
  value = azurerm_cosmosdb_account.iot_cosmosdb_account.endpoint
}

output "cosmos_db_database" {
  description = "Cosmos database"
  value = azurerm_cosmosdb_account.iot_cosmosdb_account.name
}

output "cosmos_db_sql_container" {
  description = "Cosmos database container"
  value = azurerm_cosmosdb_sql_container.iot_cosmosdb_sql_container.name
}

output "grafana_endpoint" {
  value       = module.monitoring_iot.grafana_endpoint
  description = "Public endpoint for the Azure Managed Grafana instance"
}

output "grafana_resource_id" {
  description = "Azure resource ID of the Grafana instance"
  value = module.monitoring_iot.grafana_resource_id
}

output "grafana_dashboard_url" {
  value = module.monitoring_iot.grafana_dashboard_url
}