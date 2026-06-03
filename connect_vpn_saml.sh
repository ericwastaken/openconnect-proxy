#!/bin/bash

set -e

SAML_AUTH_PORT="${SAML_AUTH_PORT:-8080}"
SAML_VNC_PORT="${SAML_VNC_PORT:-5900}"
SAML_DISPLAY="${SAML_DISPLAY:-:99}"
SAML_CLIENTOS="${SAML_CLIENTOS:-Windows}"
SAML_USER_AGENT="${SAML_USER_AGENT:-}"
SAML_USER_AGENT_OVERRIDE=""
if [ -n "$SAML_USER_AGENT" ] && printenv | grep -q "^SAML_USER_AGENT="; then
    SAML_USER_AGENT_OVERRIDE="true"
fi
# Function to load password
load_password() {
  if [ -z "$PASSWORD" ]; then
    if [ -n "$PASSWORD_PATH" ] && [ -f "$PASSWORD_PATH" ]; then
      PASSWORD=$(cat "$PASSWORD_PATH")
    fi
  fi
}
load_password

# Default User-Agents to satisfy Duo/Okta OS checks
DEFAULT_LINUX_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
DEFAULT_WINDOWS_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

# Function to map SAML_CLIENTOS to openconnect --os format
update_os_flags() {
    # Allowed by some servers: linux, linux-64, win, mac-intel, android, apple-ios
    case "$(printf '%s' "$SAML_CLIENTOS" | tr '[:upper:]' '[:lower:]')" in
        windows|win) OPENCONNECT_OS_FLAG="win" ;;
        linux)       OPENCONNECT_OS_FLAG="linux" ;;
        mac|macos|mac-intel) OPENCONNECT_OS_FLAG="mac-intel" ;;
        *)           OPENCONNECT_OS_FLAG="win" ;; # Default to win for best compatibility if unknown
    esac

    # Also update SAML_USER_AGENT if it wasn't explicitly provided in the environment
    if [ -z "$SAML_USER_AGENT_OVERRIDE" ]; then
        case "$(printf '%s' "$SAML_CLIENTOS" | tr '[:upper:]' '[:lower:]')" in
            linux)   SAML_USER_AGENT="$DEFAULT_LINUX_UA" ;;
            windows) SAML_USER_AGENT="$DEFAULT_WINDOWS_UA" ;;
            *)       SAML_USER_AGENT="PAN GlobalProtect" ;;
        esac
    fi
}
update_os_flags
echo "SAML_USER_AGENT: $SAML_USER_AGENT"
SAML_MODE="$(printf '%s' "${SAML_MODE:-portal}" | tr '[:upper:]' '[:lower:]')"
SAML_MODE_OVERRIDE=""
# SAML_MODE defaults to 'portal' in docker-compose.yml.
# We only treat it as an override if it's NOT 'portal'.
if [ -n "$SAML_MODE" ] && [ "$SAML_MODE" != "portal" ] && printenv | grep -q "^SAML_MODE="; then SAML_MODE_OVERRIDE="true"; fi

SAML_NO_VERIFY="$(printf '%s' "${SAML_NO_VERIFY:-true}" | tr '[:upper:]' '[:lower:]')"
SAML_AUTH_ONLY="$(printf '%s' "${SAML_AUTH_ONLY:-false}" | tr '[:upper:]' '[:lower:]')"
SAML_COOKIES_FILE="${SAML_COOKIES_FILE:-/tmp/gp-saml-gui-cookies.txt}"
SAML_OUTPUT_FILE="${SAML_OUTPUT_FILE:-/tmp/gp-saml-gui-output.env}"
ORIGINAL_HOST="$HOST"
SAML_HOST="${HOST#https://}"
SAML_HOST="${SAML_HOST#http://}"
SAML_HOST="${SAML_HOST%/}"
SAML_HOST_OVERRIDE=""
# HOST is always set in docker-compose, so we can't easily tell if it's a specific SAML_HOST override
# unless SAML_HOST was explicitly provided and differs from normalized HOST.
# But we can check if SAML_HOST is explicitly in the environment and non-empty.
# To be safe, we allow discovery if SAML_HOST matches the normalized primary HOST.
if [ -n "$SAML_HOST" ] && printenv | grep -q "^SAML_HOST="; then
    # If SAML_HOST is set but matches the main HOST, we still allow discovery.
    # We only block if it's different (suggesting a manual override).
    normalized_host="${HOST#https://}"
    normalized_host="${normalized_host#http://}"
    normalized_host="${normalized_host%/}"
    if [ "$SAML_HOST" != "$normalized_host" ]; then
        SAML_HOST_OVERRIDE="true"
    fi
fi

echo "SAML_MODE: $SAML_MODE (override: ${SAML_MODE_OVERRIDE:-false})"
echo "SAML_HOST: $SAML_HOST (override: ${SAML_HOST_OVERRIDE:-false})"

if [ "$PROTOCOL" != "gp" ]; then
  echo "AUTH_MODE=saml is only supported with PROTOCOL=gp"
  exit 1
fi

if [ -n "$FINGERPRINT_2" ]; then
  FINGERPRINT_ARG="--servercert $FINGERPRINT --servercert $FINGERPRINT_2"
else
  FINGERPRINT_ARG="--servercert $FINGERPRINT"
fi

# Function to check if a host/URL requires SAML
check_saml_required() {
  local target_host="$1"
  local target_mode="$2"
  local target_path
  
  if [ "$target_mode" = "gateway" ]; then
    target_path="/ssl-vpn/prelogin.esp"
  else
    target_path="/global-protect/prelogin.esp"
  fi

  echo "Checking if $target_host ($target_mode) requires SAML..."
  
  # Prepare curl flags for certificates
  local curl_args="-s -L --max-time 10"
  if [ "$SAML_NO_VERIFY" = "true" ] || [ "$SAML_NO_VERIFY" = "1" ] || [ "$SAML_NO_VERIFY" = "yes" ]; then
    curl_args="$curl_args -k"
  fi
  
  # Note: curl doesn't directly support --servercert pinning in the same way openconnect does
  # but for the purpose of checking for SAML tags, -k or standard CA verification is usually enough
  # during this discovery phase.
  
  # Use POST as some servers only return SAML tags for POST requests
  # and include a standard User-Agent.
  local url="https://${target_host}${target_path}?tmp=tmp&clientVer=4100&clientos=${SAML_CLIENTOS}"
  echo "Probing $url via POST..."
  
  local response
  local curl_log="/tmp/curl_probe.log"
  response=$(curl $curl_args -v -X POST -d "" -H "User-Agent: PAN GlobalProtect" "$url" 2>"$curl_log")
  local curl_exit=$?
  
  if [ $curl_exit -ne 0 ]; then
    echo "  curl failed with exit code $curl_exit"
    cat "$curl_log" | sed 's/^/    /'
  fi

  if echo "$response" | grep -Eq "<saml-auth-method>|<saml-request>|saml-auth-method"; then
    echo "  SAML requirement detected."
    return 0
  fi

  # Fallback to Linux clientos if the initial probe (usually Windows) failed
  if [ "$SAML_CLIENTOS" != "Linux" ]; then
    echo "  No SAML tags found with clientos=${SAML_CLIENTOS}. Retrying with clientos=Linux..."
    url="https://${target_host}${target_path}?tmp=tmp&clientVer=4100&clientos=Linux"
    response=$(curl $curl_args -v -X POST -d "" -H "User-Agent: PAN GlobalProtect" "$url" 2>>"$curl_log")
    if echo "$response" | grep -Eq "<saml-auth-method>|<saml-request>|saml-auth-method"; then
      echo "  SAML requirement detected (with Linux fallback)."
      # Set a flag to indicate that we should use Linux for the SAML flow
      SAML_PROBE_CLIENTOS="Linux"
      return 0
    fi
  fi

  echo "  No SAML tags found in response."
  echo "  Full response (first 500 chars): $(echo "$response" | head -c 500)"
  return 1
}

# Smart Discovery Logic
if [ -z "$SAML_HOST_OVERRIDE" ] && [ -z "$SAML_MODE_OVERRIDE" ]; then
  # Try portal first (default)
  if check_saml_required "$SAML_HOST" "portal"; then
     if [ -n "$SAML_PROBE_CLIENTOS" ]; then
        echo "  Updating SAML_CLIENTOS to $SAML_PROBE_CLIENTOS based on successful probe."
        SAML_CLIENTOS="$SAML_PROBE_CLIENTOS"
        update_os_flags
     fi
  else
    echo "Portal $SAML_HOST did not return SAML tags. Attempting to discover Gateway..."
    
    # Use openconnect --authenticate to get the config which contains the gateway list
    echo "Querying Portal for configuration XML via openconnect..."
    config_xml=$(echo "$PASSWORD" | openconnect --authenticate --protocol=gp --os="$OPENCONNECT_OS_FLAG" --user="$USERNAME" "$ORIGINAL_HOST" $FINGERPRINT_ARG 2>/tmp/oc_err || true)
    if [ ! -s "/tmp/oc_err" ] || grep -q "XML" <<< "$config_xml"; then
        echo "  GetConfig response length: ${#config_xml}"
    else
        echo "  openconnect failed:"
        cat /tmp/oc_err | sed 's/^/    /'
    fi
    
    if [ -n "$AUTHGROUP" ] && [ ${#config_xml} -gt 20 ]; then
       if echo "$config_xml" | grep -iq "<gateway"; then
         # Attempt to find the gateway host for the specified AUTHGROUP from XML
         config_clean=$(echo "$config_xml" | tr -d '\n\r')
         discovered_host=$(echo "$config_clean" | sed -n "s/.*<gateway[^>]*>.*<name>$AUTHGROUP<\/name>.*<host>\([^<]*\)<\/host>.*/\1/p")
         if [ -z "$discovered_host" ]; then
            # If exact match failed, try case-insensitive match for the name
            discovered_host=$(echo "$config_clean" | sed -n "s/.*<gateway[^>]*>.*<name>$(echo "$AUTHGROUP" | tr '[:lower:]' '[:upper:]')<\/name>.*<host>\([^<]*\)<\/host>.*/\1/Ip")
         fi
         if [ -n "$discovered_host" ]; then
            echo "Found Gateway host '$discovered_host' for AUTHGROUP '$AUTHGROUP' in Portal XML config."
         fi
       elif echo "$config_xml" | grep -q "$AUTHGROUP"; then
         # Attempt to extract from openconnect's text output: "  AUTHGROUP (host)"
         # Looking for lines like:   UO-P48-GW (uo-p48-gw.ucdp.net)
         discovered_host=$(echo "$config_xml" | sed -n "s/.*[[:space:]]$AUTHGROUP (\([^)]*\)).*/\1/p" | head -n 1)
         if [ -n "$discovered_host" ]; then
            echo "Found Gateway host '$discovered_host' for AUTHGROUP '$AUTHGROUP' in openconnect text output."
         fi
       fi
    fi

    # Fallback: If discovery failed but we have AUTHGROUP, try common patterns
    if [ -z "$discovered_host" ] && [ -n "$AUTHGROUP" ]; then
        echo "Discovery failed. Trying predictive fallback for AUTHGROUP '$AUTHGROUP'..."
        # If AUTHGROUP contains a dot, it might be the hostname itself
        if echo "$AUTHGROUP" | grep -q "\."; then
            discovered_host="$AUTHGROUP"
            echo "  Using AUTHGROUP '$AUTHGROUP' as potential Gateway host."
        else
            # Try to construct a gateway hostname: subdomain-gw.domain.com
            # Example: uo-p48.ucdp.net -> uo-p48-gw.ucdp.net
            base_host="${SAML_HOST%%.*}"
            domain="${SAML_HOST#*.}"
            discovered_host="${base_host}-gw.${domain}"
            echo "  Trying constructed Gateway host: $discovered_host"
        fi
    fi

    if [ -n "$discovered_host" ]; then
         # Check if the discovered host has a port
         if ! echo "$discovered_host" | grep -q ":"; then
            # If the original host had a port, try to preserve it if the discovered host doesn't have one
            # This is common in testing environments like host.docker.internal:9443
            # We strip the protocol first to accurately find the port
            host_without_protocol="${ORIGINAL_HOST#*://}"
            if echo "$host_without_protocol" | grep -q ":"; then
                port_to_preserve="${host_without_protocol##*:}"
                port_to_preserve="${port_to_preserve%/}" # remove trailing slash if any
                echo "  Adding port $port_to_preserve from ORIGINAL_HOST to discovered Gateway host"
                discovered_host="${discovered_host}:${port_to_preserve}"
            fi
         fi

         if check_saml_required "$discovered_host" "gateway"; then
           echo "Pivoting to Gateway mode for SAML authentication."
           SAML_HOST="$discovered_host"
           SAML_MODE="gateway"
           if [ -n "$SAML_PROBE_CLIENTOS" ]; then
              echo "  Updating SAML_CLIENTOS to $SAML_PROBE_CLIENTOS based on successful probe."
              SAML_CLIENTOS="$SAML_PROBE_CLIENTOS"
              update_os_flags
           fi
         else
           echo "  Gateway host '$discovered_host' did not return SAML tags."
         fi
    fi
  fi
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

echo "Starting SAML browser session on http://localhost:${SAML_AUTH_PORT}/"
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
  $SAML_VERIFY_ARG \
  "$SAML_MODE_ARG" \
  --allow-insecure-crypto \
  --user-agent "$SAML_USER_AGENT" \
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
