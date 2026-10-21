#!/usr/bin/env bash
# Workbook pages 9-11: peering, routes on both sides, verification tests 02-05.
source "$(dirname "$0")/lib.sh"
need VPC_A VPC_B RT_A_PUB RT_A_PRIV RT_B_PRIV I_APP_A I_APP_B

log "Request and accept peering (same account, same Region)"
save PCX "$(aws ec2 create-vpc-peering-connection --vpc-id "$VPC_A" --peer-vpc-id "$VPC_B" \
  --tag-specifications "$(tags vpc-peering-connection ewb-a-b-peer)" \
  --query VpcPeeringConnection.VpcPeeringConnectionId --output text)"
aws ec2 wait vpc-peering-connection-exists --vpc-peering-connection-ids "$PCX"
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id "$PCX" >/dev/null
sleep 5
aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PCX" \
  --query 'VpcPeeringConnections[0].{Id:VpcPeeringConnectionId,Status:Status.Code,Requester:RequesterVpcInfo.[VpcId,CidrBlock],Accepter:AccepterVpcInfo.[VpcId,CidrBlock]}' \
  --output json | tee "$EVIDENCE/checkpoint03-peering.json"

log "Routes on both sides (page 10)"
aws ec2 create-route --route-table-id "$RT_A_PRIV" --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "$PCX" >/dev/null
aws ec2 create-route --route-table-id "$RT_B_PRIV" --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id "$PCX" >/dev/null
aws ec2 create-route --route-table-id "$RT_A_PUB"  --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "$PCX" >/dev/null  # bastion ProxyJump to App-B

aws ec2 describe-route-tables --route-table-ids "$RT_A_PUB" "$RT_A_PRIV" "$RT_B_PRIV" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Assoc:Associations[].SubnetId,Routes:Routes[].[DestinationCidrBlock,GatewayId||VpcPeeringConnectionId]}' \
  --output json | tee "$EVIDENCE/checkpoint04-routes.json"

sleep 10
log "Test 02 - forward path (App-A -> App-B)"
{ echo '$ ping -c 4 10.20.1.10   (from App-A)'; ssh ewb-app-a 'hostname; hostname -I; ping -c 4 10.20.1.10'; } 2>&1 | tee "$EVIDENCE/test02-forward.txt"

log "Test 03 - reverse path (App-B -> App-A)"
{ echo '$ ping -c 4 10.10.2.10   (from App-B)'; ssh ewb-app-b 'hostname; hostname -I; ping -c 4 10.10.2.10'; } 2>&1 | tee "$EVIDENCE/test03-reverse.txt"

log "Test 04 - private SSH to App-B through the bastion"
ssh -o StrictHostKeyChecking=accept-new ewb-app-b 'echo "Connected to $(hostname) at $(hostname -I)"' 2>&1 | tee "$EVIDENCE/test04-ssh-app-b.txt"

log "Test 05 - isolation (no public IPv4 on App-A / App-B)"
aws ec2 describe-instances --instance-ids "$I_APP_A" "$I_APP_B" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,PublicIp:PublicIpAddress}' --output table \
  | tee "$EVIDENCE/test05-isolation.txt"
echo "Done. Next: ./04-controlled-failure.sh"
