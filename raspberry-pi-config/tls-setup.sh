#!/bin/bash
# TLS Certificate Setup for IEC 62443-3-3
# Generates self-signed certificates for edge device
# For production, replace with proper CA-signed certificates

set -e

CERT_DIR="./certs"
DAYS_VALID=365

echo "=== TLS Certificate Setup for IEC 62443-3-3 ==="

# Create certificate directory
mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"

# Generate private key
echo "[1/3] Generating RSA private key (4096-bit)..."
openssl genrsa -out "$CERT_DIR/server.key" 4096

# Set proper permissions for private key
chmod 600 "$CERT_DIR/server.key"

# Generate certificate signing request
echo "[2/3] Generating certificate signing request..."
openssl req -new \
    -key "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.csr" \
    -subj "/C=ES/ST=State/L=City/O=IEC62443/CN=rpi-analyzer"

# Generate self-signed certificate
echo "[3/3] Generating self-signed certificate (valid for $DAYS_VALID days)..."
openssl x509 -req \
    -days "$DAYS_VALID" \
    -in "$CERT_DIR/server.csr" \
    -signkey "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.crt" \
    -extfile <(printf "subjectAltName=DNS:localhost,DNS:rpi-analyzer,IP:127.0.0.1")

# Verify certificate
echo ""
echo "=== Certificate Information ==="
openssl x509 -in "$CERT_DIR/server.crt" -text -noout | grep -A 2 "Subject:\|Issuer:\|Not Before\|Not After\|Public-Key"

# Cleanup CSR
rm "$CERT_DIR/server.csr"

echo ""
echo "=== TLS Setup Complete ==="
echo "Certificate generated: $CERT_DIR/server.crt"
echo "Private key: $CERT_DIR/server.key"
echo "Validity: $DAYS_VALID days"
echo ""
echo "IMPORTANT: For production deployment:"
echo "1. Obtain certificates from a trusted Certificate Authority"
echo "2. Update server.crt with the CA-signed certificate"
echo "3. Ensure private key permissions are 600 (read-only for owner)"
echo "4. Store in secure location with restricted access"
echo ""
