# deepbox

Migrate old folders from Dropbox to S3 Glacier Deep Archive using Terraform.

Gotten as far as building the EC2 instance, and I have the S3 CLI commands ready. Just putting together the pieces now.

For anyone who wants a jump start, I'm using the following commands to get the files from Dropbox to S3; I'm using the AWS CLI on the EC2 instance to do this, and there are 16TB of files, so I'm trying to use the Deep Archive storage class to keep costs down. I'm also using the Dropbox CLI to get the files from Dropbox to the EC2 instance, but only figured out how to download the WHOLE Dropbox at once, which is overkill, I want only select folders and will investigate that tomorrow.

Dropbox fetch:

```
cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -~/.dropbox-dist/dropboxd
```

Take a folder and tar it up, then upload to S3:

```
tar -czvf <folder-name>.tgz <folder-name>
aws s3 cp <folder-name>.tgz s3://<bucket-name> --storage-class "DEEP_ARCHIVE"
```
