x#!/bin/bash

# Load environment variables from build-manifest.env
source build-manifest.env

# ask if we want to build the image for multi platform or current platform only
echo "Do you want to build the image for multi platform or current platform only?"
echo "1. Multi platform (Requires docker buildx support qith qemu - built into macOS Docker Desktop)"
echo "2. Current platform only"
read -p "Enter your choice: " choice
case $choice in
  1)
    echo "Building the image for multi platform"
    BUILDER_NAME="ericbuilder"
    # Check if the builder exists
    if docker buildx inspect "$BUILDER_NAME" > /dev/null 2>&1; then
      echo "Builder $BUILDER_NAME already exists. Reusing it."
      docker buildx use "$BUILDER_NAME"
      docker buildx inspect --bootstrap
    else
      # Create a new builder instance
      echo "Builder $BUILDER_NAME does not exist. Creating a new one."
      docker buildx create --name "$BUILDER_NAME" --use
      docker buildx inspect --bootstrap
    fi
    docker buildx build --platform linux/amd64,linux/arm64  -t $NAME:$CURR_TAG-amd64 .
#    docker buildx build --platform linux/arm64 -t $NAME:$CURR_TAG-arm64 .
    ;;
  2)
    echo "Building the image for current platform only"
    docker build -t $NAME:$CURR_TAG .
    ;;
  *)
    echo "Invalid choice!"
    exit 1
    ;;
esac





