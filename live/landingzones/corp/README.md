# corp

Management group: **Corp** (id `corp`), child of `landingzones`.

Corp-connected landing zones: workloads with no public ingress by default,
connected to the platform hub. Placeholder until the customer's first corp
subscription is onboarded.

To onboard one, add a named subscription folder here (for example
`corp-workload/`) with:

- `subscription.hcl`: the subscription id
- a placement stack wrapping the catalog `lz-vending` stack. It owns the
  subscription lifecycle only: alias or adoption, placement under this
  management group (`subscription_management_group_id`), identities, RBAC, and
  budgets. It creates no network. Corp versus online is just the target
  management group.
- a network stack, under a region folder, wrapping the catalog `lz-network`
  stack. It owns all spoke network config (the virtual network, subnets, NSGs,
  route tables, and hub peering) for the spoke peered to the platform hub.

Both stacks forward their whole values map to their single unit, so the module
inputs are set directly. See the catalog `lz-network` stack's example and README
for the settings a spoke needs against this template's minimal hub: a
`network_security_groups` entry associated to every subnet (the ALZ policy
`Deny-Subnet-Without-Nsg` denies subnets with none) and `hub_peering_options_tohub
= { use_remote_gateways = false }` if the hub has no VPN/ExpressRoute gateway.
Subscription-level keys are reserved in `lz-network` and fail loudly by design;
set them in the `lz-vending` stack.

## Workload resources

Common single resources (storage account, key vault, Log Analytics workspace,
user-assigned identity) are not catalog stacks. Compose them here from catalog
**units**: add a region folder and a resource folder (for example
`westeurope/storage/`) with a `terragrunt.stack.hcl` holding one `unit` block per
resource, each sourcing the catalog unit at a pinned `?ref`:

```hcl
locals {
  catalog_url     = "git::https://github.com/nrit-solutions/nrit-terragrunt-catalog.git"
  catalog_version = "v1.1.0"
}

unit "storage_account" {
  source = "${local.catalog_url}//units/storage-account?ref=${local.catalog_version}"
  path   = "storage-account"
  values = {
    name                = "stcorpworkloadweu001"
    resource_group_name = "rg-corp-workload-weu" # existing or created below
    # add a resource-group unit block and set resource_group_path to create the
    # group here; omit both to deploy into an existing group.
  }
}
```

The resource group is optional: include a `resource-group` unit block (and set
the resource's `resource_group_path`) to create one, or omit it and point
`resource_group_name` at an existing group. See the catalog units under
`units/` and the worked example at
`examples/terragrunt/stacks/storage-account` for both variants.
