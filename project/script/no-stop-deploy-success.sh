#!/bin/bash

IMAGE_NAME=wypl-web
TAG=latest
DEPLOY_PORT1=58324
DEPLOY_PORT2=58325
DEPLOY_PROFILE1=prod1
DEPLOY_PROFILE2=prod2

######### Check IDLE PROFILE & PORT ############
CURR_PROFILE=$(curl -s --connect-timeout 10 https://api.wypl.site/profile  | tr -d '\n' | tr -d '\r')

echo "profile > $CURR_PROFILE"
#[ "$CURR_PROFILE" == *"$DEPLOY_PROFILE1"* ]

if [[ "$CURR_PROFILE" == *"prod1"* ]]; then
    echo "Debug: Current profile is DEPLOY_PROFILE1"
    IDLE_PROFILE="$DEPLOY_PROFILE2"
    IDLE_PORT="$DEPLOY_PORT2"
elif [ "$CURR_PROFILE" == "$DEPLOY_PROFILE2" ]; then
    echo "Debug: Current profile is DEPLOY_PROFILE2"
    IDLE_PROFILE="$DEPLOY_PROFILE1"
    IDLE_PORT="$DEPLOY_PORT1"
else
    echo "Debug: No matching Profile found. Profile: $CURR_PROFILE"
    echo "> Assigning $DEPLOY_PROFILE1."
    IDLE_PROFILE="$DEPLOY_PROFILE1"
    IDLE_PORT="$DEPLOY_PORT1"
fi
echo "IDLE_PROFILE > $IDLE_PROFILE IDLE_PROT > $IDLE_PORT "

######### Build Docker Image ############
echo "Building Docker image..."s
IDLE_APPLICATION_NAME="$IDLE_PROFILE-$IMAGE_NAME"
ACTIVE_APPLICATION_NAME="$CURR_PROFILE-$IMAGE_NAME"

echo "IDLE_APPLICATION_IMAGE_NAME > $IDLE_APPLICATION_NAME"
echo "ACTIVE_APPLICATION_IMAGE_NAME > $ACTIVE_APPLICATION_NAME"
docker build -t "$IDLE_APPLICATION_NAME":"$TAG" .

######### IDLE Deploy ############
echo "> $IDLE_PROFILE 배포"

CONTAINER_IDS=$(docker ps -aqf "name=$IDLE_APPLICATION_NAME")
echo "Find CONTAINER_IDS ...  >>  $CONTAINER_IDS"

if [ -n "$CONTAINER_IDS" ]; then
    echo 'Stopping and removing Docker container...'
    for container_id in "$CONTAINER_IDS"; do
        docker stop $container_id
        docker rm $container_id
    done
fi
docker run -d --name $IDLE_APPLICATION_NAME -e PROFILE=$IDLE_PROFILE -p $IDLE_PORT:8080 $IDLE_APPLICATION_NAME:$TAG

######### HEALTH CHECK ############

echo "> $IDLE_PROFILE 10초 후 Health check 시작"
echo "> curl -s http://api.wypl.site/actuator/health"
sleep 10

URL="https://api.wypl.site/actuator/health"
MAX_TRIES=10
tries=0

while [ $tries -lt $MAX_TRIES ]; do
    response=$(curl -s $URL)
    if echo "$response" | grep -q "UP"; then
        echo "Success: Server is UP!"
        break
    else
        echo "Waiting Server..."
        tries=$((tries+1))
        if [ $tries -lt $MAX_TRIES ]; then
            echo "Retrying in 10 seconds..."
            sleep 10
        else
            echo "Failed: Server Is Down..."
            exit 1
        fi
    fi
done

######### NGINX RELOAD ############
echo "> 전환할 Port: $IDLE_PORT"
echo "> Port 전환"
echo "set \$deploy_service_url http://43.203.229.26:${IDLE_PORT};" |sudo tee /etc/nginx/sites-available/deploy-service-url.inc

PROXY_PROFILE=$(curl -s http://api.wypl.site/profile)
echo "> Nginx Current Proxy Profile: $PROXY_PROFILE"

echo "> Nginx Reload"

sudo service nginx reload

