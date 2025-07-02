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

output "databricks_workspace_url_value" {
  value = var.databricks_workspace_url
}

output "eventhub_connection_string_module_output" {
  description = "The Event Hub connection string (passed into this module)."
  value       = var.eventhub_connection_string # Output the variable received by the module
  # sensitive   = true # VERY IMPORTANT for security
  sensitive   = false # GMB change
}
