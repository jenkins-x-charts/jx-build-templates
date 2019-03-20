#!/bin/bash

set -euo pipefail

JENKINS_TAG=$(yq r jx-build-templates/values.yaml jenkinsTag)
BUILDERS_TAG=$(yq r jx-build-templates/values.yaml builderTag)
IMAGES=$(cat jx-build-templates/templates/*.yaml | grep image | grep -v allure | sed 's/- image: //' | sed 's/image: //' | sed "s/{{ .Values.jenkinsTag }}/$JENKINS_TAG/" | sed "s/{{ .Values.builderTag }}/$BUILDERS_TAG/" )

function get_digest() {
  local image=$1
  local tag=$2
  local registry=$3

  curl \
    --silent \
    --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "https://$registry/v2/$image/manifests/$tag" |
    jq -r '.config.digest'
}

function get_image_configuration() {
  local image=$1
  local digest=$2
  local registry=$3

  CONTAINER_CONFIG=$(curl --silent --location "https://$registry/v2/$image/blobs/$digest" | jq -r '.container_config')
  if [[ $CONTAINER_CONFIG == "null" ]]; then
    echo "Unable to find image"
	exit 1
  fi
}

for IMAGE in $IMAGES; do
	echo $IMAGE
	WITHOUT_REG=${IMAGE#*/}
	NAME=${WITHOUT_REG%:*}
	VERSION=${IMAGE##*:}
	REGISTRY=${IMAGE%%/*}
	if [[ "$REGISTRY" == "jenkinsxio" ]]; then
		REGISTRY="docker.io"
	fi
    
    digest=$(get_digest $NAME $VERSION $REGISTRY)

    get_image_configuration $NAME $digest $REGISTRY
done

