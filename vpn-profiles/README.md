# README - vpn-profiles

Place your VPN .env profiles here.

They should include the following:
```
USERNAME=your-username@your-domain.com
PASSWORD=your-password
HOST=https://your-vpn-host.domain.com
FINGERPRINT=your-vpn-fingerprint
# Enter the VPN group/gateway name
AUTHGROUP=""
# Choose from one of the supported protocols: gp, openvpn, wireguard
PROTOCOL=gp
# Choose the port to expose for the proxy
PROXY_PORT=8222
```