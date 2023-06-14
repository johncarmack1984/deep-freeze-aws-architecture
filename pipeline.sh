
chmod +x .env
source .env

APP_BASE64=$(echo -n "$APP_KEY:$APP_SECRET" | base64)
sed "s/APP_BASE64=.*/APP_BASE64=\"$APP_BASE64\"/g" .env > .env.tmp && mv .env.tmp .env

CURRENT_ACCOUNT=$(curl -s -X POST https://api.dropboxapi.com/2/users/get_current_account \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID")
# echo $CURRENT_ACCOUNT | jq -r '.root_info'
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

# RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder \
#   --header "Authorization: Bearer $ACCESS_TOKEN" \
#   --header 'Content-Type: application/json' \
#   --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
#   --data '{"path":"","recursive":true}')

# echo $RES | jq -r '.entries[] | select(.[".tag"] == "file") | .path_display'

# while [ $(echo $RES | jq -r '.has_more') == "true" ]
# do
#     echo $RES | jq -r '.entries[] | select(.[".tag"] == "file") | .path_display'
#     echo $RES | jq -r '.entries[] | select(.[".tag"] == "folder") | .path_display'
#     echo "Has More is"
#     echo $RES | jq '.has_more'
#     echo "Resetting..."
#     RES=$(echo $RES | jq '.has_more = false')
#     echo "Has More is..."
#     echo $RES | jq '.has_more'
# done

RES=$(curl -s -X POST https://api.dropboxapi.com/2/team/team_folder/list \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{\"limit\":100}")

TEAM_FOLDER_ID=$(echo $RES | jq -r '.team_folders[].team_folder_id')

curl -X POST https://api.dropboxapi.com/2/team/team_folder/get_info \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{\"team_folder_ids\": [\"$TEAM_FOLDER_ID\"]}"

# tar -czvf <folder-name>.tgz <folder-name>
# aws s3 cp brand.tgz s3://vegify-dropbox-archive --storage-class "DEEP_ARCHIVE"
# aws s3 sync ./brand s3://vegify-dropbox-archive/brand --storage-class "DEEP_ARCHIVE"
