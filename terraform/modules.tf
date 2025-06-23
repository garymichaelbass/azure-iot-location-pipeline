# azure-iot-location-monitoring\terraform\modules.tf  

module "monitoring" {
  source              = "./modules/monitoring"
  location            = var.location
  resource_group_name = azurerm_resource_group.iot_resource_group.name
  aks_cluster_id      = azurerm_kubernetes_cluster.iot_aks_cluster.id
  aks_cluster_name    = azurerm_kubernetes_cluster.iot_aks_cluster.name
  prefix              = var.prefix
  environment         = var.environment
  owner               = var.owner
  project             = var.project
}
