[![Merge](https://github.com/bcgov/quickstart-openshift-helpers/actions/workflows/merge.yml/badge.svg)](https://github.com/bcgov/quickstart-openshift-helpers/actions/workflows/merge.yml)
[![PR Closed](https://github.com/bcgov/quickstart-openshift-helpers/actions/workflows/pr-close.yml/badge.svg)](https://github.com/bcgov/quickstart-openshift-helpers/actions/workflows/pr-close.yml)

# QuickStart OpenShift - Helpers
Workflows and any other common code used by bcgov/quickstart-openshift (template).

# Breaking Changes

`oc_server` has been moved to a secret.  It is an optional field, only affecting some users.

Example using shared workflow .pr-close.yml:
```
jobs:
  cleanup:
    name: Cleanup and Image Promotion
    uses: bcgov/quickstart-openshift-helpers/.github/workflows/.pr-close.yml@vX.Y.Z
    permissions:
      packages: write
    secrets:
      oc_namespace: ${{ secrets.OC_NAMESPACE }}
      oc_server: ${{ secrets.OC_SERVER }}   # ADDED - OPTIONAL!
      oc_token: ${{ secrets.OC_TOKEN }}
    with:
      cleanup: helm
      packages: backend client migrations
      oc_server: ${{ secrets.OC_SERVER }}   # REMOVED - OPTIONAL!
```
