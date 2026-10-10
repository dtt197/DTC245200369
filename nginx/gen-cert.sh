#!/usr/bin/env bash
# Tao chung chi SSL tu ky (self-signed) cho moi truong lab
set -e
cd "$(dirname "$0")/certs"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout server.key -out server.crt \
  -subj "/C=VN/ST=ThaiNguyen/O=DTC245200369/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
chmod 644 server.crt
chmod 600 server.key
echo "Da tao nginx/certs/server.crt va server.key"
