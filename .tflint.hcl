plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.48.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# --- Terraform plugin rules (on top of recommended preset) ---

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

# Existing resource addresses are retained to avoid unnecessary state migrations.
# Naming style is cosmetic and does not affect infrastructure correctness.
rule "terraform_naming_convention" {
  enabled = false
}

rule "terraform_comment_syntax" {
  enabled = true
}

# --- AWS plugin rules ---

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags    = ["Environment", "Project"]
}
