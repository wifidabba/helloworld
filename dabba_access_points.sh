#!/bin/bash

ENV_FILE="/home/wifidabba/env/.env"

set -a
. "$ENV_FILE"
set +a

wdToken=$WD_TOKEN

parentDabbaId=$DABBA_ID

dabbaAccessPoints=$(curl --location 'https://b2b-api.wifidabba.com/api/base-dabbas/access-points?hasAccessPoints=true&parentDabbaId='$parentDabbaId'' --header 'Authorization: '$wdToken'')

status=$(echo "$dabbaAccessPoints" | jq -r '.status')

message=$(echo "$dabbaAccessPoints" | jq -r '.message')


if [ "$status" == "error" ]; then
	echo $message
	exit 1
fi

accessPointsString=$(echo "$dabbaAccessPoints" | jq -r '.data.dabbas')

accessPoints=$(echo $accessPointsString | jq -r '.')

echo $accessPoints | tee /home/wifidabba/helloworld/access_point_static_ip_list.json


