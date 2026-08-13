# Changelog

Per-customer changelog for repositories generated from this template. Records
version bumps (AVM modules, the ALZ and AMBA library refs, the engine caller
pins) and when new workloads are added.

Template changes only reach repositories stamped after they merge. Each entry
therefore states whether existing customer repositories need the change
backported, or whether only new stamps get it.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- The engine pins move from `v3.2.2` to `v3.3.1` in all four callers.
  What changes for operators: apply refuses a unit whose plan changed
  since the reviewed plan (`/apply --force` overrides), units whose
  reviewed plan shows no changes are skipped during apply, the apply job
  installs the `TFPR_EXTRA_TOOLS` gate tools, and superseded reports and
  check rows are outdated per command instead of globally. No caller
  contract change: backporting is the pin edit alone, and an
  un-backported repository keeps working on its old pins.

- The drift caller grants `pull-requests: read`: v3.2.2's lock-sweep job
  reads holder PR state, and a called job requesting an ungranted
  permission fails the whole drift run at startup. Existing customer
  repositories on v3.2.2 need this one line backported or their nightly
  drift fails at startup. New stamps get it automatically.

- The engine pins move from `v3.2.1` to `v3.2.2`, the audit sweep release,
  and the closed-event unlock moves to a new `tf-pr-ops-unlock.yml`
  workflow (the PR caller drops `closed` and its exemptions), so merged
  PRs stop showing a skipped pre-commit row and a duplicate dispatch row.
  Existing customer repositories should backport the whole set together
  (bump the three pins, add `tf-pr-ops-unlock.yml`, re-sync
  `tf-pr-ops-pr.yml`); an un-backported combined caller keeps working,
  it just keeps the two noise rows. New stamps get it automatically.

- The engine pins move from `v3.2.0` to `v3.2.1` in all three workflows:
  unit lock reclaim and release are now conditional on the lock row's
  ETag, so two pull requests racing to reclaim a closed PR's lock can no
  longer both report acquired and apply the same unit. Lock row keys
  change format; a lock held across the bump is invisible to the new
  engine until its PR closes, and `/unlock` covers leftovers. The caller
  contract is unchanged, so existing customer repositories backport this
  as a plain pin bump, ideally with no open PRs holding unit locks.

- The engine pins move from `v3.1.1` to `v3.2.0` in all three workflows,
  the Go port release: event parsing, the changed-file diff, the
  removed-unit check, the project runner and the ordered apply walk now
  run inside the tfpr binary instead of shell scripts. The removed-unit
  check skips itself when the diff cannot have removed a unit, plan
  reports render from the plan's own output (warnings now reach the
  report), and an empty plan on the apply path skips the apply. The
  caller contract is unchanged, so existing customer repositories
  backport this as a plain pin bump.

- The engine pins move from `v3.0.6` to `v3.1.1` in all three workflows,
  the performance release: engine jobs download a prebuilt, checksummed
  tfpr binary from the release instead of compiling it per job, and the
  drift, comment, and lock paths drop redundant API round-trips. The PR
  caller passes the engine app credentials to the dispatch action so its
  job uses the prebuilt binary too; the inputs are optional and empty
  values build from source. Existing customer repositories should
  backport the pin bump and the two new dispatch-action inputs together.
  Do not pin v3.1.0: its within-job provider cache fails init on units
  whose lock files carry no linux h1 hashes, and v3.1.1 backs it out.

- The engine pins move from `v3.0.5` to `v3.0.6` in all three workflows:
  the engine pages through the check-run listing instead of reading one
  page, so a pull request with more than 100 check runs on one commit no
  longer ends up with a stuck per-unit check, a missed leftover sweep, or
  a duplicated merge-gate row. Existing customer repositories should
  backport the pin bump.

- The engine pins move from `v3.0.4` to `v3.0.5` in all three workflows:
  the changed-file diff is quote-proof (non-ASCII and quoted paths no
  longer bypass change detection and the merge gate), renames plan both
  the source and destination unit, the diff targets the pinned head SHA,
  and fork pull requests are rejected explicitly. Pin bump only; existing
  customer repositories should backport it.

- `check-repo-invariants.sh` reads git paths NUL-separated (synced from
  the platform-skills tooling bundle): a unit holding a non-ASCII path
  was falsely blocked as "not a unit", and the generated-file and secret
  checks silently skipped such files. Backport with the pin bump.

- The engine pins move from `v3.0.3` to `v3.0.4` in all three workflows:
  the apply job completes its per-unit checks with the checks App token,
  so a successful apply renders as a completed check. Pin bump only.

- The engine pins move from `v3.0.2` to `v3.0.3` in all three workflows:
  the removed-unit PR comment now reflows instead of rendering
  hard-wrapped fixed-width lines. Pin bump only; backport by bumping the
  same pins.

- The engine moves from `v2.1.0` to `v3.0.2`, the v3 PR surface. The single
  `terraform-pr-ops.yml` caller and `lint.yml` are replaced by the
  three-file set: `tf-pr-ops-pr.yml` (the repository's pre-commit hooks as
  the first job, gating a `dispatch` job that runs the engine's dispatch
  composite action; the changelog reminder moves with it), `tf-pr-ops.yml`
  (comment commands and dispatched work), and `drift.yml` (pin bump only).
  Every engine-authored row on a PR carries the `tf-pr-ops /` prefix under
  the checks App identity; the merge gate and approval are App check runs
  instead of commit statuses, names unchanged, so a ruleset requiring
  `tf-pr-ops / merge-gate` by name needs no edit. **Backport required** for
  existing customer repositories: replace the two old workflow files with
  the three new ones and rename any `TF_PR_OPS_*` repository variables to
  `TFPR_*` (five: `DISABLE_LOCKS`, `ALLOW_UNREVIEWED_APPLY`,
  `PLAN_ENVIRONMENT`, `APPLY_ENVIRONMENT`, `UNLOCK_ENVIRONMENT`). The
  checks App is now required for the merge gate to carry the engine
  identity; provisioning it joins onboarding
  (nrit-alz-bootstrap#19).

- The engine caller pins move from `v2.0.0` to `v2.1.0` in both workflows.
  The minor adds the optional dedicated checks App: when a stamped
  repository carries `TFPR_CHECKS_APP_CLIENT_ID` and
  `TFPR_CHECKS_APP_PRIVATE_KEY` (the `tf-pr-ops` App, Checks read/write,
  installed on the repo), per-unit checks render under the App's heading
  instead of an arbitrary workflow's. Unset, nothing changes, so existing
  customer repositories can take this as a plain pin bump; wiring the App
  into the bootstrap is tracked separately. Verified on the reference
  tenant (App-owned check on a draft PR, drift sweep on the new pin).

- The engine caller pins move from `v1.17.0` to `v2.0.0` in both workflows.
  The major carries two caller changes, both included here: the permissions
  ceiling gains `actions: write`, and `workflow_dispatch` declares and
  forwards four engine-set dispatch inputs. A pull request plan now runs as
  a thin dispatcher, so every per-unit check on the PR is engine-named
  (`plan / <label> #<run>`); the merge-gate and approval status contexts
  are unchanged, so rulesets need no edit. Existing customer repositories
  need this backported: the caller edits are required, a bare pin bump is
  not enough. Verified on the reference tenant with a dispatched
  pull_request plan, a comment-path plan, the lock release on close, and a
  full drift sweep.

- The engine caller pins move from `v1.16.0` to `v1.17.0` in both workflows.
  The last GitHub-facing script families (command authorization, the /apply
  approval gate, the reactions, the unlock confirmation, the drift-issue
  reporter) run compiled, and the shell fallbacks for everything ported
  earlier are retired. Behaviour is unchanged and nothing changes in a
  consumer repository. Verified on the reference tenant with a comment-path
  plan and a full drift sweep on the new pin.

- The engine caller pins move from `v1.15.0` to `v1.16.0` in both workflows.
  The two commit statuses the engine owns, the merge gate and the
  informational approval status, are now written by the compiled engine part
  (`tfpr`), decision table unchanged; a failed review-decision lookup now
  errors instead of reporting as no-reviews-required. Nothing changes in a
  consumer repository. Verified on the reference tenant with a comment-path
  plan (gate flipped to blocked by the compiled writer) and a full drift
  sweep on the new pin.

- The engine caller pins move from `v1.14.0` to `v1.15.0` in both workflows.
  The per-project check runs on comment-triggered plans and applies
  (creation, completion, and the leftover sweep) now go through the compiled
  engine part (`tfpr`). Requests to GitHub are identical to before; nothing
  changes in a consumer repository. Existing customer repositories take this
  as a normal pin bump backport; verified on the reference tenant with a
  comment-path plan (checks created and completed by the compiled engine)
  and a full drift sweep on the new pin.

- The engine caller pins move from `v1.13.0` to `v1.14.0` in both workflows.
  The pull-request comment surface now goes through the compiled engine part
  (`tfpr`): the run reports, the outdated-report sweep, and the moved-head
  verification before any project code runs. Requests to GitHub are identical
  to before; nothing changes in a consumer repository. Existing customer
  repositories take this as a normal pin bump backport; verified on the
  reference tenant with a two-run smoke at the engine sha and a full drift
  sweep on the new pin.

- The engine caller pins move from `v1.12.0` to `v1.13.0` in both workflows.
  The run report on pull requests and drift issues is now rendered by the
  same compiled engine part (`tfpr`) that already does discovery, with output
  byte-identical to before. Nothing changes in a consumer repository: no new
  variables, tools, or permissions. Existing customer repositories take this
  as a normal pin bump backport; verified on the reference tenant with a
  smoke plan at the engine sha and a full drift sweep on the new pin.

- The engine caller pins move from `v1.11.2` to `v1.12.0` in both workflows.
  Project discovery now runs a compiled part of the engine (`tfpr`), built in
  the run from the pinned engine source. Nothing changes in a consumer
  repository: no new variables, tools, or permissions. Existing customer
  repositories take this as a normal pin bump backport; verified on the
  reference tenant with a full drift sweep on the new pin.

- The engine caller pins move from `v1.11.1` to `v1.11.2` in both workflows.
  Drift issues no longer show the `/apply` and `/unlock` instructions block.
  Those commands are only answered on a pull request, so on an issue they
  started no run and posted no reply, which read as queued. The issue now says
  to open a pull request instead, and to read the plan before acting on it.
  Existing customer repositories should backport the two-line pin change.

- The changelog reminder moves out of its own `changelog.yml` workflow and into
  the existing `lint.yml` pre-commit job as a step. Same trigger and same
  warning, one fewer workflow and one fewer check row on every pull request. It
  still only warns; the pre-commit hooks in that job are what fail. New stamps
  get this automatically. Existing customer repositories should backport it if
  the pull request surface matters to them, but nothing breaks if they do not:
  the old workflow keeps working as it always did.

- The engine caller pins move from `v1.11.0` to `v1.11.1` in both workflows.
  The plan matrix now runs in a called workflow, so its checks read
  `tf-pr-ops / engine / plan / <label>` instead of
  `tf-pr-ops / engine / plan (<label>)`, and a run that does not plan reports a
  plain `tf-pr-ops / engine / plan` where it used to print an unexpanded name
  template. The `help` and `unauthorized` jobs merged into `comment-reply`. The
  `tf-pr-ops / merge-gate` status context, the required check, is unchanged, so
  branch protection needs no edit. Existing customer repositories should
  backport the two-line pin change per engagement.

### Fixed

- The corp landing zone README told you to name a new subscription folder
  `corp-workload/`, which has no environment segment and so breaks the
  documented `<archetype>-<purpose>-<environment>` convention. The example is
  now `corp-payments-prod/`, with the shape and the allowed environment values
  stated inline. The same stale name in the two Terragrunt skill tree diagrams
  is corrected, synced from `nrit-alz-platform-skills`. **Backport optional**:
  documentation only, nothing deployed changes, but a stamped repository that
  followed the old example has a subscription folder worth renaming. Read the
  runbook before moving one: the folder is the state key.

### Changed

- The engine caller pins move from `v1.9.2` to `v1.11.0`. The v1.9.3 patch
  closes a silent failure: deleting a whole unit directory used to do nothing.
  Discovery walks the branch's own tree, so a deleted unit was never discovered,
  never planned and never destroyed, and with nothing selected the merge gate
  called the pull request "No Terraform changes" and let it merge, leaving the
  live resources and the state blob behind with no warning. Every run now also
  discovers the base branch's tree and reports a unit that is missing here,
  naming it in a pull request comment. A rename, or a new `projects.yml`
  exclude, reads the same way and has the same effect.

  v1.11.0 then settled what that report does. v1.9.3 failed the gate, and there
  was no way to clear the failure except restoring the directory, so a
  legitimate removal had no path to a green gate at all. The removal is now
  reported and does not block, and the comment carries the commands to destroy
  the unit by hand from a local checkout. The gate grants that pass only when
  the removal accounts for every changed Terraform path, so removing one unit
  while adding another still blocks on the one that was added.

  **Backport strongly recommended.** This is the failure mode most likely to
  lose a customer's resources quietly, and the gate cannot tell you about a
  removal that already merged. After backporting, a pull request that deletes a
  unit merges as before, but now says so and tells the author what is left to
  clean up.

- v1.10.0 rides along in the same bump. A command comment gets a single 👀
  reaction instead of 👀 then 🚀 then 🎉 or 👎, and the apply output is filtered
  down to the real actions the way the plan output already was.

  One part of it matters beyond cosmetics. infracost used to leave the decision
  about uploading run results to a remote Infracost Cloud organisation setting,
  which in a customer's own account is not ours to control, and the breakdown it
  would upload carries the commit sha, author name, author email and message.
  The engine now sets that off itself instead of inheriting a default. Region
  and SKU still reach the hosted pricing API to look up prices, which is the
  accepted position and is unchanged. **Backport recommended for any stamped
  repository that sets `TFPR_EXTRA_TOOLS` to include infracost.**
  Validated on nrit-alz-live.
- The engine caller pins move from `v1.9.1` to `v1.9.2`. The patch carries the
  robustness batch of the 2026-08-04 engine review: one total size budget for
  report comments so a large plan cannot lose the report to GitHub's 65536
  character cap, leftover check runs completed as cancelled instead of hanging
  `in_progress` forever, discovery de-duplicated into one implementation with
  the bare-directory exclusion bug fixed, `tf_changed` extended to every
  Terraform file type, and a sweep of smaller fixes including SHA-pinned
  third-party actions and Dependabot.

  Two changes are visible to users. `/apply` and `/unlock` now require write
  permission on the repository rather than organisation membership alone, so a
  stamped repo whose appliers hold membership without write must grant write
  before they can apply again. And per-project check runs are renamed to carry
  the run number (`plan (<label>) #128`); the two required statuses,
  `tf-pr-ops / merge-gate` and `tf-pr-ops / approval`, are unchanged, so this
  only matters if a stamped repo made a per-project check required in branch
  protection.

  **Backport recommended**: `tf_changed` and the comment size budget both close
  ways a change could reach main unplanned or unreported. Check the two
  behaviour changes above against the repo's collaborators and branch
  protection before backporting. Validated on nrit-alz-live.
- The engine caller pins move from `v1.9.0` to `v1.9.1`. The patch carries
  the urgent batch of the 2026-08-04 engine review: filtered runs (`-p`) no
  longer write the merge gate, approval is re-checked at the top of the apply
  job, the catalog token and plan files are cleaned up per job (relevant on
  persistent runners), and the fallback Terragrunt is now 1.1.2 with a
  checksum-verified, arch-aware install (minimum supported 0.91.3).
  **Backport recommended**: the merge-gate fix closes a real bypass; validated
  on nrit-alz-live.
- The engine caller pins move from `v1.8.0` to `v1.9.0`. Outdated run
  reports are now minimized by default with an Outdated banner linking to
  the report that replaced them; only the latest report per unit reads at
  full size. A repository that wants the old always-full-size trail sets
  the `TFPR_MINIMIZE_OUTDATED` variable to `false`. **Backport optional**:
  comment UX only, nothing breaks on v1.8.0.
- The engine caller pins move from `v1.7.0` to `v1.8.0`. The digger comment
  aliases are gone: slash commands only (`/plan`, `/apply`, `/unlock`,
  `/help`); a digger-prefixed comment gets no reply. **Backport optional**:
  nothing breaks in a repository staying on v1.7.0, but operators used to
  the aliases should know they end here.
- The engine caller pins move from `v1.6.1` to `v1.7.0`. Comment-UX and
  locking release: one-line result headlines in the run report, the hook
  section renamed to "Validation checks", `/unlock` in the instructions,
  `/help`, a reply on a `-p` selector that matches nothing, change counts in
  the per-project check titles, opt-in minimizing of outdated report comments
  (`TFPR_MINIMIZE_OUTDATED` repository variable, unset by default), and
  stale-lock reclaim at acquire time so a lock whose holder PR is already
  closed cannot hold a unit hostage. No caller or variable changes.
  **Backport recommended**: the stale-lock reclaim closes a real operational
  hole (a missed close event orphaned the unit lock until a manual
  `/unlock`); the rest is comment UX a repository works fine without.
  Validated on the reference tenant (nrit-alz-live PR #115 pre-release,
  PR #116 on the tag).

- The policy gate now ships with nothing active. `policy/governance.rego` and
  the `examples/policy/` folder are gone, replaced by a single
  `policy/tags.rego.example`. The gate globs `policy/*.rego`, which that name
  does not match, so a freshly stamped repository reports "no policies found"
  and passes until someone drops the suffix. **Backport optional**: it changes
  what a repository ships, not how it behaves, since the old
  `governance.rego` was warn-only and blocked nothing.

  The example is a shift-left mirror of the ALZ `Enforce-Tag-Gov` assignment,
  proven against real infrastructure before it shipped: deny on the four
  `rgMandatoryTags` keys and on values outside the allowed sets, warn on the
  three keys a Modify rule inherits from the subscription. It also absorbs the
  destroy warning that was `governance.rego`'s only rule.

  Activate with `git mv policy/tags.rego.example policy/tags.rego`, and read
  what it denies first. Turning it on against an estate that is not yet tagged
  blocks pull requests until the estate is clean, so the usual order is to
  demote the deny rules to `warn`, clear the findings, then promote them back.

  It ships inert on purpose. A template that shipped a blocking tag policy
  would stop a new customer's first pull request, which is the opposite of the
  report-only-by-default posture every other gate here takes.

- The engine caller pins move from `v1.6.0` to `v1.6.1`. **Backport
  recommended for existing customer repositories**, though nothing breaks
  without it: v1.6.1 only changes how a failed hook is reported.

  A failing hook used to mangle its own report and, more importantly, replace
  the plan with the hook error. A policy denial therefore hid the diff needed
  to judge it. The plan now survives the failure, with its summary table.

- The engine caller pins move from `v1.5.0` to `v1.6.0`, in both
  `.github/workflows/terraform-pr-ops.yml` and `drift.yml`. **Backport
  required for existing customer repositories.**

  v1.6.0 fixes a conftest policy gate that has never run in any repository
  stamped from this template. The engine resolved its policy directory
  relative to its own script location, which in reusable mode is the engine
  checkout rather than the customer repository, so every run reported
  ``No policies found in `.tfpr-engine/policy`; skipped`` and passed. The
  `policy/governance.rego` this template ships has therefore never been
  evaluated anywhere, and the plan-time gate has been checkov-only in
  practice.

  The shipped policy is `warn`-only, so after the bump it reports without
  blocking the merge gate. Before backporting a repository that has added its
  own rego, check it for `deny` rules: a `deny` that was silently passing will
  start failing the hook and blocking the merge gate. Repositories the
  bootstrap provisioned already have conftest available, from the runner image
  on the private posture and from `TFPR_EXTRA_TOOLS` on the hosted one, so no
  variable changes with this bump.

### Removed

- The in-repo `docs/` folder. Its five pages had drifted against the copies in
  `nrit-alz-live`, in both directions, which is exactly the failure a
  duplicated doc invites. The public docs site is now the single source:
  everything the pages covered lives there, including a new "Sharing data
  between units" page and the multi-region and deploy-order material merged
  into the foundation-units page. `README.md`, `ONBOARDING.md`, and
  `AGENTS.md` link to the site instead. Backport: recommended for existing
  customer repositories; delete `docs/` and copy the updated `AGENTS.md`,
  nothing else changes.

### Added

- Pre-commit hooks, in `.pre-commit-config.yaml`, and a `lint` workflow that runs
  the identical set on every pull request and fails. The hooks are formatting
  (`terraform fmt`, `terragrunt hcl fmt`, whitespace, line endings), `tflint`,
  `checkov`, and `.github/scripts/check-repo-invariants.sh`. Enable them with
  `pre-commit install`; the workflow is what catches a commit made without them.
  Backport: optional, only new stamps need it, though an existing customer
  repository gains the invariants below by copying the same five files.
- `.github/scripts/check-repo-invariants.sh`, guarding five things no linter covers: a
  generated `backend.tf`, `providers.tf`, or `context.tf` staged by hand (each
  carries the resolved tenant and subscription ids and is excluded by
  `.gitignore`, so this only fires when something forced it in), Terraform state,
  a `terragrunt.stack.hcl`, and a directory holding Terraform but no
  `terragrunt.hcl`. The last two are the silent failures worth catching early:
  discovery skips the directory, so the pull request plans nothing, every gate
  passes with nothing to gate, and it merges green having deployed nothing. A
  fifth check, a unit with no `.terraform.lock.hcl`, warns rather than fails,
  because a freshly stamped repository has none until onboarding runs.
- `.tflint.hcl` and `.checkov.yaml`. Both disable checks that this repository's
  shape makes permanently unsatisfiable rather than leaving them to fail on every
  run: `terraform_required_providers` and `terraform_required_version`, because
  `providers.tf` is generated by `root.hcl` and never in the source tree, and
  `CKV_TF_1`, because registry sources cannot carry a commit hash. In exchange
  `terraform_module_version` is set to `exact`, which enforces the exact-version
  rule on every Azure Verified Module call.
- ONBOARDING step 3 covers a third kind of version: generating a
  `.terraform.lock.hcl` per unit and committing them. Both Terragrunt and
  HashiCorp say to commit these, and Terragrunt copies the file into its run
  directory and back out again, so it is what actually decides the provider
  versions. Nothing pinned them before: the generated `providers.tf` carries only
  `~>` constraints, so every plan and every apply re-resolved and `/apply` could
  run a different provider version than the plan under review.

  This template deliberately ships no lock files. A lock file records the exact
  versions resolved at the moment it is written, so pre-generating them here
  would start every customer on whatever resolved the day this repository was
  last touched, and further behind with each month that passes. Generating them
  at stamp time pins the customer to current providers, deliberately, with the
  versions visible in their first pull request. The invariants check warns rather
  than fails so a freshly stamped repository is not red before onboarding runs.

  Backport: recommended for existing customer repositories, and it must be done
  per repository, because the versions a customer's estate currently runs are
  whatever their last apply resolved. Generate with
  `terragrunt --working-dir live/<unit> init -backend=false`, then plan every
  unit and confirm the diff is empty before merging. A non-empty plan means that
  repository has already drifted onto newer providers.

### Changed

- `mise.toml` also pins `pre-commit`, `tflint`, and `checkov`, so the hooks run
  the same versions locally and in CI. `mise install` picks them up. Backport:
  required alongside the hooks, otherwise the versions drift per machine.
- `AGENTS.md` gains the two-layer gate model (on commit against the source, on
  plan against the generated plan, and why checkov at the first layer sees only
  the module calls), the lock file rule, and the matching definition-of-done
  items. It stays byte-identical to the copy in `nrit-alz-live` and
  `nrit-alz-platform-skills`. Backport: optional, copy the file over.

### Fixed

- Documentation that named an engine version no longer does. `README.md` and
  `docs/upgrade-guide.md` said the callers were pinned at `v1.4.0` while the
  workflows had been on `v1.5.0` since the cross-PR locks rollout. They now point
  at the caller files as the source of truth instead of repeating a number that
  goes stale on every bump. `ONBOARDING.md` was already version-agnostic.
  Backport: optional, documentation only.
- The comment above the deep-merged include in `_foundation/landing-zones` and
  `_foundation/amba` said generate blocks are "shallow-merged, child wins". That
  describes what happens once `merge_strategy = "deep"` is set, not the default.
  Under the default include, two same-named generate blocks are a hard error and
  nothing is generated. Confirmed by removing the attribute on terragrunt 1.0.7.
  The rationale in `live/root.hcl` was already correct. Backport: optional,
  comment only, no behaviour change.

### Added

- `.mcp.json` declaring two MCP servers for agents working in the repository:
  `microsoft-learn` (Microsoft's official documentation server over HTTPS, no
  account or install, so Azure Policy, CAF, WAF, and naming answers come from
  current Microsoft Learn rather than training data) and `terraform`
  (HashiCorp's official registry server, run locally as a container pinned to
  `1.1.0`, for looking up Azure Verified Module arguments and current versions).
  No token is set: the public registry needs none. The Terraform server requires
  Docker; without it, it fails to start and nothing else is affected. Both
  receive queries only, never the contents of `live/`, state, or plan output.
  `.claude/README.md` documents what each does, what leaves the machine, and how
  to turn either off. Backport: optional, only new stamps need it.
- Two agent skills vendored under `.claude/skills/`, so they work the moment a
  repository is stamped with no install step, no network, and no dependency on a
  particular CLI: `terragrunt` (NRIT's own, covering the Terragrunt 1.0 CLI, HCL
  blocks, functions, Stacks, best practices, an Azure/ALZ layer, and copyable
  templates) and `terraform-style-guide` (HashiCorp's official HCL style
  conventions, MPL-2.0, with its `LICENSE` alongside it). A README in that folder
  records provenance, the precedence rule that `AGENTS.md` wins on any conflict,
  and how to refresh each one. Skills for authoring Terraform providers, building
  Azure Verified Modules, and Packer images were deliberately left out: this
  repository consumes published modules rather than authoring them. Backport:
  optional, only new stamps need it.
- `AGENTS.md`, generic instructions for AI coding agents, identical in every
  repository built on this platform: the layout, the root contract and
  `local.context`, unit authoring rules (shape, provider overrides, module
  pinning, the CAF naming split, tags, sharing values between units), the
  comment-ops change flow, what is pinned where, the commands an agent may and
  may not run, and a definition of done. It carries no tenant values; anything
  specific to this repository stays in `README.md`, `ONBOARDING.md`, and the
  `live/` tree. `CLAUDE.md` is a one-line pointer at it.
- A changelog reminder workflow: CI warns, without failing, when a PR changes
  code but not this file. Backport: optional, only new stamps need it.

### Changed

- The engine caller pins moved from `v1.4.0` to `v1.5.0` and the
  `terraform-pr-ops.yml` caller added `closed` to its `pull_request` trigger
  types. This adopts cross-PR unit locks: the first PR to plan a unit owns it
  until that PR merges or closes, other PRs see a `locked` result, and
  `/unlock` force-releases. The `closed` trigger is what releases locks on
  merge. Backport: required for existing customer repositories; without the
  bump they have no locking, and a repository bumped without the `closed`
  type would strand locks until someone comments `/unlock`. The identities
  need Storage Table Data Contributor on the state account first, which the
  current nrit-alz-bootstrap applies.

### Fixed

- `tenant_root_id` is wired up. `live/_foundation/landing-zones/main.tf` sets
  `parent_resource_id` from `local.context.tenant_root_id` instead of the client
  config tenant id, so setting the value in `live/tenant.hcl` now actually places
  the hierarchy under an existing intermediate management group. Before this it
  was read by nothing and the hierarchy was always created at tenant root, with a
  clean plan and a clean apply either way. The default is unchanged: it resolves
  to the tenant id. A precondition on the unit's existing
  `azapi_client_config` data source fails the plan if the value is empty or still
  the all-zeros placeholder, which is what a missing `AZURE_TENANT_ID` produces,
  so a bad tenant id cannot silently become the hierarchy's parent. The guard
  adds nothing to state, so an applied estate still plans as a no-op.
- `docs/foundation-structure.md` lists the foundation leaves in deploy order
  (`management-resources`, then `landing-zones`, then `amba`), matching the deploy
  order section further down the same page.
- `live/platform/connectivity/README.md` includes the co-located `region.hcl` in
  its onboarding recipe. `root.hcl` reads a region unconditionally, so the unit
  failed without it.
- The first plan no longer needs a guess. `architecture_name` in
  `live/_foundation/landing-zones/main.tf` defaults to `nrit`, the only
  architecture the vendored library defines, and
  `connectivity_subscription_id` defaults to empty, which omits the connectivity
  entry from `subscription_placement` instead of sending a placeholder id a
  customer without a connectivity subscription cannot satisfy.

### Added

- ONBOARDING step 2 covers the two per-customer values it omitted: `environment`
  in `live/_foundation/region.hcl` (it feeds the `env` tag, and the tag policy
  allows prod, staging, and dev only) and `tenant_root_id` in `live/tenant.hcl`.
- ONBOARDING step 5 makes `.github/CODEOWNERS` and `LICENSE` explicit decisions.
  The CODEOWNERS team exists only in the NRIT organisation, so GitHub reports the
  file as invalid in the customer's; the licence is a self-declared placeholder
  that otherwise ships to the customer untouched.

### Changed

- `live/root.hcl` generates a `context.tf` into every unit, holding the hierarchy
  values as one `local.context` object (tenant, subscription, location,
  location_short, environment). The foundation units read `local.context` instead
  of hardcoding the region, so `live/_foundation/region.hcl` is the single source
  of truth and changing the region is a one-file edit. Same mechanism already used
  for `backend.tf` and `providers.tf`. Proven in `nrit-alz-live` first: the
  rollout there applied as a no-op across all ten units.
- Rebuilt the template to the current landing-zone design. The foundation is now
  three plain-Terraform `_foundation` units (`management-resources`,
  `landing-zones`, `amba`), each a `main.tf` plus `terragrunt.hcl` with its own
  state, replacing the previous `terragrunt.stack.hcl` catalog-stack layout. The
  four `nrit-azure-pipelines` consumer workflows are replaced by two
  `nrit-tf-pr-ops` reusable-workflow callers (`terraform-pr-ops.yml`, `drift.yml`),
  pinned `@v1` with `engine_ref: v1` and `secrets: inherit`. Plan and apply now run
  from pull request comments (comment-ops); the foundation applies through the same
  flow in dependency order rather than a separate manual dispatch. The bootstrap
  moved to `nrit-alz-bootstrap`; README, ONBOARDING, and the docs are rewritten for
  the reusable-workflow model.
