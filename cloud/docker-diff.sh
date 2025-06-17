#!/usr/bin/env bash
# Based on https://github.com/moul/docker-diff

#
# Compare the contents of two Docker images.
#
# Usage:
#   docker-diff alpine:3.4 alpine:3.5
#

if [ -z "$2" ]
then
  echo "Usage: $0 img1 img2"
  echo ""
  echo "Example: $0 alpine:3.4 alpine:3.5"
  exit 99
fi

PLATFORM="--platform linux/amd64"
tmpdir=$(mktemp -d)
IMAGE_A=$1
IMAGE_B=$2
CONTAINER_A_ID=$(docker create $PLATFORM $IMAGE_A /bin/sh)
CONTAINER_B_ID=$(docker create $PLATFORM $IMAGE_B /bin/sh)

set -e
docker export "${CONTAINER_A_ID}" > ${tmpdir}/A.tar
docker export "${CONTAINER_B_ID}" > ${tmpdir}/B.tar
mkdir -p ${tmpdir}/${IMAGE_A} && tar -xf ${tmpdir}/A.tar -C ${tmpdir}/${IMAGE_A} --exclude='./etc/mtab' --exclude='./proc' --exclude='./dev'
mkdir -p ${tmpdir}/${IMAGE_B} && tar -xf ${tmpdir}/B.tar -C ${tmpdir}/${IMAGE_B} --exclude='./etc/mtab' --exclude='./proc' --exclude='./dev'
(
    cd ${tmpdir}
    diff --unified -arq ${IMAGE_A} ${IMAGE_B} 2>&1 | grep -v "No such file or directory" | grep -v "is a character special file" | grep -v "is a block special file" | tee ${tmpdir}/diff
)
cat ${tmpdir}/diff | wc -l > ${tmpdir}/difflinecount
set +e

code=1
if [ "$(echo `cat ${tmpdir}/difflinecount`)" = "0" ]; then
  code=0
fi

rm -rf ${tmpdir}
docker rm -fv "${CONTAINER_A_ID}" "${CONTAINER_B_ID}" > /dev/null

exit $code
