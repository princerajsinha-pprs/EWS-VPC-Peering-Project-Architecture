#!/usr/bin/env bash
# Workbook page 11: remove ONLY the App-B ICMP echo rule from 10.10.2.10/32, show failure, restore, show recovery.
source "$(dirname "$0")/lib.sh"
need SG_APP_B

OUT="$EVIDENCE/test06-controlled-failure.txt"
: > "$OUT"
say() { echo -e "$*" | tee -a "$OUT"; }

say "--- Before: ping works ---"
ssh ewb-app-a 'ping -c 4 10.20.1.10' 2>&1 | tee -a "$OUT" || true

say "\n--- Removing ICMP echo-request rule (10.10.2.10/32) from ewb-sg-app-b; SSH rule untouched ---"
aws ec2 revoke-security-group-ingress --group-id "$SG_APP_B" --protocol icmp --port 8 --cidr 10.10.2.10/32 | tee -a "$OUT"
sleep 5
say "\n--- During: expect 100% packet loss ---"
ssh ewb-app-a 'ping -c 4 -W 2 10.20.1.10' 2>&1 | tee -a "$OUT" || say "(ping failed as expected)"
say "\nSSH to App-B still works:"
ssh ewb-app-b 'hostname' 2>&1 | tee -a "$OUT"

say "\n--- Restoring the exact rule ---"
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B" --protocol icmp --port 8 --cidr 10.10.2.10/32 | tee -a "$OUT"
sleep 5
say "\n--- After: expect 0% packet loss ---"
ssh ewb-app-a 'ping -c 4 10.20.1.10' 2>&1 | tee -a "$OUT"

aws ec2 describe-security-groups --group-ids "$SG_APP_B" --query 'SecurityGroups[0].IpPermissions' --output json \
  | tee "$EVIDENCE/sg-app-b-restored.json" >/dev/null
echo "Done. Evidence in $EVIDENCE"
