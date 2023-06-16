sudo apt-get update -y
sudo apt-get install jq xdg-utils firefox aws-cli -y

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

firefox "https://www.dropbox.com/"
