#!/bin/bash

# EDIT ME
PROJECT="demo"
PROJECT_URL="demo.snappyselling.com"
GIT_REPO="git@git.snappyselling.com:other/demo.git"

NGINX_CONF_DIR=./nginx
NGINX_LOG_DIR=./logs/nginx
SSL_CERTS_DIR=./certs
SSL_CERTS_DATA_DIR=./certs-data

mklog(){
echo -e "$(date)\t${@}"
}

mkcert(){
 openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
    -days 365 -nodes -subj '/CN='${PROJECT_URL}''
 mv cert.pem ${PROJECT}/certs/live/${PROJECT_URL}/fullchain.pem
 mv key.pem ${PROJECT}/certs/live/${PROJECT_URL}/privkey.pem
}

mklog "Creating directory structure..."
mkdir -p ${PROJECT}/db_data ${PROJECT}/nginx ${PROJECT}/logs/nginx \
         ${PROJECT}/certs/live/${PROJECT_URL} ${PROJECT}/certs-data

if ! [ -z $GIT_REPO ];then
 mklog "Cloning ${GIT_REPO}"
 git clone ${GIT_REPO} ${PROJECT}/
fi

mklog "Creating nginx configuration..."
cat << EOF > ${PROJECT}/nginx/default.conf
server {
    listen      443           ssl http2;
    listen [::]:443           ssl http2;
    server_name               ${PROJECT_URL};
    add_header                Strict-Transport-Security "max-age=31536000" always;

    ssl_session_cache         shared:SSL:20m;
    ssl_session_timeout       10m;
    ssl_protocols             TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers               "ECDH+AESGCM:ECDH+AES256:ECDH+AES128:!ADH:!AECDH:!MD5;";
    ssl_stapling              on;
    ssl_stapling_verify       on;
    ssl_certificate           /etc/letsencrypt/live/${PROJECT_URL}/fullchain.pem;
    ssl_certificate_key       /etc/letsencrypt/live/${PROJECT_URL}/privkey.pem;

    resolver                  8.8.8.8 8.8.4.4;

    root /var/www/html;
    index /;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        proxy_pass http://demo:5001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
     }
}
EOF

mklog "Creating docker-compose.yml"
cat << EOF > ${PROJECT}/docker-compose.yml
version: '3.3'
services:
    demo:
        container_name: demo
        environment:
          - ASPNETCORE_ENVIRONMENT=Development
          - ASPNETCORE_URLS=https://+:443;http://+:80
          - ASPNETCORE_HTTPS_PORT=443
        image: demo
        restart: always
        build:
          context: .
          dockerfile: demo/Demo/Dockerfile
        ports:
          - "5000:80"
          - "5001:443"
        depends_on:
          - db
    db:
        image: postgres
        restart: always
        container_name: db
        hostname: db
        ports:
          - "5432:5432"
        environment:
          - POSTGRES_PASSWORD=local_user+2019*
          - POSTGRES_USER=local_user
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U local_user"]
          interval: 10s
          timeout: 5s
          retries: 5
    nginx:
        image: nginx:${NGINX_VERSION:-latest}
        container_name: nginx
        ports:
          - '443:443'
        volumes:
          - ${NGINX_CONF_DIR:-./nginx}:/etc/nginx/conf.d
          - ${NGINX_LOG_DIR:-./logs/nginx}:/var/log/nginx
          - ${SSL_CERTS_DIR:-./certs}:/etc/letsencrypt
          - ${SSL_CERTS_DATA_DIR:-./certs-data}:/data/letsencrypt
        depends_on:
          - demo
        restart: always
EOF

mklog "Creating SSL/TLS Certificates..."
mkcert
mklog "Running containers... hit CTRL+C to exit"
cd ${PROJECT}
#docker-compose up
