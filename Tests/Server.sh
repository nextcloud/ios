#!/usr/bin/env zsh

# The fixed Docker container name for the Nextcloud server.
CONTAINER_NAME="xcode-test-server"

# Check for environment variable of server version to use including a default value.
SERVER_VERSION=${SERVER_VERSION:-"stable30"}

# First, kill any existing container with the same name.
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME

# Launch Nextcloud Server in Docker Container.
docker run \
    --detach \
    --name $CONTAINER_NAME \
    --publish 8080:80 \
    ghcr.io/nextcloud/continuous-integration-shallow-server:latest

# Wait a moment until the server is ready.
sleep 2

# Enable File Download Limit App.
docker exec $CONTAINER_NAME su www-data -c "git clone --depth 1 -b $SERVER_VERSION https://github.com/nextcloud/files_downloadlimit.git /var/www/html/apps/files_downloadlimit/"
docker exec $CONTAINER_NAME su www-data -c "php /var/www/html/occ app:enable files_downloadlimit"
