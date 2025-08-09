Libraries installed:

> Login as wifidabba and perform the following

```
sudo chown root:root /

sudo apt remove apache2 php-pgsql php8.1-pgsql php-cli php-common php-gd php8.1-cgi php8.1-cli php8.1-common php8.1-curl php8.1-fpm php8.1-gd php8.1-opcache php8.1-readline php8.1 -y && sudo apt autoremove

sudo apt update -y && sudo apt install curl gpg gnupg2 software-properties-common ca-certificates apt-transport-https lsb-release -y


#Select [2] for nginx
sudo add-apt-repository ppa:ondrej/php

sudo apt update -y && sudo apt install bridge-utils nginx php8.4 php8.4-cli php8.4-curl php8.4-cgi php8.4-gd php8.4-mbstring php8.4-xml php8.4-bcmath php8.4-common php8.4-fpm -y
```

### Env Creation

```
sudo rm -rf /home/wifidabba/partner-kit /home/wifidabba/helloworldv2 /home/wifidabba/helloworld /home/wifidabba/customer.wifidabba.in /home/wifidabba/clickhouse

cd /home/wifidabba && git clone https://github.com/wifidabba/helloworld.git && mkdir env && cd env && sudo nano .env
```

Update env with the following and update the `WDNumber & Dabba ID`

> **Also add the following in ~/env/.env**

```
# Application configurations
APP_NAME="B2B RabbitMQ Broker"
APP_ENV=production
NODE_ENV=production
APP_PORT=3099
APP_URL="http://localhost:3099"
B2B_API_URL="https://b2b-api.wifidabba.com"
METRICS_API_URL="https://metrics.wifidabba.com"
#Token for routers
WD_TOKEN="01b6c5f3-b124-44af-9a18-787ee174b57d"

#RabbitMQ connection for app servers
B2B_RABBITMQ_CONNECTION_URL="amqp://wifidabba:6L8690pnb9VLWkt@app-broker.wifidabba.com:5672?heartbeat=45"

B2B_RABBITMQ_QUEUE=WD2692
WD_NUMBER=WD2692
DABBA_ID="65b7b96e335898c0b7f1d3c9"

DABBA_PASSWORD="2DizAm4B059ZlkOo6VHQ"
DABBA_LITE_PASSWORD="C4tM0u3ED@g!"

#App MQTT Broker
APP_MQTT_URL="mqtt://app-broker.wifidabba.com:1883"
APP_MQTT_USERNAME="mqttuser"
APP_MQTT_PASSWORD="Z5wtl5C2i6xl"

WIREGUARD_TOKEN="158d28c1-08e6-487d-b3f8-08cf6e327b1c"
WIREGUARD_URL="http://167.71.233.253:3000"
```

```
/home/wifidabba/helloworld/dabba_access_points.sh
```

###### partner-kit project merged with b2b-router-consumer

```
cd ~/b2b-router-consumer

git pull origin develop && npm i && pm2 kill && npm run pm2:start && pm2 startup


#Copy and paste the startup script


pm2 save && pm2 restart all

```

##### NGINX

```
sudo cp /home/wifidabba/helloworld/nginx/default /etc/nginx/sites-available/default && sudo nginx -t && sudo service nginx restart
```

NOTE: Check permissions, if no www-data then follow the further steps

```
cd /var/www/html && sudo rm -rf * && sudo rm -rf .DS_Store .git .gitignore && sudo git clone https://github.com/wifidabba/dabba-router-captive-portal.git .


#Update wd number
sudo nano /var/www/html/config/config.json

sudo chown -R www-data:www-data /var/www/html/

sudo chmod -R 755 /var/www/html/
```

Give SUDO permissions for NFT

```
sudo visudo

www-data ALL=(root) NOPASSWD: /usr/sbin/nft
```

##### Firewall Rules

```
sudo cp /home/wifidabba/helloworld/rc.local /etc/rc.local
```

NFT Tables:

CAUTION: Backup line isp nftables:

    ```
    sudo mkdir -p /etc/firewall_rules && sudo cp /home/wifidabba/helloworld/nftables/backup-connection/nft-rules.nft /etc/firewall_rules/nft-rules.nft

    sudo cp /home/wifidabba/helloworld/nftables/backup-connection/nftables.conf /etc/nftables.conf

    sudo cp /home/wifidabba/helloworld/nftables/backup-connection/dual-wan-monitor.sh /usr/local/bin/dual-wan-monitor.sh
    ```

CAUTION: Single line isp nftables:

    ```
    sudo mkdir -p /etc/firewall_rules && sudo cp /home/wifidabba/helloworld/nftables/single-connection/nft-rules.nft /etc/firewall_rules/nft-rules.nft

    sudo cp /home/wifidabba/helloworld/nftables/single-connection/nftables.conf /etc/nftables.conf
    ```

##### cronjobs update the heartbeats and natlog path to b2b-router-consumer

### NOTE: comment the NAT LOG CRON JOB

crontab -e

From

```
cd /home/wifidabba/partner-kit
```

To

```
cd /home/wifidabba/b2b-router-consumer
```

```sh
 */7 * * * * (cd /home/wifidabba/b2b-router-consumer && /home/wifidabba/.nvm/versions/node/v20.11.0/bin/node src/cronjobs/dabbas-heartbeat.cron.js) 2>&1 | logger -t dabbas-heartbeat-cronjob

#*/3 * * * * (cd /home/wifidabba/partner-kit && /home/wifidabba/.nvm/versions/node/v20.11.0/bin/node src/cronjobs/natlog.cron.js) 2>&1 | logger -t natlog-cronjob
```

##### Increase the ip range

```
sudo nano /etc/systemd/network/25-lanbr.network
```

Replace:

```
Address=192.168.174.1/19
```

```
sudo cp /home/wifidabba/helloworld/dnsmasq.conf /etc/dnsmasq.conf
```

##### Bandwidth Accounting Scripts on BPI R3 routers - CL and HW

#### NOTE : use only after the bw accounting packages are setup .

1. Open crontab and remove all the content

```sh
sudo crontab -e
```

2. Replace it with

```c
*/2 * * * * /home/wifidabba/bandwidth-accounting/bandwidth_accounting.sh
```

3. Go to home folder .

```sh
cd /home/wifidabba && git clone https://github.com/wifidabba/bandwidth-accounting.git
```

4. Test it.

```c
sudo /home/wifidabba/bandwidth-accounting/bandwidth_accounting.sh && sudo tail -n 50 /var/log/syslog | grep 'Successfully'
```

##### NAT LOG SETUP

1. Install Packages

```sh
sudo apt update && sudo apt install tcpdump -y && sudo apt install rsyslog
```

5 . Create a log file

Run the whole command

```sh
sudo tee /etc/rsyslog.d/10-natlog.conf > /dev/null << 'EOF'

# For NAT logs
if $msg contains "NAT LOG" then {
    *.* @135.235.193.231:514  # For UDP
    # *.* @@167.71.233.252:514  # Uncomment for TCP
    stop
}
*.* /var/log/syslog
EOF
```

6. Other Commands

Resolve Conf:

```
sudo cp /home/wifidabba/helloworld/resolv.conf /etc/resolv.conf
```

7. Restart and make sure no logs are being written to the router.

```sh
sudo systemctl restart rsyslog && sudo reboot
```

Check the nat table

```sh
sudo nft list table nat
```
