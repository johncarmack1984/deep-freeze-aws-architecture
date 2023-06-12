FROM amazonlinux:latest

WORKDIR /app

RUN yum install wget tar gzip -y
RUN wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -

CMD [".dropbox-dist/dropboxd"]
