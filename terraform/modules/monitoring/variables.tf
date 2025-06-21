# azure-iot-location-monitoring\terraform\modules\monitoring\variables.tf

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where monitoring resources will be deployed"
  type        = string
}

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
