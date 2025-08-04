#Application libraries installation
ENV_FILE="/home/wifidabba/env/.env"

set -a
. "$ENV_FILE"
set +a

wdNumber=$WD_NUMBER
wdToken=$WD_TOKEN
boardSerialNumber=null
overwrite=true
wireguardToken=$WIREGUARD_TOKEN
wireguardUrl=$WIREGUARD_URL


#If the private & public keys are not generated then only generate else dont
if [ ! -f /etc/wireguard/private.key ]; then
    #Wireguard public & private keys generation
    sudo wg genkey | sudo tee /etc/wireguard/private.key
    sudo chmod go= /etc/wireguard/private.key
    sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
    
    sudo chmod -R 777 /etc/wireguard
    sudo touch /etc/wireguard/wg0.conf
    sudo chmod -R 775 /etc/wireguard/wg0.conf
fi

#Call the dabba API to get the updated details
dabbaRegistration=$(curl -s --location 'https://b2b-api.wifidabba.com/api/dabbas/dabba-registration' \
--header 'Content-Type: application/json' \
--header "Authorization: $wdToken" \
--data '{
    "wdNumber": "'$wdNumber'",
    "boardSerialNumber": "'$boardSerialNumber'",
    "overwrite": '$overwrite'
}')

status=$(echo "$dabbaRegistration"| jq -r '.status')

message=$(echo "$dabbaRegistration"| jq -r '.message')

if [ "$status" == "error" ]; then
        echo $message
        exit 1
fi

#Access user router & wireguard server details for configuration
WG_ROUTER_ASSIGNED_IP_ADDRESS=$(echo "$dabbaRegistration"| jq -r '.data.dabba.client_vpn_ip_address')
WG_ROUTER_PRIVATE_KEY=$(sudo cat /etc/wireguard/private.key)
WG_ROUTER_PUBLIC_KEY=$(sudo cat /etc/wireguard/public.key)
WG_SERVER_IP_ADDRESS=$(echo "$dabbaRegistration"| jq -r '.data.dabba.server_vpn_ip_address')
WG_SERVER_PORT="51820"
WG_SERVER_PUBLIC_KEY=$(echo "$dabbaRegistration"| jq -r '.data.dabba.server_vpn_public_key')

#Just in case if any wireguard services then bring them down else the below configurations will not take into affect, later we will be turning it on
sudo wg-quick down wg0

#Copy the wireguard client configuration in "/etc/wireguard/wg0.conf" file
echo '
[Interface]
PrivateKey = '${WG_ROUTER_PRIVATE_KEY}'
SaveConfig = true
Address = '${WG_ROUTER_ASSIGNED_IP_ADDRESS}'/32
' | sudo tee /etc/wireguard/wg0.conf

#Now all settings are saved and we will start the wireguard client and run it as ubuntu service
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0.service
sudo systemctl start wg-quick@wg0.service

#Wireguard server registration so that all the net traffice moves via the wireguard server
#sudo wg set wg0 peer $WG_SERVER_PUBLIC_KEY allowed-ips 0.0.0.0/0,::/0 endpoint ${WG_SERVER_IP_ADDRESS}:${WG_SERVER_PORT} persistent-keepalive 30
sudo wg set wg0 peer $WG_SERVER_PUBLIC_KEY allowed-ips 10.0.0.1/24 endpoint ${WG_SERVER_IP_ADDRESS}:${WG_SERVER_PORT} persistent-keepalive 30

#Once everything is up and running we are saving the configuration files so that even after reboot it works perfectly fine
sudo wg-quick save wg0

#Call the wireguard server and tell it to register the new wireguard client
curl --location "$wireguardUrl/api/wg-server/wg-register-client" \
--header "Authorization: $wireguardToken" \
--header 'Content-Type: application/json' \
--data-raw '{
    "client_vpn_ip_address": "'${WG_ROUTER_ASSIGNED_IP_ADDRESS}'",
    "router_public_key": "'${WG_ROUTER_PUBLIC_KEY}'"
}'

#Check the wireguard interface and client associated with it
sudo wg show

#For the initial script the wireguard service will not be running, so reboot the system to make it run as service
WG_SERVICE_STATUS=$(systemctl is-active wg-quick@wg0.service)

sleep 5

if [ "${WG_SERVICE_STATUS}" != "active" ]; then
    sudo reboot now
fi
