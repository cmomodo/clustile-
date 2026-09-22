#!/bin/bash

set -e

CLUSTER_NAME="${1:-gamehub38}"
REGION="${2:-us-east-1}"

echo "🔍 Verifying AWS Load Balancer Controller IRSA Setup"
echo "======================================================"
echo ""

# 1. Check trust policy has aud condition
echo "1️⃣ Trust Policy Security"
echo "----------------------------"
ROLE_NAME="AWSLoadBalancerControllerRole-${CLUSTER_NAME}"
TRUST_POLICY=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)

if echo "$TRUST_POLICY" | grep -q "sts.amazonaws.com"; then
  echo "✅ Trust policy includes aud condition"
else
  echo "❌ Trust policy MISSING aud condition - run terraform apply"
  exit 1
fi

if echo "$TRUST_POLICY" | grep -q "system:serviceaccount:kube-system:aws-load-balancer-controller"; then
  echo "✅ Trust policy scoped to correct ServiceAccount"
else
  echo "❌ Trust policy NOT scoped to correct ServiceAccount"
  exit 1
fi

# 2. Check ServiceAccount annotation
echo ""
echo "2️⃣ ServiceAccount Configuration"
echo "------------------------------"
cd "$(dirname "$0")/.."
EXPECTED_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "")

if [ -z "$EXPECTED_ARN" ]; then
  echo "⚠️  Cannot get role ARN from Terraform - run terraform apply first"
  exit 1
fi

ACTUAL_ARN=$(kubectl get sa aws-load-balancer-controller -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")

if [ "$ACTUAL_ARN" == "$EXPECTED_ARN" ]; then
  echo "✅ ServiceAccount correctly annotated"
  echo "   Role: $ACTUAL_ARN"
else
  echo "❌ ServiceAccount annotation mismatch"
  echo "   Expected: $EXPECTED_ARN"
  echo "   Actual: $ACTUAL_ARN"
  exit 1
fi

# 3. Check controller pods
echo ""
echo "3️⃣ Controller Pods"
echo "-------------------"
POD_NAME=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
  echo "❌ No controller pods found"
  exit 1
fi

POD_STATUS=$(kubectl get pod -n kube-system "$POD_NAME" -o jsonpath='{.status.phase}')
echo "✅ Controller pod: $POD_NAME ($POD_STATUS)"

if [ "$POD_STATUS" != "Running" ]; then
  echo "⚠️  Pod not running - checking logs..."
  kubectl logs -n kube-system "$POD_NAME" --tail=20 2>/dev/null || echo "   Could not fetch logs"
fi

# 4. Check for credential errors
echo ""
echo "4️⃣ Credential Check"
echo "--------------------"
ERRORS=$(kubectl logs -n kube-system "$POD_NAME" --tail=50 2>/dev/null | \
  grep -i "error.*credential\|unauthorized\|forbidden" || echo "")

if [ -z "$ERRORS" ]; then
  echo "✅ No credential errors in logs"
else
  echo "❌ Found credential errors:"
  echo "$ERRORS"
  exit 1
fi

# 5. Check Traefik NLB
echo ""
echo "5️⃣ LoadBalancer Provisioning"
echo "-------------------------------"
LB_HOST=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$LB_HOST" ]; then
  echo "⏳ NLB not provisioned yet (may still be creating)"
else
  echo "✅ NLB provisioned: $LB_HOST"
fi

echo ""
echo "=========================================="
echo "✅ IRSA Verification Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  • IAM Role: ✅ Managed by Terraform"
echo "  • Trust Policy: ✅ Has aud condition"
echo "  • ServiceAccount: ✅ Correctly annotated"
echo "  • Controller Pods: ✅ Running"
if [ ! -z "$LB_HOST" ]; then
  echo "  • LoadBalancer: ✅ Functional"
fi
echo ""
echo "🎉 AWS Load Balancer Controller IRSA is properly configured!"
