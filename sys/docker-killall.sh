#!/usr/bin/env bash
sudo systemctl restart docker.socket docker.service
sudo docker image ls -q | xargs -r sudo docker image rm -f
sudo pkill docker-proxy
