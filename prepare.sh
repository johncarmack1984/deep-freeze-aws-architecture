sudo apt-get update -y
sudo apt install pkg-config openssl libssl-dev awscli build-essential -y 
sudo apt-get upgrade -y
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh              
source $HOME/.cargo/env
cd deep-freeze
cargo build --release
sudo mv target/release/deep-freeze /usr/local/bin
sudo chmod +x /usr/local/bin/deep-freeze

