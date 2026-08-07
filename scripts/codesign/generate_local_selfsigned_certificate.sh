#!/usr/bin/env bash

set -euo pipefail
umask 077

certificateFile="${1:?usage: generate_local_selfsigned_certificate.sh certificate-prefix}"

cat >"$certificateFile.conf" <<'EOF'
  [ req ]
  distinguished_name = req_name
  prompt = no
  [ req_name ]
  CN = Local Self-Signed
  [ extensions ]
  basicConstraints=critical,CA:false
  keyUsage=critical,digitalSignature
  extendedKeyUsage=critical,1.3.6.1.5.5.7.3.3
  1.2.840.113635.100.6.1.14=critical,DER:0500
EOF

openssl genrsa -out "$certificateFile.key" 2048
openssl req -x509 -new -config "$certificateFile.conf" -nodes -key "$certificateFile.key" -extensions extensions -sha256 -days 3650 -out "$certificateFile.crt"
cat "$certificateFile.crt" "$certificateFile.key" >"$certificateFile.pem"
