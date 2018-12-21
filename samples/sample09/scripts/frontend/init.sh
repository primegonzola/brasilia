#!/bin/bash
PROJECT_NAME="<PROJECT_NAME>"
ROOT_DIR="<ROOT_DIR>"
STORAGE_ACCOUNT_ID="<STORAGE_ACCOUNT_ID>"

# wait until all installers are finished
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 30; done;

# update
DEBIAN_FRONTEND="noninteractive" sudo apt-get -qy update
# install additional packages here
# install jq
DEBIAN_FRONTEND="noninteractive" sudo apt-get -qy install jq 
# Install Java JDK 8
DEBIAN_FRONTEND="noninteractive" sudo add-apt-repository -y ppa:webupd8team/java
DEBIAN_FRONTEND="noninteractive" sudo apt-get -qy update
DEBIAN_FRONTEND="noninteractive" echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
DEBIAN_FRONTEND="noninteractive" echo debconf shared/accepted-oracle-license-v1-1 seen   true | sudo debconf-set-selections
DEBIAN_FRONTEND="noninteractive" sudo apt-get -qy install oracle-java8-installer

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
