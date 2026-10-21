#!/usr/bin/env bash
# Workbook pages 5-6: VPC A, VPC B, subnets, IGW, route tables, security groups.
source "$(dirname "$0")/lib.sh"

log "VPC A"
save VPC_A "$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 \
  --tag-specifications "$(tags vpc ewb-vpc-a)" --query Vpc.VpcId --output text)"
save SUBNET_A_PUB "$(aws ec2 create-subnet --vpc-id "$VPC_A" --cidr-block 10.10.1.0/24 \
  --availability-zone "$AZ" --tag-specifications "$(tags subnet ewb-a-public)" \
  --query Subnet.SubnetId --output text)"
save SUBNET_A_PRIV "$(aws ec2 create-subnet --vpc-id "$VPC_A" --cidr-block 10.10.2.0/24 \
  --availability-zone "$AZ" --tag-specifications "$(tags subnet ewb-a-private)" \
  --query Subnet.SubnetId --output text)"

log "Internet gateway (attached to VPC A only)"
save IGW "$(aws ec2 create-internet-gateway --tag-specifications "$(tags internet-gateway ewb-igw-a)" \
  --query InternetGateway.InternetGatewayId --output text)"
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_A"

log "Route tables for VPC A"
save RT_A_PUB "$(aws ec2 create-route-table --vpc-id "$VPC_A" \
  --tag-specifications "$(tags route-table ewb-rt-a-public)" --query RouteTable.RouteTableId --output text)"
aws ec2 associate-route-table --route-table-id "$RT_A_PUB" --subnet-id "$SUBNET_A_PUB" >/dev/null
aws ec2 create-route --route-table-id "$RT_A_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW" >/dev/null

save RT_A_PRIV "$(aws ec2 create-route-table --vpc-id "$VPC_A" \
  --tag-specifications "$(tags route-table ewb-rt-a-private)" --query RouteTable.RouteTableId --output text)"
aws ec2 associate-route-table --route-table-id "$RT_A_PRIV" --subnet-id "$SUBNET_A_PRIV" >/dev/null
# no internet route on purpose; private subnet keeps auto-assign public IP disabled (the default)

log "VPC B (no IGW)"
save VPC_B "$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --tag-specifications "$(tags vpc ewb-vpc-b)" --query Vpc.VpcId --output text)"
save SUBNET_B_PRIV "$(aws ec2 create-subnet --vpc-id "$VPC_B" --cidr-block 10.20.1.0/24 \
  --availability-zone "$AZ" --tag-specifications "$(tags subnet ewb-b-private)" \
  --query Subnet.SubnetId --output text)"
save RT_B_PRIV "$(aws ec2 create-route-table --vpc-id "$VPC_B" \
  --tag-specifications "$(tags route-table ewb-rt-b-private)" --query RouteTable.RouteTableId --output text)"
aws ec2 associate-route-table --route-table-id "$RT_B_PRIV" --subnet-id "$SUBNET_B_PRIV" >/dev/null

log "Security groups (inbound rules from workbook page 6; default outbound allow-all kept)"
MYIP="$(curl -s https://checkip.amazonaws.com | tr -d '[:space:]')"
echo "Your public IPv4 for the bastion SSH rule: $MYIP/32"

mk_sg() { aws ec2 create-security-group --group-name "$1" --description "$2" --vpc-id "$3" \
  --tag-specifications "$(tags security-group "$1")" --query GroupId --output text; }

save SG_BASTION "$(mk_sg ewb-sg-bastion "EWB bastion SSH" "$VPC_A")"
save SG_APP_A   "$(mk_sg ewb-sg-app-a   "EWB App-A"       "$VPC_A")"
save SG_APP_B   "$(mk_sg ewb-sg-app-b   "EWB App-B"       "$VPC_B")"

aws ec2 authorize-security-group-ingress --group-id "$SG_BASTION" --protocol tcp --port 22 --cidr "$MYIP/32" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_A" --protocol tcp  --port 22 --cidr 10.10.1.10/32 >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_A" --protocol icmp --port 8   --cidr 10.20.1.10/32 >/dev/null  # echo request, App-B
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B" --protocol tcp  --port 22 --cidr 10.10.1.10/32 >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B" --protocol icmp --port 8   --cidr 10.10.2.10/32 >/dev/null  # echo request, App-A

log "Checkpoint 01 evidence"
{
  aws ec2 describe-route-tables --route-table-ids "$RT_A_PUB" "$RT_A_PRIV" "$RT_B_PRIV" \
    --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Id:RouteTableId,Assoc:Associations[].SubnetId,Routes:Routes[].[DestinationCidrBlock,GatewayId]}' --output json
} | tee "$EVIDENCE/checkpoint01-routes.json"
echo "Done. Next: ./02-launch-instances.sh"
