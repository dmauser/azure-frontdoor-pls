#!/bin/bash

# Prompt for default values
read -p "Enter the first region (default: eastus2): " region1
region1=${region1:-eastus2}
read -p "Enter the second region (default: westus3): " region2
region2=${region2:-westus3}
# Prompt for username and password with validation
read -p "Enter a username for the VMs: " username
while [[ -z $username ]]; do
    read -p "Username cannot be empty. Please enter a username for the VMs: " username
done
while true; do
  read -s -p "Enter your password: " password
  echo
  read -s -p "Confirm your password: " password_confirm
  echo
  [ "$password" = "$password_confirm" ] && break
  echo "Passwords do not match. Please try again."
done

# Parameters
resourcegroup1="afd-plslab-$region1"
resourcegroup2="afd-plslab-$region2"
vnet1="vnet-$region1"
vnet2="vnet-$region2"
subnet1="main"
subnet2="main"
nsg1="nsg-$region1"
nsg2="nsg-$region2"
vm1="winvm-$region1"
vm2="winvm-$region2"
pls1="pls-$region1"
pls2="pls-$region2"
afd="frontdoor-lab"
bastionsubnet="azurebastionsubnet"
bastion1="bastion-$region1"
bastion2="bastion-$region2"
vmsize="Standard_D2s_v5"

# Adding script starting time and finish time
start=`date +%s`
echo "Script started at $(date)"

# Create Resource Groups
echo "Creating resource groups..."
az group create --name $resourcegroup1 --location $region1 -o none
az group create --name $resourcegroup2 --location $region2 -o none

# Create Virtual Networks and Subnets
echo "Creating virtual networks and subnets..."
az network vnet create --resource-group $resourcegroup1 --name $vnet1 --location $region1 --address-prefix 10.0.0.0/16 --subnet-name $subnet1 --subnet-prefix 10.0.1.0/24 -o none
az network vnet subnet create --resource-group $resourcegroup1 --vnet-name $vnet1 --name $bastionsubnet --address-prefix 10.0.0.0/27 -o none

az network vnet create --resource-group $resourcegroup2 --name $vnet2 --location $region2 --address-prefix 10.1.0.0/16 --subnet-name $subnet2 --subnet-prefix 10.1.1.0/24 -o none
az network vnet subnet create --resource-group $resourcegroup2 --vnet-name $vnet2 --name $bastionsubnet --address-prefix 10.1.0.0/27 -o none

# Create NSGs
echo "Creating network security groups..."
az network nsg create --resource-group $resourcegroup1 --name $nsg1 --location $region1 -o none
az network nsg create --resource-group $resourcegroup2 --name $nsg2 --location $region2 -o none

# Associate NSGs to main subnets
az network vnet subnet update --resource-group $resourcegroup1 --vnet-name $vnet1 --name $subnet1 --network-security-group $nsg1 -o none
az network vnet subnet update --resource-group $resourcegroup2 --vnet-name $vnet2 --name $subnet2 --network-security-group $nsg2 -o none

# Deploy Windows VMs without Public IPs
echo "Creating VMs..."
az vm create --resource-group $resourcegroup1 --name $vm1 --image Win2019Datacenter --vnet-name $vnet1 --subnet $subnet1 --admin-username $username --admin-password $password --public-ip-address "" --nsg "" --size $vmsize -o none --no-wait
az vm create --resource-group $resourcegroup2 --name $vm2 --image Win2019Datacenter --vnet-name $vnet2 --subnet $subnet2 --admin-username $username --admin-password $password --public-ip-address "" --nsg "" --size $vmsize -o none --no-wait

# Create Azure Bastion
echo "Creating Azure Bastion..."
az network public-ip create --resource-group $resourcegroup1 --name "bastionip-$region1" --sku standard --location $region1 -o none
az network bastion create --resource-group $resourcegroup1 --name $bastion1 --public-ip-address "bastionip-$region1" --vnet-name $vnet1 --location $region1 &>/dev/null &

az network public-ip create --resource-group $resourcegroup2 --name "bastionip-$region2" --sku standard --location $region2 -o none
az network bastion create --resource-group $resourcegroup2 --name $bastion2 --public-ip-address "bastionip-$region2" --vnet-name $vnet2 --location $region2 &>/dev/null &

# Create LB for VM1
echo "Creating Load Balancer for VM1..."
az network lb create --resource-group $resourcegroup1 --name "pls-lb-$region1" --location $region1 --sku standard --frontend-ip-name "frontend" --backend-pool-name "backendpool" --vnet-name $vnet1 --subnet $subnet1 -o none
az network lb probe create --resource-group $resourcegroup1 --lb-name "pls-lb-$region1" --name "http-probe" --protocol tcp --port 80 -o none
az network lb rule create --resource-group $resourcegroup1 --lb-name "pls-lb-$region1" --name "http-rule" --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name "frontend" --backend-pool-name "backendpool" --probe-name "http-probe" -o none
az network nic ip-config address-pool add --resource-group $resourcegroup1 --nic-name "${vm1}VMNic" --lb-name "pls-lb-$region1" --address-pool "backendpool" --ip-config-name "ipconfig${vm1}" -o none

# Private Link Service for VM1
echo "Creating Private Link Service for VM1..."
az network vnet subnet create --resource-group $resourcegroup1 --vnet-name $vnet1 --name "pls-subnet-$region1" --address-prefixes 10.0.2.0/24 --private-link-service-network-policies Disabled -o none
az network private-link-service create --resource-group $resourcegroup1 --name $pls1 --vnet-name $vnet1 --subnet pls-subnet-$region1 --lb-name "pls-lb-$region1" -o none --lb-frontend-ip-configs "frontend" --visibility "*"

# Create LB for VM2
echo "Creating Load Balancer for VM2..."
az network lb create --resource-group $resourcegroup2 --name "pls-lb-$region2" --location $region2 --sku standard --frontend-ip-name "frontend" --backend-pool-name "backendpool" --vnet-name $vnet2 --subnet $subnet2 -o none
az network lb probe create --resource-group $resourcegroup2 --lb-name "pls-lb-$region2" --name "http-probe" --protocol tcp --port 80 -o none
az network lb rule create --resource-group $resourcegroup2 --lb-name "pls-lb-$region2" --name "http-rule" --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name "frontend" --backend-pool-name "backendpool" --probe-name "http-probe" -o none
az network nic ip-config address-pool add --resource-group $resourcegroup2 --nic-name "${vm2}VMNic" --lb-name "pls-lb-$region2" --address-pool "backendpool" --ip-config-name "ipconfig${vm2}" -o none

# Private Link Service for VM2
echo "Creating Private Link Service for VM2..."
az network vnet subnet create --resource-group $resourcegroup2 --vnet-name $vnet2 --name "pls-subnet-$region2" --address-prefixes 10.1.2.0/24 --private-link-service-network-policies Disabled -o none	
az network private-link-service create --resource-group $resourcegroup2 --name $pls2 --vnet-name $vnet2 --subnet pls-subnet-$region2 --lb-name "pls-lb-$region2" -o none --lb-frontend-ip-configs "frontend" --visibility "*"

# Install IIS on both VMs using run-command extension and also add a page to the default website with the hostname
echo "Installing IIS on both VMs..."
az vm run-command invoke --command-id RunPowerShellScript --name $vm1 --resource-group $resourcegroup1 --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools; \$computerName = \$env:COMPUTERNAME; Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value \"<html><body style='color:blue;'>\$computerName</body></html>\" -Force" --no-wait
az vm run-command invoke --command-id RunPowerShellScript --name $vm2 --resource-group $resourcegroup2 --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools; \$computerName = \$env:COMPUTERNAME; Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value \"<html><body style='color:red;'>\$computerName</body></html>\" -Force" --no-wait

# Deploy azure front door
echo "Creating Azure Front Door..."
az afd profile create --resource-group $resourcegroup1 --profile-name $afd --sku premium_azurefrontdoor -o none
az afd origin-group create --resource-group $resourcegroup1 --profile-name $afd --origin-group-name "origingroup1" --probe-request-type get --probe-protocol http --probe-interval-in-seconds 60 -o none --sample-size 4 --successful-samples-required 3 --additional-latency-in-milliseconds 100

# add backends using private link services
# get private link service alias
echo "Creating origins for Azure Front Door..."
pls1resourceid=$(az network private-link-service show --resource-group $resourcegroup1 --name $pls1 --query "id" -o tsv)
pls2resourceid=$(az network private-link-service show --resource-group $resourcegroup2 --name $pls2 --query "id" -o tsv)
az afd origin create --resource-group $resourcegroup1 --profile-name $afd --origin-group-name "origingroup1" --origin-name "backend-$region1" --host-name "${pls1}.privatelink.azurefd.net" --priority 1 --weight 500 --enabled-state Enabled --http-port 80 --https-port 443 --enable-private-link true --private-link-resource $pls1resourceid --private-link-location $region1 --private-link-request-message 'Please approve this request' -o none
az afd origin create --resource-group $resourcegroup1 --profile-name $afd --origin-group-name "origingroup1" --origin-name "backend-$region2" --host-name "${pls2}.privatelink.azurefd.net" --priority 1 --weight 500 --enabled-state Enabled --http-port 80 --https-port 443 --enable-private-link true --private-link-resource $pls2resourceid --private-link-location $region2 --private-link-request-message 'Please approve this request' -o none 

# Create Front Door endpoint
echo "Creating Front Door endpoint..."
az afd endpoint create --resource-group $resourcegroup1 --endpoint-name endpoint1 --profile-name $afd --enabled-state Enabled -o none

# Add routing rule
echo "Creating routing rule for Azure Front Door..."
az afd route create --resource-group $resourcegroup1 --endpoint-name "endpoint1" --profile-name $afd --route-name "route1" --patterns-to-match "/*" --origin-group "origingroup1" --supported-protocols Http Https --forwarding-protocol MatchRequest --https-redirect Disabled --link-to-default-domain Enabled -o none

# If the private link service shows "Pending" status, approve the connection
echo "Approving private endpoint connections if status is 'Pending'..."
az network private-link-service list --resource-group $resourcegroup1 --query "[].{Name:name, ID:id}" -o tsv | while read -r name id; do
  az network private-link-service show --name "$name" --resource-group "$resourcegroup1" --query "privateEndpointConnections[].{Name:name, Status:privateLinkServiceConnectionState.status}" -o tsv | while read -r pe_name pe_status; do
    if [ "$pe_status" == "Pending" ]; then
      echo "Approving connection for $pe_name in $name..."
      az network private-endpoint-connection approve --resource-group "$resourcegroup1" --name "$pe_name" --resource-name $name --type Microsoft.Network/privateLinkServices --description "Approved by CLI script" -o none
    fi
  done
done

az network private-link-service list --resource-group $resourcegroup2 --query "[].{Name:name, ID:id}" -o tsv | while read -r name id; do
  az network private-link-service show --name "$name" --resource-group "$resourcegroup2" --query "privateEndpointConnections[].{Name:name, Status:privateLinkServiceConnectionState.status}" -o tsv | while read -r pe_name pe_status; do
    if [ "$pe_status" == "Pending" ]; then
      echo "Approving connection for $pe_name in $name..."
      az network private-endpoint-connection approve --resource-group "$resourcegroup2" --name "$pe_name" --resource-name "$name" --type Microsoft.Network/privateLinkServices --description "Approved by CLI script" -o none
    fi
  done
done

echo "Azure Front Door with Private Link Service deployed successfully!"

# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."





