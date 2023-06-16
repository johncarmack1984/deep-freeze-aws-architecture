set -e

chmod +x .env
source .env
export XAUTHORITY="$HOME/.Xauthority"

sudo apt-get update -y
sudo apt-get install jq xdg-utils firefox aws-cli -y

APP_BASE64=$(echo -n "$APP_KEY:$APP_SECRET" | base64)
sed "s/APP_BASE64=.*/APP_BASE64=\"$APP_BASE64\"/g" .env > .env.tmp && mv .env.tmp .env

CURRENT_ACCOUNT=$(curl -s -X POST https://api.dropboxapi.com/2/users/get_current_account \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID")
CURRENT_ACCOUNT=$(echo $CURRENT_ACCOUNT | jq -r '.account_id')

if [ -z "$CURRENT_ACCOUNT" ] 
then
    echo "No account found"

    echo "Initiating login..."
    firefox "https://www.dropbox.com/"
    read -n1 -r -p "Press any key to continue once logged in via Firefox..." key

    echo "Initiating token request"
    firefox "https://www.dropbox.com/oauth2/authorize?client_id=$APP_KEY&token_access_type=offline&response_type=code"

    echo "Enter authorization code:"
    read AUTHORIZATION_CODE
    sed "s/AUTHORIZATION_CODE=.*/AUTHORIZATION_CODE=\"$AUTHORIZATION_CODE\"/g" .env > .env.tmp && mv .env.tmp .env

    echo "Requesting access token..."
    ACCESS_TOKEN=$(curl -s https://api.dropbox.com/oauth2/token \
        -d code=$AUTHORIZATION_CODE \
        -d grant_type=authorization_code \
        -d client_id=$APP_KEY \
        -d client_secret=$APP_SECRET)
    REFRESH_TOKEN=$(echo $ACCESS_TOKEN | jq -r '.refresh_token')
    ACCESS_TOKEN=$(echo $ACCESS_TOKEN | jq -r '.access_token')
    sed "s/REFRESH_TOKEN=.*/REFRESH_TOKEN=\"$REFRESH_TOKEN\"/g" .env > .env.tmp && mv .env.tmp .env
    sed "s/ACCESS_TOKEN=.*/ACCESS_TOKEN=\"$ACCESS_TOKEN\"/g" .env > .env.tmp && mv .env.tmp .env

    echo "Requesting team member id..."
    CURRENT_ACCOUNT=$(curl -s -X POST https://api.dropboxapi.com/2/users/get_current_account \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID")
    CURRENT_ACCOUNT=$(echo $CURRENT_ACCOUNT | jq -r '.account_id')

    if [ "null" != "$CURRENT_ACCOUNT" ]; then echo "Authorized DropBox API using OAuth2 and codeflow"; else echo "Failed to authorize DropBox API using OAuth2 and codeflow" && exit 1; fi
elif [ $CURRENT_ACCOUNT == "null" ]
then
    echo "Refreshing access token..."
    ACCESS_TOKEN=$(curl -s https://api.dropbox.com/oauth2/token \
        -d refresh_token=$REFRESH_TOKEN \
        -d grant_type=refresh_token \
        -d client_id=$APP_KEY \
        -d client_secret=$APP_SECRET)
    ACCESS_TOKEN=$(echo $ACCESS_TOKEN | jq -r '.access_token')
    sed "s/ACCESS_TOKEN=.*/ACCESS_TOKEN=\"$ACCESS_TOKEN\"/g" .env > .env.tmp && mv .env.tmp .env

    echo "Requesting team member id..."
    CURRENT_ACCOUNT=$(curl -s -X POST https://api.dropboxapi.com/2/users/get_current_account \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID")
    CURRENT_ACCOUNT=$(echo $CURRENT_ACCOUNT | jq -r '.account_id')
    echo "Re-Authorized with DropBox API using OAuth2 and codeflow"
fi


RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
  --header 'Content-Type: application/json' \
  --data "{\"path\":\"$BASE_FOLDER\",\"recursive\":true, \"limit\":2000}")
LENGTH=$(echo $RES | jq -r '[.entries[]]' | jq '. | length')

add_files_to_list() {
    echo $RES | jq -r '.entries[] | select(.[".tag"] == "file") | .path_display' >> $paths
}

paths='paths.txt'
touch paths.txt
chmod 777 paths.txt
cat /dev/null > $paths

if [[ $LENGTH -gt 0 ]]
then
    echo "Creating file list..."
    add_files_to_list
    HAS_MORE=$(echo $RES | jq -r '.has_more')
    count=0
else
    echo "No entries found"
    exit 1
fi

while [ $HAS_MORE == "true" ]
do
    count=$((count+1))
    echo "Loop $count"...
    CURSOR=$(echo $RES | jq -r '.cursor')
    RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder/continue \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header 'Content-Type: application/json' \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
        --data "{\"cursor\": \"$CURSOR\"}")
    add_files_to_list
    HAS_MORE=$(echo $RES | jq -r '.has_more')
done

input=$paths
while IFS= read -r line
do
    FILEPATH=$(echo "${line#*$BASE_FOLDER/}") 
    FILEPATH=$(echo ${FILEPATH/channel/Channel})
    if [ -z "$(aws s3 ls "s3://$S3_BUCKET/$FILEPATH")" ]; then
        echo "S3 file not found: $FILEPATH"
        output=$(basename "${line}")
        echo "Downloading $output from DropBox..."
        echo ""
        curl -X POST https://content.dropboxapi.com/2/files/download \
            --header "Authorization: Bearer $ACCESS_TOKEN" \
            --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
            --header "Dropbox-API-Arg: {\"path\":\"${line}\"}" \
            --output "$output"
        echo ""
        echo "Uploading $output to S3..."
        aws s3 cp "$output" "s3://$S3_BUCKET/$FILEPATH" --storage-class "DEEP_ARCHIVE"
        rm "$output"
    else
        echo "S3 already exists: $FILEPATH"
    fi
done < "$input"
