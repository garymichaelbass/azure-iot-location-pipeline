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
  spark_version           = data.databricks_spark_version.latest_lts.id
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
        device_count = "100"
        eventhub_connection_string = var.eventhub_connection_string
        cosmos_db_endpoint         = var.cosmos_db_endpoint # Also ensure these are passed
        cosmos_db_key              = var.cosmos_db_key      # (with security considerations)
      }
    }
  }
}

