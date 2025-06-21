# azure-iot-location-monitoring/terraform/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "owner" {
  description = "Owner or team responsible for this deployment"
  type        = string
}

variable "iot_hub_name" {
  description = "IoT Hub name"
  type        = string
}

variable "iot_device_name" {
  description = "IoT device name"
  type        = string
}

variable "cosmos_db_name" {
  description = "Cosmos DB account name"
  type        = string
}

variable "prefix" {
  description = "Prefix for naming AKS and related resources"
  type        = string
}

variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool"
  type        = number
}

variable "aks_node_vm_size" {
  description = "The size of the Virtual Machine for AKS nodes (e.g., Standard_DS2_v2, Standard_B2s)."
  type        = string
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "github_client_id" {
  description = "The client ID (application ID) of the GitHub Actions service principal"
  type        = string
}

/* GMB maybe delete this
variable "github_actions_sp_object_id" {
  description = "Object ID of the GitHub Actions Service Principal"
  type        = string
}
# $ az ad sp show --id <clientId> --query "id" --output tsv
# <clientId> is from AZURE_CREDENTIALS 
*/