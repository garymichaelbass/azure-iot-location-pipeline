# azure-iot-location-monitoring\terraform\aks.tf
  
# Create a Log Analytics workspace (ie, logs logical storage unit) for AKS monitoring
resource "azurerm_log_analytics_workspace" "aks_logs" {
  name                = "${var.prefix}-log"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  sku                 = "PerGB2018"

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Provision the AKS cluster
resource "azurerm_kubernetes_cluster" "iot_aks_cluster" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  dns_prefix          = "${var.prefix}-dns"
  kubernetes_version  = "1.32.4"

  default_node_pool {
    /* Prior to 20250623
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.aks_node_vm_size
    temporary_name_for_rotation = "tmpnodepool1"
    */
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2ms"
    temporary_name_for_rotation = "tmpnodepool1"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

resource "azurerm_monitor_data_collection_rule" "aks_dcr" {
  name                = "${var.prefix}-dcr"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name

  data_sources {
    performance_counter {
      streams                       = ["Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["\\Processor(_Total)\\% Processor Time"]
      name                          = "processorTime"
    }
  }

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.aks_logs.id
      name                  = "logAnalyticsDest"
    }
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["logAnalyticsDest"]
  }

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks_dcra" {
  name                    = "${var.prefix}-dcra"
  target_resource_id      = azurerm_kubernetes_cluster.iot_aks_cluster.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_dcr.id
}

# Look up the existing ACR
data "azurerm_container_registry" "iot_acr" {
  name                = "azureiotlocationmonitoringregistry"
  resource_group_name = "iot-location-rg"
}

# Assign AcrPull to the AKS kubelet identity
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = data.azurerm_container_registry.iot_acr.id
  role_definition_name = "AcrPull"
  # GMB_Delete_Later  principal_id         = azurerm_kubernetes_cluster.iot_aks_cluster.kubelet_identity[0].object_id
  principal_id         = azurerm_kubernetes_cluster.iot_aks_cluster.identity[0].principal_id # <-- CORRECTED LINE

  # Explicit dependencies ensure ACR and AKS are created before attempting role assignment.
  depends_on = [
    azurerm_container_registry.iot_acr,
    azurerm_kubernetes_cluster.iot_aks_cluster
  ]

}
