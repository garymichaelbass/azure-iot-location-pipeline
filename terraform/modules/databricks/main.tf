# azure-iot-location-monitoring\terraform\modules\databricks\main.tf

# Fetches the smallest available Databricks node type with local disk support
data "databricks_node_type" "smallest" {
  local_disk = true
}

# Fetches the latest long-term support (LTS) Spark version available on Databricks
data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

# Provisions a Databricks cluster using the LTS Spark version and smallest node type
resource "databricks_cluster" "iot_cluster" {
  cluster_name            = "iot-dbx-cluster"
  spark_version           = "16.4.x-scala2.12"
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 30
  num_workers             = 1

  library {
    maven {
      coordinates = "com.microsoft.azure:azure-eventhubs-spark_2.12:2.3.22" 
    }
  }

  library {
    maven {
      coordinates = "com.azure.cosmos.spark:azure-cosmos-spark_3-5_2-12:4.37.2"
    }
  }

  # (Optional) Use spark_conf to inject secrets into the Spark runtime.
  # Recommended only if you're not using Databricks Secret Scopes.
  #
  # spark_conf = {
  #   "spark.databricks.io.eventhubs.connectionString" = var.eventhub_connection_string
  #   "spark.databricks.io.cosmos_db_endpoint"         = var.cosmos_db_endpoint
  #   "spark.databricks.io.cosmos_db_key"              = var.cosmos_db_key
  # }

}

# Upload a Python notebook (notebook.py) to read from Event Hub and write to Cosmos DB. 
resource "databricks_notebook" "iot_notebook" {
  # Location for uploaded notebook inside of the Databricks workspace
  # https://<your-databricks-url>#workspace/Shared/iot-location-notebook
  path     = "/Shared/iot-location-notebook"
  language = "PYTHON"
  source = "${path.module}/notebook.py"
}

# Create a Databricks job that executes the uploaded notebook on the specified cluster
resource "databricks_job" "iot_job" {
  name = "iot-dbx-job"

  task {
    task_key = "simulate-iot"
    existing_cluster_id = databricks_cluster.iot_cluster.id

    notebook_task {
      notebook_path = databricks_notebook.iot_notebook.path
      base_parameters = {
        device_count                           = "100"
        eventhub_connection_string_incl_entity = var.eventhub_connection_string_incl_entity

        cosmos_db_endpoint                     = var.cosmos_db_endpoint
        cosmos_db_key                          = var.cosmos_db_key
        cosmos_db_database                     = var.cosmos_db_database
        cosmos_db_container                    = var.cosmos_db_container

      }
    }
  }
}

