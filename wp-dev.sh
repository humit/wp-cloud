#!/bin/bash

# EDIT ME
PROJECT="CHANGEME"
PROJECT_URL="${PROJECT}.com"
GIT_REPO="git@github.com:humit/skeleton-wp.git"

WORDPRESS_DB_HOST="CHANGEME"
WORDPRESS_DB_USER="wordpress"
WORDPRESS_DB_PASSWORD=""
WORDPRESS_DB_NAME=""
WORDPRESS_TABLE_PREFIX=""
WORDPRESS_DEBUG="1"
CDN_S3_BUCKET="${PROJECT}-prod"
CDN_S3_KEY=""
WORDPRESS_IMAGE="CHANGEME/${PROJECT}-wp"
CDN_S3_REGION="CHANGEME"
CDN_S3_SECRET=""

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
mkdir -p ${PROJECT}/db_data ${PROJECT}/wordpress ${PROJECT}/nginx ${PROJECT}/logs/nginx \
         ${PROJECT}/certs/live/${PROJECT_URL} ${PROJECT}/certs-data

mklog "Cloning $GIT_REPO into ${PROJECT}/wordpress"
git clone ${GIT_REPO} ${PROJECT}/wordpress

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
    index index.php;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        proxy_pass http://wordpress:80;
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
   wordpress:
     container_name: wordpress
     image: $WORDPRESS_IMAGE
     ports:
       - "80:80"
     restart: always
     environment:
       - WORDPRESS_DB_HOST=\${WORDPRESS_DB_HOST:-$WORDPRESS_DB_HOST}
       - WORDPRESS_DB_USER=\${WORDPRESS_DB_USER:-$WORDPRESS_DB_USER}
       - WORDPRESS_DB_PASSWORD=\${WORDPRESS_DB_PASSWORD:-$WORDPRESS_DB_PASSWORD}
       - WORDPRESS_DB_NAME=\${WORDPRESS_DB_NAME:-$WORDPRESS_DB_NAME}
       - WORDPRESS_TABLE_PREFIX=\${WORDPRESS_TABLE_PREFIX:-$WORDPRESS_TABLE_PREFIX}
       - SSH_PRIVATE_KEY=\${SSH_PRIVATE_KEY:-$SSH_PRIVATE_KEY}
       - GIT_REPO=\${GIT_REPO:-$GIT_REPO}
       - CDN_S3_KEY=\${CDN_S3_KEY:-$CDN_S3_KEY}
       - CDN_S3_SECRET=\${CDN_S3_SECRET:-$CDN_S3_SECRET}
       - CDN_S3_BUCKET=\${CDN_S3_BUCKET:-$CDN_S3_BUCKET}
       - CDN_S3_REGION=\${CDN_S3_REGION:-$CDN_S3_REGION}
     volumes:
       - ./wordpress/wordpress:/var/www/html
   memcache:
     container_name: memcache
     image: memcached:alpine
     ports:
       - 11211:11211
     restart: always
   nginx:
     image: nginx:\${NGINX_VERSION:-latest}
     container_name: nginx
     ports:
       - '443:443'
     volumes:
       - \${NGINX_CONF_DIR:-./nginx}:/etc/nginx/conf.d
       - \${NGINX_LOG_DIR:-./logs/nginx}:/var/log/nginx
       - \${WORDPRESS_DATA_DIR:-./wordpress}:/var/www/html
       - \${SSL_CERTS_DIR:-./certs}:/etc/letsencrypt
       - \${SSL_CERTS_DATA_DIR:-./certs-data}:/data/letsencrypt
     depends_on:
       - wordpress
     restart: always
EOF

mklog "Creating SSL/TLS Certificates..."
mkcert
mklog "Running containers... hit CTRL+C to exit"
cd ${PROJECT}
docker-compose up
