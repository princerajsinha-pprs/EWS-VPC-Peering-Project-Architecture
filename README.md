# EWS-VPC-Peering-Project-Architecture
# EWB AWS VPC Peering - Project Kit

Automates every step of the workbook with the AWS CLI. You run it in your own lab account, so the
evidence in your report is genuinely yours (the workbook requires your own execution results).

## Prerequisites
- AWS CLI v2 configured for your lab account (`aws sts get-caller-identity` works)
- Region defaults to `ap-south-1` (Mumbai); OpenSSH client (WSL on Windows); `curl`
- Permissions for VPC, EC2, key pairs, SSM parameter read

## Run order
```bash
cd ewb-vpc-peering
chmod +x *.sh
export STUDENT="Prince Raj"        # used in the Student tag
./01-build-network.sh             # Checkpoint 01  (VPCs, subnets, IGW, route tables, SGs)
./02-launch-instances.sh          # Checkpoint 02 + SSH config + Test 01 BASELINE (ping must fail)
./03-peering-and-routes.sh        # Checkpoint 03/04 + Tests 02-05
./04-controlled-failure.sh        # Test 06: remove ICMP rule -> fail -> restore -> recover
./05-capture-inventory.sh         # IDs and SG rules for the report
# take console screenshots now (see REPORT_TEMPLATE.md), then:
./99-cleanup.sh                   # deletes everything, writes cleanup evidence
```
Output is saved in `evidence/`. Resource IDs are stored in `state.env`.

## Console screenshots you still need to capture
Checkpoint 01 (subnet associations, public default route), Checkpoint 03 (peering Active with both VPC IDs),
Checkpoint 04 (all three route tables), instance details showing no public IPv4 on App-A/App-B,
and the cleanup check. Label each with host, test and result.

## Cost notes
3 x t3.micro + 8 GB gp3 each + 1 public IPv4 (bastion). No NAT gateway. Do the work in one sitting and
run cleanup immediately afterwards.

## Troubleshooting (from workbook page 12)
| Symptom | Check |
|---|---|
| Bastion SSH times out | Your current public IP in the bastion SG (re-run: revoke old /32, authorize new); public route table has 0.0.0.0/0 to IGW |
| App-B SSH fails | Public route table has 10.20.0.0/16 -> pcx; VPC B route table has 10.10.0.0/16 -> pcx; SG source is 10.10.1.10/32 |
| Ping fails after peering | Both private route tables, pcx Active, Echo request rule on destination SG |
| Permission denied (publickey) | Key file, `ec2-user`, IdentityFile (routing is fine if you got this far) |
| Bastion IP changed after stop/start | Update `HostName` in `~/.ssh/config` |
| Your home IP changed | Update the ewb-sg-bastion rule |
