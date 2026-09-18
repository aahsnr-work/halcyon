#!/usr/bin/env bash
# p03-keygen.sh — P03 Secure Boot signing keypair, generated BEFORE the
# kernel is installed (bootc/ostree exception from the P03 README: keying
# after the fact would regenerate on every upgrade and break enrollment).
set -euo pipefail

CERT_DIR=/etc/kernel/certs/p03-kernel

echo "::group::p03-keygen — Secure Boot keypair"
install -d -m 0755 "${CERT_DIR}"
if [ -s "${CERT_DIR}/mok.der" ]; then
  echo "  SKIP  ${CERT_DIR}/mok.der already present"
else
  openssl req -new -x509 -newkey rsa:4096 \
    -keyout "${CERT_DIR}/mok.key" \
    -out "${CERT_DIR}/mok.pem" \
    -nodes -days 36500 -subj "/CN=P03 Kernel Secure Boot/"
  openssl x509 -in "${CERT_DIR}/mok.pem" -outform DER -out "${CERT_DIR}/mok.der"
  chmod 0644 "${CERT_DIR}/mok.der"
  chmod 0600 "${CERT_DIR}/mok.key" "${CERT_DIR}/mok.pem"
  echo "  OK    keypair generated (${CERT_DIR}/mok.der)"
  echo "  NOTE  Secure Boot users: mokutil --import ${CERT_DIR}/mok.der after first boot"
fi
echo "--- p03-keygen complete ---"
echo "::endgroup::"
