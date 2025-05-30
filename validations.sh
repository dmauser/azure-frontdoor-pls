#!/bin/bash
read -p "Enter the first region (default: eastus2): " region1
region1=${region1:-eastus2}
read -p "Enter the second region (default: westus3): " region2
region2=${region2:-westus3}
# Parameters
resourcegroup1="afd-plslab-$region1"
resourcegroup2="afd-plslab-$region2"
afd="frontdoor-lab"

# Update origin group with different latencies and run the script below to see the changes

# 50 milliseconds additional latency
az afd origin-group update --resource-group $resourcegroup1 --profile-name $afd \
--origin-group-name "origingroup1" --probe-request-type get --probe-protocol http \
--probe-interval-in-seconds 60 -o none --sample-size 4 --successful-samples-required 3 \
--additional-latency-in-milliseconds 50

# 0 milliseconds additional latency
az afd origin-group update --resource-group $resourcegroup1 --profile-name $afd \
--origin-group-name "origingroup1" --probe-request-type get --probe-protocol http \
--probe-interval-in-seconds 60 -o none --sample-size 4 --successful-samples-required 3 \
--additional-latency-in-milliseconds 0

# Retreive the endpoint URL
afdfqdn=$(az afd endpoint show --resource-group $resourcegroup1 --profile-name $afd --name "endpoint1" --query "hostName" -o tsv)
echo http://$afdfqdn
#!/bin/bash

# Infinite loop script to test connectivity to Azure Front Door
while true; do
  # Make the curl request (no keep-alive)
  content=$(curl -s --no-keepalive "http://$afdfqdn") 

  # Extract color and text using regex (grep/sed)
  color=$(echo "$content" | sed -n "s/.*<body style='color:\([^;]*\);'>.*/\1/p")
  text=$(echo "$content" | sed -n "s/.*<body style='color:[^;]*;'>\([^<]*\)<\/body>.*/\1/p")

  # Map color to terminal ANSI color codes
  case "${color,,}" in
    red)
      consoleColor="\033[31m" # Red
      ;;
    blue)
      consoleColor="\033[34m" # Blue
      ;;
    *)
      consoleColor="\033[37m" # Default White
      ;;
  esac

  # Print the text in the color
  echo -e "${consoleColor}${text}\033[0m"

  # Wait 5 seconds
  sleep 5
done


