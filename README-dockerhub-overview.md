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

## Running with Docker Compose

To run the container using Docker Compose, create a `docker-compose.yml` file in your project directory (assuming you have a vpn1.env file with the needed environment variables):

```yaml
services:
  vpn_service_1:
    image: ericwastakenondocker/openconnect-proxy:latest
    container_name: "vpn_service_port_${PROXY_PORT}"
    ports:
      - "${PROXY_PORT}:${PROXY_PORT}"
    environment:
      USERNAME: "${USERNAME}"
      PASSWORD: "${PASSWORD:-}"
      PASSWORD_PATH: "${PASSWORD_PATH:-}"
      HOST: "${HOST}"
      FINGERPRINT: "${FINGERPRINT}"
      FINGERPRINT_2: "${FINGERPRINT_2:-}"
      AUTHGROUP: "${AUTHGROUP}"
      PROTOCOL: "${PROTOCOL}"
      PROXY_PORT: "${PROXY_PORT}"
```

Ensure you have your profile env file in the same directory as `docker-compose.yml` or under `vpn-profiles`.

To start the service with Docker Compose, run:

```sh
docker compose --env-file "vpn-profiles/vpn1.env" -p "vpn1" up -d
```

For manual Docker Compose usage, `--env-file` is required unless the variables are already exported in your shell or stored in Compose's default `.env` file. The `-p` project name is optional for one profile, but required if you want multiple profiles to run side by side cleanly. The `-d` flag is optional; it runs the service in the background.

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
