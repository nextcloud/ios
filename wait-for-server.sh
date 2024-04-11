#!/usr/bin/env bash
# Based on the script from Milen Pivchev in nextcloud/ios repository

# This scripts waits until a server transitions to the "installed" state

SERVER_PORT=8080
SERVER_URL="http://localhost:${SERVER_PORT}"

timeout=2000
elapsed=0

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
