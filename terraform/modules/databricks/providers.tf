# azure-iot-location-monitoring\terraform\modules\databricks\providers.tf

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.83.0"
    }
  }
}

