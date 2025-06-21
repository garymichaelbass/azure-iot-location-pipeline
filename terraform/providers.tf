# azure-iot-location-monitoring\providers.tf    

terraform {
  required_version = ">= 1.4.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # version = "~> 3.100.0"
      version = "3.108.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50.0"
    }

    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.83.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }

  }
}

provider "azurerm" {
  features {}
}


provider "azuread" {
  # Inherits authentication from the environment (e.g., GitHub Actions, az CLI)
}

provider "databricks" {
  host                        = azurerm_databricks_workspace.iot_databricks_workspace.workspace_url
  azure_workspace_resource_id = azurerm_databricks_workspace.iot_databricks_workspace.id
}

provider "random" {
  # No config needed; just initializes the plugin
}

