#!/bin/bash

# Load environment variables from build-manifest.env
source build-manifest.env

if [ -z "$BUILDER_NAME" ] || [ -z "$NAME" ] || [ -z "$CURR_TAG" ] || [ -z "$SAML_TAG_SUFFIX" ]; then
  echo "BUILDER_NAME, NAME, CURR_TAG and SAML_TAG_SUFFIX must be set in build-manifest.env"
  exit 1
fi

PLAIN_TAG="$NAME:$CURR_TAG"
SAML_TAG="$NAME:$CURR_TAG$SAML_TAG_SUFFIX"
PLAIN_LATEST_TAG="$NAME:latest"
SAML_LATEST_TAG="$NAME:latest$SAML_TAG_SUFFIX"

# Check that the user is logged into docker
if ! docker info > /dev/null 2>&1; then
  echo "You need to be logged into Docker to run this script!"
  exit 1
fi

# Confirm that we want to tag and push current
echo "This can tag and push:"
echo " - Plain: $PLAIN_TAG and $PLAIN_LATEST_TAG"
echo " - SAML:  $SAML_TAG and $SAML_LATEST_TAG"
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

echo "Which image variant do you want to push?"
echo "1. Plain image only"
echo "2. SAML image only"
echo "3. Both"
read -p "Enter your choice: " variant_choice
case $variant_choice in
  1)
    PUSH_PLAIN=true
    PUSH_SAML=false
    ;;
  2)
    PUSH_PLAIN=false
    PUSH_SAML=true
    ;;
  3)
    PUSH_PLAIN=true
    PUSH_SAML=true
    ;;
  *)
    echo "Invalid choice!"
    exit 1
    ;;
esac

# ask if we want to push multi-platform or current platform only
echo "Do you want to push the image for multi platform or current platform only?"
echo "1. Multi platform (Requires docker buildx support qith qemu - built into macOS Docker Desktop)"
echo "2. Current platform only"
read -p "Enter your choice: " choice
case $choice in
  1)
    echo "Tagging & Pushing the image for multi platform"
    if [ "$PUSH_PLAIN" = true ]; then
      docker buildx build --platform linux/amd64,linux/arm64 --target plain -t "$PLAIN_TAG" -t "$PLAIN_LATEST_TAG" --push .
    fi
    if [ "$PUSH_SAML" = true ]; then
      docker buildx build --platform linux/amd64,linux/arm64 --target saml -t "$SAML_TAG" -t "$SAML_LATEST_TAG" --push .
    fi
    ;;
  2)
    echo "Tagging & Pushing the image for current platform only"
    if [ "$PUSH_PLAIN" = true ]; then
      docker build --target plain -t "$PLAIN_TAG" .
      docker tag "$PLAIN_TAG" "$PLAIN_LATEST_TAG"
      docker push "$PLAIN_TAG"
      docker push "$PLAIN_LATEST_TAG"
    fi
    if [ "$PUSH_SAML" = true ]; then
      docker build --target saml -t "$SAML_TAG" .
      docker tag "$SAML_TAG" "$SAML_LATEST_TAG"
      docker push "$SAML_TAG"
      docker push "$SAML_LATEST_TAG"
    fi
    ;;
  *)
    echo "Invalid choice!"
    exit 1
    ;;
esac
