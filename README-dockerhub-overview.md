# OpenConnect Proxy Docker Container

This containerized version of OpenConnect and OCProxy establishes a SOCKS5 proxy through a VPN. It is designed to be highly flexible, supporting standard password authentication and browser-based SAML flows (specifically for GlobalProtect).

The repository includes a helper script `x-start-vpn.sh` that makes it easy to manage multiple VPN profiles across Docker Compose and Docker Swarm.

For more information...
* https://www.infradead.org/openconnect/
* https://github.com/cernekee/ocproxy


## Image Variants

There are two Docker image variants:

- `ericwastakenondocker/openconnect-proxy:latest` is the plain username/password image. Use this for normal OpenConnect password, Duo push, or OTP-style flows where OpenConnect can authenticate from stdin.
- `ericwastakenondocker/openconnect-proxy:latest-saml` is the GlobalProtect SAML image. Use this when `AUTH_MODE=saml` and the VPN requires browser-based SAML authentication.

Versioned tags follow the same pattern:

```text
ericwastakenondocker/openconnect-proxy:<version>
ericwastakenondocker/openconnect-proxy:<version>-saml
```

The SAML image is much larger because it includes the browser/noVNC/Xvfb/WebKit stack needed to complete SAML login. If you do not need SAML, use the plain image.

Set `IMAGE` in each VPN profile so the selected image is explicit.

For a plain username/password profile:

```text
IMAGE=ericwastakenondocker/openconnect-proxy:latest
AUTH_MODE=password
```

For a GlobalProtect SAML profile:

```text
IMAGE=ericwastakenondocker/openconnect-proxy:latest-saml
AUTH_MODE=saml
```

## Environment Variables

Before running the container, you need to define the following environment variables:

- `IMAGE`
- `USERNAME`
- `PASSWORD`
- `HOST`
- `FINGERPRINT`
- `FINGERPRINT_2` (optional)
- `AUTHGROUP`
- `PROTOCOL`
- `PROXY_PORT`
- `PASSWORD_PATH` (Recommended for Swarm/Secrets: `/run/secrets/vpn-password`)
- `AUTH_MODE` (optional, defaults to `password`; use `saml` for GlobalProtect SAML)
- `SAML_AUTH_PORT` (required for `AUTH_MODE=saml`)
- `SAML_MODE` (optional, defaults to `portal`. Supports automatic gateway discovery.)
- `SAML_CLIENTOS` (optional, defaults to `Windows`)
- `SAML_USER_AGENT` (optional; spoofs a browser User-Agent for Duo/Okta checks)
- `SAML_NO_VERIFY` (optional, defaults to `true`; only affects `gp-saml-gui` portal discovery)
- `SAML_AUTH_ONLY` (optional, defaults to `false`; only for local SAML mock testing)

See the example .env file provided in the GitHub repo for more information. (See the bottom of this page for the link.)

## Running with Docker CLI

To run the container using the Docker CLI, use the following command (assuming you have a vpn1.env file with the needed environment variables):

```sh
docker run -d \
  --name vpn_service_1 \
  --env-file vpn1.env \
  -p 8222:8222 \
  ericwastakenondocker/openconnect-proxy:latest
```

Be sure you expose the same port in the `-p 8222:8222` argument in the command line as you entered in the `PROXY_PORT` variable in your `vpn1.env` file.

## Managing Profiles with the Helper Script

The GitHub repo includes `x-start-vpn.sh`, a helper for choosing and starting VPN profiles without typing the full Docker Compose command each time.

The script looks for VPN profile `.env` files in the project directory and in `./vpn-profiles`, shows which profiles are already running, warns about duplicate `PROXY_PORT` conflicts, and only offers profiles that can be started safely.

Run it from the project directory:

```sh
./x-start-vpn.sh
```

After you select a profile, the script shows the equivalent Docker Compose command so you can run it manually in the future. It uses the profile file name as the Compose project namespace. For example, `vpn-profiles/vpn1.env` becomes project `vpn1`:

```sh
docker compose --env-file "vpn-profiles/vpn1.env" -p "vpn1" up -d
```

The `-p` flag is the Docker Compose project name. It is not strictly required for a single VPN profile, but it is recommended when using multiple profiles because it keeps each profile in its own Compose namespace.

For a GlobalProtect SAML profile, set `AUTH_MODE=saml` and a unique `SAML_AUTH_PORT` in the profile. The helper automatically adds the SAML Compose override, checks both the proxy port and browser-login port for conflicts, shows the image it will use, and prints the equivalent manual command.

## Running with Docker Compose

To run the container using Docker Compose, create a `docker-compose.yml` file in your project directory (assuming you have a vpn1.env file with the needed environment variables):

```yaml
services:
  vpn_service_1:
    image: "${IMAGE:-ericwastakenondocker/openconnect-proxy:latest}"
    container_name: "vpn_service_port_${PROXY_PORT}"
    ports:
      - "${PROXY_PORT}:${PROXY_PORT}"
    environment:
      AUTH_MODE: "${AUTH_MODE:-password}"
      USERNAME: "${USERNAME}"
      PASSWORD: "${PASSWORD:-}"
      PASSWORD_PATH: "${PASSWORD_PATH:-}"
      HOST: "${HOST}"
      FINGERPRINT: "${FINGERPRINT}"
      FINGERPRINT_2: "${FINGERPRINT_2:-}"
      AUTHGROUP: "${AUTHGROUP}"
      PROTOCOL: "${PROTOCOL}"
      PROXY_PORT: "${PROXY_PORT}"
      SAML_AUTH_PORT: "${SAML_AUTH_PORT:-8080}"
      SAML_CLIENTOS: "${SAML_CLIENTOS:-Windows}"
      SAML_USER_AGENT: "${SAML_USER_AGENT:-}"
      SAML_MODE: "${SAML_MODE:-portal}"
      SAML_NO_VERIFY: "${SAML_NO_VERIFY:-true}"
      SAML_AUTH_ONLY: "${SAML_AUTH_ONLY:-false}"
```

Ensure you have your profile env file in the same directory as `docker-compose.yml` or under `vpn-profiles`.

To start the service with Docker Compose, run:

```sh
docker compose --env-file "vpn-profiles/vpn1.env" -p "vpn1" up -d
```

For a SAML profile, include the SAML override file so the browser-login port is exposed:

```sh
docker compose -f docker-compose.yml -f docker-compose.saml.yml --env-file "vpn-profiles/vpn1.env" -p "vpn1" up -d
```

For manual Docker Compose usage, `--env-file` is required unless the variables are already exported in your shell or stored in Compose's default `.env` file. The `-p` project name is optional for one profile, but required if you want multiple profiles to run side by side cleanly. The `-d` flag is optional; it runs the service in the background.

## GlobalProtect SAML Authentication

SAML mode is for GlobalProtect (`PROTOCOL=gp`) portals or gateways that require browser authentication. The image includes **Smart Discovery** logic that automatically detects if SAML is required at the Portal or Gateway level.

Set `AUTH_MODE=saml`, choose a unique `SAML_AUTH_PORT`, and open the printed noVNC URL, usually `http://localhost:<SAML_AUTH_PORT>/`. Complete the browser login there. After `gp-saml-gui` captures the SAML cookie, the container starts OpenConnect.

Use `SAML_MODE=portal` first (it's the default and handles discovery). `SAML_USER_AGENT` defaults to a standard Chrome browser string to bypass OS checks from Duo/Okta.

The default Docker image is the smaller password-mode image. SAML profiles must use a SAML-capable image, such as `ericwastakenondocker/openconnect-proxy:latest-saml` or a local test image like `openconnect-proxy:saml-test`.


## Running with Docker Swarm

Docker Swarm provides a more robust way to manage VPN proxies across a cluster, with better handling of secrets and configurations.

### Standard Password Deployment
1. **Secret**: `echo "your-pass" | docker secret create vpn-password -`
2. **Config**: Create a config from your `.env` file or the `swarm-config-plain.template` found in the GitHub repo.
3. **Deploy**: Use `stack.yml` from the repo:
   ```bash
   docker stack deploy -c stack.yml vpn-service
   ```

### SAML Deployment
1. **Secret**: `echo "your-pass" | docker secret create vpn-password-saml -`
2. **Config**: Create a config with `AUTH_MODE=saml` and `PROTOCOL=gp`.
3. **Deploy**: Use `stack.saml.yml` from the repo. Note that SAML mode requires exposing an additional port for the browser-based login.

For detailed Swarm templates and instructions, see the `docker-swarm/` directory in the GitHub repository.

## Additional Commands

To stop the container (Compose):
```sh
docker-compose down
```

To stop the service (Swarm):
```sh
docker stack rm vpn-service
```

To view logs:
```sh
docker-compose logs # Compose
docker service logs vpn-service_openconnect-proxy # Swarm
```

## Usage Notes

- Ensure Docker and Docker Compose are installed on your machine.
- Adapt environment variables according to your needs.
- Ensure ports in the DOCKER CLI and `docker-compose.yml` match the `PROXY_PORT` variable!
- You can have multiple .env files and multiple services in the `docker-compose.yml` file to run multiple VPN connections. Be sure to select different ports for the PROXY_PORT variable in each .env file and service so you can use them simultaneously.

## GitHub

See the GitHub repo for more information including how to for and build your own version.

https://github.com/ericwastaken/openconnect-proxy
