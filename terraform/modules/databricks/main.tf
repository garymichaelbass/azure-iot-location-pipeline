# azure-iot-location-monitoring\terraform\modules\databricks\main.tf

# Fetches the smallest available Databricks node type with local disk support
data "databricks_node_type" "smallest" {
  local_disk = true
}

# Retrieves the latest long-term support (LTS) Spark version available on Databricks
data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

# Provisions a Databricks cluster using the LTS Spark version and smallest node type
resource "databricks_cluster" "iot_cluster" {
  cluster_name            = "iot-location-cluster"
  spark_version           = "10.4.x-scala2.12"
  # node_type_id            = data.databricks_node_type.smallest.id
  # Available node types (Databricks-compatible in East US 2):
  # ✅ Databricks-compatible node types for East US 2:
  # - Standard_E2s_v3    (2 vCPU, 16 GiB) → memory optimized
  # - Standard_D2_v3     (2 vCPU, 8 GiB)  → general purpose
  # - Standard_DS1_v2    (1 vCPU, 3.5 GiB) → lightweight test config (deprecated in this workspace)
  # - Standard_E2s_v5    (2 vCPU, 16 GiB) → newer gen, if quota allows
  # - Standard_D3_v2     (4 vCPU, 14 GiB) → broadly supported, general purpose ← ✅ CURRENTLY SELECTED
  # - Standard_DS3_v2    (4 vCPU, 14 GiB) → same as above with premium disk support
  # - Standard_D4s_v3    (4 vCPU, 16 GiB) → strong general-purpose node, good CPU–RAM balance
  # - Standard_E4s_v4    (4 vCPU, 32 GiB) → memory heavy Spark ETL or telemetry
  # - Standard_E4ds_v5   (4 vCPU, 32 GiB) → newer gen, premium disk, quota-friendly

  # GMB Google Gemini recommends Standard_D4s_v3

  # node_type_id            = "Standard_DS2_v2"
  # node_type_id            = "Standard_B2s"
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 30
  num_workers             = 1

  library {
    maven {
      # Use the commonly available 2.3.23 for Scala 2.12
      coordinates = "com.microsoft.azure:azure-eventhubs-spark_2.12:2.3.22"
    }
  }

  # GMB: Make sure the Scala version in the artifact (_2.12) matches the one used in Databricks
  # runtime (which the cluster inherits from data.databricks_spark_version.latest_lts.id).

  # --- Also add the Cosmos DB connector here if you haven't already ---
  library {
    maven {
      # Try a slightly older but known good version if 4.32.0 is problematic for Spark 3.2
      # Or, verify that Spark 3.2 is truly available with 4.32.0.
      # If your latest_lts is 16.4, it's Spark 3.5.
      # For Spark 3.5.x, you might need a `_3-5_2-12` artifact or a more generic `spark_3-2_2-12`
      # that is forward compatible.
      # Let's try the common Spark 3.1 version first as it's often more broadly compatible.
      coordinates = "com.azure.cosmos.spark:azure-cosmos-spark_3-2_2.12:4.11.2"
      # If 4.20.0 doesn't work, try other common versions or check the exact Spark version of `latest_lts`
      # databricks_spark_version.latest_lts.id typically looks like "16.4.x-scala2.12" (Spark 3.5.x)
      # For Spark 3.5, `azure-cosmos-spark_3-2_2-12` might not be correct or compatible.
      # You might need to use `azure-cosmos-spark_3-1_2-12` which is often the most stable branch.
    }
  }
  # --- END Cosmos DB CONNECTOR ---

  # (Optional: Add any spark_conf here if you pass sensitive keys via spark.conf.get)
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
  name = "iot-simulator-job"

  task {
    task_key = "simulate-iot"
    existing_cluster_id = databricks_cluster.iot_cluster.id

    notebook_task {
      notebook_path = databricks_notebook.iot_notebook.path
      base_parameters = {
        device_count              = "100"
        eventhub_connection_string = var.eventhub_connection_string

        cosmos_db_endpoint        = var.cosmos_db_endpoint
        cosmos_db_key             = var.cosmos_db_key
        cosmos_db_database        = var.cosmos_db_database
        cosmos_db_container       = var.cosmos_db_container

      }
    }
  }
}

