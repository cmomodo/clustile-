#!/bin/bash

set -e

CLUSTER_NAME="${1:-gamehub38}"
REGION="${2:-us-east-1}"
ROLE_NAME="AWSLoadBalancerControllerRole-${CLUSTER_NAME}"

echo "🔍 Checking IAM import status..."
echo ""

# Check if role exists in AWS
if aws iam get-role --role-name "$ROLE_NAME" --region "$REGION" 2>/dev/null >/dev/null; then
  echo "✅ IAM Role exists in AWS: $ROLE_NAME"
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --region "$REGION" --query 'Role.Arn' --output text)
  echo "   ARN: $ROLE_ARN"

  # Check if in Terraform state
  cd "$(dirname "$0")/.."
  if terraform state show aws_iam_role.aws_load_balancer_controller 2>/dev/null >/dev/null; then
    echo "✅ Already in Terraform state - no import needed"
  else
    echo "⚠️  NOT in Terraform state"
    echo ""
    echo "📋 Run these commands to import:"
    echo "   terraform import aws_iam_role.aws_load_balancer_controller $ROLE_NAME"
    echo "   terraform import aws_iam_role_policy.aws_load_balancer_controller ${ROLE_NAME}:AWSLoadBalancerControllerPolicy"
  fi
else
  echo "✅ Role does not exist in AWS - Terraform will create it"
fi

echo ""
echo "---"
echo ""

# Check OIDC provider
OIDC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)
OIDC_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null >/dev/null; then
  echo "✅ OIDC provider exists: $OIDC_ARN"

  cd "$(dirname "$0")/.."
  if terraform state show aws_iam_openid_connect_provider.eks 2>/dev/null >/dev/null; then
    echo "✅ Already in Terraform state"
  else
    echo "⚠️  NOT in Terraform state"
    echo ""
    echo "📋 Import command needed:"
    echo "   terraform import aws_iam_openid_connect_provider.eks $OIDC_ARN"
  fi
else
  echo "ℹ️  OIDC provider does NOT exist"
  echo "✅ No import needed - Terraform will create it"
fi

echo ""
echo "🎯 Next steps:"
echo "   1. Run any import commands shown above"
echo "   2. Run: terraform plan"
echo "   3. Review changes (should show trust policy update with aud condition)"
echo "   4. Run: terraform apply"
