#!/bin/sh
set -euo nounset

# Custom Domain Helper
#
# Usage: ./custom_url.sh [optional: DOMAIN]

# Sorry, internal! - https://apps.nrs.gov.bc.ca/int/confluence/display/DEVGUILD/Generating+a+CSR
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent


### Get inputs

# Vanity URL (DOMAIN)
if [[ -z "${1:-}" ]]; then
  echo "Enter the fully qualified domain name (FQDN) name for the certificate:"
  echo "  E.g. <app>.nrs.gov.bc.ca"
  read DOMAIN
else
  DOMAIN="${1}"
fi
echo -e "\nDomain: ${DOMAIN}\n"

# Vanity URL (DOMAIN)
if [[ -z "${2:-}" ]]; then
  echo "Enter the OpenShift service name to expose:"
  echo "  E.g. nr-<app>-prod-frontend"
  read SERVICE
else
  SERVICE="${2}"
fi
echo -e "\nService: ${SERVICE}\n"

# Confirm
echo "Please make sure the following files are present before continuing:"
echo "${DOMAIN}.cert"
echo "${DOMAIN}.key"
echo "${DOMAIN}.ca-cert"

echo -e "\nContinue? [y/n]"
read ACCEPT
if [[ ! "${ACCEPT}" =~ [Yy] ]]; then
  echo "Exiting..."
  exit 1
else
  # https://docs.openshift.com/container-platform/4.15/networking/routes/secured-routes.html#nw-ingress-creating-an-edge-route-with-a-custom-certificate_secured-routes
  echo "Installing route"
  oc create route edge --service=${SERVICE} --cert=${DOMAIN}.cert --key=${DOMAIN}.key --ca-cert=${DOMAIN}.ca-cert --hostname=${DOMAIN} ${SERVICE}-vanity
fi
