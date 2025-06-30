# azure-iot-location-monitoring\terraform\modules\databricks\outputs.tf

output "databricks_cluster_id" {
  description = "The ID of the provisioned Databricks cluster."
  value       = databricks_cluster.iot_cluster.id
}

output "databricks_job_id" {
  description = "The ID of the Databricks job."
  value       = databricks_job.iot_job.id
}

output "databricks_notebook_path" {
  description = "The full path where the notebook was uploaded in Databricks."
  value       = databricks_notebook.iot_notebook.path
}
