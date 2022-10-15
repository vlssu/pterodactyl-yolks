#!/bin/bash
cd /home/container

# Make internal Docker IP address available to processes
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Print Dart version
dart --version

# Replace startup variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Run the server
eval ${MODIFIED_STARTUP}
