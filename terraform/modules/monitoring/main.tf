# azure-iot-location-monitoring\terraform\modules\monitoring\main.tf

# Deploy an Azure Managed Grafana instance with system-assigned identity and tags for ownership
resource "azurerm_dashboard_grafana" "iot_grafana" {
  name                   = "${var.prefix}-grafana"
  location               = var.location
  resource_group_name    = var.resource_group_name
  grafana_major_version  = 9

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Grant Grafana permissions to read monitoring data from the AKS cluster
resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = var.aks_cluster_id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.iot_grafana.identity[0].principal_id
}
