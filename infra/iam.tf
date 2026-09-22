# OIDC provider for EKS to enable IAM roles for service accounts (IRSA)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.gamehub.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.gamehub.identity[0].oidc[0].issuer
  tags            = local.common_tags
}

# Fetch official AWS Load Balancer Controller IAM policy
# Chart v1.9.1 corresponds to controller v2.9.1
data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.9.1/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to fetch AWS Load Balancer Controller IAM policy from GitHub"
    }
  }
}

# IAM role for AWS Load Balancer Controller
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    # Restrict to exact ServiceAccount
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    # SECURITY: Add audience condition per AWS IRSA best practices
    # Prevents token replay - only tokens issued for AWS STS can assume this role
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "AWSLoadBalancerControllerRole-${aws_eks_cluster.gamehub.name}"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "aws_load_balancer_controller" {
  name   = "AWSLoadBalancerControllerPolicy"
  role   = aws_iam_role.aws_load_balancer_controller.id
  policy = data.http.aws_load_balancer_controller_iam_policy.response_body
}
