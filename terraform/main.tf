# azure-iot-location-monitoring\terraform\main.tf

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

# Provision an Azure IoT Hub. Enables fallback routing to the Event Hub-compatible endpoint.
resource "azurerm_iothub" "iot_hub" {
  name                = var.iot_hub_name    # iotlocationhub
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name

  sku {
    name     = "S1"
    capacity = 1
  }

  fallback_route {
    enabled         = true
    source          = "DeviceMessages"
    endpoint_names  = ["events"]
  }

  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
  }
}

# Provision an IoT Simulator Device as a "null resource"
resource "null_resource" "register_iot_simulator_device" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"] # Add this line
    command = <<EOT
      set -e
      az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
      az extension show --name azure-iot || az extension add --name azure-iot --only-show-errors --yes
      az iot hub device-identity create \
        --device-id ${var.iot_device_name} \
        --hub-name ${azurerm_iothub.iot_hub.name} \
        --resource-group ${azurerm_resource_group.iot_resource_group.name} \
        --only-show-errors
    EOT
  }

  depends_on = [azurerm_iothub.iot_hub]
}

# Create an Event Hub instance to buffer and transport device telemetry messages.
resource "azurerm_eventhub" "iot_eventhub" {
  name                = "ioteventhub"
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  namespace_name      = azurerm_eventhub_namespace.iot_eventhub_namespace.name
  partition_count     = 2
  message_retention   = 1
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
  name                = var.cosmos_db_name
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

# Create an Azure Container Registry for the Docker image of the IoT device
resource "azurerm_container_registry" "iot_acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
}

data "azuread_service_principal" "github_sp" {
  display_name = "github-iot-acr-pusher"
}

 # Enable GitHub Actions to login into Registry utilizing ArcPush role
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.iot_acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azuread_service_principal.github_sp.object_id
}

# Databricks section added 20250623

# azure-iot-location-monitoring\terraform\modules\databricks\main.tf

# Fetches the smallest available Databricks node type with local disk support
data "databricks_node_type" "smallest" {
  local_disk = true
}

# Retrieves the latest long-term support (LTS) Spark version available on Databricks
data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

# Provisions a Databricks cluster using the LTS Spark version and smallest node type
resource "databricks_cluster" "iot_cluster" {
  cluster_name            = "iot-location-cluster"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 30
  num_workers             = 2
}

# Upload a Python notebook (notebook.py) to read from Event Hub and write to Cosmos DB.
resource "databricks_notebook" "iot_notebook" {
  # Location for uploaded notebook inside of the Databricks workspace
  # https://<your-databricks-url>#workspace/Shared/iot-location-notebook
  path     = "/Shared/iot-location-notebook"
  language = "PYTHON"
  source = "${path.module}/notebook.py"
}



# Create a Databricks job that executes the uploaded notebook on the specified cluster
resource "databricks_job" "iot_job" {
  name = "iot-simulator-job"

  task {
    task_key = "simulate-iot"
    existing_cluster_id = databricks_cluster.iot_cluster.id

    notebook_task {
      notebook_path = databricks_notebook.iot_notebook.path
      base_parameters = {
        device_count = "100"
      }
    }
  }
}

output "databricks_cluster_id" {
  description = "The ID of the provisioned Databricks cluster."
  value       = databricks_cluster.iot_cluster.id
}

output "databricks_job_id" {
  description = "The ID of the Databricks job."
  value       = databricks_job.iot_job.id
}

output "notebook_path_in_databricks" {
  description = "The full path where the notebook was uploaded in Databricks."
  value       = databricks_notebook.iot_notebook.path
}
