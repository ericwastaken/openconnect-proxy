#!/bin/bash

# Figure out if we have 2 fingerprints and prepare the servercert argument
if [ -n "$FINGERPRINT_2" ]; then
  FINGERPRINT_ARG="--servercert $FINGERPRINT --servercert $FINGERPRINT_2"
else
  FINGERPRINT_ARG="--servercert $FINGERPRINT"
fi

# Verify if the env variable PASSWORD is set and if so,
# use it to create a local variable PASS_LOCAL
# Otherwise, check for a file in PASSWORD_PATH and use it to create PASS_LOCAL
if [ -z "$PASSWORD" ]; then
  if [ -n "$PASSWORD_PATH" ]; then
    if [ -f "$PASSWORD_PATH" ]; then
      PASS_LOCAL=$(cat "$PASSWORD_PATH")
    else
      echo "Password file specified in PASSWORD_PATH does not exist"
      exit 1
    fi
  else
    echo "PASSWORD environment variable is not set"
    exit 1
  fi
else
  PASS_LOCAL="$PASSWORD"
fi

echo openconnect --user="$USERNAME" --passwd-on-stdin --script-tun --script \"ocproxy --allow-remote -D ${PROXY_PORT} -k 5\" --protocol=$PROTOCOL $HOST --verbose --authgroup "$AUTHGROUP" $FINGERPRINT_ARG

echo "$PASS_LOCAL" \
  | openconnect \
    --script-tun \
    --user="$USERNAME" \
    --passwd-on-stdin \
    --script "ocproxy --allow-remote -D ${PROXY_PORT} -k 5" \
    --protocol=$PROTOCOL \
    $HOST \
    --verbose \
    --authgroup "$AUTHGROUP" \
    $FINGERPRINT_ARG
