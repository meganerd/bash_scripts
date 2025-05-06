#!/usr/bin/env bash

# Find all disk devices including NVMe
DEVICES=""
for device in $(lsblk -d -o NAME -n | grep -v loop | grep -v sr| grep -v nbd | grep -v zram); do
  DEVICES="$DEVICES --device=/dev/$device"
done

mkdir -p "$HOME/scrutiny/cfg"
mkdir -p "$HOME/scrutiny/influxdb2"

docker run -it --rm -p 8080:8080 -p 8086:8086 \
  -v "$HOME/scrutiny/cfg":/opt/scrutiny/config \
  -v "$HOME/scrutiny/influxdb2":/opt/scrutiny/influxdb \
  -v /run/udev:/run/udev:ro \
  --cap-add SYS_RAWIO \
  $DEVICES \
  --name scrutiny \
  ghcr.io/analogj/scrutiny:master-omnibus
