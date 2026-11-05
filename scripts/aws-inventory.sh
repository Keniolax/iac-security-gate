#!/usr/bin/env bash
# Record what exists in the account, so a baseline taken before the lab can be
# compared to a teardown check taken after. If they match, nothing was left
# behind. No secrets are printed: only resource IDs, names and tags.
# usage: scripts/aws-inventory.sh <output-file>
set -euo pipefail

out="${1:?usage: aws-inventory.sh <output-file>}"
region="${AWS_REGION:-us-east-1}"
account="$(aws sts get-caller-identity --query Account --output text)"

{
  echo "=== INVENTORY for account ${account}, region ${region} ==="
  echo "Recorded: $(date -u +%FT%TZ)"
  echo

  echo "=== VPCs ==="
  aws ec2 describe-vpcs --region "$region" \
    --query 'sort_by(Vpcs,&VpcId)[].{Id:VpcId,Cidr:CidrBlock,Default:IsDefault}' --output table

  echo "=== Subnets ==="
  aws ec2 describe-subnets --region "$region" \
    --query 'sort_by(Subnets,&SubnetId)[].{Id:SubnetId,Vpc:VpcId,Cidr:CidrBlock}' --output table

  echo "=== Security groups ==="
  aws ec2 describe-security-groups --region "$region" \
    --query 'sort_by(SecurityGroups,&GroupId)[].{Id:GroupId,Name:GroupName,Vpc:VpcId}' --output table

  echo "=== EC2 instances (non-terminated) ==="
  aws ec2 describe-instances --region "$region" \
    --query 'sort_by(Reservations[].Instances[?State.Name!=`terminated`][],&InstanceId)[].{Id:InstanceId,Type:InstanceType,State:State.Name}' \
    --output table

  echo "=== S3 buckets (global) ==="
  aws s3api list-buckets --query 'sort_by(Buckets,&Name)[].Name' --output table

  echo "=== IAM roles (seceng-iac-gate only) ==="
  aws iam list-roles --query "sort_by(Roles,&RoleName)[?starts_with(RoleName,'seceng-iac-gate')].RoleName" --output table

  echo "=== IAM instance profiles (seceng-iac-gate only) ==="
  aws iam list-instance-profiles --query "sort_by(InstanceProfiles,&InstanceProfileName)[?starts_with(InstanceProfileName,'seceng-iac-gate')].InstanceProfileName" --output table

  echo "=== Elastic IPs ==="
  aws ec2 describe-addresses --region "$region" \
    --query 'sort_by(Addresses,&AllocationId)[].{Alloc:AllocationId,Ip:PublicIp,Assoc:AssociationId}' --output table
} > "$out"

echo "wrote $out"
