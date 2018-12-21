#!/bin/bash
PROJECT_NAME="${1}"
OMS_WORKSPACE_ID="${2}"
OMS_WORKSPACE_KEY="${3}"

# wait until all installers are finished
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 30; done

# onboard OMS agent
until sh onboard_agent.sh -w "${OMS_WORKSPACE_ID}" -s "${OMS_WORKSPACE_KEY}"; do
	echo "Retrying onboard agent installation in 10 seconds"
	sleep 10
done

# define root of all evil
ROOT_DIR=/opt/${PROJECT_NAME}

# create working folders
mkdir -vp ${ROOT_DIR}

# create diagnostics utility script
cat <<-EOF >${ROOT_DIR}/sanity-check.sh
ls -la /etc/systemd/system
cat /var/log/waagent.log
cat /var/lib/waagent/custom-script/download/1/stderr
cat /var/lib/waagent/custom-script/download/1/stdout
EOF
# right permissions
chmod +x ${ROOT_DIR}/sanity-check.sh
