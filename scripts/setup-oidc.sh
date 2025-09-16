#!/bin/bash

# Setup script for AWS GitHub OIDC infrastructure
# This script creates the IAM role and OIDC provider for GitHub Actions

set -e

echo "Setting up AWS GitHub OIDC infrastructure..."

# Variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
GITHUB_ORG="catherinevee"
GITHUB_REPO="terraform-yov"
ROLE_NAME="terraform-yov-github-actions"
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

# Check if OIDC provider exists
echo "Checking for existing OIDC provider..."
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &>/dev/null; then
    echo "Creating OIDC provider for GitHub Actions..."
    THUMBPRINT=$(openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -noout -sha1 | cut -d'=' -f2 | tr -d ':')

    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list "$THUMBPRINT"
    echo "  OIDC provider created"
else
    echo "  OIDC provider already exists"
fi

# Create trust policy
echo "Creating trust policy..."
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create or update IAM role
echo "Creating IAM role: $ROLE_NAME"
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "  Role exists, updating trust policy..."
    aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document file:///tmp/trust-policy.json
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "GitHub Actions OIDC role for ${GITHUB_REPO} repository"
    echo "  Role created"
fi

# Attach PowerUserAccess policy
echo "Attaching PowerUserAccess policy..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Clean up
rm -f /tmp/trust-policy.json

# Output role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo ""
echo "Setup complete!"
echo "Role ARN: $ROLE_ARN"
echo ""
echo "Add this to your GitHub workflow:"
echo "  - uses: aws-actions/configure-aws-credentials@v4"
echo "    with:"
echo "      role-to-assume: $ROLE_ARN"
echo "      aws-region: ap-southeast-1"