#!/bin/sh
set -euo nounset

# Custom Domain Helper
#
# Usage: ./custom_url.sh [optional: DOMAIN_WITH_PATH] [optional: OC_SERVICE]

# Sorry, internal! - https://apps.nrs.gov.bc.ca/int/confluence/display/DEVGUILD/Generating+a+CSR
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent


### Get inputs

# Vanity URL (domain with path)
if [[ -z "${1:-}" ]]; then
  echo "Enter the fully qualified domain name (FQDN) and any path/subdir for the certificate:"
  echo "  E.g. <app>.nrs.gov.bc.ca/<subdir>"
  read DOMAIN_WITH_PATH
else
  DOMAIN_WITH_PATH="${1}"
fi

# Break the URL into domain and (optional) path
[[ ${DOMAIN_WITH_PATH} =~ .*/$ ]] || DOMAIN_WITH_PATH="${DOMAIN_WITH_PATH}/"
DOMAIN=${DOMAIN_WITH_PATH%%/*}
SUBDIR=${DOMAIN_WITH_PATH#*/}

echo -e "\nDomain: ${DOMAIN}"
echo -e "Subdir: ${SUBDIR}\n"

# Service to route/expose
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
fi

# Install the certificate, modified slightly if a path is present
echo "Installing route"
# https://docs.openshift.com/container-platform/4.15/networking/routes/secured-routes.html#nw-ingress-creating-an-edge-route-with-a-custom-certificate_secured-routes
if [ -z "${SUBDIR}" ]; then
  oc create route edge --service=${SERVICE} --cert=${DOMAIN}.cert --key=${DOMAIN}.key --ca-cert=${DOMAIN}.ca-cert --hostname=${DOMAIN} ${SERVICE}-vanity
else
  oc create route edge --service=${SERVICE} --cert=${DOMAIN}.cert --key=${DOMAIN}.key --ca-cert=${DOMAIN}.ca-cert --hostname=${DOMAIN} --path=${SUBDIR} ${SERVICE}-vanity
fi

# Visit and confirm the new route
echo -e "\nWould you like to be redirected to the new route?"
echo -e " => https://${DOMAIN_WITH_PATH} (y/n)"
read ACCEPT
if [[ "${ACCEPT}" =~ [Yy] ]]; then
  xdg-open "https://${DOMAIN_WITH_PATH}"
fi
