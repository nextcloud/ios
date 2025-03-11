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
    -e BRANCH=$SERVER_VERSION \
    ghcr.io/nextcloud/continuous-integration-shallow-server:latest

# Wait a moment until the server is ready.
echo "Please wait until the server is provisioned…"
sleep 20

# Enable File Download Limit App.
docker exec $CONTAINER_NAME su www-data -c "git clone --depth 1 -b $SERVER_VERSION https://github.com/nextcloud/files_downloadlimit.git /var/www/html/apps/files_downloadlimit/"
docker exec $CONTAINER_NAME su www-data -c "php /var/www/html/occ app:enable files_downloadlimit"

# Enable Assistant and Testing app
docker exec $CONTAINER_NAME su www-data -c "php /var/www/html/occ app:enable assistant"
docker exec $CONTAINER_NAME su www-data -c "php /var/www/html/occ app:enable testing"

#Testing app generates fake Assitant responses via cronjob. Reduce cronjob downtime so it's quicker.
docker exec $CONTAINER_NAME su www-data -c "set -e; while true; do php /var/www/html/occ background-job:worker -v -t 10 \"OC\TaskProcessing\SynchronousBackgroundJob\"; done"

echo "Server provisioning done."
