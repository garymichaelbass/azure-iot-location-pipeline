# azure-iot-location-monitoring\terraform\modules\monitoring\outputs.tf

output "grafana_endpoint" {
  description = "Public endpoint for the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.iot_grafana.endpoint
}

output "grafana_resource_id" {
  description = "Azure resource ID of the Grafana instance"
  value       = azurerm_dashboard_grafana.iot_grafana.id
}

output "grafana_dashboard_url" {
  description = "Link to the deployed Azure Managed Grafana dashboards"
  value       = "${azurerm_dashboard_grafana.iot_grafana.endpoint}/dashboards"
}
