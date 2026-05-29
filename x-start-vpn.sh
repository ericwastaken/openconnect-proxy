#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

profiles=()
available_profiles=()
running_profiles=()
running_details=()
duplicate_port_profiles=()
duplicate_port_details=()

is_vpn_profile() {
  grep -Eq "^(HOST|PROXY_PORT|PROTOCOL|USERNAME)=" "$1"
}

profile_project_name() {
  basename "$1" .env | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g'
}

profile_proxy_port() {
  sed -n 's/^PROXY_PORT=//p' "$1" | tail -n 1 | sed 's/^["'\'']//; s/["'\'']$//'
}

running_containers_for_profile() {
  local profile="$1"
  local project_name

  project_name="$(profile_project_name "$profile")"

  docker ps --filter "label=com.docker.compose.project=$project_name" --format "{{.Names}}" 2>/dev/null || true
}

running_containers_for_port() {
  local proxy_port="$1"

  {
    docker ps --filter "publish=$proxy_port" --format "{{.Names}}" 2>/dev/null || true
    docker ps --filter "name=^/vpn_service_port_${proxy_port}$" --format "{{.Names}}" 2>/dev/null || true
  } | awk 'NF && !seen[$0]++'
}

while IFS= read -r profile; do
  if is_vpn_profile "$profile"; then
    profiles+=("$profile")
  fi
done < <(
  {
    find . -maxdepth 1 -type f -name "*.env" -print
    if [ -d "./vpn-profiles" ]; then
      find ./vpn-profiles -maxdepth 1 -type f -name "*.env" -print
    fi
  } | sort
)

if [ ${#profiles[@]} -eq 0 ]; then
  echo "No .env files found in $SCRIPT_DIR or $SCRIPT_DIR/vpn-profiles"
  exit 1
fi

can_read_docker_status=false
if docker ps > /dev/null 2>&1; then
  can_read_docker_status=true
else
  echo "Could not read Docker status; running profiles may still be listed as available."
  echo
fi

for profile in "${profiles[@]}"; do
  containers=""
  port_containers=""
  proxy_port="$(profile_proxy_port "$profile")"

  if [ "$can_read_docker_status" = true ]; then
    containers="$(running_containers_for_profile "$profile")"
  fi

  if [ -n "$containers" ]; then
    running_profiles+=("$profile")
    running_details+=("$containers")
  elif [ "$can_read_docker_status" = true ] && [ -n "$proxy_port" ]; then
    port_containers="$(running_containers_for_port "$proxy_port")"
    if [ -n "$port_containers" ]; then
      duplicate_port_profiles+=("$profile")
      duplicate_port_details+=("port $proxy_port: $port_containers")
    else
      available_profiles+=("$profile")
    fi
  else
    available_profiles+=("$profile")
  fi
done

if [ ${#running_profiles[@]} -gt 0 ]; then
  echo "Already running:"
  for i in "${!running_profiles[@]}"; do
    printf " - %s" "${running_profiles[$i]#./}"
    printf " (%s)\n" "$(echo "${running_details[$i]}" | paste -sd ", " -)"
  done
  echo
fi

if [ ${#duplicate_port_profiles[@]} -gt 0 ]; then
  echo "Duplicate ports:"
  for i in "${!duplicate_port_profiles[@]}"; do
    printf " - %s" "${duplicate_port_profiles[$i]#./}"
    printf " (%s)\n" "$(echo "${duplicate_port_details[$i]}" | paste -sd ", " -)"
  done
  echo
fi

if [ ${#available_profiles[@]} -eq 0 ]; then
  echo "No stopped VPN profiles without port conflicts are available to start."
  exit 0
fi

echo "Available VPN profiles:"
for i in "${!available_profiles[@]}"; do
  printf "%2d. %s\n" "$((i + 1))" "${available_profiles[$i]#./}"
done

echo
read -p "Select a profile number: " selection

if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#available_profiles[@]}" ]; then
  echo "Invalid selection"
  exit 1
fi

profile="${available_profiles[$((selection - 1))]}"
project_name="$(profile_project_name "$profile")"

echo
echo "Selected profile: ${profile#./}"
echo "Compose project: $project_name"
echo
echo "Future command:"
echo "docker compose --env-file \"${profile#./}\" -p \"$project_name\" up -d"
echo

read -p "Start this VPN now? [y/N] " -n 1 -r
echo
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Canceled"
  exit 0
fi

docker compose --env-file "$profile" -p "$project_name" up -d
