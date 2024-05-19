#!/bin/bash

IMAGE_NAME=wypl-web
TAG=latest
DEPLOY_PORT1=58324
DEPLOY_PORT2=58325
DEPLOY_PROFILE1=blue
DEPLOY_PROFILE2=green
SERVER_IP_ADDR="43.203.229.26"
IDLE_PROFILE=""
IDLE_PORT=""
HOST_VOLUME_PATH=/home/ubuntu/wypl-deploy/logs
DOCKER_VOLUME_PATH=/logs

######### Check IDLE PROFILE & PORT ############
CURR_PROFILE=$(curl -s --connect-timeout 10 https://api.wypl.site/profile  | tr -d '\n' | tr -d '\r')

echo "현재 PROFILE > $CURR_PROFILE"

if [[ "$CURR_PROFILE" == *"$DEPLOY_PROFILE1"* ]]; then
    IDLE_PROFILE="$DEPLOY_PROFILE2"
    IDLE_PORT="$DEPLOY_PORT2"
elif [[ "$CURR_PROFILE" == *"$DEPLOY_PROFILE2"* ]]; then
    IDLE_PROFILE="$DEPLOY_PROFILE1"
    IDLE_PORT="$DEPLOY_PORT1"
else
    echo "Debug: No matching Profile found. Profile: $CURR_PROFILE"
    echo "> $DEPLOY_PROFILE1 으로 설정합니다."
    IDLE_PROFILE="$DEPLOY_PROFILE1"
    IDLE_PORT="$DEPLOY_PORT1"
fi
echo "IDLE_PROFILE > $IDLE_PROFILE IDLE_PROT > $IDLE_PORT "

######### Build Docker Image ############
echo "######### Building Docker image ############"
IDLE_APPLICATION_NAME="$IDLE_PROFILE-$IMAGE_NAME"
ACTIVE_APPLICATION_NAME="$CURR_PROFILE-$IMAGE_NAME"

echo "IDLE_APPLICATION_IMAGE_NAME > $IDLE_APPLICATION_NAME"
echo "ACTIVE_APPLICATION_IMAGE_NAME > $ACTIVE_APPLICATION_NAME"
docker build -t "$IDLE_APPLICATION_NAME":"$TAG" .

######### IDLE Deploy ############
echo "######### Deploy ############"
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
docker run -d --name $IDLE_APPLICATION_NAME -e PROFILE=$IDLE_PROFILE -p $IDLE_PORT:8080 -v $HOST_VOLUME_PATH:$DOCKER_VOLUME_PATH $IDLE_APPLICATION_NAME:$TAG

######### HEALTH CHECK ############
echo "######### HEALTH CHECK ############"
echo "> $IDLE_PROFILE 3초 후 Health check 시작"
sleep 3

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
            sleep 3
        else
            echo "Failed: Server Is Down..."
            exit 1
        fi
    fi
done

######### NGINX RELOAD ############
echo "######### NGINX RELOAD ############"
echo "> 전환할 Port: $IDLE_PORT"
echo "set \$deploy_service_url http://${SERVER_IP_ADDR}:${IDLE_PORT};" |sudo tee /etc/nginx/sites-available/deploy-service-url.inc
sudo service nginx reload
sleep 3
PROXY_PROFILE=$(curl -s --connect-timeout 10 https://api.wypl.site/profile)
echo "> Nginx Current Proxy Profile: $PROXY_PROFILE"


######### NGINX RELOAD ############
# 최종 수정일 : 24-05-15
