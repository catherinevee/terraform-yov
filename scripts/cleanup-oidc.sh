#!/bin/bash

# Cleanup script for AWS GitHub OIDC infrastructure
# This script removes the IAM role and OIDC provider created for GitHub Actions

set -e

echo "Starting cleanup of AWS GitHub OIDC infrastructure..."

# Variables
ROLE_NAME="terraform-yov-github-actions"
OIDC_PROVIDER_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"

# Detach policies from role
echo "Detaching policies from role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | while read -r policy; do
    if [ -n "$policy" ]; then
        echo "  Detaching policy: $policy"
        aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy"
    fi
done

# Delete the role
echo "Deleting IAM role: $ROLE_NAME"
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    aws iam delete-role --role-name "$ROLE_NAME"
    echo "  Role deleted successfully"
else
    echo "  Role not found"
fi

# Check if this was the last role using the OIDC provider
echo "Checking if OIDC provider can be deleted..."
ROLES_USING_PROVIDER=$(aws iam list-roles --query "Roles[?contains(AssumeRolePolicyDocument.Statement[0].Principal.Federated, 'token.actions.githubusercontent.com')].RoleName" --output text)

if [ -z "$ROLES_USING_PROVIDER" ]; then
    echo "No other roles are using the OIDC provider"
    echo "Delete OIDC provider manually if desired with:"
    echo "  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $OIDC_PROVIDER_ARN"
else
    echo "Other roles are still using the OIDC provider:"
    echo "$ROLES_USING_PROVIDER"
    echo "OIDC provider will not be deleted"
fi

echo "Cleanup complete!"