FROM --platform=linux/amd64 ubuntu:18.04

WORKDIR /app

RUN apt-get update && apt-get install -y wget

RUN wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
CMD [".dropbox-dist/dropboxd"]