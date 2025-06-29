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

# (Ensure your actual resource block for ACR exists and is named azurerm_container_registry.iot_acr)
# Example (if you don't have it elsewhere):
resource "azurerm_container_registry" "iot_acr" {
  name                = "azureiotlocationmonitoringregistry"
  resource_group_name = azurerm_resource_group.iot_resource_group.name # Or hardcode "iot-location-rg"
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = true # Common to enable for CI/CD logins
  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Assign AcrPull to the AKS cluster's SYSTEM-ASSIGNED IDENTITY
resource "azurerm_role_assignment" "aks_cluster_acr_pull_permission" {
  # Scope now refers to the resource being created by Terraform
  scope                = azurerm_container_registry.iot_acr.id # <-- REFERENCE THE RESOURCE BLOCK
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.iot_aks_cluster.identity[0].principal_id
  depends_on = [
    azurerm_container_registry.iot_acr,
    azurerm_kubernetes_cluster.iot_aks_cluster
  ]
}
