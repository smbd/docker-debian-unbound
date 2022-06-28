#!/bin/bash

DEBIAN_REL="bullseye"
OPENSSL_VER="3.0.3"

while getopts lo:p OPT ; do
  case ${OPT} in
    "l") LATEST="true" ;;
    "o") OPENSSL_VER="${OPTARG}" ;;
    "p") PUSH="true" ;;
  esac
done

shift $((${OPTIND}-1))

if [ "$1" == "" ] ; then
  echo "Usage: ${0} [-l] [-o OPENSSL_VERSION] [-p] UNBOUND_VERSION"
  echo "    -l: update latest tag"
  echo "    -o OPENSSL_VERSION: set openssl version"
  echo "    -p: push to dockerhub"
  exit 1
fi

UNBOUND_VER="$1"

if [ "${PUSH}" == "true" ] ; then
  docker buildx build --push --platform linux/amd64,linux/arm64 -t smbd/unbound:${UNBOUND_VER} --build-arg DEBIAN_REL=${DEBIAN_REL} --build-arg OPENSSL_VER=${OPENSSL_VER} --build-arg UNBOUND_VER=${UNBOUND_VER} .

  if [ "${LATEST}" == "true" ] ; then
    docker buildx build --push --platform linux/amd64,linux/arm64 -t smbd/unbound:latest --build-arg DEBIAN_REL=${DEBIAN_REL} --build-arg OPENSSL_VER=${OPENSSL_VER} --build-arg UNBOUND_VER=${UNBOUND_VER} .
  fi
else
  docker buildx build --progress=plain --load -t smbd/unbound:${UNBOUND_VER} --build-arg DEBIAN_REL=${DEBIAN_REL} --build-arg OPENSSL_VER=${OPENSSL_VER} --build-arg UNBOUND_VER=${UNBOUND_VER} .

  if [ "${LATEST}" == "true" ] ; then
    docker buildx build --progress=plain --load -t smbd/unbound:latest --build-arg DEBIAN_REL=${DEBIAN_REL} --build-arg OPENSSL_VER=${OPENSSL_VER} --build-arg UNBOUND_VER=${UNBOUND_VER} .
  fi
fi
