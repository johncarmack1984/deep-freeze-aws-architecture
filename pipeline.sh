
cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
~/.dropbox-dist/dropboxd

# aws s3 cp brand.tgz s3://vegify-dropbox-archive --storage-class "DEEP_ARCHIVE"
