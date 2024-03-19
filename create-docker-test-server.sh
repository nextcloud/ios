#!/usr/bin/env bash
#This script creates a testable Docker enviroment of the Nextcloud server, and is used by the CI for tests.

CONTAINER_NAME=nextcloud_test
SERVER_PORT=8080
TEST_BRANCH=master
SERVER_URL="http://localhost:${SERVER_PORT}"
USER="admin"

#docker run --rm -d \
#    --name $CONTAINER_NAME \
#    -e SERVER_BRANCH=$TEST_BRANCH \
#    -p $SERVER_PORT:80 \
#    ghcr.io/juliushaertl/nextcloud-dev-php80:latest
#
#timeout=2000
#elapsed=0

echo "Waiting for server..."

sleep 5

while true; do
    content=$(curl -s $SERVER_URL/status.php || true)

    if [[ $content == *"installed\":true"* ]]; then
        break
    fi

    elapsed=$((elapsed + 1))

    if [ $elapsed -ge $timeout ]; then
        echo "No success after $timeout seconds."
        exit 1
    fi

    sleep 1
done

echo "Server is installed."
echo "Exporting env vars..."

sleep 10

password=$(docker exec -e NC_PASS=$USER $CONTAINER_NAME sudo -E -u www-data php /var/www/html/occ user:add-app-password $USER --password-from-env | tail -1)

export TEST_APP_PASSWORD=$password
export TEST_SERVER_URL=$SERVER_URL
export TEST_USER=$USER

echo "TEST_SERVER_URL: ${TEST_SERVER_URL}"
echo "TEST_USER: ${TEST_USER}"
echo "TEST_APP_PASSWORD: ${TEST_APP_PASSWORD}"
echo "Env vars exported."

if [ ! -f ".env-vars" ]; then
    # If it doesn't exist, create it and add variable exports
    touch .env-vars
    echo ".env-vars file created successfully"
else
    # If it exists, remove it and recreate with new variables
    rm .env-vars
    echo "Existing .env-vars file removed"

    touch .env-vars
    echo ".env-vars file recreated successfully"
fi

echo "export TEST_SERVER_URL=\"$TEST_SERVER_URL\"" >> .env-vars
echo "export TEST_USER=\"$TEST_USER\"" >> .env-vars
echo "export TEST_APP_PASSWORD=\"$TEST_APP_PASSWORD\"" >> .env-vars
