# OpenConnect Proxy Docker Container

This is a Docker containerized version of Openconnect and OCProxy that establishes a SOCKS5 proxy through a VPN. The container requires specific environment variables to be set before running. Below are the steps to launch this container using both Docker CLI and Docker Compose.

For more information on OpenConnect and OCProxy, visit the following links:
* https://www.infradead.org/openconnect/
* https://github.com/cernekee/ocproxy

## Environment Variables

Before running the container, you need to define the following environment variables:

- `USERNAME`
- `PASSWORD`
- `HOST`
- `FINGERPRINT`
- `FINGERPRINT_2` (optional)
- `AUTHGROUP`
- `PROTOCOL`
- `PROXY_PORT`
- `AUTH_MODE` (optional, defaults to `password`; use `saml` for GlobalProtect SAML)
- `SAML_AUTH_PORT` (required for `AUTH_MODE=saml`)
- `SAML_MODE` (optional, defaults to `portal`)
- `SAML_CLIENTOS` (optional, defaults to `Windows`)
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

SAML mode is only for GlobalProtect (`PROTOCOL=gp`) portals or gateways that return SAML fields in the GlobalProtect prelogin response. If the portal only returns username/password fields, use `AUTH_MODE=password`.

Set `AUTH_MODE=saml`, choose a unique `SAML_AUTH_PORT`, and open the printed noVNC URL, usually `http://localhost:<SAML_AUTH_PORT>/vnc.html`. Complete the browser login there. After `gp-saml-gui` captures the SAML cookie, the container starts OpenConnect with `ocproxy`.

Use `SAML_MODE=portal` first. Try `SAML_MODE=gateway` or `SAML_CLIENTOS=Mac` only if the portal does not expose SAML for the default settings. `SAML_NO_VERIFY=true` only affects `gp-saml-gui` portal discovery; OpenConnect still uses your configured `FINGERPRINT` pin.

### Local SAML Mock Test

The GitHub repo includes `test/x-mock-saml-start.sh`, `test/mock-gp-saml-server.py`, and `test/mock-saml.env.template` for local SAML workflow testing without a real VPN gateway. Start the mock server, build `openconnect-proxy:saml-test`, copy the template to `vpn-profiles/mock-saml.env`, then start the mock profile with the SAML Compose override.

Open `http://localhost:18080/vnc.html` for the mock browser flow. The mock profile sets `SAML_AUTH_ONLY=true`, so the container exits after `gp-saml-gui` returns mock SAML values instead of starting OpenConnect.

## Additional Commands

To stop the container:

```sh
docker-compose down
```

To view the logs:

```sh
docker-compose logs
```

## Usage Notes

- Ensure Docker and Docker Compose are installed on your machine.
- Adapt environment variables according to your needs.
- Ensure ports in the DOCKER CLI and `docker-compose.yml` match the `PROXY_PORT` variable!
- You can have multiple .env files and multiple services in the `docker-compose.yml` file to run multiple VPN connections. Be sure to select different ports for the PROXY_PORT variable in each .env file and service so you can use them simultaneously.

## GitHub

See the GitHub repo for more information including how to for and build your own version.

https://github.com/ericwastaken/openconnect-proxy
