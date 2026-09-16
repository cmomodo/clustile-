variable "eks_admin_principal_arn" {
  description = "ARN of an existing IAM user or role to grant EKS cluster administrator access. Use the IAM role ARN, not an STS assumed-role session ARN."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:iam::[0-9]{12}:(user|role)/.+$", var.eks_admin_principal_arn))
    error_message = "Provide an IAM user or role ARN, not an STS session ARN or account root ARN."
  }
}
