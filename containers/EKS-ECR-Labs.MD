# EKS/ECR

## Basic Container Runtime

Create a small EKS cluster with an associated ECR: [template](../resources/containers/basic-container-rt-cfn.yaml)

The template defines:

* A VPC
* 2 public subnets
* 2 private subnets
* An internet Gateway
* Route table linking public subnets to the IGW