#!/bin/bash -e
if [ $# -ne 6 ]; then
    echo >&2 "Usage: $0 location resource-group storage-account subscription-id client-id client-secret"
fi

# pack
packer build -on-error=ask -var "location=$1" -var "resource_group=$2" -var "storage_account=$3" -var "subscription_id=$4" -var "client_id=$5" -var "client_secret=$6" build-vhd.json