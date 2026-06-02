#!/bin/bash
# Generate TLS certificates for RCT-Engine

DOMAIN="rct-engine.com"
DAYS=365
OUTPUT_DIR="/etc/ssl/rct-engine"

mkdir -p "$OUTPUT_DIR"

# Generate CA key and certificate (for internal use only)
echo "Generating CA certificate..."
openssl genrsa -out "$OUTPUT_DIR/ca.key" 4096
openssl req -new -x509 -days 3650 -key "$OUTPUT_DIR/ca.key" \
    -out "$OUTPUT_DIR/ca.crt" \
    -subj "/C=US/ST=State/L=City/O=RCT-Engine/CN=RCT-Engine CA"

# Generate server key
echo "Generating server certificate..."
openssl genrsa -out "$OUTPUT_DIR/server.key" 2048

# Generate CSR
openssl req -new -key "$OUTPUT_DIR/server.key" \
    -out "$OUTPUT_DIR/server.csr" \
    -subj "/C=US/ST=State/L=City/O=RCT-Engine/CN=*.${DOMAIN}"

# Generate server certificate
openssl x509 -req -in "$OUTPUT_DIR/server.csr" \
    -CA "$OUTPUT_DIR/ca.crt" \
    -CAkey "$OUTPUT_DIR/ca.key" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/server.crt" \
    -days $DAYS \
    -extfile <(cat <<EOF
subjectAltName=DNS:*.${DOMAIN},DNS:${DOMAIN},DNS:api.${DOMAIN},DNS:dashboard.${DOMAIN}
EOF
)

# Generate DH parameters
openssl dhparam -out "$OUTPUT_DIR/dhparam.pem" 2048

# Set permissions
chmod 600 "$OUTPUT_DIR/"*.key
chmod 644 "$OUTPUT_DIR/"*.crt "$OUTPUT_DIR/"*.pem

echo "Certificates generated in $OUTPUT_DIR"
