# Networking notes

- a Nat Gateway is defined within a public subnet of an availability zone and allows an outbound connection to be initiated
  from say a private subnet bound Ec2 instance in that AZ and VPC
- an Internet Gateway allows:
  -  public outbound internet connectivity from the NAT Gateway associated private EC2 
  -  Inbound access to instances with a public IP
- Internet Gateway (IGW) allows instances with public IPs to access the internet.
- NAT Gateway (NGW) allows instances with no public IPs to access the internet.
- Each NAT gateway is created in a specific Availability Zone and implemented with redundancy in that zone.
- Internet Gateway is not Availability Zone specific.