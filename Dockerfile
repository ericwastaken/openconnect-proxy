FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y network-manager-openconnect ocproxy && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

COPY connect_vpn.sh /connect_vpn.sh

CMD ["/bin/bash", "/connect_vpn.sh"]
