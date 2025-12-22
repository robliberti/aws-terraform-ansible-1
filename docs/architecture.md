# Architecture (Tiny)

This repo provisions a **2-tier AWS VPC** with a safe, real-world layout:

- **Public subnet**: inbound SSH allowed only from `my_ip_cidr`
- **Private subnet**: **no inbound from Internet**, outbound via **NAT Gateway**
- **Bastion pattern**: you SSH to the public instance, then hop to the private one

## Traffic flow

```text
Internet
  |
  | 0.0.0.0/0
 [IGW]
  |
  v
Public Subnet (10.0.1.0/24)  ----SSH (22) from my_ip_cidr---->  Public EC2 (bastion)
  |
  | SSH (22) allowed ONLY from public SG
  v
Private Subnet (10.0.2.0/24) -> 0.0.0.0/0 -> NAT GW (public subnet + EIP) -> Internet (yum/dnf updates)
```

## Route tables

- **Public RT**: `0.0.0.0/0 -> Internet Gateway`
- **Private RT**: `0.0.0.0/0 -> NAT Gateway`
- Both RTs also have an implicit `VPC CIDR -> local` route for east/west traffic.

## Why NAT is in the public subnet

A NAT Gateway needs a path **to the Internet** (via the IGW) so it must live in a subnet that routes `0.0.0.0/0` to the IGW.  
Private instances never talk directly to the IGW — they talk to the NAT (private-to-public inside the VPC), and the NAT talks outward.
