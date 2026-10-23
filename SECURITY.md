# Security

## Reporting a vulnerability

Report security problems in this repository's own files (units, hierarchy
files, workflows, hooks) to the platform operator who created the repository,
through the support channel agreed with them. Do not open a public issue for
a vulnerability.

Problems in the PR-ops engine belong with the engine, not here. Its public
entry point is `nrit-solutions/tfpr`; see the troubleshooting page at
https://docs.nrit.cloud/reference/troubleshooting/ for the route.

## What this repository protects

- Cloud credentials never live in this repository. Workflows authenticate
  with OpenID Connect; secrets and variables are repository settings, listed
  at https://docs.nrit.cloud/reference/secrets-and-variables/.
- Plan files, state, `.env` files, keys and non-example `.tfvars` files are
  ignored and blocked by the repository invariants hook.
- Every change reaches Azure through a pull request, a posted plan, a review
  and an explicit apply command. The controls are described at
  https://docs.nrit.cloud/overview/security/.
