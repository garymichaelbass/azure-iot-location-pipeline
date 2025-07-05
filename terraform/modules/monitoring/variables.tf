# azure-iot-location-monitoring\terraform\modules\monitoring\variables.tf

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where monitoring resources will be deployed"
  type        = string
}

# Remove the following as it is causing a deployment error due to modules not having it defined yet
# variable "resource_group_id" {
#   description = "ID of the resource group"
#   type        = string
# }

variable "aks_cluster_id" {
  description = "ID of the AKS cluster to attach monitoring"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster used for tagging or monitoring references"
  type        = string
}

variable "prefix" {
  description = "Prefix for naming resources like Grafana"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "owner" {
  description = "Owner or team responsible for the deployment"
  type        = string
}

variable "project" {
  description = "Project name or identifier"
  type        = string
}

# Adding this within the module to grant the user permission to Grafana (defined as AZURE_USER_OBJECT_ID in GitHub Secrets)

variable "grafana_admin_principal_id" {
  description = "The Azure AD Object ID of the user or group to assign Grafana Admin permissions."
  type        = string
  sensitive   = true # Mark as sensitive as it's an ID for a principal
}