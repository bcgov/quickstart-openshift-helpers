# QuickStart OpenShift Helpers (Moving)

> [!IMPORTANT]
> **This repository is being moved!**
>
> Development and maintenance of these reusable workflows and scripts are being consolidated in [bcgov/actions-openshift](https://github.com/bcgov/actions-openshift).
>
> This repository will stay available until that transition is finished. Prefer the new paths below; pin a release tag, not `@main`.
>
> Reusable workflows:
> ```yaml
> jobs:
>   deploy:
>     uses: bcgov/actions-openshift/.github/workflows/.deployer.yml@vX.Y.Z
>   document-db:
>     uses: bcgov/actions-openshift/.github/workflows/.schema-spy.yml@vX.Y.Z
>   cleanup:
>     uses: bcgov/actions-openshift/.github/workflows/.pr-close.yml@vX.Y.Z
> ```
>
> Composite actions live in the same destination (`cleanup-pr`, `crunchy`, `deployer`, `oc-runner`, `route-tls`). Scripts live under [`scripts/oc/`](https://github.com/bcgov/actions-openshift/tree/main/scripts/oc) and [`scripts/cert/`](https://github.com/bcgov/actions-openshift/tree/main/scripts/cert).
