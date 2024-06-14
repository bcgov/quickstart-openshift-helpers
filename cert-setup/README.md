# Setting Up a Vanity or Custom URL

## Generating a Request

Ticketing and administrative steps are for the Natural Resources only.  Other ministries will have their own processes.

Steps:
1. Create a certificate signing request (CSR) using `./scr_generator.sh`.
2. Create a [JIRA issue](https://apps.nrs.gov.bc.ca/int/jira/secure/CreateIssue!default.jspa).
3. Provide details, which are glossed over in the script from step 1.
4. Attached the CSR file generated in step 1.
5. Wait, answering questions or following up as necessary.

## Installing the Certificate

These steps should work for any OpenShift (and hopefully Kubernetes!) setup.  Certificates must have already been provided by your ministry's administrators.

Files required:
- <DOMAIN>.csr file from `Generating a Request`
- <DOMAIN>.key file from `Generating a Request`
- <DOMAIN>.cert file provided by your administrators
- <DOMAIN>.ca-cert file provided by your administrators

Steps:
1. Ensure all required files are on hand
2. Ensure any L1k (ca-cert) files are renamed <DOMAIN>.ca-cert
3. Login to [OpenShift](https://console.apps.silver.devops.gov.bc.ca/k8s/cluster/projects)
4. Switch to the appropriate namespace: `oc project <namespace>`
5. Install the certificate using `./install_cert.sh`

## Reinstall and Renewals

Retain all four certificate-related files (csr, key, cert, ca-cert).  All four are required for reinstallation or recovery of deleted OpenShift routes.  The csr and key files are required with future certificate renewals.  Use `./install_cert.sh` as required.


## Reference

[How do I get a custom vanity URL for my application in Openshift?](https://stackoverflow.developer.gov.bc.ca/questions/172/176)

[Creating government web presences](https://www2.gov.bc.ca/gov/content/governments/services-for-government/service-experience-digital-delivery/digital-delivery/web-property-process)

[Order Domain Name Registration and Domain Name Services Article](https://ociomysc.service-now.com/sp?id=ocio_sr_kb_article_view&sysparm_article=KB0031620&sys_kb_id=c66a12a8db4c0510fa8619381396197f&spa=1)

[OCP 4 platform network topology](https://digital.gov.bc.ca/cloud/services/private/internal-resources/topology/)

[SSL Certificates for https://system.eao.gov.bc.ca/](https://apps.nrs.gov.bc.ca/int/jira/browse/SD-96171)

[How to update route TLS certificate from CLI?](https://stackoverflow.developer.gov.bc.ca/questions/239)
