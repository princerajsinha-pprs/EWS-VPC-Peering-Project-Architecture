#!/usr/bin/env bash
# Collects the inventory and security group rules needed for the report (workbook page 13).
source "$(dirname "$0")/lib.sh"
need VPC_A VPC_B

{
  echo "Region: $AWS_REGION   Student: $STUDENT   Date: $(date +%F)"
  echo; cat "$STATE"
} > "$EVIDENCE/inventory-ids.txt"

aws ec2 describe-vpcs --vpc-ids "$VPC_A" "$VPC_B" \
  --query 'Vpcs[].{Name:Tags[?Key==`Name`]|[0].Value,Id:VpcId,Cidr:CidrBlock}' --output table | tee "$EVIDENCE/inventory-vpcs.txt"
aws ec2 describe-subnets --filters "Name=tag:Project,Values=EWB-VPC-Peering" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,Id:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone}' --output table | tee "$EVIDENCE/inventory-subnets.txt"
aws ec2 describe-security-groups --group-ids "$SG_BASTION" "$SG_APP_A" "$SG_APP_B" \
  --query 'SecurityGroups[].{Name:GroupName,Inbound:IpPermissions[].[IpProtocol,FromPort,IpRanges[0].CidrIp]}' \
  --output json | tee "$EVIDENCE/inventory-security-groups.json"
echo "Saved to $EVIDENCE"
