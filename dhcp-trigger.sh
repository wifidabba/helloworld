#!/bin/bash
# Your custom script logic here
# $1 will contain "add" or "del" indicating lease acquisition or release
# $2 will contain the MAC address of the device
# $3 will contain the IP address assigned to the device

ENV_FILE="/home/wifidabba/env/.env"

set -a
. "$ENV_FILE"
set +a

#leaseAcquistion=$1
macAddress=$2
wdNumber=$WD_NUMBER
ipAddress=$3

#CURL command options used are as follows
# -s : run silently
# -m : max timeout

autologin=$(curl -s -m 20 --location "https://b2b-api.wifidabba.com/api/auth/autologin?macAddress=${macAddress}&wdNumber=${wdNumber}")

autologinStatus=$(echo "${autologin}" | jq -r ".status")

if [[ "${autologinStatus}" -eq "success" ]]; then

	userPlans=$(echo "${autologin}" | jq -r ".data.userPlans|length")

	logger "${macAddress} has ${userPlans} plans................."

	if [ "$userPlans" -gt 0 ]; then

		nft add element ip filter whitelist_ips { {$ipAddress} }
		nft add element ip nat whitelist_ips { {$ipAddress} }

		echo "DHCP trigger device whitelist: ${macAddress}"

		logger "DHCP trigger device whitelist: ${macAddress}"

	fi
fi
