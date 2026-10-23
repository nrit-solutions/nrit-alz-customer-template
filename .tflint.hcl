config {
  call_module_type = "none"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# required_providers and required_version live in providers.tf, which root.hcl
# generates at run time and .gitignore excludes, so it is never in the source tree.
rule "terraform_required_providers" {
  enabled = false
}

rule "terraform_required_version" {
  enabled = false
}

# every AVM module call carries an exact version, per AGENTS.md
rule "terraform_module_version" {
  enabled = true
  exact   = true
}
