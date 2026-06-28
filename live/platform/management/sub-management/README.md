# sub-management

The management subscription.

The central Log Analytics workspace, the data collection rules, and the AMA
identity that live in this subscription are provisioned by the platform
foundation (the `alz-platform-management` unit inside the
`caf-platform-foundation` stack under `live/tenant/_global/`), not from here.
The foundation owns them because the ALZ policy assignments wire their resource
ids into policy default values and need them in place before the policy role
assignments are created.

This folder is therefore empty by default. Add extra management-subscription
workloads here as the customer needs them, each in its own region folder as a
unit or a stack that includes `live/root.hcl`, for example:

```
sub-management/
└── westeurope/
    └── backup-vault/
        └── terragrunt.hcl
```

Add a `subscription.hcl` (the management subscription id) and a `region.hcl`
alongside the first workload so root.hcl can resolve them, the same way the
foundation folder does.
