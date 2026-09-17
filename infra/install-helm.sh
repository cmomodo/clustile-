#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${1:-gamehub38}"
REGION="${2:-us-east-1}"
ACCOUNT_ID="${3:-$(aws sts get-caller-identity --query Account --output text)}"

echo "=========================================="
echo "Installing Helm Releases"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "AWS Account: $ACCOUNT_ID"
echo ""

# 1. Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add eks https://aws.github.io/eks-charts
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 2. Create IAM role for AWS Load Balancer Controller
echo ""
echo "🔑 Setting up IAM role for AWS Load Balancer Controller..."

# Create trust policy for the service account
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${REGION}.amazonaws.com/id/$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5):sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

# Create or update IAM role
ROLE_NAME="AWSLoadBalancerControllerRole-${CLUSTER_NAME}"
if aws iam get-role --role-name "$ROLE_NAME" --region $REGION 2>/dev/null; then
  echo "   ✓ IAM role $ROLE_NAME already exists"
else
  echo "   Creating IAM role $ROLE_NAME..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --region $REGION
fi

# Create and attach inline policy
echo "   Attaching AWSLoadBalancerControllerPolicy..."

# Create policy document
cat > /tmp/alb-policy.json <<'POLICY_EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elbv2:CreateLoadBalancer",
        "elbv2:CreateTargetGroup",
        "elbv2:CreateListener",
        "elbv2:CreateListenerCertificate",
        "elbv2:DeleteLoadBalancer",
        "elbv2:DeleteTargetGroup",
        "elbv2:DeleteListener",
        "elbv2:DescribeLoadBalancers",
        "elbv2:DescribeTargetGroups",
        "elbv2:DescribeListeners",
        "elbv2:DescribeListenerCertificates",
        "elbv2:DescribeSSLPolicies",
        "elbv2:ModifyLoadBalancerAttributes",
        "elbv2:ModifyTargetGroupAttributes",
        "elbv2:RegisterTargets",
        "elbv2:DeregisterTargets",
        "elbv2:DescribeTargetHealth",
        "elbv2:DescribeTags",
        "elbv2:AddTags",
        "elbv2:RemoveTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeInstances",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    }
  ]
}
POLICY_EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name AWSLoadBalancerControllerPolicy \
  --policy-document file:///tmp/alb-policy.json \
  --region $REGION

# 3. Install AWS Load Balancer Controller
echo ""
echo "🔧 Installing AWS Load Balancer Controller..."
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)

kubectl apply -f "$SCRIPT_DIR/k8s/addons/aws-load-balancer-controller/serviceaccount.yaml"
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  "eks.amazonaws.com/role-arn=$ROLE_ARN" --overwrite

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f "$SCRIPT_DIR/k8s/addons/aws-load-balancer-controller/values.yaml" \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --wait --timeout=5m

echo "✅ AWS Load Balancer Controller installed"

# 4. Install Traefik
echo ""
echo "🚀 Installing Traefik Ingress Controller..."
helm install traefik traefik/traefik \
  -n kube-system \
  -f "$SCRIPT_DIR/k8s/addons/traefik/values.yaml" \
  --wait --timeout=5m

echo "✅ Traefik installed"

# 5. Get Traefik's external URL
echo ""
echo "=========================================="
echo "✅ All Helm releases installed successfully!"
echo "=========================================="
echo ""
echo "📊 Status:"
kubectl get svc -n kube-system traefik -o wide

# Wait for NLB to get hostname
echo ""
echo "⏳ Waiting for NLB hostname to be assigned (this may take 1-2 minutes)..."
for i in {1..120}; do
  TRAEFIK_HOST=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  if [ ! -z "$TRAEFIK_HOST" ]; then
    echo ""
    echo "🎉 Traefik NLB Ready!"
    echo "   Hostname: $TRAEFIK_HOST"
    echo ""
    echo "📍 Your app URL: http://$TRAEFIK_HOST"
    break
  fi
  echo -n "."
  sleep 2
done

echo ""
echo "Done! The app should be accessible via the Traefik NLB."
echo ""
