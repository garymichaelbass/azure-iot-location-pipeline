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
  node_type_id            = data.databricks_node_type.smallest.id
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
      }
    }
  }
}

output "databricks_cluster_id" {
  description = "The ID of the provisioned Databricks cluster."
  value       = databricks_cluster.iot_cluster.id
}

output "databricks_job_id" {
  description = "The ID of the Databricks job."
  value       = databricks_job.iot_job.id
}

output "notebook_path_in_databricks" {
  description = "The full path where the notebook was uploaded in Databricks."
  value       = databricks_notebook.iot_notebook.path
}
