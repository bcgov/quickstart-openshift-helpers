#!/bin/bash
set -euo pipefail

# Certificate Backup Helper
#
# This script backs up TLS certificates from OpenShift routes to secrets.
# This protects against certificate loss if routes are accidentally deleted.
#
# Usage: ./backup_certs.sh [OPTIONS]
#
# Options:
#   -n, --namespace NAMESPACE    Specify the OpenShift namespace (default: current namespace)
#   -r, --route ROUTE           Backup only a specific route
#   -l, --label LABEL           Filter routes by label selector (e.g., "app=myapp")
#   -p, --prefix PREFIX         Prefix for backup secret names (default: "backup")
#   --dry-run                   Show what would be backed up without creating secrets
#   -h, --help                  Display this help message and exit
#
# Examples:
#   ./backup_certs.sh                           # Backup all routes in current namespace
#   ./backup_certs.sh -r myapp-vanity           # Backup specific route
#   ./backup_certs.sh -l "app=myapp"            # Backup routes matching label
#   ./backup_certs.sh --dry-run                 # Preview what would be backed up

# Display help
display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -n, --namespace NAMESPACE    Specify the OpenShift namespace (default: current namespace)"
  echo "  -r, --route ROUTE           Backup only a specific route"
  echo "  -l, --label LABEL           Filter routes by label selector (e.g., 'app=myapp')"
  echo "  -p, --prefix PREFIX         Prefix for backup secret names (default: 'backup')"
  echo "  --dry-run                   Show what would be backed up without creating secrets"
  echo "  -h, --help                  Display this help message and exit"
  echo ""
  echo "Examples:"
  echo "  $0                           # Backup all routes in current namespace"
  echo "  $0 -r myapp-vanity           # Backup specific route"
  echo "  $0 -l 'app=myapp'            # Backup routes matching label"
  echo "  $0 --dry-run                 # Preview what would be backed up"
  exit 0
}

# Parse options
NAMESPACE=""
ROUTE=""
LABEL=""
PREFIX="backup"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -r|--route)
      ROUTE="$2"
      shift 2
      ;;
    -l|--label)
      LABEL="$2"
      shift 2
      ;;
    -p|--prefix)
      PREFIX="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      display_help
      ;;
    *)
      echo "Error: Unknown option $1"
      display_help
      ;;
  esac
done

# Check if oc is available
if ! command -v oc &> /dev/null; then
  echo "Error: 'oc' command not found. Please install the OpenShift CLI."
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' command not found. Please install jq for JSON parsing."
  exit 1
fi

# Set namespace if specified
NAMESPACE_FLAG=""
if [[ -n "${NAMESPACE}" ]]; then
  NAMESPACE_FLAG="-n ${NAMESPACE}"
  NAMESPACE_DISPLAY="${NAMESPACE}"
else
  NAMESPACE_DISPLAY=$(oc project -q)
fi

echo "Backing up certificates from namespace: ${NAMESPACE_DISPLAY}"
echo "Backup secret prefix: ${PREFIX}"
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "DRY RUN MODE - No secrets will be created"
fi
echo ""

# Build the oc get routes command
GET_ROUTES_CMD="oc get routes ${NAMESPACE_FLAG} -o json"

if [[ -n "${ROUTE}" ]]; then
  GET_ROUTES_CMD="oc get route ${ROUTE} ${NAMESPACE_FLAG} -o json"
  echo "Filtering to route: ${ROUTE}"
elif [[ -n "${LABEL}" ]]; then
  GET_ROUTES_CMD="oc get routes -l ${LABEL} ${NAMESPACE_FLAG} -o json"
  echo "Filtering routes by label: ${LABEL}"
fi

# Get routes and process them
ROUTES_JSON=$(eval "${GET_ROUTES_CMD}")

# Handle single route vs multiple routes JSON structure
if [[ -n "${ROUTE}" ]]; then
  # Single route - wrap in array
  ROUTES_JSON="{\"items\":[${ROUTES_JSON}]}"
fi

# Count total routes
TOTAL_ROUTES=$(echo "${ROUTES_JSON}" | jq '.items | length')
echo "Found ${TOTAL_ROUTES} route(s) to process"
echo ""

BACKED_UP=0
SKIPPED=0

# Process each route
for i in $(seq 0 $((TOTAL_ROUTES - 1))); do
  ROUTE_NAME=$(echo "${ROUTES_JSON}" | jq -r ".items[${i}].metadata.name")
  TLS_TERMINATION=$(echo "${ROUTES_JSON}" | jq -r ".items[${i}].spec.tls.termination // empty")
  
  if [[ -z "${TLS_TERMINATION}" || "${TLS_TERMINATION}" == "null" ]]; then
    echo "⊘ Skipping route '${ROUTE_NAME}': No TLS configuration"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  
  echo "→ Processing route '${ROUTE_NAME}' (TLS: ${TLS_TERMINATION})"
  
  # Extract certificate components based on termination type
  CERT=$(echo "${ROUTES_JSON}" | jq -r ".items[${i}].spec.tls.certificate // empty")
  KEY=$(echo "${ROUTES_JSON}" | jq -r ".items[${i}].spec.tls.key // empty")
  CA_CERT=$(echo "${ROUTES_JSON}" | jq -r ".items[${i}].spec.tls.caCertificate // empty")
  DEST_CA_CERT=$(echo "${ROUTES_JSON}" | jq -r ".items[${i}].spec.tls.destinationCACertificate // empty")
  
  # Check if there are any certificates to backup
  if [[ -z "${CERT}" && -z "${KEY}" && -z "${CA_CERT}" && -z "${DEST_CA_CERT}" ]]; then
    echo "  ⊘ No certificates found in route"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  
  # Create secret name
  SECRET_NAME="${PREFIX}-${ROUTE_NAME}-tls"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  ✓ Would create secret: ${SECRET_NAME}"
    if [[ -n "${CERT}" ]]; then echo "    - certificate: present"; fi
    if [[ -n "${KEY}" ]]; then echo "    - key: present"; fi
    if [[ -n "${CA_CERT}" ]]; then echo "    - ca-certificate: present"; fi
    if [[ -n "${DEST_CA_CERT}" ]]; then echo "    - destination-ca-certificate: present"; fi
    BACKED_UP=$((BACKED_UP + 1))
    continue
  fi
  
  # Build the secret creation command with only present fields
  # Use temporary files to safely handle certificate data
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf ${TEMP_DIR}" EXIT
  
  HAS_DATA=false
  if [[ -n "${CERT}" ]]; then
    echo -n "${CERT}" > "${TEMP_DIR}/tls.crt"
    HAS_DATA=true
  fi
  if [[ -n "${KEY}" ]]; then
    echo -n "${KEY}" > "${TEMP_DIR}/tls.key"
    HAS_DATA=true
  fi
  if [[ -n "${CA_CERT}" ]]; then
    echo -n "${CA_CERT}" > "${TEMP_DIR}/ca.crt"
    HAS_DATA=true
  fi
  if [[ -n "${DEST_CA_CERT}" ]]; then
    echo -n "${DEST_CA_CERT}" > "${TEMP_DIR}/destination-ca.crt"
    HAS_DATA=true
  fi
  
  if [[ "${HAS_DATA}" == "false" ]]; then
    echo "  ⊘ No certificate data to backup"
    SKIPPED=$((SKIPPED + 1))
    rm -rf "${TEMP_DIR}"
    continue
  fi
  
  # Add annotations to track source route and backup timestamp
  ANNOTATIONS="route.openshift.io/source-route=${ROUTE_NAME},backup.openshift.io/timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ),backup.openshift.io/tls-termination=${TLS_TERMINATION}"
  
  # Check if secret already exists and delete it
  if oc get secret "${SECRET_NAME}" ${NAMESPACE_FLAG} &>/dev/null; then
    echo "  → Updating existing secret..."
    oc delete secret "${SECRET_NAME}" ${NAMESPACE_FLAG}
  fi
  
  # Create the secret from files
  oc create secret generic "${SECRET_NAME}" \
    --from-file="${TEMP_DIR}/" \
    ${NAMESPACE_FLAG} &>/dev/null
  
  # Add annotations
  oc annotate secret "${SECRET_NAME}" ${ANNOTATIONS} ${NAMESPACE_FLAG} &>/dev/null
  
  # Add label for easy identification
  oc label secret "${SECRET_NAME}" backup.openshift.io/type=route-tls ${NAMESPACE_FLAG} &>/dev/null
  
  # Clean up temp files
  rm -rf "${TEMP_DIR}"
  
  echo "  ✓ Created/updated secret: ${SECRET_NAME}"
  BACKED_UP=$((BACKED_UP + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
echo "  Total routes processed: ${TOTAL_ROUTES}"
echo "  Certificates backed up: ${BACKED_UP}"
echo "  Routes skipped: ${SKIPPED}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo ""
  echo "This was a dry run. Run without --dry-run to create the secrets."
fi
