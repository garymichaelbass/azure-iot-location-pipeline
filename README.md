
# Azure IoT Location Monitoring

This project implements a comprehensive IoT solution for real-time location monitoring using Azure services. 
It enables the collection, processing, and tracking of GPS location data from an IoT device.

## Architecture Overview

The solution follows a streamlined workflow:

1. **IoT Device**: Collects and transmits location data (simulated via a Kubernetes Deployment of a Docker container running a Python app).
    * Simulated via a Kubernetes Deployment of a Docker container running a Python app.
2. **IoT Hub**: Manages device communication and ingests telemetry data.
3. **Event Hub**: Buffers and transports device telemetry messages.
4. **Databricks**: Processes and analyzes the incoming data streams.
5. **Cosmos DB**: Stores processed data for scalable and low-latency access.
6. **Grafana**: Visualizes data through interactive dashboards.

## Data Flow

The solution follows a clear data flow for location telemetry:

`IoT_Device -> IoT_Hub -> Event_Hub -> Databricks -> Cosmos_DB -> Grafana`

![Architecture Diagram](https://github.com/garymichaelbass/azure-iot-location-pipeline/blob/main/Architecture.jpg)


## Project Structure

The repository is organized as follows:

```markdown

+-- .github/                            # GitHub Actions workflows for CI/CD
¦   +-- workflows/
¦       +-- GithubActionsDestroy.yml    # Main CI/CD pipeline for infrastructure Terraform destroy of the current environment
¦       +-- GithubActionsFullDeploy.yml # Main CI/CD pipeline for infrastructure deployment and application updates
+-- Architecture.jpg                    # High-level system architecture diagram
+-- azure-creds.json                    # Service Principal credentials (IGNORED by Git, used by CI/CD and local setup)
+-- azure-creds.json.template           # Template for azure-creds.json
+-- CONTRIBUTING.md                     # Guidelines for external contributors
+-- LICENSE                             # Project LICENSE
+-- README.md                           # This main Project README
+-- README_databricks.md                # READ for Databricks
+-- iot-simulator/                      # Source code for the IoT device simulator (Python, Dockerfile)
¦   +-- device_simulator.py             # The core device simulation logic
¦   +-- Dockerfile                      # Dockerfile for containerizing the simulator
¦   +-- requirements.txt                # Python dependencies for the simulator
+-- kubernetes/                         # Kubernetes manifests for deploying the simulator to AKS
¦   +-- simulator-deployment.yaml       # Kubernetes deployment and service definitions for the simulator
+-- terraform/                          # Terraform configuration files for Azure infrastructure deployment
¦   +-- aks.tf                          # Azure Kubernetes Service (AKS) cluster definition
¦   +-- backend.tf                      # Remote backend configuration for shared tfstate
¦   +-- main.tf                         # Core Azure resources (IoT Hub, Event Hub, Cosmos DB, Azure Container Registry)
¦   +-- modules.tf                      # Terraform module definitions (e.g., for Databricks, Monitoring)
¦   +-- outputs.tf                      # Terraform outputs for deployed resource information
¦   +-- providers.tf                    # Terraform provider configurations (AzureRM, Databricks, Grafana)
¦   +-- variables.tf                    # Terraform input variables for customization
¦   +-- terraform.tfvars.json           # Local variables file (IGNORED by Git, for local development)
¦   +-- modules/                        # Reusable Terraform modules
¦       +-- databricks/                 # Databricks cluster and notebook provisioning
¦       ¦   +-- main.tf                 # Databricks module main configuration
¦       ¦   +-- notebook.py             # Databricks notebook for data processing
¦       ¦   +-- outputs.tf              # Databricks module outputs
¦       ¦   +-- providers.tf            # Databricks module provider configurations
¦       ¦   +-- variables.tf            # Databricks module input variables
¦       +-- monitoring/                 # Monitoring stack: Azure Monitor, Grafana, Alerts
¦           +-- dashboards/             # Grafana dashboard JSON file
¦           +-- main.tf                 # Monitoring module main configuration (e.g., Grafana, Azure Monitor)
¦           +-- outputs.tf              # Monitoring module outputs
¦           +-- variables.tf            # Monitoring module input variables
+-- Screenshots/                        # Directory for project screenshots and visualizations
¦   +-- 20250708_01_IoTHub_Activity.jpg
¦   +-- 20250708_02_IoTHub_TelemetryInAndOut.jpg
¦   +-- 20250708_03_EventHub_OutgoingBytes.jpg
¦   +-- 20250708_04_CosmosDB_DataUsage.jpg
¦   +-- 20250708_05_CosmosDB_SQLQuery.jpg
¦   +-- 20250708_06_CosmosDB_SQLQuery_Items.jpg
¦   +-- 20250708_07_Grafana_CosmosDB_Usage.jpg
¦   +-- 20250708_08_Grafana_CosmosDB_Usage_PlusDefinitions.jpg
¦   +-- 20250708_09_Grafana_IoTHub_TotalDeviceUsage.jpg
¦   +-- 20250708_10_Grafana_CosmosDB_TotalRequest.jpg
¦   +-- 20250708_11_Grafana_IoTHub_TotalDeviceUsage__CosmosDB_TotalRequests__CosmosDB_Usage.jpg
```


## Technologies Used

- **Azure Services:**
    * Azure IoT Hub
    * Azure Event Hubs
    * Azure Databricks
    * Azure Cosmos DB (NoSQL API)
    * Azure Kubernetes Service (AKS)
    * Azure Container Registry (ACR)
    * Azure Log Analytics Workspace
    * Azure Managed Grafana
    * Azure Active Directory (Microsoft Entra ID)

- **Tools & Frameworks:**
    * **Terraform:** For infrastructure provisioning.
    * **GitHub Actions:** For CI/CD automation.
    * **Docker:** For containerizing the IoT simulator.
    * **Python:** For the IoT device simulator and Databricks notebook.
    * **kubectl:** For Kubernetes cluster interaction.
    * **Azure CLI:** For Azure authentication and management.
    * **jq:** For JSON parsing in scripts.

## Setup and Deployment

### Prerequisites

Before deploying this solution, ensure you have the following:

- **GitHub Account:** With a personal access token (PAT) to perform `gh` CLI commands.
- **Git:** Installed.
- **Azure Subscription**: Ensure you have an active Azure subscription.
- **Azure CLI:** Installed and configured (`az login`).
- **Terraform**: Install Terraform to manage infrastructure.
- **Terraform CLI:** Installed.
- **Terraform Backend:** Azure Blob storage for Terraform state file, as referenced in azure-iot-location-monitor/backend.tf.
- **Docker**: Required for containerizing the IoT simulator.
- **Kubernetes Cluster**: Set up a Kubernetes cluster for deploying the simulator.
- **jq:** A lightweight and flexible command-line JSON processor.

### Screenshots

See the screenshots directory for sample images of IoTHub, EventHub, CosmosDB, and Grafana.


## Deployment Guide

The deployment is primarily automated via GitHub Actions. However, some initial setup is required.


### 1\. Clone the Repository

Clone this repository to your local machine:

```bash
git clone https://github.com/garymichaelbass/azure-iot-location-pipeline.git
cd azure-iot-location-pipeline
```


### 2\. Azure Service Principal Setup

Your GitHub Actions workflow will use an Azure Service Principal (SP) to authenticate and deploy resources.

Create a Service Principal with Contributor role at the subscription level (for initial setup simplicity; *for production, refine permissions to least privilege after deployment*):

```bash
az ad sp create-for-rbac --name "github-iot-acr-pusher" --role contributor --scopes /subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID> --sdk-auth > azure-creds.json
```

**Important:** The `azure-creds.json` file contains sensitive credentials. Include it in your `.gitignore`. **Do NOT commit this file to your Git repository.**


### 3\. Databricks Token Setup

Generate DATABRICKS_PAT_TOKEN as follows:

1.	Go to your Databricks workspace
Open: https://adb-XXXXXXXXXXXXXXXX.14.azuredatabricks.net
2.	Click your user icon in the top right
→ Select Settings
3.	In the left click Developer tab:
→ To right of "Access tokens" at the top, click Manage
4.	Click "Generate new token."
5.	Add a name ("GitHubActionsToken") and set expiration to "365" days.
→ Click Generate.
6.	Copy the token immediately and save it somewhere safe—it’s only shown once.


### 4\. Terraform Configuration (`terraform.tfvars.json`)

Customize your Azure resource names and locations by creating a `terraform.tfvars.json` file in the `terraform/` directory. This file is ignored by Git, so it's safe for local values. Feel free to use the `terraform/terraform.tfvars.json.template` as a reference.

```json
{
  "azure_client_id": "YOUR_SERVICE_PRINCIPAL_CLIENT_ID",
  "azure_client_secret": "YOUR_SERVICE_PRINCIPAL_CLIENT_SECRET",
  "azure_subscription_id": "YOUR_AZURE_SUBSCRIPTION_ID",
  "azure_tenant_id": "YOUR_AZURE_TENANT_ID",

  "grafana_admin_principal_id": "YOUR_AZURE_USER_OBJECT_ID",

  "resource_group_name": "iot-location-rg-<your-unique-suffix>",
  "location": "<azure-region>",

  "iot_hub_name": "iotlocationhub-<your-unique-suffix>",
  "iot_device_name": "truck-001",
  "cosmos_db_name": "iotcosmosdb-<your-unique-suffix>",
  "acr_name": "youracrname-<your-unique-suffix>",

  "aks_node_count": 3,
  "aks_node_vm_size": "Standard_DS2_v2",
  "prefix": "iot",
  "environment": "dev",
  "project": "iot-simulator",
  "owner": "<your-name>"
}
```

**Remember to replace all placeholders such as  `<YOUR_SERVICE_PRINCIPAL_CLIENT_ID>`, `<YOUR_SERVICE_PRINCIPAL_CLIENT_SECRET>`, `<YOUR_AZURE_SUBSCRIPTION_ID>`, `<YOUR_AZURE_TENANT_ID>`, and `<YOUR_AZURE_USER_OBJECT_ID>` with your actual values.**


### 5\. GitHub Secrets Configuration - DATABRICKS_PAT_TOKEN and AZURE_CREDENTIALS

Since your `terraform.tfvars.json` file is not uploaded into Github, Github requires access to the following via Github Secrets. 

- AZURE_CLIENT_ID
- AZURE_CLIENT_SECRET
- AZURE_SUBSCRIPTION_ID
- AZURE_TENANT_ID
- AZURE_USER_OBJECT_ID

- AZURE_CREDENTIALS
- DATABRICKS_TOKEN

Secrets can be added for Github access as follows:

1.  Go to your GitHub repository: `https://github.com/<YOUR-REPOSITORY-NAME>/azure-iot-location-pipeline`
2.  Navigate to **`Settings` \> `Secrets and variables` \> `Actions`**.
3.  Click **`New repository secret`**.
4.  Name the secret: `AZURE_CLIENT_ID` (or AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID, etc.)
5.  Please note, when enterring the Value, do not enclose it in double-quotes.
6.  For the Value: **Copy the appropriate value** and paste it here.
7.  Click **`Add secret`**.
8.  Repeat for all of the aforementioned secrets.

From there, your GitHub Actions workflow will be able to access as follows:

```yaml
env: 
DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_PAT_TOKEN }} 
```

### 6. Initial Terraform Apply (Local - Optional but Recommended)

It's often a good idea to perform an initial `terraform apply` locally to ensure all providers are correctly configured and to handle any one-time issues (like importing existing resources or the two-phase Databricks deployment).

- **Important for Databricks:** If this is the *very first* time deploying, the `terraform apply` might fail when it tries to create Databricks cluster/notebook/job resources. This is because the Databricks provider needs the Databricks Workspace URL (which isn't known until the `azurerm_databricks_workspace` is fully deployed). If it fails, simply run `terraform apply -auto-approve` **again**. The second run should succeed.

- **For AKS Extensions/Resource Providers:** Ensure you have registered the necessary resource providers if prompted (e.g., `az provider register --namespace Microsoft.ContainerService`, `az provider register --namespace Microsoft.Dashboard`).

- **Command line initial deploment via command line:

    1. **Initial Infrastructure Provision via Command Line**:
      - Navigate to the `terraform/` directory.
      - Initialize Terraform:
        ```bash
        terraform init
        ```
      - Apply the Terraform configuration:
        ```bash
        terraform apply
        ```
      - This will create the necessary Azure resources, including IoT Hub, Event Hub, Databricks workspace, Cosmos DB, and Grafana.

    2. **Initial IoT Simulator Deployment via Command Line**:
      - Build the Docker image:
        ```bash
        docker build -t iot-simulator .
        ```
      - Deploy the simulator to your Kubernetes cluster using the provided `simulator-deployment.yaml`.

    3. **Initial Databricks Deployment via Command Line**:
      - Refer to `README_databricks.md` for detailed instructions on setting up Databricks to process and analyze the data.


### 7. Github Actions Deployment

Push the code to your own repository as follows:
1.  Create your own Git repository as follows:
    ```bash
    cd azure-iot-location-monitoring/
    git remote add origin https://github.com/<YOUR-GITHUB-ACCOUNT>/azure-iot-location-pipeline.git
    ```

2. Deploy using Github Actions
   - In the Github repository, select "Actions." Select "Full IoT Solutions Deployment." Select "Deploy."


### 8. Grafana Dashboard Setup

  - For reference, see the dashboard at https://iot-grafana-bkhzftaab0dqd8en.eus2.grafana.azure.com/dashboards

  - From the Github Actions deployment under "Get Terraform Outputs", get the "grafana_endpoint (ie, https://iot-grafana-bkhzftaab0dqd8en.eus2.grafana.azure.com).
  - In Grafana, go the left frame, click "Connections" and in the right click "Azure Monitor."
  - In the upper right, click "Add new data source."
  - Under Authentication, with Authentication set to "Managed Identity", click "Load Subscriptions" then select your subscription.
  - Click "Save & test."
  - Note confirmation message of "Successfully connected to all Azure Monitor endpoints."

  - In the left panel, click on Dashboards.
  - In the upper right, drop down the blue "New" icon and select "New dashboard."
  - Click "+ Add visualization."
  - Select data source, choose "Azure Monitor."
  - In the lower left, in the Resource/"Select a resource" block, click "Select a resource."
  - It the "search for a resource" box, enter "iot-".
  - Click the checkbox for "iot-cosmos-account-gmb" then click "Apply."
  - In the Metric dropdown, click "Data Usage." In the Aggregation select "Total." Time grain "5 minutes."
  - Click the upper right "Apply."  In the upper right, click "Last 6 hours" and change it to "Last one hour".
  - In the upper right click "Save". Assign a Title and Description of "Sample CosmosDB Usage". Click the blue "Save."
  - Shazam! You now have a sample Grafana dashboard.

![Sample Grafana Dashboard Diagram](https://github.com/garymichaelbass/azure-iot-location-pipeline/blob/main/screenshots/20250708_12_Grafana_Sample_CosmosDB_Data_Usage.jpg)


### 9. Usage

Once the infrastructure is deployed and the simulator is running, the system will:

- Simulate IoT devices sending location data.
- Ingest data into IoT Hub, which routes it to Event Hub.
- Databricks processes the data, storing results in Cosmos DB.
- Grafana provides real-time dashboards for monitoring and analysis.


### 10. Cleaning Up Resources

To destroy all deployed Azure resources (and avoid incurring further costs):

1.  From your `terraform/` directory:
    ```bash
    cd terraform/
    terraform destroy -auto-approve
    ```
    This command will remove all resources managed by your Terraform configuration.

## Contributing

Contributions are welcomed to enhance this project. Please refer to the [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License.

## Acknowledgments

- [Azure IoT Reference Architecture 2.1 release](https://azure.microsoft.com/en-us/blog/azure-iot-reference-architecture-2-1-release/)
- [Azure IoT Central solution architecture](https://learn.microsoft.com/en-us/azure/iot-central/core/concepts-architecture)
- [Real-time asset tracking and management using IoT Central](https://learn.microsoft.com/en-us/azure/architecture/solution-ideas/articles/real-time-asset-tracking-mgmt-iot-central)

For more information on Azure IoT solutions, refer to the [Azure IoT Reference Architecture](https://azure.microsoft.com/en-us/blog/azure-iot-reference-architecture-2-1-release/).
```
