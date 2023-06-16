set -e

chmod +x .env
source .env
export XAUTHORITY="$HOME/.Xauthority"

CURRENT_ACCOUNT=$(curl -s -X POST https://api.dropboxapi.com/2/users/get_current_account \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID")
CURRENT_ACCOUNT=$(echo $CURRENT_ACCOUNT | jq -r '.account_id')

if [ -z "$CURRENT_ACCOUNT" ] 
then
    echo "No account found"

    echo "Initiating login..."
    firefox "https://www.dropbox.com/"

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

    if [ "null" != "$CURRENT_ACCOUNT" ]; then echo "Authorized DropBox API using OAuth2 and codeflow"
    else echo "Failed to authorize DropBox API using OAuth2 and codeflow" && exit 1; fi
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
touch 'paths.txt'
chmod 777 'paths.txt'
cat /dev/null > $paths

if [[ $LENGTH -gt 0 ]]
then
    count=1
    echo "Creating file list..."
    echo "Query $count..."
    add_files_to_list
    HAS_MORE=$(echo $RES | jq -r '.has_more')
else
    echo "No entries found"
    exit 1
fi

while [ $HAS_MORE == "true" ]
do
    count=$((count+1))
    echo "Query $count"...
    CURSOR=$(echo $RES | jq -r '.cursor')
    RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder/continue \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header 'Content-Type: application/json' \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
        --data "{\"cursor\": \"$CURSOR\"}")
    add_files_to_list
    HAS_MORE=$(echo $RES | jq -r '.has_more')
done

migrate-to-s3 () {
    local line=$1
    local FILEPATH=$(echo "${line#*$BASE_FOLDER/}") 
    local FILEPATH=$(echo ${FILEPATH/channel/Channel})
    local CHECK_S3=$(aws s3 ls "s3://$S3_BUCKET/$FILEPATH" --summarize) || true
    local EXISTS_ON_S3=$(echo "$CHECK_S3" | grep "Total Objects: " | awk -F "Total Objects: " '{print $2}')
    local SIZE_ON_S3=$(echo "$CHECK_S3" | grep "Total Size: " | awk -F "Total Size: " '{print $2}')
    local CHECK_DB=$(curl -s -X POST https://api.dropboxapi.com/2/files/get_metadata \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
        --header "Content-Type: application/json" \
        --data "{\"include_deleted\":false,\"include_has_explicit_shared_members\":false,\"include_media_info\":false,\"path\":\"$line\"}")
    local SIZE_ON_DB=$(echo "$CHECK_DB" | jq -r '.size')
    if [[ $EXISTS_ON_S3 == 1 && $SIZE_ON_S3 -eq $SIZE_ON_DB ]]; then 
        echo "S3 already exists: $FILEPATH"
        continue
    else 
        echo "S3 needs to sync: $FILEPATH"; 
        local output=$(basename "${line}")
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
    fi
}

input="paths.txt"
while IFS= read -r line; do migrate-to-s3 "$line" & done < "$input"
wait
