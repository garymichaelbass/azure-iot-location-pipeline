output "grafana_endpoint" {
  description = "Public endpoint for the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.iot_grafana.endpoint
}

output "grafana_resource_id" {
  description = "Azure resource ID of the Grafana instance"
  value       = azurerm_dashboard_grafana.iot_grafana.id
}
