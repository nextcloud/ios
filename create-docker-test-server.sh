#!/usr/bin/env bash
#This script creates a testable Docker enviroment of the Nextcloud server, and is used by the CI for tests.

container_name="nextcloud_test"
port=8080
server_url="http://localhost:${port}"
user="admin"

docker run --rm -d --name $container_name -p $port:80 ghcr.io/juliushaertl/nextcloud-dev-php80:latest

timeout=300
elapsed=0

echo "Waiting for server..."

sleep 2

while true; do
    content=$(curl -s $server_url/status.php)

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

sleep 2

password=$(docker exec -e NC_PASS=$user $container_name sudo -E -u www-data php /var/www/html/occ user:add-app-password $user --password-from-env | tail -1)

export TEST_APP_PASSWORD=$password
export TEST_SERVER_URL=$server_url
export TEST_USER=$user

echo "TEST_SERVER_URL: ${TEST_SERVER_URL}"
echo "TEST_USER: ${TEST_USER}"
echo "TEST_APP_PASSWORD: ${TEST_APP_PASSWORD}"
echo "Env vars exported."
