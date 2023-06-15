
chmod +x .env
source .env

APP_BASE64=$(echo -n "$APP_KEY:$APP_SECRET" | base64)
sed "s/APP_BASE64=.*/APP_BASE64=\"$APP_BASE64\"/g" .env > .env.tmp && mv .env.tmp .env

CURRENT_ACCOUNT=$(curl -s -X POST https://api.dropboxapi.com/2/users/get_current_account \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID")
CURRENT_ACCOUNT=$(echo $CURRENT_ACCOUNT | jq -r '.account_id')


if [ -z "$CURRENT_ACCOUNT" ] 
then
    echo "No account found"

    echo "Initiating token request..."
    open "https://www.dropbox.com/oauth2/authorize?response_type=code&token_access_type=offline&client_id=$APP_KEY"

    echo "Enter authorization code:"
    read AUTHORIZATION_CODE
    sed "s/AUTHORIZATION_CODE=.*/AUTHORIZATION_CODE=\"$AUTHORIZATION_CODE\"/g" .env > .env.tmp && mv .env.tmp .env

    echo "Requesting access token..."
    ACCESS_TOKEN=$(curl https://api.dropbox.com/oauth2/token \
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

    echo "Authorized DropBox API using OAuth2 and codeflow"
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

echo "Current account:"
[ -z "$CURRENT_ACCOUNT" ] && echo "No account found" || echo $CURRENT_ACCOUNT

#### alternate auth method, not effective
# RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder -u "$APP_KEY:$APP_SECRET" \
#   --header 'Content-Type: application/json' \
#   --data '{"path":"","recursive":true}')
# echo $RES
####
#### alternate auth method, not effective
# RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder \
#   --header "Authorization: Basic $APP_BASE64" \
#   --header 'Content-Type: application/json' \
#   --data '{"path":"","recursive":true, "include_deleted":true}')

# echo $RES
####

add_folders_to_list() {
    echo $RES | jq -r '.entries[] | select(.[".tag"] == "file") | .path_display' >> $filename
}

#### functioning auth method
RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
  --header 'Content-Type: application/json' \
  --data '{"path":"/vegifyapp","recursive":true, "limit":2000}')
#####
LENGTH=$(echo $RES | jq -r '[.entries[]]' | jq '. | length')

if [[ $LENGTH -gt 0 ]]
then 
    echo "Found $LENGTH entries"
    filename='folders.txt'
    cat /dev/null > $filename
    add_folders_to_list
    HAS_MORE=$(echo $RES | jq -r '.has_more')
    count=0
else
    echo "No entries found"
    exit 1
fi

while [ $HAS_MORE == "true" ]
do
    ((count++))
    echo "Loop $count"
    CURSOR=$(echo $RES | jq -r '.cursor')
    RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder/continue \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header 'Content-Type: application/json' \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
        --data "{\"cursor\": \"$CURSOR\"}")
    add_folders_to_list
    HAS_MORE=$(echo $RES | jq -r '.has_more')
done

# tar -czvf <folder-name>.tgz <folder-name>
# aws s3 cp brand.tgz s3://vegify-dropbox-archive --storage-class "DEEP_ARCHIVE"
# aws s3 sync ./brand s3://vegify-dropbox-archive/brand --storage-class "DEEP_ARCHIVE"
