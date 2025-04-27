# Azure Front Door Private Link Service Lab

This lab demonstrates how to deploy and configure Azure Front Door integrated with Azure Private Link Service (PLS). The provided `deploy.sh` script automates the deployment process, including resource creation and configuration.

## Lab Objectives

- Deploy Azure resources using Azure CLI.
- Configure Azure Front Door with Private Link Service.
- Validate secure connectivity through Azure Front Door to backend services.

## Prerequisites

- Azure CLI installed and logged in.
- Appropriate Azure subscription permissions.

## Deployment Steps

1. **Login to Azure CLI**:
```bash
az login
```

2. **Set your subscription**:
```bash
az account set --subscription "<your-subscription-id>"
```

3. **Run the deployment script**:
```bash
bash deploy.sh
```

## Validation

After deployment, verify connectivity and configuration by accessing your backend services securely through Azure Front Door.

## Cleanup

To remove all resources created by this lab, delete the resource group:
```bash
az group delete --name "<resource-group-name>" --yes --no-wait
```

Replace placeholders (e.g., `<your-subscription-id>`, `<resource-group-name>`) with your actual values.
