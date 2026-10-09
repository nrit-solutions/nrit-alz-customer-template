# AMBA library, vendored with an allowed-values patch

A copy of `platform/amba` at release 2026.06.2 from the
[Azure Landing Zones Library](https://github.com/Azure/Azure-Landing-Zones-Library/tree/platform/amba/2026.06.2/platform/amba),
without its `scripts/` folder. `terragrunt.hcl` loads it with
`{ custom_url = "${get_terragrunt_dir()}/lib" }` in place of
`{ path = "platform/amba", ref = "2026.06.2" }`.

## What is changed

Four policy set definitions, and in them only parameter `allowedValues` (and a
default's casing where it had to match):

| Set | Parameters | Narrowed to |
| --- | --- | --- |
| `Alerting-VM`, `Alerting-VMSS`, `Alerting-HybridVM` | every `*EvaluationFrequency` | `PT5M`, `PT15M`, `PT30M`, `PT1H` (drops `PT1M`) |
| same | every `*WindowSize` | `PT5M` to `PT12H` (drops `PT1M` and `P1D`) |
| `Alerting-VM`, `Alerting-VMSS` | `*PercentCPUOperator` | `GreaterThan` |
| `Alerting-ResourceAndServiceHealth` | `ShaBuiltInPolicyEffect` | `DeployIfNotExists`, `Disabled` (drops the lowercase duplicates) |

Each list is narrowed to the values the policy definition parameter it feeds
accepts, so no value an assignment uses today is removed.

## Why

Azure now rejects a policy set whose parameter offers a value the referenced
definition does not accept (`PolicySetParameterAllowedValuesMismatch`). The
stock 2026.06.2 sets fail on a fresh deploy and on any update:
[Azure/azure-monitor-baseline-alerts#936](https://github.com/Azure/azure-monitor-baseline-alerts/issues/936).

The whole library is vendored because the provider's
`library_overwrite_enabled` does not replace a policy set definition from a
later library; the first copy wins.

## Going back to upstream

Once an AMBA release fixes the sets: put
`{ path = "platform/amba", ref = "<that release>" }` back in `terragrunt.hcl`,
delete this folder, and expect the plan to touch only those four sets (or
whatever else the new release changes). The narrowing script lives in the
platform's internal docs.
