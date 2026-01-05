[![Merge](https://github.com/bcgov/quickstart-openshift-helpers/actions/workflows/merge.yml/badge.svg)](https://github.com/bcgov/quickstart-openshift-helpers/actions/workflows/merge.yml)

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

# ./oc_scripts

`rename_deployment.sh` - rename a deployment (metadata, labels)

`db_transfer.sh` - stream pg_dump from one container to pg_restore in another

## Example: Postgres Database Migration

These scripts can be used to migrate a postgres or postgis database.

Note: Make sure your template deploys the correct db version.  PR-based pipelines, which we strongly recommend, often require a merge before custom images are re-labeled.

```
# 1. Scale down or delete stack (non-db only)
# Use web console or cli

# 2. Rename the old db (`-prev` auto-appended)
./rename_deployment.sh your-db

# 3. Make sure old and new PVC names are different
# E.g. Append DB_VERSION in OpenShift template:
#  - kind: PersistentVolumeClaim
#    apiVersion: v1
#    metadata:
#      name: ${NAME}-${ZONE}-${COMPONENT}-${DB_VERSION}

# 4. Deploy the new db
oc process -f openshift.deploy.yml -p ZONE=test -p TAG=test \
  | oc apply -f -

# 5. Stream dump from old to new db
./db_transfer.sh your-db-prev your-db

# 6. Scale up stack or recreate deployments
# Use web console, GitHub Actions workflow or cli
```
