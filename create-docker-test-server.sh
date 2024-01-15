#!/usr/bin/env bash
#This script creates a testable Docker enviroment of the Nextcloud server, and is used by the CI for tests.

container_name="nextcloud_test"
port=8082
server_url="http://localhost:${port}"
user="admin"

docker run --rm -d --name $container_name -p $port:80 ghcr.io/juliushaertl/nextcloud-dev-php80:latest

timeout=2000
elapsed=0

echo "Waiting for server..."

sleep 10

while true; do
    content=$(curl -s $server_url/status.php)

# wait until server returns status as installed:true, then continue
    if [[ $content == *"installed\":true"* ]]; then
        break
    fi

    elapsed=$((elapsed + 1))

    if [ $elapsed -ge $timeout ]; then
        echo "No success after $timeout seconds."
        exit 1
    fi

    sleep 1

    echo "Waiting for server..."

done

echo "Server is installed."
echo "Exporting env vars..."

sleep 10

password=$(docker exec -e NC_PASS=$user $container_name sudo -E -u www-data php /var/www/html/occ user:add-app-password $user --password-from-env | tail -1)

export TEST_APP_PASSWORD=$password
export TEST_SERVER_URL=$server_url
export TEST_USER=$user

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
