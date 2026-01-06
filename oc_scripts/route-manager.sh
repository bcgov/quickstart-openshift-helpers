#!/bin/bash
#
# Usage:
#   ./route-manager.sh
#
# Environment variables required:
#   DOMAIN         - Fully qualified domain name (FQDN) for the route
#   SERVICE        - OpenShift service name to expose
#   CERT_DIR       - Directory containing certificate files
#   ROUTE_NAME     - (Optional) Custom route name (defaults to ${SERVICE}-vanity)
#   PATH           - (Optional) Path/subdir for the route
#
# This script creates or updates an OpenShift route with TLS certificates.
# If the route exists, it patches the certificates. If not, it creates a new route.

# Strict mode: exit on error, unset vars, or failed pipes
set -euo pipefail

# Validate required environment variables
if [[ -z "${DOMAIN:-}" ]]; then
  echo "Error: DOMAIN environment variable is required"
  exit 1
fi

if [[ -z "${SERVICE:-}" ]]; then
  echo "Error: SERVICE environment variable is required"
  exit 1
fi

if [[ -z "${CERT_DIR:-}" ]]; then
  echo "Error: CERT_DIR environment variable is required"
  exit 1
fi

# Change to certificate directory
cd "${CERT_DIR}"

# Set route name (default if not provided)
ROUTE_NAME="${ROUTE_NAME:-${SERVICE}-vanity}"

# Check if route already exists
if oc get route "${ROUTE_NAME}" &>/dev/null; then
  echo "Route ${ROUTE_NAME} exists. Patching with new cert..."

  # Escape certificate data for JSON
  CERT_ESC=$(cat "${DOMAIN}.pem" | \
    sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
  KEY_ESC=$(cat "${DOMAIN}.key" | \
    sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
  CA_ESC=$(cat "${DOMAIN}.ca-cert" | \
    sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')

  # Create patch JSON
  PATCH="{\"spec\":{\"tls\":{\"certificate\":\"${CERT_ESC}\","
  PATCH="${PATCH}\"key\":\"${KEY_ESC}\","
  PATCH="${PATCH}\"caCertificate\":\"${CA_ESC}\"}}}"
  echo "${PATCH}" > /tmp/route-patch.json

  # Apply patch
  oc patch route "${ROUTE_NAME}" --type=merge \
    --patch-file=/tmp/route-patch.json
  rm -f /tmp/route-patch.json
  echo "Route patched successfully"
else
  # Create the route
  echo "Creating route ${ROUTE_NAME} for service ${SERVICE}"
  echo "with hostname ${DOMAIN}"

  # Create route with or without path
  if [ -n "${PATH:-}" ]; then
    oc create route edge "${ROUTE_NAME}" \
      --service="${SERVICE}" \
      --cert="${DOMAIN}.pem" \
      --key="${DOMAIN}.key" \
      --ca-cert="${DOMAIN}.ca-cert" \
      --hostname="${DOMAIN}" \
      --path="${PATH}"
  else
    oc create route edge "${ROUTE_NAME}" \
      --service="${SERVICE}" \
      --cert="${DOMAIN}.pem" \
      --key="${DOMAIN}.key" \
      --ca-cert="${DOMAIN}.ca-cert" \
      --hostname="${DOMAIN}"
  fi
  echo "Route created successfully"
fi

# Verify route state
echo "Current route configuration:"
oc get route "${ROUTE_NAME}" -o yaml
