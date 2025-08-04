#!/bin/bash

# Path to the JSON file
json_file="/home/wifidabba/helloworld/access_point_static_ip_list.json"

# Read JSON file and extract IP addresses
ip_addresses=($(jq -r '.[].ip_address' "$json_file"))

# Initialize arrays for successful and failed pings
successful_pings=()
failed_pings=()

# Function to ping an IP address and update arrays
ping_access_point() {
    if ping -n -c 1 -W 1 "$1" &> /dev/null; then
        successful_pings+=("$1")
    else
        failed_pings+=("$1")
    fi
}

# Loop through each IP address and ping
for ip_address in "${ip_addresses[@]}"; do
    ping_access_point "$ip_address"
done

# Display results
echo "Successfully Pinged IP Addresses: ${#successful_pings[@]}"
printf "%s\n" "${successful_pings[@]}"

echo -e "\nFailed to Ping IP Addresses: ${#failed_pings[@]}"
printf "%s\n" "${failed_pings[@]}"
