# azure-iot-location-monitoring\terraform\main.tf

# Lots of info from https://learn.microsoft.com/en-us/azure/iot-dps/quick-setup-auto-provision-terraform?tabs=bash

# Define the Azure resource group to serve as the container for all deployment resources. 
resource "azurerm_resource_group" "iot_resource_group" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Provision an IoT Simulator Device as a "null resource"
# Creates a new "device identity" ("truck-001") in the IoT Hub's internal device registry
# The IoT Hub requires a registered "device identity" for any device to secure connect and send data
resource "null_resource" "register_iot_simulator_device" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"] # Add this line
    command = <<EOT
      set -e
      az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors # Config CLI to automatically install extensions
      az extension show --name azure-iot || az extension add --name azure-iot --only-show-errors --yes  # Ensure Azure CLI extension for azure-iot is installed
      az iot hub device-identity create \     # Create new device identity ("truck-001") within Azure IoT Hub ("iotlocationhub")
        --device-id ${var.iot_device_name} \
        --hub-name ${azurerm_iothub.iot_hub.name} \
        --resource-group ${azurerm_resource_group.iot_resource_group.name} \
        --only-show-errors
    EOT
  }

  depends_on = [azurerm_iothub.iot_hub]
}

# Create Event Hub namespace to manage Event Hub entities within namespace and create an FQDN as endpoint.
resource "azurerm_eventhub_namespace" "iot_eventhub_namespace" {
  name                = "ioteventns"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  sku                 = "Standard"
  capacity            = 1

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Create Authorization Rule that HOPEFULLY creates an endpoint for the IoT Hub
resource "azurerm_eventhub_authorization_rule" "my_terraform_authorization_rule" {
  name                = "iot-hub-send"
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  namespace_name      = azurerm_eventhub_namespace.iot_eventhub_namespace.name
  eventhub_name       = azurerm_eventhub.iot_eventhub.name

  send = true
}

# Provision an Azure IoT Hub. NO LONGER ... Enables fallback routing to the Event Hub-compatible endpoint.
resource "azurerm_iothub" "iot_hub" {
  name                = var.iot_hub_name    # iotlocationhub
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name

  sku {
    name     = "S1"
    capacity = 1
  }

  endpoint {
    type              = "AzureIotHub.EventHub"
    connection_string = azurerm_eventhub_authorization_rule.my_terraform_authorization_rule.primary_connection_string
    name              = "export"
  }

  route {
    name           = "export"
    source         = "DeviceMessages"
    condition      = "true"
    endpoint_names = ["export"]
    enabled        = true
  }

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}


resource "azurerm_iothub_shared_access_policy" "iot_hub_connection_policy" {
  name                = "iothub-owner-policy"
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  iothub_name         = azurerm_iothub.iot_hub.name

  registry_read   = true
  registry_write  = true
  service_connect = true
  device_connect  = true
}

# Create an Event Hub instance to buffer and transport device telemetry messages.
resource "azurerm_eventhub" "iot_eventhub" {
  name              = "ioteventhub"
  namespace_id      = azurerm_eventhub_namespace.iot_eventhub_namespace.id
  partition_count   = 2
  message_retention = 1
}

# Create rule to grant Send and Listen access to the Event Hub
resource "azurerm_eventhub_namespace_authorization_rule" "iot_send_rule" {
  name                = "iot-send-auth"
  namespace_name      = azurerm_eventhub_namespace.iot_eventhub_namespace.name
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  listen              = true
  send                = true
  manage              = false
}

# Deploy a Standard-tier Azure Databricks workspace for streaming, transformation, and analytics of IoT data.
resource "azurerm_databricks_workspace" "iot_databricks_workspace" {
  name                = "iot-dbx"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  sku                 = "standard"

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Create a globally distributed Azure Cosmos DB account.
resource "azurerm_cosmosdb_account" "iot_cosmosdb_account" {
  name                = var.cosmos_db_account_name
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

resource "azurerm_cosmosdb_sql_database" "iot_cosmosdb_database" {
  name                = var.cosmos_db_database_name
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  account_name        = azurerm_cosmosdb_account.iot_cosmosdb_account.name
}

resource "azurerm_cosmosdb_sql_container" "iot_cosmosdb_sql_container" {
  name                = var.cosmos_db_sql_container_name
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  account_name        = azurerm_cosmosdb_account.iot_cosmosdb_account.name
  database_name       = azurerm_cosmosdb_sql_database.iot_cosmosdb_database.name
  partition_key_paths  = ["/deviceId"]

  indexing_policy {
    indexing_mode = "consistent"
  }
}

# Create an Azure Container Registry for the Docker image of the IoT device
resource "azurerm_container_registry" "iot_acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = true
}

# azuread_service_principal: 
# It is used to create and manage a Service Principal within Azure Active Directory (Azure AD). 
# It is a security identity that allows applications or services to access Azure resources. 
# It functions as a "service account" with specific permissions
# It enables secure and controlled access to resources without using a user's credentials.
data "azuread_service_principal" "github_sp" {
  display_name = "github-iot-acr-pusher"
}

# Enable GitHub Actions to login into Registry utilizing ArcPush role
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.iot_acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azuread_service_principal.github_sp.object_id
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
