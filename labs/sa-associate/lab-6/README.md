# Lab 6: Designing High-Availability & Scalability (Hard)

## Objective
Build a highly available web tier using an Auto Scaling Group across AZs behind an Application Load Balancer, with a Launch Template configuring the instances.

## Success Criteria
- Launch Template with Amazon Linux, `t3.micro`, `web-sg`, and user data to install/start httpd and write hostname page.
- Target Group on HTTP 80 for the Lab 3 VPC.
- Internet-facing ALB mapped to two public subnets in different AZs; listener forwards to Target Group.
- ASG using the Launch Template across the two public subnets; Desired=2, Min=2, Max=4.
- Accessing ALB DNS serves the page; refreshing shows changing hostnames.
- Terminating one instance triggers ASG to replace it and registers with ALB.

## Services Involved
- Amazon EC2, Launch Template, Auto Scaling Group
- Application Load Balancer
- Amazon VPC, Subnets, Security Groups

## Tips
- ALB health checks vs ASG health checks serve different purposes.
- Running two instances halves the free-tier hours; tear down promptly to control cost.
- Launch Templates are preferred over legacy Launch Configurations.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._




