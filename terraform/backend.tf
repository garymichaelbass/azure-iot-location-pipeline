# azure-iot-location-monitoring\terraform\backend.tf

/* Create with the following:

az group create --name iot-tfstate-rg --location eastus2 # Use your preferred location
az storage account create --name iotmyuniqueterraformstate2025 --resource-group iot-tfstate-rg --location eastus2 --sku Standard_LRS --allow-blob-public-access false
az storage container create --name tfstate --account-name iotmyuniqueterraformstate2025

*/

terraform {
  backend "azurerm" {
    resource_group_name  = "iot-tfstate-rg"
    storage_account_name = "iotlocationmon20250621"
    container_name       = "tfstate"
    key                  = "iot-solution.tfstate"
  }
}
