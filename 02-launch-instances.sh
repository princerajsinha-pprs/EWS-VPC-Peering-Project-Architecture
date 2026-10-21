#!/usr/bin/env bash
# Workbook pages 7-8: key pair, three instances, SSH config, baseline test.
source "$(dirname "$0")/lib.sh"
need SUBNET_A_PUB SUBNET_A_PRIV SUBNET_B_PRIV SG_BASTION SG_APP_A SG_APP_B

log "Key pair (private key stays on your laptop only)"
mkdir -p "$HOME/.ssh"
if [[ ! -f "$KEY_FILE" ]]; then
  aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type rsa --key-format pem \
    --tag-specifications "$(tags key-pair "$KEY_NAME")" --query KeyMaterial --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
fi

AMI="$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)"
echo "AMI: $AMI"

run() { # name subnet sg ip assoc(true|false)
  aws ec2 run-instances --image-id "$AMI" --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" \
    --network-interfaces "DeviceIndex=0,SubnetId=$2,Groups=$3,PrivateIpAddress=$4,AssociatePublicIpAddress=$5,DeleteOnTermination=true" \
    --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,DeleteOnTermination=true}' \
    --tag-specifications "$(tags instance "$1")" "$(tags volume "$1")" \
    --query 'Instances[0].InstanceId' --output text
}

log "Launching instances"
save I_BASTION "$(run ewb-bastion "$SUBNET_A_PUB"  "$SG_BASTION" 10.10.1.10 true)"
save I_APP_A   "$(run ewb-app-a   "$SUBNET_A_PRIV" "$SG_APP_A"   10.10.2.10 false)"
save I_APP_B   "$(run ewb-app-b   "$SUBNET_B_PRIV" "$SG_APP_B"   10.20.1.10 false)"

aws ec2 wait instance-running --instance-ids "$I_BASTION" "$I_APP_A" "$I_APP_B"
aws ec2 wait instance-status-ok --instance-ids "$I_BASTION" "$I_APP_A" "$I_APP_B"

save BASTION_IP "$(aws ec2 describe-instances --instance-ids "$I_BASTION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"

log "Checkpoint 02 evidence"
aws ec2 describe-instances --instance-ids "$I_BASTION" "$I_APP_A" "$I_APP_B" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,Id:InstanceId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress}' \
  --output table | tee "$EVIDENCE/checkpoint02-instances.txt"

log "Writing SSH config block (workbook page 8)"
touch "$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"
sed -i '/# BEGIN EWB-LAB/,/# END EWB-LAB/d' "$HOME/.ssh/config"
cat >> "$HOME/.ssh/config" <<EOF
# BEGIN EWB-LAB
Host ewb-bastion
    HostName $BASTION_IP
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
# END EWB-LAB
EOF

log "Test 01 - BASELINE (before peering): bastion and App-A reachable, ping to App-B must fail"
ssh -o StrictHostKeyChecking=accept-new ewb-bastion 'hostname; hostname -I' | tee "$EVIDENCE/ssh-bastion.txt"
ssh -o StrictHostKeyChecking=accept-new ewb-app-a   'hostname; hostname -I' | tee "$EVIDENCE/ssh-app-a.txt"
{ echo '$ ping -c 4 10.20.1.10   (from App-A, BEFORE peering)'
  ssh ewb-app-a 'ping -c 4 -W 2 10.20.1.10' || echo "(ping failed as expected: no peering/routes yet)"
} 2>&1 | tee "$EVIDENCE/test01-baseline.txt"
echo "Done. Next: ./03-peering-and-routes.sh"
