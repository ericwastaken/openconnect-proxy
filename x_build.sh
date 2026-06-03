#!/bin/bash

# Load environment variables from build-manifest.env
source build-manifest.env

# Ask if this is a production build or a local test build
echo "What type of build do you want to perform?"
echo "1. Production Build (using build-manifest.env)"
echo "2. Local Test Build (tags: openconnect-proxy:plain-test, openconnect-proxy:saml-test)"
read -p "Enter your choice: " build_mode_choice

if [ "$build_mode_choice" == "2" ]; then
  echo "Setting up Local Test Build..."
  PLAIN_TAG="openconnect-proxy:plain-test"
  SAML_TAG="openconnect-proxy:saml-test"
  
  echo "Building both variants for current platform only..."
  docker build --target plain -t "$PLAIN_TAG" .
  docker build --target saml -t "$SAML_TAG" .
  
  echo "Local Test Build complete."
  exit 0
fi

# verify that we have the necessary environment variables
if [ -z "$BUILDER_NAME" ] || [ -z "$NAME" ] || [ -z "$CURR_TAG" ] || [ -z "$SAML_TAG_SUFFIX" ]; then
  echo "BUILDER_NAME, NAME, CURR_TAG and SAML_TAG_SUFFIX must be set in build-manifest.env"
  exit 1
fi

PLAIN_TAG="$NAME:$CURR_TAG"
SAML_TAG="$NAME:$CURR_TAG$SAML_TAG_SUFFIX"

echo "Build manifest version:"
echo "  CURR_TAG=$CURR_TAG"
echo "  Plain image: $PLAIN_TAG"
echo "  SAML image:  $SAML_TAG"
read -p "Is this the version you want to build? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Build cancelled. Update build-manifest.env and run again."
  exit 1
fi

echo "Which image variant do you want to build?"
echo "1. Plain image only ($PLAIN_TAG)"
echo "2. SAML image only ($SAML_TAG)"
echo "3. Both"
read -p "Enter your choice: " variant_choice
case $variant_choice in
  1)
    BUILD_PLAIN=true
    BUILD_SAML=false
    ;;
  2)
    BUILD_PLAIN=false
    BUILD_SAML=true
    ;;
  3)
    BUILD_PLAIN=true
    BUILD_SAML=true
    ;;
  *)
    echo "Invalid choice!"
    exit 1
    ;;
esac

# ask if we want to build the image for multi platform or current platform only
echo "Do you want to build the image for multi platform or current platform only?"
echo "1. Multi platform (Requires docker buildx support qith qemu - built into macOS Docker Desktop)"
echo "2. Current platform only"
read -p "Enter your choice: " choice
case $choice in
  1)
    echo "Building the image for multi platform"
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
    if [ "$BUILD_PLAIN" = true ]; then
      docker buildx build --platform linux/amd64,linux/arm64 --target plain -t "$PLAIN_TAG" .
    fi
    if [ "$BUILD_SAML" = true ]; then
      docker buildx build --platform linux/amd64,linux/arm64 --target saml -t "$SAML_TAG" .
    fi
    ;;
  2)
    echo "Building the image for current platform only"
    if [ "$BUILD_PLAIN" = true ]; then
      docker build --target plain -t "$PLAIN_TAG" .
    fi
    if [ "$BUILD_SAML" = true ]; then
      docker build --target saml -t "$SAML_TAG" .
    fi
    ;;
  *)
    echo "Invalid choice!"
    exit 1
    ;;
esac



