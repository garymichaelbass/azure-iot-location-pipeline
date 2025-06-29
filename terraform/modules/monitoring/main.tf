# azure-iot-location-monitoring\terraform\modules\monitoring\main.tf

# Deploy an Azure Managed Grafana instance with system-assigned identity and tags for ownership
resource "azurerm_dashboard_grafana" "iot_grafana" {
  name                   = "${var.prefix}-grafana"
  location               = var.location
  resource_group_name    = var.resource_group_name
  grafana_major_version  = 11

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


# Grant your user Grafana Admin permissions to the Azure Managed Grafana instance
# principal_id is the output of "az ad signed-in-user show --query id -o tsv"
184de8f4-c1e8-48b7-81a6-bbd9e875b94a


# Grant your user Grafana Admin permissions to the Azure Managed Grafana instance
resource "azurerm_role_assignment" "grafana_admin_for_user" {
  scope                = azurerm_dashboard_grafana.iot_grafana.id
  role_definition_name = "Grafana Admin"
  principal_id         = var.grafana_admin_principal_id     # GitHub Secret of AZURE_USER_OBJECT_ID
  depends_on           = [azurerm_dashboard_grafana.iot_grafana]
}

