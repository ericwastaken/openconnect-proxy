#!/bin/bash

set -e

SAML_AUTH_PORT="${SAML_AUTH_PORT:-8080}"
SAML_VNC_PORT="${SAML_VNC_PORT:-5900}"
SAML_DISPLAY="${SAML_DISPLAY:-:99}"
SAML_CLIENTOS="${SAML_CLIENTOS:-Windows}"
SAML_MODE="$(printf '%s' "${SAML_MODE:-portal}" | tr '[:upper:]' '[:lower:]')"
SAML_NO_VERIFY="$(printf '%s' "${SAML_NO_VERIFY:-true}" | tr '[:upper:]' '[:lower:]')"
SAML_AUTH_ONLY="$(printf '%s' "${SAML_AUTH_ONLY:-false}" | tr '[:upper:]' '[:lower:]')"
SAML_COOKIES_FILE="${SAML_COOKIES_FILE:-/tmp/gp-saml-gui-cookies.txt}"
SAML_OUTPUT_FILE="${SAML_OUTPUT_FILE:-/tmp/gp-saml-gui-output.env}"
ORIGINAL_HOST="$HOST"
SAML_HOST="${HOST#https://}"
SAML_HOST="${SAML_HOST#http://}"
SAML_HOST="${SAML_HOST%/}"

if [ "$PROTOCOL" != "gp" ]; then
  echo "AUTH_MODE=saml is only supported with PROTOCOL=gp"
  exit 1
fi

if [ -n "$FINGERPRINT_2" ]; then
  FINGERPRINT_ARG="--servercert $FINGERPRINT --servercert $FINGERPRINT_2"
else
  FINGERPRINT_ARG="--servercert $FINGERPRINT"
fi

if [ "$SAML_MODE" = "gateway" ]; then
  SAML_MODE_ARG="--gateway"
else
  SAML_MODE_ARG="--portal"
fi

if [ "$SAML_NO_VERIFY" = "true" ] || [ "$SAML_NO_VERIFY" = "1" ] || [ "$SAML_NO_VERIFY" = "yes" ]; then
  SAML_VERIFY_ARG="--no-verify"
else
  SAML_VERIFY_ARG=""
fi

cleanup() {
  if [ -n "$NOVNC_PID" ]; then kill "$NOVNC_PID" 2>/dev/null || true; fi
  if [ -n "$X11VNC_PID" ]; then kill "$X11VNC_PID" 2>/dev/null || true; fi
  if [ -n "$FLUXBOX_PID" ]; then kill "$FLUXBOX_PID" 2>/dev/null || true; fi
  if [ -n "$XVFB_PID" ]; then kill "$XVFB_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT

export DISPLAY="$SAML_DISPLAY"

echo "Starting SAML browser session on http://localhost:${SAML_AUTH_PORT}/vnc.html"
echo "Open that URL in your workstation browser and complete the GlobalProtect SAML login."
echo "Using GlobalProtect SAML portal ${SAML_HOST}"

Xvfb "$SAML_DISPLAY" -screen 0 1280x900x24 &
XVFB_PID=$!
sleep 1

fluxbox >/tmp/fluxbox.log 2>&1 &
FLUXBOX_PID=$!

x11vnc -display "$SAML_DISPLAY" -rfbport "$SAML_VNC_PORT" -forever -shared -nopw >/tmp/x11vnc.log 2>&1 &
X11VNC_PID=$!

/usr/share/novnc/utils/novnc_proxy --listen "$SAML_AUTH_PORT" --vnc "localhost:${SAML_VNC_PORT}" >/tmp/novnc.log 2>&1 &
NOVNC_PID=$!

echo "Waiting for SAML login to complete..."

gp-saml-gui \
  "$SAML_MODE_ARG" \
  $SAML_VERIFY_ARG \
  --clientos "$SAML_CLIENTOS" \
  --cookies "$SAML_COOKIES_FILE" \
  "$SAML_HOST" \
  -- \
  --user="$USERNAME" \
  $FINGERPRINT_ARG \
  > "$SAML_OUTPUT_FILE"

echo "SAML login complete; starting OpenConnect and ocproxy."

set -a
# shellcheck disable=SC1090
. "$SAML_OUTPUT_FILE"
set +a

OPENCONNECT_USER="${USER:-$USERNAME}"
OPENCONNECT_HOST="${HOST:-$ORIGINAL_HOST}"
OPENCONNECT_OS="${OS:-$SAML_CLIENTOS}"

if [ -z "$COOKIE" ]; then
  echo "gp-saml-gui did not return COOKIE"
  exit 1
fi

if [ "$SAML_AUTH_ONLY" = "true" ] || [ "$SAML_AUTH_ONLY" = "1" ] || [ "$SAML_AUTH_ONLY" = "yes" ]; then
  echo "SAML_AUTH_ONLY=true; skipping OpenConnect startup."
  echo "SAML result:"
  echo "  HOST=$OPENCONNECT_HOST"
  echo "  USER=$OPENCONNECT_USER"
  echo "  OS=$OPENCONNECT_OS"
  echo "  COOKIE=present"
  exit 0
fi

echo openconnect --user="$OPENCONNECT_USER" --passwd-on-stdin --script-tun --script \"ocproxy --allow-remote -D ${PROXY_PORT} -k 5\" --protocol=gp --os="$OPENCONNECT_OS" "$OPENCONNECT_HOST" --verbose $FINGERPRINT_ARG

echo "$COOKIE" \
  | openconnect \
    --script-tun \
    --user="$OPENCONNECT_USER" \
    --passwd-on-stdin \
    --script "ocproxy --allow-remote -D ${PROXY_PORT} -k 5" \
    --protocol=gp \
    --os="$OPENCONNECT_OS" \
    "$OPENCONNECT_HOST" \
    --verbose \
    $FINGERPRINT_ARG
