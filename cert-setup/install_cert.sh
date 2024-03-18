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
  read DOMAIN
else
  DOMAIN="${1}"
fi
echo -e "\nDomain: ${DOMAIN}"

set -x
# https://docs.openshift.com/container-platform/4.15/networking/routes/secured-routes.html#nw-ingress-creating-an-edge-route-with-a-custom-certificate_secured-routes
oc create route edge --service=nr-forest-client-test-frontend --cert=${DOMAIN}.cert --key=${DOMAIN}.key --ca-cert=${DOMAIN}-L1K_Chain.txt --hostname=${DOMAIN}
