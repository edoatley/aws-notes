# Lab 3: Secure Networking - Building Your Custom VPC (Medium)

## Objective
Build a custom VPC with isolated public and private subnets, routing, and EC2 instances to practice secure network segmentation.

## Success Criteria
- VPC created with CIDR (e.g., `10.10.0.0/16`) and attached Internet Gateway.
- Public subnet (e.g., `10.10.1.0/24`) and private subnet (e.g., `10.10.2.0/24`) in the same AZ.
- Public route table with `0.0.0.0/0` to IGW associated to public subnet.
- Private route table with only local route associated to private subnet.
- Public EC2 instance (`t3.micro`) with public IP; SG allows SSH from local IP.
- Private EC2 instance (`t3.micro`) without public IP; SG allows SSH only from VPC CIDR.
- Verify: SSH to public instance; public instance can ping internet; cannot SSH to private from internet; can SSH to private from public; private cannot ping internet.

## Services Involved
- Amazon VPC, Subnets, Route Tables, Internet Gateway
- Amazon EC2, Security Groups

## Tips
- Subnet publicity is defined by its route table, not its name.
- Security Groups are stateful; NACLs are stateless—understand the distinction.
- Perform manual creation at least once to internalize relationships beyond the console wizard.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._


