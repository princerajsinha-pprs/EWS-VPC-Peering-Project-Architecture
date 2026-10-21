# AWS VPC Peering - Project Report
**Name:** Prince raj  **Batch:** 1.1  **Region:** India  **Completed:** ____________

Export this to PDF as `YourName_EWB_VPC_Peering.pdf`. Do not include the .pem key, passwords or tokens.

## 1. Architecture and inventory
Diagram: laptop -> IGW (VPC A) -> bastion (10.10.1.10) -> App-A (10.10.2.10) / App-B (10.20.1.10) via pcx.
Paste `evidence/inventory-ids.txt`, `inventory-vpcs.txt`, `inventory-subnets.txt`.

| Resource | ID | CIDR / IP |
|---|---|---|
| ewb-vpc-a | | 10.10.0.0/16 |
| ewb-vpc-b | | 10.20.0.0/16 |
| ewb-a-public | | 10.10.1.0/24 |
| ewb-a-private | | 10.10.2.0/24 |
| ewb-b-private | | 10.20.1.0/24 |
| ewb-bastion | | 10.10.1.10 + public IPv4 |
| ewb-app-a | | 10.10.2.10 |
| ewb-app-b | | 10.20.1.10 |
| ewb-a-b-peer | | - |

## 2. Subnets, IGW and route tables
Screenshots: Checkpoint 01, Checkpoint 04 (all three route tables with subnet associations).

| Route table | Associated subnet | Routes |
|---|---|---|
| ewb-rt-a-public | ewb-a-public | local; 0.0.0.0/0 igw; 10.20.0.0/16 pcx |
| ewb-rt-a-private | ewb-a-private | local; 10.20.0.0/16 pcx |
| ewb-rt-b-private | ewb-b-private | local; 10.10.0.0/16 pcx |

## 3. Peering and security rules
Screenshot: peering Active with both VPC IDs (Checkpoint 03). Paste `inventory-security-groups.json`.

## 4. Test evidence
Attach, labelled with host / test / result:
- Test 01 Baseline (`test01-baseline.txt`) - failure expected
- Test 02 Forward path (`test02-forward.txt`) - 0% loss
- Test 03 Reverse path (`test03-reverse.txt`) - 0% loss
- Test 04 SSH to App-B via bastion (`test04-ssh-app-b.txt`)
- Test 05 Isolation (`test05-isolation.txt` + console screenshot)
- Test 06 Controlled failure and recovery (`test06-controlled-failure.txt`)

## 5. Forward path and return path
Forward: App-A (10.10.2.10) sends to 10.20.1.10. The App-A private route table matches 10.20.0.0/16 and
sends it to the pcx. App-B's security group accepts ICMP Echo request from 10.10.2.10/32.
Return: App-B replies to 10.10.2.10. The VPC B route table matches 10.10.0.0/16 and sends it back over the
pcx. The security group is stateful, so the reply is allowed automatically.

## 6. Controlled failure
Removing only the ICMP Echo request rule on ewb-sg-app-b (source 10.10.2.10/32) stopped the pings, while SSH
still worked, so the fault was the security group, not routing. Restoring the same rule restored replies.

## 7. Be-ready-to-explain answers
1. **Why a return route?** Peering is not automatic routing. Without a route to 10.10.0.0/16 in VPC B, replies
   have no path back, so the connection fails even though requests arrive.
2. **Why is the App-B SSH source the bastion private IP?** ProxyJump makes the bastion open a new SSH
   connection to App-B, so App-B sees the bastion's private IP (10.10.1.10) as the source, not your laptop.
3. **Why doesn't Active peering guarantee ping?** Active only means the link exists. Route tables must point
   to it on both sides, and security groups (and NACLs) must permit the traffic.
4. **Can VPC B use VPC A's internet gateway over peering?** No. Peering does not support edge-to-edge routing
   through a peer's IGW (or NAT), and it is non-transitive.

## 8. Cleanup evidence and what I learned
Paste `evidence/cleanup-evidence.txt` and a billing/console screenshot. Short reflection: ____________
