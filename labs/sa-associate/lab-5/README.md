# Lab 5: Designing a Resilient 2-Tier Application (Medium-Hard)

## Objective
Deploy a public web server and private database in a Multi-AZ VPC, using security groups to tightly control access.

## Success Criteria
- VPC extended to Multi-AZ with two public and two private subnets.
- Web Server (`t3.micro`) in public subnet with SG `web-sg` allowing SSH from local IP and HTTP from anywhere.
- DB Subnet Group created using the two private subnets.
- RDS MySQL `db.t3.micro` launched in private subnets, not publicly accessible.
- `db-sg` created; inbound MySQL (3306) source set to `web-sg`.
- From Web Server: install MySQL client and connect to RDS endpoint successfully.
- From local machine: connection to RDS times out (not internet accessible).

## Services Involved
- Amazon VPC, Subnets, Security Groups
- Amazon EC2
- Amazon RDS (MySQL)

## Tips
- Keep RDS free-tier: `db.t3.micro`/`db.t4g.micro`, 20 GB gp2, Single-AZ (no standby).
- Security group referencing (`web-sg` as source for `db-sg`) is key for dynamic access control.
- Ensure DB is not publicly accessible; relies on SGs and subnet placement.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._




