# azure-iot-location-monitoring\providers.tf    

terraform {
  required_version = ">= 1.4.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # version = "~> 3.100.0"
      # version = "3.108.0"
      version = "~> 4.0"
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

  /* 
  # These values come from the terraform.tfvars.json file created from the following command:
  # az ad sp create-for-rbac --name "github-iot-acr-pusher" --role contributor --scopes /subscriptions/<your-subscription-id> --sdk-auth 
  {
	  "github_client_id": "your-value-here",
    "github_client_secret": "your-value-here",
    "github_tenant_id": "your-value-here",
    "github_subscription_id": "your-value-here"
  } 
  */

  client_id       = var.github_client_id
  client_secret   = var.github_client_secret
  tenant_id       = var.github_tenant_id
  subscription_id = var.github_subscription_id

}


provider "azuread" {
  # Inherits authentication from the environment (e.g., GitHub Actions, az CLI)
}

provider "databricks" {
  alias                       = "workspace"
  host                        = azurerm_databricks_workspace.iot_databricks_workspace.workspace_url
  azure_workspace_resource_id = azurerm_databricks_workspace.iot_databricks_workspace.id
}

provider "random" {
  # No config needed; just initializes the plugin
}

