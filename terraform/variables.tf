# azure-iot-location-monitoring/terraform/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "iot-location-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "iot-simulator"
}

variable "owner" {
  description = "Owner or team responsible for this deployment"
  type        = string
  default     = "dev-team"
}

variable "eventhub_instance_name" {
  description = "Event Hub instance name"
  type        = string
  default     = "ioteventhub"
}

variable "iot_hub_name" {
  description = "IoT Hub name"
  type        = string
  default     = "iotlocationhub"
}

variable "iot_device_name" {
  description = "IoT device name"
  type        = string
  default     = "truck-001"
}

variable "cosmos_db_account_name" {
  description = "Cosmos database account name"
  type        = string
  default     = "iot-cosmos-account-gmb"
}

variable "cosmos_db_database_name" {
  description = "Cosmos database name"
  type        = string
  # default     = "iot-cosmos-database-gmb"
  default     = "iot-cosmos-db-gmb"
}

variable "cosmos_db_sql_container_name" {
  description = "Within the Cosmos database, the name for the Azure Cosmos DB SQL container (collection)."
  type        = string
  default     = "iot-cosmos-sql-container-gmb" # Provide a default that matches your notebook
}

variable "prefix" {
  description = "Prefix for naming AKS and related resources"
  type        = string
  default     = "iot"
}

variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool"
  type        = number
  default     = 1
}

variable "aks_node_vm_size" {
  description = "The size of the Virtual Machine for AKS nodes (e.g., Standard_DS2_v2, Standard_B2s)."
  type        = string
  default     = "Standard_DS1_v2"
  # Standard_B2s: 2 vCPUs, 4 GB RAM. Often the cheapest option for burstable workloads.
  # Standard_B2ms: 2 vCPUs, 8 GB RAM (more memory than B2s).
  # Standard_B1ls: 1 vCPU, 0.5 GB RAM. Very small, often too small for general AKS workloads unless your pods are extremely lightweight.
  #	Standard_B1ms: 1 vCPU, 2 GB RAM.
  # Standard_DS1_v2: 1 vCPU, 3.5 GB RAM. (Less popular than D2v2/D4v2 but exists).
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "AzureIotLocationMonitoringRegistry"
}

variable "azure_client_id" {
  description = "The client ID (application ID) of the GitHub Actions service principal"
  type        = string
}

variable "azure_client_secret" {
  description = "The client secret associated with the GitHub Actions service principal"
  type        = string
}

variable "azure_tenant_id" {
  description = "The Azure Active Directory tenant ID where the service principal resides"
  type        = string
}

variable "azure_subscription_id" {
  description = "The Azure subscription ID the service principal has access to"
  type        = string
}

variable "grafana_admin_principal_id" {
  description = "The Azure AD Object ID of the user or group to assign Grafana Admin permissions."
  type        = string
  sensitive   = true # Best practice for IDs that grant access
}

variable "azure_object_id" {
  type        = string
  description = "Azure AD Object ID used for role assignments or access control"
}
