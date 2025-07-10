
# Azure IoT Location Monitoring

This project implements a comprehensive IoT solution for real-time location monitoring using Azure services. 
It enables the generation, collection, processing, and tracking of GPS location data from an IoT device.

## Architecture Overview

The solution data flow is as follows:

![Architecture Diagram](https://github.com/garymichaelbass/azure-iot-location-pipeline/blob/main/Architecture.jpg)

1. **IoT Device**: Establishes and transmits GPS location data.
    * _Simulated via a Kubernetes deployment of a Docker container running a Python app_.
2. **IoT Hub**: Manages device communication and ingests telemetry data.
3. **Event Hub**: Buffers and transports device telemetry messages.
4. **Databricks**: Processes and analyzes the incoming data stream.
5. **Cosmos DB**: Stores processed data for scalable and low-latency access.
6. **Grafana**: Visualizes data metrics through dashboards.

## Repository Structure

The repository is organized as follows:

```markdown

+-- .github/                            # GitHub Actions workflows for CI/CD
¦   +-- workflows/                      # Infrastucture-As-Code deployment stack for CI/CD workflows
¦       +-- GithubActionsDestroy.yml    # Main CI/CD pipeline for infrastructure Terraform destroy of the current solution
¦       +-- GithubActionsFullDeploy.yml # Main CI/CD pipeline for infrastructure Terraform deployment and application updates
+-- Architecture.jpg                    # High-level system architecture diagram
+-- azure-creds.json                    # Service Principal credentials (IGNORED by Git, used for local development)
+-- azure-creds.json.template           # Template for azure-creds.json
+-- CONTRIBUTING.md                     # Guidelines for external contributors
+-- LICENSE                             # Project LICENSE
+-- README.md                           # README for Main Project
+-- README_databricks.md                # README for Databricks
+-- iot-simulator/                      # Source code for the IoT device simulator (Python, Dockerfile)
¦   +-- device_simulator.py             # The core device simulation logic (Python)
¦   +-- Dockerfile                      # Dockerfile for containerizing the simulator
¦   +-- requirements.txt                # Python dependencies for the simulator
+-- kubernetes/                         # Kubernetes manifests for deploying the simulator to AKS
¦   +-- simulator-deployment.yaml       # Kubernetes deployment and service definitions for the simulator
+-- terraform/                          # Terraform configuration files for Azure infrastructure deployment
¦   +-- aks.tf                          # Azure Kubernetes Service (AKS) cluster definition
¦   +-- backend.tf                      # Remote backend configuration for shared tfstate
¦   +-- main.tf                         # Core Azure resources (IoT Hub, Event Hub, Cosmos DB, Azure Container Registry)
¦   +-- modules.tf                      # Terraform module definitions (Databricks, Monitoring)
¦   +-- outputs.tf                      # Terraform outputs for deployed resource information
¦   +-- providers.tf                    # Terraform provider configurations (AzureRM, AzureAD, Databricks, Grafana)
¦   +-- variables.tf                    # Terraform input variables for customization
¦   +-- terraform.tfvars.json           # Local variables file (IGNORED by Git, used for local development)
¦   +-- terraform.tfvars.json_TEMPLATE  # Local variables file TEMPLATE for reference
¦   +-- modules/                        # Reusable Terraform modules
¦       +-- databricks/                 # Databricks stack: Cluster and notebook provisioning
¦       ¦   +-- main.tf                 # Databricks module main configuration
¦       ¦   +-- notebook.py             # Databricks notebook for data processing (Python)
¦       ¦   +-- outputs.tf              # Databricks module outputs
¦       ¦   +-- providers.tf            # Databricks module provider configurations
¦       ¦   +-- variables.tf            # Databricks module input variables
¦       +-- monitoring/                 # Monitoring stack: Grafana and Monitoring provisioning
¦           +-- dashboards/             # Grafana dashboard JSON file
¦           +-- main.tf                 # Monitoring module main configuration (Grafana, Azure Monitor)
¦           +-- outputs.tf              # Monitoring module outputs
¦           +-- variables.tf            # Monitoring module input variables
+-- Screenshots/                        # Directory for project screenshots and visualizations
¦   +-- 00_Grafana_Sample_CosmosDB_Data_Usage.jpg
¦   +-- 01_IoTHub_Activity.jpg
¦   +-- 02_IoTHub_TelemetryInAndOut.jpg
¦   +-- 03_EventHub_OutgoingBytes.jpg
¦   +-- 04_CosmosDB_DataUsage.jpg
¦   +-- 05_CosmosDB_SQLQuery.jpg
¦   +-- 06_CosmosDB_SQLQuery_Items.jpg
¦   +-- 07_Grafana_CosmosDB_Usage.jpg
¦   +-- 08_Grafana_CosmosDB_Usage_PlusDefinitions.jpg
¦   +-- 09_Grafana_IoTHub_TotalDeviceUsage.jpg
¦   +-- 10_Grafana_CosmosDB_TotalRequest.jpg
¦   +-- 11_Grafana_Three_Panels.jpg
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

- **Prerequisites**

    Before deploying this solution, ensure you have the following:

    * **GitHub Account:** Active GitHub account with a personal access token (PAT) to perform `gh` CLI commands.
    * **Git:** Installed.
    * **Azure Subscription**: Active Azure subscription.
    * **Azure CLI:** Installed and configured (`az login`).
    * **Terraform**: Installed to manage infrastructure.
    * **Terraform CLI:** Installed for command line execution (`terraform --version`).
    * **Terraform Backend:** Created Azure Blob storage for Terraform state file (per backend.tf).
    * **Docker**: Installed to containerize the IoT simulator.
    * **Kubernetes Cluster**: Installed for deploying the simulator.
    * **kubectl**: Installed for Kubernetes command line execution.
    * **jq:** Installed as a command-line JSON processor.

- **Screenshots**

    See the screenshots directory (./screenshots) for sample images of IoTHub, EventHub, CosmosDB, and Grafana.


## Deployment Guide

The deployment is primarily automated via GitHub Actions. However, some initial setup is required.


  - **Step 1\. Repository Cloning**

    Execute the following to clone this repository to your local machine:

    ```bash
    cd ~
    git clone https://github.com/garymichaelbass/azure-iot-location-pipeline.git
    rename azure-iot-location-pipeline-main azure-iot-location-pipeline
    cd azure-iot-location-pipeline
    ```


  - **Step 2\. Azure Service Principal Setup**

    This creates **AZURE_CLIENT_ID**, **AZURE_CLIENT_SECRET**, **AZURE_SUBSCRIPTION_ID**, **AZURE_TENANT_ID**, and **AZURE_CREDENTIALS**.
    
    Your GitHub Actions workflow will use an Azure Service Principal (SP) to authenticate and deploy resources.

    Execute the following to create a Service Principal with Contributor role at the subscription level:

    ```bash
    cd ~/azure-iot-location-monitoring

    az account show --query id -o tsv  # get <YOUR-AZURE_SUBSCRIPTION_ID>

    az ad sp create-for-rbac --name "github-iot-acr-pusher" --role contributor --scopes /subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID> --sdk-auth > azure-creds.json

    gh auth login

    gh secret set AZURE_CREDENTIALS < azure-creds.json
    ```

    The file will be as follows:

    FILENAME: azure-creds.json
    ```json
    {
      "clientId": "<YOUR_SERVICE_PRINCIPAL_CLIENT_ID>",
      "clientSecret": "<YOUR_SERVICE_PRINCIPAL_CLIENT_SECRET>",
      "subscriptionId": "<YOUR_AZURE_SUBSCRIPTION_ID>",
      "tenantId": "<YOUR_AZURE_TENANT_ID>",
      "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
      "resourceManagerEndpointUrl": "https://management.azure.com/",
      "activeDirectoryGraphResourceId": "https://graph.windows.net/",
      "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
      "galleryEndpointUrl": "https://gallery.azure.com/",
      "managementEndpointUrl": "https://management.core.windows.net/"
    }
    ```

    **Important:** The `azure-creds.json` file contains sensitive credentials. Include it in your `.gitignore`.  **Do NOT commit this file to your GitHub repository.** Once again people ... **do NOT commit this file to your GitHub repository.**

  - **Step 3\. Local User Principal_ID Setup**

    This provides **AZURE_USER_OBJECT_ID**.

    Execute the following command to get your hyphenated 32 alphanumeric character Object ID of your Azure AD identity (`AZURE_USER_OBJECT_ID`) which will be used to access Grafana:

    ```bash
    az ad signed-in-user show --query id -o tsv   # output has hyphenated 32 alphanumeric characters for AZURE_USER_OBJECT_ID
    # XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    ```

   - **Step 4\. Terraform Configuration (`terraform.tfvars.json`)**

      Customize your Azure resource names and locations by creating a `terraform.tfvars.json` file in the `terraform/` directory. This file is ignored by Git, so it's safe for local values. Feel free to use the `terraform/terraform.tfvars.json.template` as a reference.

      ```json
      {
        "azure_client_id": "<YOUR_SERVICE_PRINCIPAL_CLIENT_ID>",
        "azure_client_secret": "<YOUR_SERVICE_PRINCIPAL_CLIENT_SECRET>",
        "azure_subscription_id": "<YOUR_AZURE_SUBSCRIPTION_ID>",
        "azure_tenant_id": "<YOUR_AZURE_TENANT_ID>",

        "grafana_admin_principal_id": "<YOUR_AZURE_USER_OBJECT_ID>",

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

      **Remember to replace all placeholders with your actual values.**


  - **Step 5\. GitHub Secrets Configuration.**

    Since your `terraform.tfvars.json` file is not uploaded into GitHub, GitHub requires access to the following via GitHub Secrets, all of which have now been established except for DATABRICKS_TOKEN:

    - **AZURE_CLIENT_ID**
    - **AZURE_CLIENT_SECRET**
    - **AZURE_SUBSCRIPTION_ID**
    - **AZURE_TENANT_ID**
    - **AZURE_USER_OBJECT_ID**

    - **AZURE_CREDENTIALS**
    - **DATABRICKS_TOKEN** (This one will be added later)

    Add each of your Secrets to GitHub with the following process:

    1.  Go to your GitHub repository: `https://github.com/<YOUR-REPOSITORY-NAME>/azure-iot-location-pipeline`
    2.  Navigate to **`Settings` \> `Secrets and variables` \> `Actions`**.
    3.  Click **`New repository secret`**.
    4.  Name the secret appropriately (ie, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`, ...): `AZURE_CLIENT_ID`
    5.  Please note, when enterring the Value for `AZURE_CREDENTIALS`, the first line will be `{` and the last line will be `}`.
    6.  For all of the other Secrets, when enterring the Value, do not enclose it in double-quotes.
    7.  For the Value, **copy the appropriate value** and paste it here.
    8.  Click **`Add secret`**.
    9.  Repeat for all of the aforementioned secrets.

    From there, your GitHub Actions workflow will be able to access the appropriate variable via the following example method:

    ```yaml
    env: 
    AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }} 
    ```


  - **Step 6. Microsoft.ContainerService Provider Registration**

    Execute the following from the command line to enable AKS cluster creation:

    ```bash
    cd ~/azure-iot-location-monitoring
    az provider register --namespace Microsoft.ContainerService
    ```    


  - **Step 7. Microsoft.Dashboard Provider Registration**

    Execute the following from the command line to enable Grafana:

    ```bash
    cd ~/azure-iot-location-monitoring
    az config set extension.use_dynamic_install=yes_without_prompt
    az extension add --name azure-iot 
    ```    


  - **Step 8. "azure-iot" Extension Installation for IoT Device Registration**

    Execute the following from the command line to enable the azure-iot extension:

    ```bash
    cd ~/azure-iot-location-monitoring
    az config set extension.use_dynamic_install=yes_without_prompt
    az extension add --name azure-iot 
    ```    

    Note: This is used in ./main.tf for the stanza of the "null_resource" resource defining "register_iot_simulator_device". 


  - **Step 9. Azure Backend Configuration**

    Execute the following to create a Terraform backend Azure Blob storage to store the state file.
    
    ```bash
    az group create --name <your-resource-group> --location eastus2 # Use your preferred location
        az storage account create --name iotlocationmon-<your-suffix> --resource-group <your-resource-group> --location eastus2 --sku Standard_LRS --allow-blob-public-access false# Use your preferred location
        az storage container create --name tfstate --account-name iotlocationmon-<your-suffix>
    ```

    Update `terraform\backend.tf` with your created Azure Blob storage.

    ```markup
    # terraform/backend.tf
    terraform {
      backend "azurerm" {
        resource_group_name  = "<your-resource-group>"
        storage_account_name = "iotlocationmon-<your-suffix>"
        container_name       = "tfstate"
        key                  = "iot-solution.tfstate"
      }
    }
    ```

    Please note, the storage flow is as follows: Storage Account Name (`iotlocationmon-<your-suffix>`) => Container (`tfstate`) => Blob Key (`iot-solution.tfstate`)


  - **Step 10. Initial Local Terraform Apply (Optional but Recommended)**

    It's often a good idea to perform an initial `terraform apply` locally to ensure all providers are correctly configured and to handle any one-time issues such as importing existing resources or the two-phase Databricks deployment.

    - **Important for Databricks:** If this is the *very first* time deploying, the `terraform apply` might fail when it tries to create Databricks cluster/notebook/job resources. This is because the Databricks provider needs the Databricks Workspace URL (which isn't known until the `azurerm_databricks_workspace` is fully deployed). If it fails, simply run `terraform apply -auto-approve`. This run should succeed.

    - **For AKS Extensions/Resource Providers:** Ensure you have registered the necessary resource providers if prompted (i.e., `az provider register --namespace Microsoft.ContainerService`, `az provider register --namespace Microsoft.Dashboard`).

    - **Command line initial deploment**:

      1. **Initial Infrastructure Provision**:
        - Navigate to the `terraform/` directory.
        - Execute the following to initialize Terraform:

          ```bash
          cd terraform
          terraform init
          ```

        - Execute the following to apply the Terraform configuration:

          ```bash
          terraform apply
          ```

        - This will create the necessary Azure resources, including IoT Hub, Event Hub, Cosmos DB, and Grafana; however, if this is the first deployment, the Databricks Workspace URL has just been deployed so now you are able to generate the DATABRICKS_PAT_TOKEN. 
        
          Once the Databrick URL has been established, execute the following to get the **DATABRICKS_PAT_TOKEN**:

          1. Change directory to `terraform` and execute `terraform output`, noting the output for `databricks_workspace_url`.
          2. Go to the Databricks workspace at `https://<databricks_workspace_url>` (eg, https://adb-XXXXXXXXXXXXXXXX.14.azuredatabricks.net).
          3.	Click your user icon in the top right
          → Select Settings
          4.	In the left, click Developer tab:
          → To right of "Access tokens" at the top, click Manage
          5.	Click "Generate new token."
          6.	Add a name ("GitHubActionsToken") and set expiration to "365" days.
          → Click Generate.
          7.	Copy the token **IMMEDIATELY** and save it somewhere safe — it’s only shown once.

          Use the procedure outlined in **Step 5\. GitHub Secrets Configuration**  to add the value for the newly generated `DATABRICKS_PAT_TOKEN` to the GitHub Secrets.

        - Refer to `README_databricks.md` for more information on the Databricks Cluster Lifecycle.

      2. **Initial IoT Simulator Deployment**:

        - Navigate to the `iot-simulator/` directory.
                
        - Execute the following to build the Docker image:

          ```bash
          cd iot-simulator
          docker build -t iot-simulator .
          ```

        - Execute the following to deploy the simulator to your Kubernetes cluster using the provided `simulator-deployment.yaml`:

          ```bash
          kubectl apply -f kubernetes/simulator-deployment.yaml
          ```


  - **Step 12. Azure Monitor Metrics Collection for the AKS Cluster Enablement**

      This uses the the iot_aks_cluster "name" parameter from the `./aks.tf` file stanza defining the resource "azurerm_kubernetes_cluster" "iot_aks_cluster".
      
      ```markup
      # Provision the AKS cluster
            resource "azurerm_kubernetes_cluster" "iot_aks_cluster" {
               name                = "${var.prefix}-aks"
      .......
      ```

      Execute the following to enable the Azure Monitor metrics collection for the AKS cluster by executing the following:

        ```bash
        cd ~/azure-iot-location-monitoring
        az aks update --name <iot-aks-cluster-name> --resource-group <your-resource-group> --enable-azure-monitor-metrics
        ```    


  - **Step 13. GitHub Actions Deployment**

    Push the code to your own repository as follows:

    1.  Execute the following to create your own Git repository:

        ```bash
        cd ~/azure-iot-location-monitoring/
        git remote add origin https://github.com/<YOUR-GITHUB-ACCOUNT>/azure-iot-location-pipeline.git
        ```

    2. Deploy using GitHub Actions:

       - In the GitHub repository, select "Actions." Select "Full IoT Solutions Deployment." Select "Deploy."


  - **Step 14. Grafana Dashboard Setup**

      - For reference, see the dashboard at https://iot-grafana-bkhzftaab0dqd8en.eus2.grafana.azure.com/dashboards


    **The Grafana sample dashboard can be added as follows:**

    1. From the GitHub Actions deployment under "Get Terraform Outputs", get the "grafana_endpoint" (ie, https://iot-grafana-bkhzftaab0dqd8en.eus2.grafana.azure.com).
    2. In Grafana, go the left frame, click "Connections" and in the right click "Azure Monitor."
    3. In the upper right, click "Add new data source."
    4. Under Authentication, with Authentication set to "Managed Identity", click "Load Subscriptions" then select your subscription.
    5. Click "Save & test."
    6. Note confirmation message of "Successfully connected to all Azure Monitor endpoints."

    7. In the left panel, click on Dashboards.
    8. In the upper right, drop down the blue "New" icon and select "New dashboard."
    9. Click "+ Add visualization."
    10. Select data source, choose "Azure Monitor."
    11. In the lower left, in the Resource/"Select a resource" block, click "Select a resource."
    12. It the "search for a resource" box, enter "iot-."
    13. Click the checkbox for "iot-cosmos-account-<your-suffix>" then click "Apply."
    14. In the Metric dropdown, click "Data Usage." In the Aggregation select "Total." Set time grain "5 minutes."
    15. Click the upper right "Apply."  In the upper right, click "Last 6 hours" and change it to "Last one hour."
    16. In the upper right click "Save". Assign a Title and Description of "Sample CosmosDB Usage". Click the blue "Save."
    17. **Shazam!** You now have a sample Grafana dashboard.

    ![Sample Grafana Dashboard Diagram](https://github.com/garymichaelbass/azure-iot-location-pipeline/blob/main/screenshots/00_Grafana_Sample_CosmosDB_Data_Usage.jpg)


  - **Step 15. Usage**

    Once the infrastructure is deployed and the simulator is running, the system will:

    - Simulate IoT devices sending location data.
    - Ingest data into IoT Hub, which routes it to Event Hub.
    - Process the data with Databricks, storing results in Cosmos DB.
    - Provide real-time Grafana dashboards for monitoring and analysis.


  - **Step 16. Cleaning Up Resources**

    To destroy all deployed Azure resources (and avoid incurring further costs):

    1.  Execute the following from your `terraform/` directory:

        ```bash
        cd terraform/
        terraform destroy -auto-approve
        ```
        This command will remove all resources managed by your Terraform configuration.

        This can also be done from GitHub via the "Terraform Destroy" action.

## Contributing

Contributions are welcomed to enhance this project. Please refer to the [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License.

## Acknowledgments

- [Azure IoT Reference Architecture 2.1 release](https://azure.microsoft.com/en-us/blog/azure-iot-reference-architecture-2-1-release/)
- [Azure IoT Central solution architecture](https://learn.microsoft.com/en-us/azure/iot-central/core/concepts-architecture)
- [Real-time asset tracking and management using IoT Central](https://learn.microsoft.com/en-us/azure/architecture/solution-ideas/articles/real-time-asset-tracking-mgmt-iot-central)

For more information on Azure IoT solutions, refer to the [Azure IoT Reference Architecture](https://azure.microsoft.com/en-us/blog/azure-iot-reference-architecture-2-1-release/).
