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

## Running with Docker Compose

To run the container using Docker Compose, create a `docker-compose.yml` file in your project directory (assuming you have a vpn1.env file with the needed environment variables):

```yaml
services:
  vpn_service_1:
    image: ericwastakenondocker/openconnect-proxy:latest
    container_name: vpn_service_1
    ports:
      - "8222:8222" # EXPOSE the same port you entered in PROXY_PORT in your vpn1.env file
    env_file:
      - vpn1.env
```

Ensure you have your `vpn1.env` file in the same directory as `docker-compose.yml`.

To start the service with Docker Compose, run:

```sh
docker-compose up -d
```

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