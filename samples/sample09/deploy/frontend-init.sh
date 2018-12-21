#!/bin/bash
PROJECT_NAME="${1}"
OMS_WORKSPACE_ID="${2}"
OMS_WORKSPACE_KEY="${3}"
STORAGE_ACCOUNT_ID="${4}"

# wait until all installers are finished
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 30; done

# onboard OMS agent
# wget https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/onboard_agent.sh && sh onboard_agent.sh -w "${OMS_WORKSPACE_ID}" -s "${OMS_WORKSPACE_KEY}"

# until sh onboard_agent.sh -w "${OMS_WORKSPACE_ID}" -s "${OMS_WORKSPACE_KEY}"; do
# 	echo "Retrying onboard agent installation in 10 seconds"
# 	sleep 10
# done

# define root of all evil
ROOT_DIR=/opt/${PROJECT_NAME}

# create working folders
mkdir -vp ${ROOT_DIR}

# create diagnostics utility script
cat <<-EOF >${ROOT_DIR}/sanity-check.sh
ls -la /etc/systemd/system
cat /var/log/waagent.log
cat /var/lib/waagent/custom-script/download/0/stderr
cat /var/lib/waagent/custom-script/download/0/stdout
cat /var/lib/waagent/custom-script/download/1/stderr
cat /var/lib/waagent/custom-script/download/1/stdout
EOF
# right permissions
chmod +x ${ROOT_DIR}/sanity-check.sh

# create working folders
mkdir -vp ${ROOT_DIR}/frontend
# untar file
tar -xzvf ./frontend.tar.gz -C ${ROOT_DIR}/frontend
# set permissions for all scripts
chmod +x ${ROOT_DIR}/frontend/*.sh

# replace in target init file 
sed --in-place=.bak \
	-e "s|<PROJECT_NAME>|${PROJECT_NAME}|" \
	-e "s|<ROOT_DIR>|${ROOT_DIR}|" \
	-e "s|<STORAGE_ACCOUNT_ID>|${STORAGE_ACCOUNT_ID}|" \
	${ROOT_DIR}/frontend/init.sh

# execute directly
# ${ROOT_DIR}/frontend/init.sh
