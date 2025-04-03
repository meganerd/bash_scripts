#!/usr/bin/env bash
sudo systemctl restart docker.socket docker.service
sudo docker image rm -f $(sudo docker image ls -q)
sudo pkill docker-proxy
