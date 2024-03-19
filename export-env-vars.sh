#!/usr/bin/env bash

sleep 2

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
