#!/bin/bash
# This script builds a Docker image on a remote server

# SSH into the remote server
ssh -o StrictHostKeyChecking=no ubuntu@43.203.229.26 '
    # Navigate to the project directory
    cd /home/ubuntu/waffle/deploy/ci-cd/data/jenkins/data/workspace/dev-backend-core/backend

    # Display message
    echo "Building Docker image..."

    # Build Docker image
    docker build --build-arg -t wypl-web:latest .
'