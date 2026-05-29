#!/usr/bin/env python3

import argparse
import base64
import http.server
import os
import ssl
import subprocess
import tempfile
import urllib.parse


class MockGlobalProtectSamlHandler(http.server.BaseHTTPRequestHandler):
    server_version = "MockGlobalProtectSAML/0.1"

    def do_GET(self):
        self.route()

    def do_POST(self):
        self.route()

    def route(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/global-protect/prelogin.esp":
            self.send_prelogin("portal")
        elif path == "/ssl-vpn/prelogin.esp":
            self.send_prelogin("gateway")
        elif path == "/saml":
            self.send_saml_result()
        else:
            self.send_error(404)

    def send_prelogin(self, interface):
        saml_url = f"https://{self.headers['Host']}/saml"
        saml_request = base64.urlsafe_b64encode(saml_url.encode()).decode()
        body = f"""<?xml version="1.0" encoding="UTF-8"?>
<prelogin-response>
<status>Success</status>
<ccusername/>
<autosubmit>false</autosubmit>
<msg/>
<newmsg/>
<authentication-message>Mock {interface} SAML login</authentication-message>
<username-label>Username</username-label>
<password-label>Password</password-label>
<panos-version>1</panos-version>
<saml-auth-method>REDIRECT</saml-auth-method>
<saml-request>{saml_request}</saml-request>
<region>LOCAL</region>
</prelogin-response>
"""
        self.send_xml(body)

    def send_saml_result(self):
        username = self.server.mock_username
        cookie = self.server.mock_cookie
        body = f"""<!doctype html>
<html>
<head><title>Mock GlobalProtect SAML</title></head>
<body>
<h1>Mock GlobalProtect SAML Login Complete</h1>
<p>The browser can close after gp-saml-gui captures the mock cookie.</p>
<!--
<saml-username>{username}</saml-username>
<prelogin-cookie>{cookie}</prelogin-cookie>
<saml-auth-status>1</saml-auth-status>
-->
</body>
</html>
"""
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def send_xml(self, body):
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/xml; charset=UTF-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")


def create_self_signed_cert(temp_dir, host):
    cert_path = os.path.join(temp_dir, "mock-gp-saml.crt")
    key_path = os.path.join(temp_dir, "mock-gp-saml.key")
    subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-days",
            "1",
            "-subj",
            f"/CN={host}",
            "-keyout",
            key_path,
            "-out",
            cert_path,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return cert_path, key_path


def main():
    parser = argparse.ArgumentParser(description="Tiny local GlobalProtect SAML mock server.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=9443)
    parser.add_argument("--username", default="mock.user@example.com")
    parser.add_argument("--cookie", default="mock-prelogin-cookie")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory() as temp_dir:
        cert_path, key_path = create_self_signed_cert(temp_dir, "localhost")
        server = http.server.ThreadingHTTPServer((args.host, args.port), MockGlobalProtectSamlHandler)
        server.mock_username = args.username
        server.mock_cookie = args.cookie

        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert_path, key_path)
        server.socket = context.wrap_socket(server.socket, server_side=True)

        print(f"Mock GlobalProtect SAML server listening on https://{args.host}:{args.port}")
        print("Use this in a Docker profile: HOST=host.docker.internal:%d" % args.port)
        server.serve_forever()


if __name__ == "__main__":
    main()
