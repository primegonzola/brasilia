#!/bin/bash
PROJECT_NAME="${1}"
ROOT_DIR="${2}"
STATUS_TOPIC_ID="${3}"
EVENT_HUB_NAMESPACE="${4}"
EVENT_HUB_PATH="${5}"
EVENT_HUB_KEY="${6}"

# Loop for a number of seconds by default, with a random addition of 0-9 seconds
LOOPTIME=60

get_sas_token() {
    local EVENTHUB_URI=$1
    local SHARED_ACCESS_KEY_NAME=$2
    local SHARED_ACCESS_KEY=$3
    local EXPIRY=${EXPIRY:=$((60 * 60 * 24))} # Default token expiry is 1 day

    local ENCODED_URI=$(echo -n $EVENTHUB_URI | jq -s -R -r @uri)
    local TTL=$(($(date +%s) + $EXPIRY))
    local UTF8_SIGNATURE=$(printf "%s\n%s" $ENCODED_URI $TTL | iconv -t utf8)

    local HASH=$(echo -n "$UTF8_SIGNATURE" | openssl sha256 -hmac $SHARED_ACCESS_KEY -binary | base64)
    local ENCODED_HASH=$(echo -n $HASH | jq -s -R -r @uri)

    echo -n "SharedAccessSignature sr=$ENCODED_URI&sig=$ENCODED_HASH&se=$TTL&skn=$SHARED_ACCESS_KEY_NAME"
}

# Endpoint=sb://events-evsh5eoztun.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=/u87GBnFOCq58SRV36RmFQeE2De4kQ172ZkNdoWYOgc=
# POST https://<yournamespace>.servicebus.windows.net/<yourentity>/messages
# Content-Type: application/json
# Authorization: SharedAccessSignature sr=https%3A%2F%2F<yournamespace>.servicebus.windows.net%2F<yourentity>&sig=<yoursignature from code above>&se=1438205742&skn=KeyName
# ContentType: application/atom+xml;type=entry;charset=utf-8

while true; do
	STARTTIME=$(date +%s)
	# Set status and reset watchdog timer
	# Do not use the watchdog to signal failures of any of the following commands
	# The watchdog is only there to make sure that the script itself keeps running
	systemd-notify --status="Started run on $(date)" WATCHDOG=1

	# Announce the current status
	ENDPOINT_URI=https://${EVENT_HUB_NAMESPACE}.servicebus.windows.net/
	SHARED_ACCESS_KEY_NAME="RootManageSharedAccessKey"
	SHARED_ACCESS_KEY=${EVENT_HUB_KEY}
	# generate sas token
	SAS_TOKEN=$(get_sas_token ${ENDPOINT_URI} ${SHARED_ACCESS_KEY_NAME} ${SHARED_ACCESS_KEY})
	HOST_NAME=$(hostname)
	HOST_IP_ADDRESS=$(hostname --ip-address)
	HOST_STATUS="ACTIVE"
	# create our fineal uri
	EVENT_HUB_ENDPOINT_URI=https://${EVENT_HUB_NAMESPACE}.servicebus.windows.net/${EVENT_HUB_PATH}/messages

# prepare our event data
STATUS_EVENT_DATA=$(
	cat <<EOF
{
    "id": "$RANDOM",
    "eventType": "brasilia-status",
    "eventTime": "$(date +%Y-%m-%dT%H:%M:%S%z)",
    "data": {
        "name": "${HOST_NAME}",
        "address": "${HOST_IP_ADDRESS}",
		"status":"${HOST_STATUS}"
    }
}
EOF
)

	# send message
	curl -X POST -H "Authorization: ${SAS_TOKEN}" -d "${STATUS_EVENT_DATA}" ${EVENT_HUB_ENDPOINT_URI}

	# notify watchdog
	systemd-notify --status="Waiting for next invocation"

	# Calculate our next run time
	ENDTIME=$(date +%s)
	SLEEPTIME=$(( LOOPTIME - (ENDTIME - STARTTIME) + RANDOM % 10 ))

	# Sanity check the sleeptime, if we get a negative time (due to skew )
	[ $SLEEPTIME -le 0 -o $SLEEPTIME -gt $LOOPTIME ] && SLEEPTIME=$LOOPTIME
	sleep $SLEEPTIME
done
