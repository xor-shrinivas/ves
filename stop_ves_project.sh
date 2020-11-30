#!/bin/bash
echo "Stoping all containers"
sudo docker stop $(docker ps -aq)
