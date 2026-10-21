#!/usr/bin/env bash
# Workbook page 14. Run ONLY after you have saved your evidence. Removes only resources recorded in state.env.
source "$(dirname "$0")/lib.sh"
set +e  # keep going if something is already gone

read -r -p "Delete all EWB lab resources recorded in state.env? Evidence saved? (yes/no) " a
[[ "$a" == yes ]] || exit 1

log "1. Compute and credentials"
IDS="$I_BASTION $I_APP_A $I_APP_B"
aws ec2 terminate-instances --instance-ids $IDS >/dev/null
aws ec2 wait instance-terminated --instance-ids $IDS
aws ec2 delete-key-pair --key-name "$KEY_NAME"
rm -f "$KEY_FILE"
sed -i '/# BEGIN EWB-LAB/,/# END EWB-LAB/d' "$HOME/.ssh/config"

log "2. Peering and network"
for rt in "$RT_A_PRIV:10.20.0.0/16" "$RT_B_PRIV:10.10.0.0/16" "$RT_A_PUB:10.20.0.0/16"; do
  aws ec2 delete-route --route-table-id "${rt%%:*}" --destination-cidr-block "${rt##*:}"
done
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$PCX"
sleep 5
for sg in "$SG_BASTION" "$SG_APP_A" "$SG_APP_B"; do aws ec2 delete-security-group --group-id "$sg"; done

for rt in "$RT_A_PUB" "$RT_A_PRIV" "$RT_B_PRIV"; do
  for assoc in $(aws ec2 describe-route-tables --route-table-ids "$rt" \
      --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' --output text); do
    aws ec2 disassociate-route-table --association-id "$assoc"
  done
done
for s in "$SUBNET_A_PUB" "$SUBNET_A_PRIV" "$SUBNET_B_PRIV"; do aws ec2 delete-subnet --subnet-id "$s"; done
for rt in "$RT_A_PUB" "$RT_A_PRIV" "$RT_B_PRIV"; do aws ec2 delete-route-table --route-table-id "$rt"; done
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_A"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW"
aws ec2 delete-vpc --vpc-id "$VPC_A"
aws ec2 delete-vpc --vpc-id "$VPC_B"

log "3. Verify account is clear (project tag)"
{
  echo "Instances not terminated:"; aws ec2 describe-instances --filters "Name=tag:Project,Values=EWB-VPC-Peering" \
    --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' --output text
  echo "Volumes:"; aws ec2 describe-volumes --filters "Name=tag:Project,Values=EWB-VPC-Peering" --query 'Volumes[].VolumeId' --output text
  echo "Elastic IPs:"; aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text
  echo "VPCs:"; aws ec2 describe-vpcs --filters "Name=tag:Project,Values=EWB-VPC-Peering" --query 'Vpcs[].VpcId' --output text
  echo "(empty lines above = clean)"
} | tee "$EVIDENCE/cleanup-evidence.txt"
echo "Also check the Billing console; usage reporting can lag."
