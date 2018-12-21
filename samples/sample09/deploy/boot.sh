#!/bin/bash

# get our stuff
. ./utils.sh
. ./environment.sh
. ./api-versions.sh

# start clean
clear

# variables comes here
BOOTSTRAP_STORAGE_ACCOUNT=bootstrapsa$UNIQUE_NAME_FIX

# create the resource group
display_progress "Creating resource group ${RESOURCE_GROUP}"
az group create -n ${RESOURCE_GROUP} -l ${LOCATION}

# create storage account
display_progress "Creating bootstrap account ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
az storage account create -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -l ${LOCATION} --sku Standard_LRS

# get connection string storage account
display_progress "Retrieving connection string for ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} -o tsv)

# create the storage container
display_progress "Creating bootstrap container in storage account"
az storage container create -n bootstrap

# create the SAS token to access it and upload files
display_progress "Generating SAS tokens"
STORAGE_SAS_TOKEN="?$(az storage container generate-sas -n bootstrap --permissions lr --expiry $(date ${plus_one_year} -u +%Y-%m-%dT%H:%mZ) -o tsv)"

# get right url
display_progress "Retrieving final destination uri for uploading files"
BLOB_BASE_URL=$(az storage account show -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -o json --query="primaryEndpoints.blob" -o tsv)

# get ready to upload file
display_progress "Uploading files to bootstrap account"
for file in *; do
    echo "uploading $file"
    az storage blob upload -c bootstrap -f ${file} -n ${file} &>/dev/null
done

# Mark & as escaped characters in SAS Token
ESCAPED_SAS_TOKEN=$(echo ${STORAGE_SAS_TOKEN} | sed -e "s|\&|\\\&|g")
MAIN_URI="${BLOB_BASE_URL}bootstrap/main.json${STORAGE_SAS_TOKEN}"

# replace with right versions
replace_versions main.parameters.template.json main.parameters.json

# replace additional parameters in parameter file
sed --in-place=.bak \
-e "s|<uniqueNameFix>|${UNIQUE_NAME_FIX}|" \
-e "s|<projectName>|${PROJECT_NAME}|" \
-e "s|<bootstrapStorageAccount>|${BOOTSTRAP_STORAGE_ACCOUNT}|" \
-e "s|<bootstrapStorageAccountSas>|${ESCAPED_SAS_TOKEN}|" \
-e "s|<bootstrapStorageAccountUrl>|${BLOB_BASE_URL}|" \
main.parameters.json

# prepare & tar all files up
pusha ../scripts/frontend
display_progress "Packaging frontend subsystem related files"
cp ./site/target/*api*.jar .
tar --exclude='./site' -czvf ../frontend.tar.gz .
pusha site
# build site
mvn clean package
popa
# upload files
display_progress "Uploading frontend subsystem related files to bootstrap account"
az storage blob upload -c bootstrap -f ../frontend.tar.gz -n frontend.tar.gz
# clean up
rm -rf ../frontend.tar.gz
popa

display_progress "Deploying main template into resource group"
az group deployment create -g ${RESOURCE_GROUP} --template-uri ${MAIN_URI} --parameters @main.parameters.json --output json > main.output.json

# main deployment completed
display_progress "Main deployment completed"
MAIN_OUTPUT=$(cat main.output.json)

# # get usefull info
# FRONTEND_IP_ADDRESS=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.frontendIpAddress.value')
# MANAGEMENT_VIRTUAL_NETWORK_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.managementVirtualNetworkId.value')
# APPLICATION_VIRTUAL_NETWORK_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.applicationVirtualNetworkId.value')
# DNS_ZONE_NAME=${PROJECT_NAME}-dns-${UNIQUE_NAME_FIX}.org
# DNS_FRONTEND_RECORD="frontend"

# # create dns zone
# display_progress "Creating Private DNS zone"
# # create a private zone with proper name resolution 
# az network dns zone create \
#     --resource-group ${RESOURCE_GROUP} \
#     --name ${DNS_ZONE_NAME} \
#     --zone-type Private \
#     --resolution-vnets ${MANAGEMENT_VIRTUAL_NETWORK_ID} ${APPLICATION_VIRTUAL_NETWORK_ID}
    
# # create proper A record 
# az network dns record-set a add-record \
#     --resource-group ${RESOURCE_GROUP} \
#     --zone-name ${DNS_ZONE_NAME} \
#     --record-set-name ${DNS_FRONTEND_RECORD} \
#     --ipv4-address ${FRONTEND_IP_ADDRESS}

# clean up
# display_progress "Cleaning up"
# az storage account delete --resource-group ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} --yes

# all done
display_progress "Deployment completed"