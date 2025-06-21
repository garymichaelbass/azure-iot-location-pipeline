# azure-iot-location-monitoring\terraform\outputs.tf

output "resource_group_name" {
  value = azurerm_resource_group.iot_resource_group.name
}

output "iot_hub_name" {
  value = azurerm_iothub.iot_hub.name
}

output "iot_hub_connection_string" {
  value = azurerm_iothub.iot_hub.name
}

output "iot_simulator_device_name" {
  description = "Name of the IoT simulator device"
  value       = var.iot_device_name
  sensitive   = false
}

output "cosmos_db_endpoint" {
  value = azurerm_cosmosdb_account.iot_cosmosdb_account.endpoint
}

output "eventhub_namespace" {
  value = azurerm_eventhub_namespace.iot_eventhub_namespace.name
}

output "databricks_workspace_url" {
  value = azurerm_databricks_workspace.iot_databricks_workspace.workspace_url
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