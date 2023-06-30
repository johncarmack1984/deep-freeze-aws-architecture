#!/bin/bash
set -e

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
sudo chown -R $(whoami) /home/ubuntu/*
cd /home/ubuntu/deep-freeze
cargo build --release
sudo mv target/release/ /usr/local/bin \
sudo chmod +x /usr/local/bin/deep-freeze
