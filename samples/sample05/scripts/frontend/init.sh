#!/bin/bash
PROJECT_NAME="<PROJECT_NAME>"
ROOT_DIR="<ROOT_DIR>"
STORAGE_ACCOUNT_ID="<STORAGE_ACCOUNT_ID>"

# wait until all installers are finished
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 30; done;
# install additional packages here

# create status service to host status process
FRONTEND_STATUS_SERVICE_FILE=/etc/systemd/system/${PROJECT_NAME}-frontend-status.service
cat <<-EOF > ${FRONTEND_STATUS_SERVICE_FILE}
[Unit]
Description=run frontend status 

[Service]
User=ubuntu
WorkingDirectory=${ROOT_DIR}/frontend
ExecStart=/usr/bin/java -jar api-spring-boot-0.1.0.jar
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# enable services
systemctl daemon-reload
systemctl enable --now ${PROJECT_NAME}-frontend-status.service
