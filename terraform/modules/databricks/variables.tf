# azure-iot-location-monitoring\terraform\modules\databricks\variables.tf

variable "cosmos_db_endpoint" {
  description = "Endpoint URI for the Cosmos DB account used for telemetry writes"
  type        = string
}

variable "cosmos_db_key" {
  description = "Primary key for Cosmos DB account (used for authentication)"
  type        = string
  sensitive   = true
}

variable "eventhub_connection_string_incl_entity" {
  description = "Primary connection string for the Event Hub-compatible endpoint plus entity"
  type        = string
  sensitive   = true
}

variable "databricks_workspace_url" {
  type        = string
  description = "URL of the Azure Databricks workspace"
}

variable "cosmos_db_database" {
  description = "Name of the Cosmos DB SQL database"
  type        = string
}

variable "cosmos_db_container" {
  description = "Name of the Cosmos DB container"
  type        = string
}
