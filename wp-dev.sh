#!/bin/bash

# EDIT ME
PROJECT="new_project"

mkdir ${PROJECT}
cd ${PROJECT}

mkdir db_data
mkdir wordpress
git clone git@github.com:markjaquith/WordPress-Skeleton.git wordpress

cat << EOF > docker-compose.yml
version: '3.3'

services:
   db:
     image: mysql:5.7
     volumes:
       - ./db_data:/var/lib/mysql
     restart: always
     environment:
       MYSQL_ROOT_PASSWORD: somewordpress
       MYSQL_DATABASE: wordpress
       MYSQL_USER: wordpress
       MYSQL_PASSWORD: wordpress

   wordpress:
     depends_on:
       - db
     image: wordpress:latest
     ports:
       - "80:80"
     restart: always
     environment:
       WORDPRESS_DB_HOST: db:3306
       WORDPRESS_DB_USER: wordpress
       WORDPRESS_DB_PASSWORD: wordpress
       WORDPRESS_DB_NAME: wordpress
     volumes:
       - ./wordpress:/var/www/html
EOF

docker-compose up
