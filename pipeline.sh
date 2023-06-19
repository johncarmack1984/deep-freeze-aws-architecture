set -e

chmod +x .env
source .env
export XAUTHORITY="$HOME/.Xauthority"

setenv() {
    key=$1; value=$2
    sed "s/$key=.*/$key=\"$value\"/g" .env > .env.tmp && mv .env.tmp .env
}

login () {
    echo "⚠️ No account found"

    echo "🔒 Initiating login..."
    firefox "https://www.dropbox.com/"

    echo "🔐 Initiating token request"
    firefox "https://www.dropbox.com/oauth2/authorize?client_id=$APP_KEY&token_access_type=offline&response_type=code"

    echo "🪪 Enter authorization code:"
    read AUTHORIZATION_CODE
    setenv "AUTHORIZATION_CODE" "$AUTHORIZATION_CODE"

    echo "🔐 Requesting access token..."
    ACCESS_TOKEN=$(curl -s https://api.dropbox.com/oauth2/token \
        -d code=$AUTHORIZATION_CODE \
        -d grant_type=authorization_code \
        -d client_id=$APP_KEY \
        -d client_secret=$APP_SECRET)
    REFRESH_TOKEN=$(echo $ACCESS_TOKEN | jq -r '.refresh_token')
    ACCESS_TOKEN=$(echo $ACCESS_TOKEN | jq -r '.access_token')
    setenv "REFRESH_TOKEN" "$REFRESH_TOKEN"
    setenv "ACCESS_TOKEN" "$ACCESS_TOKEN"
}

refresh_token () {
    echo "🔐 Refreshing access token..."
    ACCESS_TOKEN=$(curl -s https://api.dropbox.com/oauth2/token \
        -d refresh_token=$REFRESH_TOKEN \
        -d grant_type=refresh_token \
        -d client_id=$APP_KEY \
        -d client_secret=$APP_SECRET)
    ACCESS_TOKEN=$(echo $ACCESS_TOKEN | jq -r '.access_token')
    setenv "ACCESS_TOKEN" "$ACCESS_TOKEN"
}

check_account () {
    echo "🪪 Checking account..."
    local RES=$(curl -s -X POST https://api.dropboxapi.com/2/users/get_current_account \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID")
    error=$(echo $RES | jq -r '.error')
    if [ "$error" == "null" ]; then 
        CURRENT_USER=$(echo $RES | jq -r '.email')
        CURRENT_ACCOUNT=$(echo $RES | jq -r '.account_id')
        TEAM_MEMBER_ID=$(echo $RES | jq -r '.team_member_id')
        echo "🔓 Authorized DropBox API using OAuth2 and codeflow"
        echo "👤 Logged in as $CURRENT_USER"
    else echo "❌ $RES" && exit 1; fi
    if [ -z "$CURRENT_ACCOUNT" ]; then login && check_account
    elif [ $CURRENT_ACCOUNT == "null" ]; then refresh_token && check_account
    fi
}

check_account

printf -v MAX_THREADS "%d" "$(( $(ulimit -s) / 150 ))"
# printf -v MAX_THREADS "%d" "$(( 2 ))"
echo "🖥️ Max threads: $MAX_THREADS"

paths='paths.txt'

add_files_to_list() {
    printf $(echo $RES | jq -r '[.entries[]]' | jq '. | length')
    printf " files found\n" 
    echo $RES | jq -r '.entries[] | select(.[".tag"] == "file") | .path_display' >> $paths || echo -e "❌ Error adding files to list \n❌ Response from server: $RES" 2>&1 | tee -a logs/errors.log && true
}


get_paths () {
    touch $paths
    chmod 777 $paths
    cat /dev/null > $paths
    rm -rf temp
    rm -rf logs
    mkdir -p logs

    RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
        --header 'Content-Type: application/json' \
        --data "{\"path\":\"$BASE_FOLDER\",\"recursive\":true, \"limit\":2000}")
    
    LENGTH=$(echo $RES | jq -r '[.entries[]]' | jq '. | length')

    if [[ $LENGTH -gt 0 ]]
    then
        count=1
        echo "🗄️ Creating file list..."
        printf "📦 Query $count..."
        add_files_to_list $RES
        HAS_MORE=$(echo $RES | jq -r '.has_more')
    else
        echo "No entries found"
        exit 1
    fi

    while [ $HAS_MORE == "true" ]
    do
        count=$((count+1))
        printf "📦 Query $count"...
        CURSOR=$(echo $RES | jq -r '.cursor')
        RES=$(curl -s -X POST https://api.dropboxapi.com/2/files/list_folder/continue \
            --header "Authorization: Bearer $ACCESS_TOKEN" \
            --header 'Content-Type: application/json' \
            --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
            --data "{\"cursor\": \"$CURSOR\"}")
        add_files_to_list $RES
        HAS_MORE=$(echo $RES | jq -r '.has_more')
    done
}

[ ! -f $paths ] && get_paths
# get_paths

# sed -i '/^$/d' $paths

hold-for-thread () {
    jobs | wc -l | xargs echo "🧵 Jobs: $1"
    while [ $(jobs | wc -l) -ge $MAX_THREADS ]; do sleep 1; done
}

remove-from-list () {
    local TEMPFILE="./temp/$(basename "$1")"
    # def need controls for: [] | /
    sed "\|$1|d" $paths > "$TEMPFILE" && mv "$TEMPFILE" "$paths" || echo -e "❌ Error removing $1 from list \n" 2>&1 | tee -a logs/errors.log && true
}

migrate-to-s3 () {
    local line=$1
    local FILEPATH=$(echo "${line#*$BASE_FOLDER/}") 
    local FILEPATH=$(echo ${FILEPATH/channel/Channel})
    local S3_PATH="s3://$S3_BUCKET/$FILEPATH"
    local output=$(basename "${line}")
    # echo -e "⏳ Waiting for thread to check $output on S3..."
    # hold-for-thread
    echo -e "📦 Checking S3 $line"
    local CHECK_S3=$(aws s3 ls "$S3_PATH" --summarize) || echo -e "❌ Error checking S3 $line \n" 2>&1 | tee -a logs/errors.log && true
    local EXISTS_ON_S3=$(echo "$CHECK_S3" | grep "Total Objects: " | awk -F "Total Objects: " '{print $2}')
    local SIZE_ON_S3=$(echo "$CHECK_S3" | grep "Total Size: " | awk -F "Total Size: " '{print $2}')
    # echo -e "⏳ Waiting for thread to check $output on DropBox..."
    # hold-for-thread
    echo -e "🗳️ Checking DB $line"
    local CHECK_DB=$(curl -s -X POST https://api.dropboxapi.com/2/files/get_metadata \
        --header "Authorization: Bearer $ACCESS_TOKEN" \
        --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
        --header "Content-Type: application/json" \
        --data "{\"include_deleted\":false,\"include_has_explicit_shared_members\":false,\"include_media_info\":false,\"path\":\"$line\"}") || echo -e "❌ Error checking DB $line \n" 2>&1 | tee -a logs/errors.log && true
    local SIZE_ON_DB=$(echo "$CHECK_DB" | jq -r '.size')
    # echo -e "** $output **\nSize on S3: $SIZE_ON_S3\nSize on DB: $SIZE_ON_DB"
    # echo "CHECK_DB: $CHECK_DB"
    # line below needs controls for: _
    if [[ $EXISTS_ON_S3 == 1 && $SIZE_ON_S3 -eq $SIZE_ON_DB ]]; then 
        echo -e "✅ Already S3: $line" 2>&1 | tee -a logs/info.log && remove-from-list "$line";
    else 
        echo -e "🔄 S3 needs to sync: $line"; 
        echo -e "⬇️ Downloading from DropBox $line"
        curl -X POST https://content.dropboxapi.com/2/files/download \
            --header "Authorization: Bearer $ACCESS_TOKEN" \
            --header "Dropbox-API-Select-Admin: $TEAM_MEMBER_ID" \
            --header "Dropbox-API-Arg: {\"path\":\"${line}\"}" \
            --output "./temp/$output" || echo -e "❌ Error downloading: $line \n" 2>&1 | tee -a logs/errors.log && exit 1
        if [[ $EXISTS_ON_S3 == 1 && $SIZE_ON_S3 -ne $SIZE_ON_DB ]]; then 
            echo -e "🗑️ Removing $output from S3 \n";
            aws s3 rm "$S3_PATH" || echo -e "❌ Error removing from S3: $line" 2>&1 | tee -a logs/errors.log
        fi
        echo -e "⬆️ Uploading to S3 $line"
        aws s3 mv "./temp/$output" "$S3_PATH" --storage-class "DEEP_ARCHIVE" && echo -e "✅ Successfully migrated $line" 2>&1 | tee -a logs/info.log && remove-from-list "$line" || echo -e "❌ Error moving to S3: $line \n" > logs/errors.log && true
    fi
    return;
}


echo "🗄️ Total of $(wc -l < $paths) files to migrate (this may take a while)"
mkdir -p temp
echo "🗃️ Performing migration..."

input=$paths
while IFS= read -r line; do 
    # echo -e "⏳ Waiting for thread to migrate $line..."
    # hold-for-thread
    echo -e "📂 Migrating $line"
    migrate-to-s3 "$line" 
    # migrate-to-s3 "$line" & 
done < "$input"
wait

rm -rf temp

echo "✅✅✅ Migration complete."

trap finish EXIT
rm -rf temp
