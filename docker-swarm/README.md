# Running with Docker Swarm

This directory contains stack files and templates for deploying the OpenConnect Proxy in a Docker Swarm cluster. Using Swarm allows for better management of secrets and configurations compared to standard Docker Compose.

## Directory Structure

- `stack.yml`: Stack for standard password authentication.
- `stack.saml.yml`: Stack for SAML authentication (includes SAML callback port).
- `swarm-config-plain.template`: Configuration template for password mode.
- `swarm-config-saml.template`: Configuration template for SAML mode.
- `swarm-secrets.template`: Secret template for your VPN password.

## Prerequisites

- A Docker Swarm cluster initialized (`docker swarm init`).
- An external overlay network for the stack.

```bash
docker network create \
  --driver=overlay \
  --attachable \
  --subnet=172.50.0.0/16 \
  uo-corp-swarm
```

## Deployment: Plain Password Mode

1. **Create the Secret**:
   Edit `swarm-secrets.template` or echo your password directly:
   ```bash
   echo "your-vpn-pass" | docker secret create vpn-password -
   ```

2. **Create the Config**:
   Copy `swarm-config-plain.template`, fill in your details, and create the config:
   ```bash
   docker config create vpn-config docker-swarm/swarm-config-plain.template
   ```

3. **Deploy the Stack**:
   ```bash
   docker stack deploy -c docker-swarm/stack.yml vpn-service-1
   ```

## Deployment: SAML Mode

SAML mode requires an additional port for the browser-based login and the `-saml` image variant.

1. **Create the Secret**:
   ```bash
   echo "your-vpn-pass" | docker secret create vpn-password-saml -
   ```

2. **Create the Config**:
   Copy `swarm-config-saml.template`, fill in your details (ensure `AUTH_MODE=saml` and `PROTOCOL=gp`), and create the config:
   ```bash
   docker config create vpn-config-saml docker-swarm/swarm-config-saml.template
   ```

3. **Deploy the Stack**:
   ```bash
   # Set the IMAGE env var if not using the default latest-saml
   export IMAGE=ericwastakenondocker/openconnect-proxy:latest-saml
   docker stack deploy -c docker-swarm/stack.saml.yml vpn-service-saml
   ```

4. **Complete Authentication**:
   Open the noVNC interface at `http://[swarm-node-ip]:8023` to complete the SAML login.

## Managing the Stacks

- **View logs**: `docker service logs vpn-service-1_openconnect-proxy`
- **Stop stack**: `docker stack rm vpn-service-1`
- **Update configuration**: You must remove and recreate the config/secret, then redeploy the stack (or use versioned names like `vpn-config-v2`).

## Restart Policy

The stacks are configured with `restart_policy.condition: on-failure`. 
- If the VPN connection drops due to a network error, Swarm will automatically restart the container to reconnect.
- If you manually stop the service, it stays stopped.
