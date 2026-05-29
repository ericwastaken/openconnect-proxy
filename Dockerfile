FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive
ARG GP_SAML_GUI_URL="https://github.com/dlenski/gp-saml-gui/archive/master.zip#sha256=e229ad5ff817b2d3b2b0ccb89755640fccb890344b950a413e6a019536569066"

RUN apt-get update && \
    apt-get install -y \
      ca-certificates=20260223 \
      fluxbox=1.3.7-1build3 \
      gir1.2-gtk-3.0=3.24.52-0ubuntu1 \
      gir1.2-webkit2-4.1=2.52.3-0ubuntu0.26.04.2 \
      network-manager-openconnect=1.2.10-4.1 \
      novnc=1:1.6.0-2 \
      ocproxy=1.60-1build7 \
      python3-cairo=1.27.0-2build2 \
      python3-gi=3.56.2-1 \
      python3-pip=25.1.1+dfsg-1ubuntu2 \
      python3-venv=3.14.3-0ubuntu2 \
      websockify=0.13.0+dfsg1-2ubuntu1 \
      x11vnc=0.9.17-2 \
      xvfb=2:21.1.22-1ubuntu1 && \
    python3 -m venv --system-site-packages /opt/gp-saml-gui && \
    /opt/gp-saml-gui/bin/pip install --no-deps "$GP_SAML_GUI_URL" && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

ENV PATH="/opt/gp-saml-gui/bin:${PATH}"

COPY connect_vpn.sh /connect_vpn.sh
COPY connect_vpn_saml.sh /connect_vpn_saml.sh

RUN chmod +x /connect_vpn.sh /connect_vpn_saml.sh

CMD ["/bin/bash", "/connect_vpn.sh"]
