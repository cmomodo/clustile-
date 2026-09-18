# Local pre-commit hooks

From the repository root, install the tools on macOS with `brew install pre-commit terraform tflint`, then
run `make hooks` once per clone to enable checks before every commit.
Run `make lint` to check all tracked files manually.

The hooks are configured in `.pre-commit-config.yaml` and run against staged
files before each `git commit`:

- `check-yaml` checks YAML syntax and supports manifests containing multiple
  documents. Helm templates are excluded because they contain template syntax.
- `end-of-file-fixer` ensures files end with a single newline.
- `trailing-whitespace` removes whitespace at the ends of lines.
- `terraform_fmt` formats Terraform files.
- `terraform_validate` validates Terraform configuration.
- `terraform_tflint` checks Terraform using the rules in `.tflint.hcl`.
- `terraform_providers_lock` checks provider checksums for Linux and macOS
  on AMD64 and updates the lockfile only when those checksums are missing.

Hooks can fix formatting automatically. Review and stage those changes, then
retry the commit. Terraform validation and provider locking may download providers
and need network access. TFLint findings must be resolved before checks pass.

## Project exceptions

`.tflint.hcl` disables `terraform_naming_convention` so existing IAM policy
attachment addresses can retain their AWS policy names without state migrations.
All other configured lint rules remain enabled, including required
`Environment` and `Project` tags, supplied through `local.common_tags` in each
Terraform root.
