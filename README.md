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
- `PASSWORD` or `PASSWORD_PATH` (if you want to use a file for the password, which is more secure)
- `HOST`
- `FINGERPRINT`
- `FINGERPRINT_2` (optional)
- `AUTHGROUP`
- `PROTOCOL`
- `PROXY_PORT`
- `AUTH_MODE` (optional, defaults to `password`; use `saml` for GlobalProtect SAML)
- `SAML_AUTH_PORT` (required for `AUTH_MODE=saml`)
- `SAML_MODE` (optional, defaults to `portal`. See **Smart Discovery** below.)
- `SAML_CLIENTOS` (optional, defaults to `Windows`)
- `SAML_USER_AGENT` (optional; spoofs a browser User-Agent to satisfy Duo/Okta OS checks)
- `SAML_NO_VERIFY` (optional, defaults to `true`; only affects `gp-saml-gui` portal discovery)
- `SAML_AUTH_ONLY` (optional, defaults to `false`; only for local SAML mock testing)

See the example file `env.template` for more a template you can copy.

Edit a copy of the provided template and create a `vpn1.env` file in your project directory with the appropriate values:

```dotenv
USERNAME=[your_username]
# Less secure password as an environment variable
PASSWORD=[your_password]
# (if you want to use a file for the password)
PASSWORD_PATH=[/path/to/password_file]
HOST=[vpn_host]
FINGERPRINT=[vpn_fingerprint]
# FINGERPRINT_2=[vpn_fingerprint_2] (if needed - some hosts have 2 signatures)
AUTHGROUP="[auth_group]"
# One of the Protocols supported by OPENCONNECT https://www.infradead.org/openconnect/manual.html
PROTOCOL=[gp|nc|pulse|f5|fortinet|array]
AUTH_MODE=password
# For GlobalProtect SAML only:
# AUTH_MODE=saml
# SAML_AUTH_PORT=8080
# SAML_MODE=portal
# SAML_CLIENTOS=Windows
# SAML_USER_AGENT=
# SAML_NO_VERIFY=true
# SAML_AUTH_ONLY=false
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

## Managing Profiles with the Helper Script

This repo includes `x-start-vpn.sh`, a helper for choosing and starting VPN profiles without typing the full Docker Compose command each time.

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

To run the container using Docker Compose, create a `docker-compose.yml` file in your project directory:

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

SAML mode is designed for GlobalProtect (`PROTOCOL=gp`) portals or gateways that require browser-based authentication.

### Smart Discovery (Under the Hood)

The SAML image includes "Smart Discovery" logic. You typically only need to set `SAML_MODE=portal` (the default). If the Portal doesn't require SAML itself but one of its Gateways does, the container will:

1.  **Probe the Portal**: Check if it requires SAML.
2.  **Discover Gateways**: If not, it uses your `USERNAME` and `PASSWORD` to query the Portal for available Gateways.
3.  **Target your Gateway**: It matches your `AUTHGROUP` to a specific Gateway host and probes it for SAML.
4.  **Auto-Pivot**: If the Gateway requires SAML, the container automatically pivots the browser session to that Gateway.

A SAML profile looks like this:

```dotenv
IMAGE=ericwastakenondocker/openconnect-proxy:latest-saml # Optional. Default: ericwastakenondocker/openconnect-proxy:latest
USERNAME=your_username # Required
PASSWORD=your_password # Optional. Required for "Smart Discovery" if SAML is triggered at the Gateway level
HOST=vpn.example.com # Required. The VPN Portal/Gateway address
FINGERPRINT=pin-sha256:... # Required. The certificate pin (one or more)
AUTHGROUP="Your-Gateway-Name" # Required for GlobalProtect
PROTOCOL=gp # Required. Set to 'gp' for GlobalProtect (only protocol supporting SAML currently)
PROXY_PORT=8222 # Required. Port for the SOCKS/HTTP proxy
AUTH_MODE=saml # Required for SAML workflow. Options: password (default), saml
SAML_AUTH_PORT=18080 # Optional. Default: 8080. Port for the VNC/noVNC login interface
# SAML_MODE=portal # Optional. Default: portal. Options: portal, gateway
# SAML_CLIENTOS=Windows # Optional. Default: Windows. Options: Windows, Linux, Mac
# SAML_USER_AGENT= # Optional. Defaults to a standard Chrome UA based on SAML_CLIENTOS
# SAML_NO_VERIFY=true # Optional. Default: true. Ignore SSL errors during discovery/SAML probe
```

Notes:

- `HOST` can be `vpn.example.com` or `https://vpn.example.com`; SAML mode normalizes it automatically.
- `SAML_MODE=portal` starts with `/global-protect/prelogin.esp`. This is the recommended starting point as discovery will handle gateways automatically.
- `SAML_MODE=gateway` bypasses discovery and targets `/ssl-vpn/prelogin.esp` on the `HOST` directly.
- `SAML_CLIENTOS=Windows` is a good default. Some portals only expose SAML for supported desktop clients.
- `SAML_USER_AGENT`: If set, this overrides the browser's User-Agent. If left empty, it defaults to a standard Chrome-on-Windows (or Linux) string based on `SAML_CLIENTOS` to satisfy Duo/Okta security policies.
- `SAML_NO_VERIFY=true` lets `gp-saml-gui` perform portal discovery even when the TLS chain is not trusted inside the container.
- The default Docker image is the smaller password-mode image. SAML profiles must use a SAML-capable image.

When SAML mode starts, open the printed noVNC URL:

```text
http://localhost:18080/
```

Complete the login inside the browser window. After `gp-saml-gui` captures the SAML cookie, the container starts OpenConnect with `ocproxy`.

Expected successful SAML log lines include:

```text
Starting SAML authentication workflow
Got SAML REDIRECT, opening browser...
[SAML   ] Got all required SAML headers, done.
SAML login complete; starting OpenConnect and ocproxy.
```

If you see this, that portal is not offering SAML for the selected host/auth mode/client OS:

```text
prelogin response does not contain SAML tags
```

### Local SAML Mock Test

For local SAML workflow testing without a real VPN gateway, start the mock server:

```sh
./test/x-mock-saml-start.sh
```

Then build the local image and start the included mock profile:

```sh
docker build --target saml -t openconnect-proxy:saml-test .
cp test/mock-saml.env.template vpn-profiles/mock-saml.env
docker compose -f docker-compose.yml -f docker-compose.saml.yml --env-file "vpn-profiles/mock-saml.env" -p "mock-saml" up -d --force-recreate
```

Open `http://localhost:18080/` and complete the mock browser flow. The profile sets `SAML_AUTH_ONLY=true`, so the container exits after `gp-saml-gui` returns mock SAML values instead of starting OpenConnect.

Expected mock success:

```text
[SAML   ] Got all required SAML headers, done.
SAML_AUTH_ONLY=true; skipping OpenConnect startup.
COOKIE=present
```

### Additional Docker Commands

To stop the container:

```sh
docker-compose down
```

To view the logs:

```sh
docker-compose logs
```

## Running with Docker Swarm

For advanced deployments using Docker Swarm, including support for Secrets and Configs, please see the [Docker Swarm Documentation](docker-swarm/README.md).

## Usage Notes

- Ensure Docker, Docker Compose, and Docker Swarm (if you're using Swarm) are installed on your machine.
- Adapt environment variables according to your needs.
- Ensure ports in the DOCKER CLI and `docker-compose.yml` match the `PROXY_PORT` variable!
- You can have multiple .env files and multiple services in the `docker-compose.yml` file to run multiple VPN connections. Be sure to select different ports for the PROXY_PORT variable in each .env file and service so you can use them simultaneously.

## Building the Image

Use the included `x_build.sh` script to build the container. The script provides an interactive menu to choose between production builds (multi-platform) or local test builds (current platform only). 

Local test builds use the tags `openconnect-proxy:plain-test` and `openconnect-proxy:saml-test`.

You can also build the variants manually:

```sh
docker build --target plain -t openconnect-proxy:plain-test .
docker build --target saml -t openconnect-proxy:saml-test .
```

The plain image contains only OpenConnect and `ocproxy`. The SAML image adds the browser stack, noVNC, Xvfb, WebKit GTK, and `gp-saml-gui`, so it is expected to be much larger.

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
