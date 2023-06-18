sudo apt-get update -y
sudo apt-get install jq firefox xdg-utils awscli -y

chmod +x .env
source .env
export XAUTHORITY="$HOME/.Xauthority"

sed -i 's/#X11Forwarding no/X11Forwarding yes/g' /etc/ssh/sshd_config
sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config

sudo systemctl restart sshd

sudo apt-get upgrade -y

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

firefox "https://www.dropbox.com/"
