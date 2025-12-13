# Lab 4: Cost-Optimized Networking - NAT Instance Challenge (Medium)

## Objective
Provide internet access for private subnet instances using a low-cost NAT instance instead of a managed NAT Gateway.

## Success Criteria
- Launch `t3.micro` NAT instance in the public subnet (from Lab 3) with a public IP and SSH allowed from local IP.
- Disable source/destination check on the NAT instance.
- Update private route table to send `0.0.0.0/0` to the NAT instance ID.
- From the bastion/public host, SSH into the private instance and successfully ping the internet.
- Private instance remains inaccessible via SSH from the public internet.

## Services Involved
- Amazon EC2
- Amazon VPC, Route Tables, Security Groups

## Tips
- Disabling source/destination check is mandatory for NAT behavior.
- NAT instance is cheaper but is a single point of failure and bandwidth-limited.
- Keep using the existing VPC and subnets from Lab 3 to avoid extra cost.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._



