#!/bin/bash 

echo -e "
__        ___  __ _   ____        _     _
\ \      / (_)/ _(_) |  _ \  __ _| |__ | |__   __ _
 \ \ /\ / /| | |_| | | | | |/ _| | '_ \| '_ \ / _| |
  \ V  V / | |  _| | | |_| | (_| | |_) | |_) | (_| |
   \_/\_/  |_|_| |_| |____/ \__,_|_.__/|_.__/ \__,_|
\n
@author: Channaveer Hakari
@email: channaveer@wifidabba.com 
\n\n"

#### Downlod fresh package information from all configured sources ####
echo -e "\n\033[1mUpdating ubuntu package libraries...\033[0m\n"
sudo apt-get update -y

#Sudo apt install netools
echo -e "\n\033[1mInstalling net tools...\033[0m \n"
sudo apt install net-tools -y

#Install git zip unzip curl
echo -e "\n\033[1mInstalling git zip unzip curl...\033[0m\n"
sudo apt install git zip unzip curl openssh-server -y

#### Install NGINX so that we can setup local domains or reverse proxy stuff ####
#echo -e "\n\033[1mInstalling NGINX...\033[0m\n"
#sudo apt install -y nginx

#### Install Wireguard VPN ####
echo -e "\n\033[1mInstalling Wireguard VPN...\033[0m\n"
sudo apt install jq wireguard resolvconf -y

#### Install NVM (Node Version Manager) ####
echo -e "\n\033[1mInstalling NVM (Node Version Manager)...\033[0m\n"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
source ~/.bashrc

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm install --lts

#### PM2 process manager for NodeJS applications ####
echo -e "\n\033[1mInstalling PM2 process manager for NodeJS applications...\033[0m\n"
npm install pm2@latest -g

# Wireguard: to work only on domains ipv4 addresses that connect via mobile hotspot
if grep -q "^#precedence ::ffff:0:0/96  100" /etc/gai.conf; then
    sudo sed -i "/^#precedence ::ffff:0:0\/96  100/ s/^#//" /etc/gai.conf
else
    echo 1
fi
