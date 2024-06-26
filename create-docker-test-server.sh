#!/usr/bin/env bash
#This script creates a testable Docker enviroment of the Nextcloud server, and is used by the CI for tests.

CONTAINER_NAME=nextcloud_test
SERVER_PORT=8080
TEST_BRANCH=stable28
SERVER_URL="http://localhost:${SERVER_PORT}"
USER="admin"

docker run --rm -d \
    --name $CONTAINER_NAME \
    -e SERVER_BRANCH=$TEST_BRANCH \
    -p $SERVER_PORT:80 \
    ghcr.io/juliushaertl/nextcloud-dev-php80:latest


source ./wait-for-server.sh
