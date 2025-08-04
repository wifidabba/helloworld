#!/bin/bash

###MANUALLY EDIT THIS FILE AND ADD IPV4 FORWARD /etc/sysctl.conf
### MANUALL SET STATIC ip using GUI
#sudo nano /etc/sysctl.conf

sysctl -w net.ipv4.ip_forward=1

sudo apt update
sudo apt-get install curl openssh-server git zip unzip dnsmasq ipset sshpass -y
sudo apt-get install net-tools iw build-essential libncurses5-dev libncursesw5-dev flex bison libssl-dev libelf-dev dbus libdbus-1-dev libdbus-glib-1-2 libdbus-glib-1-dev libnl-3-dev libnl-genl-3-dev sysstat -y

sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

chmod 777 /etc/resolv.conf

sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq

sudo cp --remove-destination /home/wifidabba/helloworld/resolv.conf /etc/

sudo cp /home/wifidabba/helloworld/dnsmasq.conf /etc/




