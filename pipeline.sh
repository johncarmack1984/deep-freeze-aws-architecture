curl -X POST https://api.dropboxapi.com/2/files/list_folder \
    --header "Authorization: Basic <get app key and secret>" \
    --header "Content-Type: application/json" \
    --data "{\"include_deleted\":false,\"include_has_explicit_shared_members\":false,\"include_media_info\":false,\"include_mounted_folders\":true,\"include_non_downloadable_files\":true,\"path\":\"/Homework/math\",\"recursive\":false}"
# aws s3 cp brand.tgz s3://vegify-dropbox-archive --storage-class "DEEP_ARCHIVE"
