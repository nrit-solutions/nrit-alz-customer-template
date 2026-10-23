# Onboarding checklist

One line per step. Each link goes to the step in
[First plan to first apply](https://docs.nrit.cloud/setup/quickstart/), which
has the commands and what to expect.

1. The platform operator has run the bootstrap for this customer; see
   [Run the bootstrap](https://docs.nrit.cloud/setup/quickstart/#1-run-the-bootstrap).
2. Check the values in `live/customer.hcl` and `live/_foundation/env.hcl`; see
   [Set the customer values](https://docs.nrit.cloud/setup/quickstart/#2-clone-the-customer-repository-and-set-the-customer-values).
3. Generate and commit the provider lock files; see
   [Generate the provider lock files](https://docs.nrit.cloud/setup/quickstart/#generate-the-provider-lock-files).
4. Check the repository variables and secrets; see
   [Check the repo settings](https://docs.nrit.cloud/setup/quickstart/#3-repo-settings-the-bootstrap-does-not-cover)
   and [Secrets and variables](https://docs.nrit.cloud/reference/secrets-and-variables/).
5. Open `.github/CODEOWNERS` on GitHub and fix any owner it cannot resolve; see
   [Check the repo settings](https://docs.nrit.cloud/setup/quickstart/#3-repo-settings-the-bootstrap-does-not-cover).
6. Install the Renovate GitHub App on this repository only; see
   [Renovate](https://docs.nrit.cloud/reference/upgrades/#renovate).
7. Open the first pull request and comment `tfpr apply`; see
   [Open the first pull request](https://docs.nrit.cloud/setup/quickstart/#4-open-the-first-pull-request)
   and [First apply](https://docs.nrit.cloud/setup/quickstart/#5-first-apply).
8. Confirm the license variables are set, or `tfpr apply` is refused; see
   [License](https://docs.nrit.cloud/reference/license/).

A repository that cannot call an external workflow can vendor the engine
instead. The platform operator arranges this; see
[Vendored mode, the escape hatch](https://docs.nrit.cloud/reference/pr-ops-engine/#vendored-mode-the-escape-hatch).
