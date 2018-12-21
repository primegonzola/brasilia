#!/bin/bash
. ./utils.sh

function display_help() {
	echo -e "\n${PROJECT_NAME} deployment utility v1.0\n"
	echo -e "usage: deploy.sh -/-- options:\n"
	echo -e "\t--help, -h"
	echo -e "\t  displays more detailed help\n"
	echo -e "\t--resource-group, -g <resource group>"
	echo -e "\t  the resource group to deploy to\n"
	echo -e "\t--location, -l <location> "
	echo -e "\t  the location to deploy to\n"
	echo -e "\t--service-principal-id, -u <service principal id>"
	echo -e "\t  the service principal id to use for deploying\n"
	echo -e "\t--service-principal-key, -p <service principal key>"
	echo -e "\t  the service principal key to use for deploying\n"
}

# set some defaults
PROJECT_NAME="brasilia"
OUTPUT_DIR="$(dirname "$PWD")"/output
UNIQUE_NAME_FIX="$(dd if=/dev/urandom bs=6 count=1 2>/dev/null | base64 | tr '[:upper:]+/=' '[:lower:]abc')"

# parse the argumens
while true; do
  case "$1" in
	-h | --help ) display_help; exit 1 ;;
    -l | --location ) LOCATION="$2"; shift ; shift ;;
    -g | --resource-group ) RESOURCE_GROUP="$2"; shift ; shift ;;
    -u | --service-principal-id ) SERVICE_PRINCIPAL_ID="$2"; shift ; shift ;;
    -p | --service-principal-key ) SERVICE_PRINCIPAL_KEY="$2"; shift ; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# tools required to be able to work
require_tool az || exit 1
require_tool jq || exit 1

# validation checking
if [ -z ${LOCATION+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --location, -l is missing.\n"
	echo -e "\tusage: --location, -l [westeurope, westus, northeurope, ...]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${RESOURCE_GROUP+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --resource-group, -g is missing.\n"
	echo -e "\tusage: --resource-group, -g [NAME]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-id, -u is missing.\n"
	echo -e "\tusage: --service-principal-id, -u [SERVICE PRINCIPAL ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_KEY+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-key, -p is missing.\n"
	echo -e "\tusage: --service-principal-key, -p [SERVICE PRINCIPAL KEY]"
	echo -e "\n"
	exit 1; 
fi


# prepare target environment
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}/deploy
cp -r * ${OUTPUT_DIR}/deploy

# pass the environment
cat <<-EOF > ${OUTPUT_DIR}/deploy/environment.sh
LOCATION=${LOCATION}
OUTPUT_DIR=${OUTPUT_DIR}
PROJECT_NAME=${PROJECT_NAME}
RESOURCE_GROUP=${RESOURCE_GROUP}
UNIQUE_NAME_FIX=${UNIQUE_NAME_FIX}
SERVICE_PRINCIPAL_ID=${SERVICE_PRINCIPAL_ID}
SERVICE_PRINCIPAL_KEY=${SERVICE_PRINCIPAL_KEY}
EOF

# all done change directory and let's boot
pushd ${OUTPUT_DIR}/deploy >/dev/null
${OUTPUT_DIR}/deploy/boot.sh
popd >/dev/null