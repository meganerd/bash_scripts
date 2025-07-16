#!/usr/bin/env bash
# Based on https://github.com/moul/docker-diff

#
# Compare the contents of two Docker images.
#
# Usage:
#   docker-diff [--platform PLATFORM] img1 img2
#

# Default platform
PLATFORM_VALUE="linux/amd64"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      if [ -z "$2" ]; then
        echo "Error: --platform requires a value"
        exit 1
      fi
      PLATFORM_VALUE="$2"
      shift 2
      ;;
    *)
      # Store non-flag arguments
      if [ -z "$IMAGE_A" ]; then
        IMAGE_A="$1"
      elif [ -z "$IMAGE_B" ]; then
        IMAGE_B="$1"
      else
        echo "Error: Too many arguments"
        echo "Usage: $0 [--platform PLATFORM] img1 img2"
        exit 1
      fi
      shift
      ;;
  esac
done

# Check if we have both images
if [ -z "$IMAGE_A" ] || [ -z "$IMAGE_B" ]; then
  echo "Usage: $0 [--platform PLATFORM] img1 img2"
  echo ""
  echo "Options:"
  echo "  --platform PLATFORM    Specify the platform (default: linux/amd64)"
  echo ""
  echo "Example: $0 alpine:3.4 alpine:3.5"
  echo "Example: $0 --platform linux/arm64 alpine:3.4 alpine:3.5"
  exit 99
fi

PLATFORM="--platform $PLATFORM_VALUE"
tmpdir=$(mktemp -d)
CONTAINER_A_ID=$(docker create "$PLATFORM" "$IMAGE_A" /bin/sh)
CONTAINER_B_ID=$(docker create "$PLATFORM" "$IMAGE_B" /bin/sh)

set -e
docker export "${CONTAINER_A_ID}" > "${tmpdir}"/A.tar
docker export "${CONTAINER_B_ID}" > "${tmpdir}"/B.tar
mkdir -p "${tmpdir}/${IMAGE_A}" && tar -xf "${tmpdir}"/A.tar -C "${tmpdir}/${IMAGE_A}" --exclude='./etc/mtab' --exclude='./proc' --exclude='./dev'
mkdir -p "${tmpdir}/${IMAGE_B}" && tar -xf "${tmpdir}"/B.tar -C "${tmpdir}/${IMAGE_B}" --exclude='./etc/mtab' --exclude='./proc' --exclude='./dev'
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
