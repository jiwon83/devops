#!/bin/sh

# Variable
PROFILE="$1" #"dev"
PORT="$2"
NAME="$3" #"wypl-web-dev"
TAG="latest"

# Build Docker Image
echo "Building Docker image..."
docker build -t "$NAME":"$TAG" .

# date tag 
# DATE_TAG=$(date +%y%m%d%H%M)

# Deploy
if [ $(docker ps -aq -f name=$NAME) ]; then
    echo 'Stopping and removing Docker container...'
    docker stop $NAME
    docker rm $NAME
fi
echo "Depoly Spring Boot!!"
docker run -d --name $NAME -e PROFILE=$PROFILE -p $PORT:8080 $NAME:$TAG