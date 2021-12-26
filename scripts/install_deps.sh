#!/bin/bash -eE

echo "INFO: install dependencies..."
sudo apt update
sudo apt install -y \
    docker-compose \
    git
echo "INFO: install dependencies... DONE"
