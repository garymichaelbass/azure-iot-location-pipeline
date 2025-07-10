# 📦 Databricks Cluster Lifecycle (Terraform-Based)

This document explains the full lifecycle of the Databricks cluster used in the Azure IoT location monitoring pipeline. The cluster is provisioned with Terraform using the `databricks_cluster` resource and is tightly integrated with a notebook job for real-time data streaming and enrichment.

---

## 🔁 Lifecycle Phases

### 1. 📥 Spark Version and Node Selection

The configuration dynamically retrieves the latest stable Spark runtime and smallest node type:

```hcl
data "databricks_spark_version" "latest_lts" { long_term_support = true }
data "databricks_node_type" "smallest" { local_disk = true }

💡 This ensures that the cluster uses a reliable runtime and cost-efficient nodes, and remains up-to-date over time.

2. 🏗️ Cluster Definition

The databricks_cluster resource defines the actual compute environment.

azure-iot-location-monitoring\databricks\main.tf

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


✅ Key behaviors:
- Auto-termination shuts down idle clusters after 30 minutes
- Two-worker nodes support modest streaming loads from Event Hub
- Cluster can be reused by multiple notebook jobs (cost optimization)

3. 📡 Execution via Databricks Job

This cluster is used by the databricks_job resource defined in main.tf

azure-iot-location-monitoring\databricks\main.tf

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

4. 💥 Runtime Behavior

Once the job starts:
- The cluster is provisioned via the Databricks REST API
- Workers are initialized and attach to the driver
- The notebook begins streaming from Azure Event Hub in micro-batches
- Processed records are written to Cosmos DB using Spark's writeStream

5. 🧹 Auto-Termination

If no job is running or the notebook is canceled:
- The cluster remains active for 30 minutes
- After that, it automatically shuts down to save compute costs

Cluster Resource Summary
| Attribute | Value | 
| Spark Version | Latest LTS (auto-resolved) | 
| Node Type | Smallest node with local disk | 
| Workers | 2 | 
| Auto-Termination | 30 minutes | 
| Provisioned via | Terraform (databricks_cluster) | 
| Used By | databricks_job.iot_job notebook | 


📘 Best Practices
- Use auto-termination to reduce costs for streaming jobs
- Store the cluster ID in Terraform outputs if you want to reuse it across environments
- Define additional clusters for batch workloads or training jobs separately


