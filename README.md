# OpenConnect Proxy Docker Container

This is a Docker containerized version of Openconnect and OCProxy that establishes a SOCKS5 proxy through a VPN. The container requires specific environment variables to be set before running. Below are the steps to launch this container using both Docker CLI and Docker Compose.

Once this container is running, you can configure any application that supports SOCKS5 PROXY to use **localhost** and the port you specified in the `PROXY_PORT` environment variable to connect to the VPN and access any resources available via the VPN.

For more information on OpenConnect and OCProxy, visit the following links:
* https://www.infradead.org/openconnect/
* https://github.com/cernekee/ocproxy

## Available on Docker Hub

This container is available on Docker Hub at [ericwastakenondocker/openconnect-proxy](https://hub.docker.com/r/ericwastakenondocker/openconnect-proxy).

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

See the example file `env.template` for more a template you can copy.

Edit a copy of the provided template and create a `vpn1.env` file in your project directory with the appropriate values:

```dotenv
USERNAME=[your_username]
PASSWORD=[your_password]
HOST=[vpn_host]
FINGERPRINT=[vpn_fingerprint]
# FINGERPRINT_2=[vpn_fingerprint_2] (if needed - some hosts have 2 signatures)
AUTHGROUP="[auth_group]"
# One of the Protocols supported by OPENCONNECT https://www.infradead.org/openconnect/manual.html
PROTOCOL=[gp|nc|pulse|f5|fortinet|array]
PROXY_PORT=[8222-8229]
```

## Running with Docker CLI

To run the container using the Docker CLI, use the following command:

```sh
docker run -d \
  --name vpn_service_1 \
  --env-file vpn1.env \
  -p 8222:8222 \
  ericwastakenondocker/openconnect-proxy:latest
```

Be sure you expose the same port in the `-p 8222:8222` argument in the command line as you entered in the `PROXY_PORT` variable in your `vpn1.env` file.

## Running with Docker Compose

To run the container using Docker Compose, create a `docker-compose.yml` file in your project directory:

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

## Building the Image

Use the included `x_build.sh` script to build the container. The script will build the container and tag it with the version number in the `build-manifest.env` file. Edit the manifest file to change the version number and image name as needed.

Note this build supports multi-platform builds, which require Docker Buildx to be enabled and QEMU to be installed on the host machine. On macOS, buildx and QEMU are both part of Docker Desktop, but in other Linux distros, you might need to enable this. (See the [Docker Buildx documentation](https://docs.docker.com/buildx/working-with-buildx/) for more information.)

## Proxy Support Notes

Unfortunately, standard versions of Chrome, Edge and Safari do not support distinct SOCKS5 proxies (they use your system proxy only). You can use a browser like Firefox or other tools (see below.)

### Proxy Support Notes

The following environments and applications support sending your traffic via a SOCKS5 proxy:

- **Windows Proxy All Traffic (not recommended)**

    It's possible to send all Windows traffic via the proxy. This is not ideal because you don't really want to send ALL TRAFFIC via the proxy.
    
    This might also crash the OCPROXY and the VPN connection.

    If you really want to put all of your traffic through the VPN, you can set up a Windows VPN connection directly. See the directory `openconnect-vpn-only` for details.

- **macOS Proxy All Traffic (not recommended)**

    It's possible to send all macOS traffic via the proxy. This is not ideal because you don't really want to send ALL TRAFFIC via the proxy. 

    Set this up in SETTINGS, NETWORK, ADVANCED, PROXIES, and set the SOCKS Proxy to localhost:8222.

- **Browser: Chrome (not recommended)**

    Chrome uses the system proxy unfortunately, so it's not a great choice for the same reasons as proying macOS or Windows.

- **Proxifier: Application-Specific Proxy**

    Proxifier is a Windows, macOS and Android app that will allow you to direct specific apps and ports over the proxy. Learn more about Proxifier at [https://www.proxifier.com/](https://www.proxifier.com/). 

    You'll need to PROXY the DNS also, which is tricky in this mixed mode! Easiest is to proxy all your DNS if you don't mind that you'll be sending some DNS queries over the VPN that have nothing to do with the VPN. But you could also set up specific rules to limit what DNS queries are sent over the VPN.

    If you prefer to use Chrome, Safari or Edge, your best choice is Proxifier to direct all traffic for this app via the proxy.

    Note that putting too much traffic via Proxifier can cause the VPN to crash. So be careful that you strategically route only the traffic you need to go over the VPN.

- **Browser: Firefox (Preferred setup for accessing websites that require the VPN)**

    Firefox allows for the setting of a Proxy for a chrome instance. We recommend setting up a PROFILE to use the Proxy. To setup the proxy, go to SETTINGS, NETWORK SETTINGS, MANUAL PROXY CONFIGURATION, SOCKS HOST: localhost, PORT: 8222. IMPORTANT: You must also check the box for "Proxy DNS when using SOCKS5".

    Learn more about Firefox profiles at [https://support.mozilla.org/en-US/kb/profile-manager-create-and-remove-firefox-profiles](https://support.mozilla.org/en-US/kb/profile-manager-create-and-remove-firefox-profiles).

    Also, it is recommended that you set up Firefox to PROMPT for the profile to use on Startup. If you are using multiple VPN connections at the same time, you might want multiple profiles, each set up to use the specific PROXY port.

- **SSH**

    You can use the proxy with SSH by using the `-o ProxyCommand` option. For example, `ssh -o ProxyCommand='nc -X 5 -x localhost:8222 %h %p' user@host`. (Update "localhost:8222" for the proper port number for your proxy profile.) 

    This also supports the use of a `~/.ssh/config` file to set up the proxy command for a specific host as well as SSH Tunnels using the standard syntax with the `-o ProxyCommand` option.

- **AUTO SSH**
     
    (Untested) You can use the proxy with AUTOSSH by setting the `AUTOSSH_PROXY` environment variable to `socks5://localhost:8222` (or the proper host + port number for your proxy profile).

- **SSH over Termius or other Terminal Apps that support PROXY**

    You can use any Terminal app that supports a SOCKS 5 proxy. Just set the proxy accordingly in the app's setup.





