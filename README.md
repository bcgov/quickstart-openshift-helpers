# QuickStart OpenShift Helpers (Moving)

> [!IMPORTANT]
> **This repository is being moved!**
>
> Development and maintenance of these reusable workflows and scripts are being consolidated in [bcgov/actions-openshift](https://github.com/bcgov/actions-openshift).
>
> This repository will stay available until that transition is finished. Prefer the new paths below; pin a release tag, not `@main`.
>
> Composite actions: [`cleanup-pr`](https://github.com/bcgov/actions-openshift/tree/main/cleanup-pr), [`crunchy`](https://github.com/bcgov/actions-openshift/tree/main/crunchy), [`deployer`](https://github.com/bcgov/actions-openshift/tree/main/deployer), [`oc-runner`](https://github.com/bcgov/actions-openshift/tree/main/oc-runner), [`route-tls`](https://github.com/bcgov/actions-openshift/tree/main/route-tls).
>
> Scripts: [`oc/`](https://github.com/bcgov/devops-scripts/tree/main/oc) (including the Postgres migration walkthrough) and [`cert/`](https://github.com/bcgov/devops-scripts/tree/main/cert) in [bcgov/devops-scripts](https://github.com/bcgov/devops-scripts).
>
> SchemaSpy remains a reusable workflow: `bcgov/actions-openshift/.github/workflows/.schema-spy.yml@vX.Y.Z`. PR title validation lives in [`bcgov/actions/pr-validate`](https://github.com/bcgov/actions/tree/main/pr-validate).
>
> Moving from `.pr-validate.yml` to `bcgov/actions/pr-validate`: it is a step (`- uses: bcgov/actions/pr-validate@vX.Y.Z`), not a reusable workflow. `reject_forks` is gone: fork PRs now get a warning and validation continues, instead of failing. `markdown_links` is now `add_markdown`, which takes the full Markdown to append rather than a list of links wrapped in a template. `conventional_commits` is unchanged.
>
> Helpers `.deployer.yml` is not moving. Existing pins on helper tags keep working; new work uses the [`deployer`](https://github.com/bcgov/actions-openshift/tree/main/deployer) action.
