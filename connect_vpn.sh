#!/bin/bash

# Figure out if we have 2 fingerprints and prepare the servercert argument
if [ -n "$FINGERPRINT_2" ]; then
  FINGERPRINT_ARG="--servercert $FINGERPRINT --servercert $FINGERPRINT_2"
else
  FINGERPRINT_ARG="--servercert $FINGERPRINT"
fi

echo openconnect --user="$USERNAME" --passwd-on-stdin --script-tun --script \"ocproxy --allow-remote -D ${PROXY_PORT} -k 5\" --protocol=$PROTOCOL $HOST --verbose --authgroup "$AUTHGROUP" $FINGERPRINT_ARG

echo "$PASSWORD" \
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
