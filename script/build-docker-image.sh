#!/bin/sh
echo "Building Docker image..."
REPOSITORY_NAME= "$1" #"wypl-web-dev"
TAG="latest"
docker build -t "$REPOSITORY_NAME":"$TAG" .

# date tag 
# DATE_TAG=$(date +%y%m%d%H%M)
# docker build -t "$REPOSITORY_NAME":"$DATE_TAG" .