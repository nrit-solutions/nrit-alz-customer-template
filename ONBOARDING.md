# Onboarding checklist

The checklist for standing up a customer landing zone in a repository the
bootstrap created from the customer template. The full walkthrough, with the
commands and what to expect at each step, is
[First plan to first apply](https://docs.nrit.cloud/setup/quickstart/). The
bootstrap run itself is on
[Bootstrap a customer](https://docs.nrit.cloud/setup/bootstrap/), and what it
needs before it starts is on
[Prerequisites](https://docs.nrit.cloud/setup/prerequisites/).

## 1. Run the bootstrap

The operator runs `nrit-solutions/nrit-alz-bootstrap` once per customer, with
`scripts/onboard.sh`. It generates this repository from the template and
creates the state backend, the plan and apply identities, the `plan` and
`apply` environments, the repository variables (the license pair included), the
`require-approved-pr-to-main` ruleset, and the self-hosted runner when the
posture asks for one. It also writes `live/customer.hcl` and
`.github/CODEOWNERS` once. This repository owns both files after that, and a
bootstrap re-run never overwrites them.

## 2. Check the customer values

- `live/customer.hcl`: `tenant_root_id`, `location`, `location_short`,
  `business_unit`, and `amba_action_group_email`. Get `tenant_root_id` right
  before the first apply. Changing it later moves the whole hierarchy, which is
  a migration, not an edit. `amba_action_group_email` must be a monitored inbox.
- `live/_foundation/region.hcl`: `environment` defaults to `prod` and becomes
  the `env` tag. The tag policy allows `prod`, `staging`, and `dev`.
- `live/_foundation/landing-zones/main.tf`: set `connectivity_subscription_id`
  when the customer has a connectivity subscription. Leave `architecture_name`
  as `nrit` unless you add a second architecture to the vendored library.

The tenant id, subscription ids, and backend names come from repository
variables the bootstrap wrote. The placeholders in `live/tenant.hcl` and
`live/_foundation/subscription.hcl` are for local runs only. See
[Secrets and variables](https://docs.nrit.cloud/setup/secrets-and-variables/).

## 3. Generate the provider lock files

The template ships no `.terraform.lock.hcl` files, so this repository pins its
providers now, at current versions. Commit them with the value changes above:

```sh
for u in live/_foundation/*/; do
  terragrunt --working-dir "$u" init -backend=false
  TG_NO_AUTO_INIT=true terragrunt --working-dir "$u" run -- providers lock -platform=darwin_arm64 -platform=linux_amd64
done
```

Replace `darwin_arm64` with your own platform if it differs. Keep
`linux_amd64`: the runner's provider cache needs those hashes. Why the template
ships none, and how to move a provider later, is on
[Provider lock files](https://docs.nrit.cloud/reference/versions/#provider-lock-files).

## 4. Check the repository settings

Check each item in
[Repo settings the bootstrap does not cover](https://docs.nrit.cloud/setup/quickstart/#3-repo-settings-the-bootstrap-does-not-cover):

- `TFPR_LICENSE` and `TFPR_ENTITLEMENT` are set, and `AZURE_TENANT_ID` is the
  tenant the entitlement is bound to. Without them `/apply` is refused. See
  [License](https://docs.nrit.cloud/operations/license/).
- The checks App is installed on the organization.
- `INFRACOST_API_KEY` is set if the customer wants cost estimates.
- `tf-pr-ops / merge-gate` is a required status check on `main`.
- A single-writer organization has `TFPR_ALLOW_UNREVIEWED_APPLY` set to `true`
  by the bootstrap. Never set it by hand.

## 5. Check the code owners

`.github/CODEOWNERS` gives `.github/` and `projects.yml` to the apply approvers
team the bootstrap created. Open the file on GitHub: it flags an owner it
cannot resolve, and GitHub skips that line, so the path then needs no owner
review. A single-writer organization sets `require_code_owner_review = false`
in its bootstrap tfvars.

## 6. Install Renovate

Install the Renovate GitHub App on this repository only.
`.github/renovate.json` then opens the engine bump pull requests. When GitHub
sends you to developer.mend.io to onboard the organization, choose interactive
mode: silent mode opens no pull requests. See
[Renovate](https://docs.nrit.cloud/reference/versions/#renovate).

## 7. First plan and first apply

Open a pull request with the changes from steps 2 and 3. Review the plans,
get the approval, and comment `/apply`. The foundation applies in dependency
order: `management-resources`, then `landing-zones`, then `amba`. The first
apply can take sixty to ninety minutes in a tenant with existing policy state.
See [Plan and apply](https://docs.nrit.cloud/operations/plan-and-apply/), then
[Growing the tree](https://docs.nrit.cloud/operations/growing-the-tree/) for
the connectivity hub and the first landing zones.

## License of this repository

`LICENSE` is Apache-2.0 and covers this repository's files only. The engine
and its `/apply` license have separate terms; see
[License](https://docs.nrit.cloud/operations/license/).

## Vendoring the engine

A repository that cannot call an external workflow can vendor the engine
instead. This needs read access to the private engine source, which the
operator arranges. See
[Vendored mode, the escape hatch](https://docs.nrit.cloud/setup/pr-ops-engine/#vendored-mode-the-escape-hatch).
