# azure-iot-location-monitoring\terraform\modules\monitoring\main.tf

resource "azurerm_monitor_workspace" "iot_monitor_workspace" {
  name                = "${var.prefix}-monitor-workspace"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Deploy an Azure Managed Grafana instance with system-assigned identity and tags for ownership
resource "azurerm_dashboard_grafana" "iot_grafana" {
  name                   = "${var.prefix}-grafana"
  location               = var.location
  resource_group_name    = var.resource_group_name
  grafana_major_version  = 11
  api_key_enabled        = true
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }

  # GMB Add this in later.
  azure_monitor_workspace_integrations {
    # CORRECTED: Referencing the ID of the azurerm_monitor_account resource
    resource_id = azurerm_monitor_workspace.iot_monitor_workspace.id
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
resource "azurerm_role_assignment" "grafana_admin_for_user" {
  scope                = azurerm_dashboard_grafana.iot_grafana.id
  role_definition_name = "Grafana Admin"
  principal_id         = var.grafana_admin_principal_id     # GitHub Secret of AZURE_USER_OBJECT_ID
  depends_on           = [azurerm_dashboard_grafana.iot_grafana]
}

resource "azurerm_role_assignment" "grafana_monitor_reader_iothub" {
  scope                = var.iot_hub_id  # Pass this in as a variable
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.iot_grafana.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_monitor_reader_cosmosdb" {
  scope                = var.cosmosdb_account_id  # Pass this in as a variable
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.iot_grafana.identity[0].principal_id
}
