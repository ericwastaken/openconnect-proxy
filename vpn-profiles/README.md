# README - vpn-profiles

Place your VPN .env profiles here.

They should include the following:
```dotenv
IMAGE=ericwastakenondocker/openconnect-proxy:latest-saml # Optional. Default: plain image
USERNAME=your-username@your-domain.com # Required
PASSWORD=your-password # Optional. Required for "Smart Discovery"
HOST=https://your-vpn-host.domain.com # Required
FINGERPRINT=your-vpn-fingerprint # Required
AUTHGROUP="" # Required for GlobalProtect (gp)
PROTOCOL=gp # Required. Set to 'gp' for SAML
PROXY_PORT=8222 # Required
AUTH_MODE=saml # Required for SAML. Options: password (default), saml
SAML_AUTH_PORT=18080 # Required for SAML. Default: 8080
```