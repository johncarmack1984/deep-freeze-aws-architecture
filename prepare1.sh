#!/bin/bash
set -e

sudo apt-get update
sudo NEEDRESTART_MODE=a apt install libssl-dev --yes
sudo NEEDRESTART_MODE=a apt install openssl -y 
sudo NEEDRESTART_MODE=a apt-get upgrade -y
sudo NEEDRESTART_MODE=a apt install pkg-config -y 
sudo NEEDRESTART_MODE=a apt install awscli -y 
sudo NEEDRESTART_MODE=a apt install build-essential -y 

sudo chown -R $(whoami) /home/ubuntu/*
git clone https://github.com/johncarmack1984/deep-freeze.git /home/ubuntu/deep-freeze
mv /home/ubuntu/.env /home/ubuntu/deep-freeze/.env
