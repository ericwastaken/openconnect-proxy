#!/bin/bash

# Load environment variables from build-manifest.env
source build-manifest.env

# Check that the user is logged into docker
if ! docker info > /dev/null 2>&1; then
  echo "You need to be logged into Docker to run this script!"
  exit 1
fi

# Confirm that we want to tag and push current
echo "Tagging and pushing current image to $NAME:$CURR_TAG"
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

echo "tagging $NAME:$CURR_TAG to $NAME:latest"
docker tag $NAME:$CURR_TAG $NAME:latest
echo "pushing $NAME:$CURR_TAG"
docker push $NAME:$CURR_TAG