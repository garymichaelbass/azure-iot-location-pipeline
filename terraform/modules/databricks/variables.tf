# azure-iot-location-monitoring\terraform\modules\databricks\providers.tf

variable "cosmos_db_endpoint" {
  description = "Endpoint URI for the Cosmos DB account used for telemetry writes"
  type        = string
}

variable "cosmos_db_key" {
  description = "Primary key for Cosmos DB account (used for authentication)"
  type        = string
  sensitive   = true
}

variable "eventhub_connection_string" {
  description = "Primary connection string for the Event Hub-compatible endpoint"
  type        = string
  sensitive   = true
}