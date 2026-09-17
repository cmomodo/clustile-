plugin "terraform" {
  # Plugin common attributes
  required_version = "1.15.9"
  enabled          = true
  preset           = "recommended"
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

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

# --- AWS plugin rules ---

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_eks_node_group_invalid_instance_types" {
  enabled = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags    = ["Environment", "Project"]
}
