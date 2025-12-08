# Hands-On Lab Guide for the AWS Certified Solutions Architect - Associate (SAA-C03)

## Section 1: A Strategic Approach to SAA-C03 Hands-On Preparation

### Introduction to the SAA-C03

This report provides a series of hands-on lab challenges designed to build practical skills for the AWS Certified Solutions Architect - Associate (SAA-C03) exam. This certification is not a test of simple memorization; it validates the ability to *design* cost-effective, high-performing, and resilient solutions. These labs are therefore engineered to build that specific "design muscle."

### Mapping Labs to Exam Domains

The SAA-C03 exam consists of 65 multiple-choice or multiple-response questions, administered over 130 minutes. The curriculum is structured around four core domains, which these labs directly address:

1.  **Domain 1: Design Secure Architectures (30%)**: This domain is covered extensively in labs focusing on AWS Identity and Access Management (IAM), Virtual Private Clouds (VPCs), Security Groups, Network ACLs, and data encryption.
2.  **Domain 2: Design Resilient Architectures (26%)**: This domain is addressed by building multi-Availability Zone (Multi-AZ) applications, implementing Auto Scaling, and designing decoupled, event-driven systems using services like Amazon SQS and SNS.
3.  **Domain 3: Design High-Performing Architectures (24%)**: This domain is explored through labs involving compute selection (Amazon EC2), storage tiers (Amazon S3, Amazon EBS), database choice (Amazon RDS, Amazon DynamoDB), and content delivery (Amazon CloudFront).
4.  **Domain 4: Design Cost-Optimised Architectures (20%)**: This domain is not a single lab but a critical theme woven through every exercise. It is addressed by adhering to the AWS Free Tier, creating billing alarms, and explicitly contrasting design choices based on their cost implications (e.g., a NAT Instance versus a managed NAT Gateway).

### Our Progressive Approach

The labs presented in this report follow a progressive structure. They begin with foundational, single-service building blocks (IAM, S3) and progressively combine them into complex, multi-service architectures that mirror real-world projects and exam scenarios.

## Section 2: Prerequisites: Your Lab Environment & Cost-Control Mandate

Adhering to a minimal budget is a primary constraint. This requires a precise understanding of the AWS Free Tier and the implementation of non-negotiable cost-control mechanisms.

### Your AWS Account: The Free Tier Explained

The AWS Free Tier model was updated on July 15, 2025. The benefits available depend on when the AWS account was created.

  * **Scenario A: "Legacy" 12-Month Free Tier (Account created *before* July 15, 2025):** This model provides specific service allocations (e.g., 750 hours of `t2.micro`) for 12 months from the account sign-up date. Usage within these limits incurs no charge.
  * **Scenario B: "New" Free Plan (Account created *on or after* July 15, 2025):** This model offers a 6-month Free Plan that includes $100 in sign-up credits and the potential to earn up to $100 more. These credits create a financial buffer, allowing the use of services beyond the "Always Free" tier until the credit balance is depleted or the 6-month period expires.
  * **"Always Free" Services:** Regardless of the account's age, AWS provides an "Always Free" tier for many services. These offers do not expire and typically include a baseline allocation (e.g., 1 million AWS Lambda requests per month) sufficient for many of these labs.

### Key Free Tier Limits Table

This table summarizes the specific free tier limits for the primary services used in these labs. It is imperative to operate within these constraints to avoid charges.

**Table 1: SAA-C03 Lab Free Tier Service Allocations**

| Service | 12-Month Tier (Pre-July 15, 2025) | Always Free Tier (All Accounts) |
| :--- | :--- | :--- |
| **Amazon EC2** | 750 hours/month of `t2.micro` or `t3.micro` | N/A |
| **Amazon S3** | 5 GB Standard Storage, 20,000 Get Requests, 2,000 Put Requests | 5 GB Standard Storage |
| **Amazon RDS** | 750 hours/month of `db.t3.micro` or `db.t4g.micro` (Single-AZ only) | N/A |
| | 20 GB General Purpose SSD (gp2) Storage | |
| **Amazon DynamoDB**| N/A | 25 GB Storage, 25 Read Capacity Units (RCU), 25 Write Capacity Units (WCU) |
| **AWS Lambda** | N/A | 1 Million requests/month |
| | | 400,000 GB-seconds/month compute time |
| **Application LB** | 750 hours/month (shared with Classic LB) | N/A |
| | 15 Load Balancer Capacity Units (LCUs) | |
| **Amazon SQS** | N/A | 1 Million requests/month |
| **Amazon SNS** | N/A | 1 Million publishes/month |
| **Amazon CloudFront**| N/A | 1 TB Data Transfer Out/month |
| | | 10 Million HTTP/S requests/month |
| **Amazon CloudWatch**| N/A | 10 custom metrics, 5 GB Logs |

### Lab 0 (Mandatory): Create a Billing Alarm

  * **Introduction:** This is the primary safety net for cost control. Before any resources are provisioned, a billing alarm must be created. This alarm will send an email notification if estimated charges exceed a defined monetary threshold.
  * **Success Criteria:**
    1.  An Amazon CloudWatch alarm is created in the `us-east-1` (N. Virginia) region, as billing metrics are global and published to this region.
    2.  The alarm is configured to monitor the `EstimatedCharges` metric.
    3.  The threshold is set to a low value (e.g., $5.00 USD).
    4.  An Amazon SNS (Simple Notification Service) topic is created and configured as the alarm's action.
    5.  An email subscription for this SNS topic is confirmed. An email should be received from AWS confirming the subscription.
  * **Services Involved:** Amazon CloudWatch, Amazon SNS.
  * **Tips:**
      * This alarm is free. The 10 custom metrics in the CloudWatch "Always Free" tier cover this.
      * This alarm tracks *estimated* charges. It is a lagging indicator, but it is the most effective tool for preventing significant, unexpected costs.
      * This step is non-negotiable for any cost-conscious student.

## Section 3: Lab 1 (Easy): Foundations - Secure Access with IAM

  * **Introduction:** This lab addresses **Domain 1: Design Secure Architectures**. The objective is to configure a secure AWS account environment based on the *principle of least privilege*. AWS best practice dictates that the root account, which has unrestricted access, should not be used for any daily tasks. Instead, IAM users and groups should be created for administrative and development tasks.
  * **Success Criteria:**
    1.  Multi-Factor Authentication (MFA) is enabled on the root account using a virtual MFA application.
    2.  Two new IAM users are created: `dev-user` and `readonly-user`.
    3.  Two new IAM groups are created: `Developers` and `Auditors`.
    4.  The `Auditors` group has the AWS-managed policy `ReadOnlyAccess` attached.
    5.  The `Developers` group has the AWS-managed policies `AmazonS3FullAccess` and `AmazonEC2FullAccess` attached.
    6.  Log in as `readonly-user` (who is a member of the `Auditors` group).
    7.  Verification: `readonly-user` can successfully *view* S3 buckets but receives an "Access Denied" error when attempting to *create* one.
    8.  Log in as `dev-user` (who is a member of the `Developers` group).
    9.  Verification: `dev-user` can successfully *create* an S3 bucket but receives an "Access Denied" error when attempting to view the IAM dashboard.
  * **Services Involved:** AWS Identity and Access Management (IAM).
  * **Tips:**
      * **MFA is Critical:** The first action in any new AWS account must be to secure the root user with MFA.
      * **Groups \> Users:** Note that policies are applied to *groups*, not directly to users. This is a core IAM best practice for scalability. When an employee (user) changes roles, their permissions are modified simply by moving them to a different group, rather than auditing and editing complex policies attached directly to their user.
      * **Exam Insight:** The SAA-C03 exam will test the difference between IAM Users (long-term credentials for a person or application), IAM Roles (temporary credentials assumed by a user or service), and IAM Policies (the JSON documents defining permissions). This lab solidifies the relationship between users, groups, and policies.

## Section 4: Lab 2 (Easy): Resilient Foundations - Secure Static Website Hosting

  * **Introduction:** This lab addresses **Domain 2 (Resilient)** and **Domain 3 (High-Performing)**. It involves deploying a static website using the secure, modern, and exam-correct architecture. The *insecure* method is to make an S3 bucket public. The *correct* method is to keep the S3 bucket **private** and use **Amazon CloudFront** with **Origin Access Control (OAC)** to serve the content. This architecture provides enhanced security, a global Content Delivery Network (CDN) for high performance, and HTTPS encryption at no additional cost.
  * **Success Criteria:**
    1.  An Amazon S3 bucket is created. The "Block all public access" setting must remain **ON** (enabled).
    2.  A simple `index.html` file (e.g., `<html>Hello World</html>`) is uploaded to the bucket.
    3.  Verification: Accessing the S3 object's URL (e.g., `s3.region.amazonaws.com/.../index.html`) directly in a browser results in a "403 Access Denied" error. This confirms the bucket is private.
    4.  An Amazon CloudFront distribution is created, with the S3 bucket selected as its origin.
    5.  During configuration, the "Origin access" setting is set to "Origin access control settings (recommended)".
    6.  CloudFront will provide a bucket policy that must be copied and applied to the S3 bucket's permissions. This policy explicitly grants the CloudFront service principal permission to get objects from the bucket.
    7.  Verification: Accessing the CloudFront distribution's domain name (e.g., `d12345.cloudfront.net`) in a browser successfully displays the `index.html` file over HTTPS.
  * **Services Involved:** Amazon S3, Amazon CloudFront.
  * **Tips:**
      * **OAC \> OAI:** Older exam preparation materials may mention "Origin Access Identity" (OAI). "Origin Access Control" (OAC) is the newer, more robust, and recommended replacement.
      * **Cost:** This lab is effectively **free**. The S3 "Always Free" tier includes 5 GB of storage, and the CloudFront "Always Free" tier is exceptionally generous, with 1 TB of data transfer and 10 million HTTP/S requests per month.
      * **Exam Insight:** A common exam scenario involves securing a static website or improving its global performance. The correct architectural answer is invariably **S3 for storage + CloudFront for distribution**. The security component is OAC, and the performance component is the global edge-caching provided by the CDN.

## Section 5: Lab 3 (Medium): Secure Networking - Building Your Custom VPC

  * **Introduction:** This is the most critical foundational lab for the SAA-C03 exam, directly addressing **Domain 1: Design Secure Architectures**. This lab moves beyond the "Default VPC" to build a custom, isolated network from scratch. This process is fundamental to demonstrating an understanding of network segmentation, a core competency for a solutions architect.
  * **Success Criteria:**
    1.  Create a new VPC with a private IPv4 CIDR block (e.g., `10.10.0.0/16`).
    2.  Create an Internet Gateway (IGW) and attach it to the new VPC.
    3.  Create two subnets in the *same* Availability Zone:
          * "Public Subnet" (e.g., `10.10.1.0/24`).
          * "Private Subnet" (e.g., `10.10.2.0/24`).
    4.  Create two custom Route Tables:
          * "Public Route Table": Create a default route (`0.0.0.0/0`) with the IGW as the target. Associate this table with the "Public Subnet".
          * "Private Route Table": Ensure it *only* contains the default `local` route for the VPC's CIDR. Associate this table with the "Private Subnet".
    5.  Launch a `t3.micro` EC2 instance in the **Public Subnet**. Ensure "Auto-assign public IP" is enabled. Attach a Security Group that allows inbound SSH (Port 22) from your local IP address.
    6.  Launch a `t3.micro` EC2 instance in the **Private Subnet**. Ensure "Auto-assign public IP" is *disabled*. Attach a Security Group that allows inbound SSH (Port 22) *only* from the private IP range of the VPC (e.g., `10.10.0.0/16`).
    7.  Verification 1: Successfully SSH into the Public instance from the local computer.
    8.  Verification 2: From the Public instance, successfully `ping google.com`. This confirms outbound internet access via the IGW.
    9.  Verification 3: *Fail* to SSH into the Private instance from the local computer. This confirms it is not internet-accessible.
    10. Verification 4: From the Public instance, successfully SSH into the Private instance using its private IP address (e.g., `ssh -i "key.pem" ec2-user@10.10.2.X`). This is known as using a "bastion host" or "jump box".
    11. Verification 5: From the Private instance, *fail* to `ping google.com`. This confirms it has no outbound internet access.
  * **Services Involved:** Amazon VPC, Subnets, Route Tables, Internet Gateway, Amazon EC2, Security Groups.
  * **Tips:**
      * **Public vs. Private:** The *only* thing that makes a subnet "public" is its associated Route Table. A public subnet has a route table with a route to an Internet Gateway; a private subnet does not.
      * **Security Groups vs. NACLs:** This lab uses Security Groups (SGs), which are *stateful* (outbound replies are automatically allowed) and act as a firewall at the *instance* (ENI) level. Network Access Control Lists (NACLs) are *stateless* (both inbound and outbound rules must be explicitly allowed) and act as a firewall at the *subnet* level. Understanding this distinction is critical for the exam.
      * **VPC Wizard:** The AWS console provides a "VPC and more" wizard that automates this creation. It is strongly recommended to perform this lab *manually* (resource by resource) at least once. Manual creation builds a deep understanding of how the components connect, which the wizard abstracts away.

## Section 6: Lab 4 (Medium): Cost-Optimized Networking - The NAT Instance Challenge

  * **Introduction:** This lab builds on Lab 3 and directly addresses **Domain 4: Design Cost-Optimised Architectures**. The private instance from Lab 3 is secure, but it cannot access the internet for essential tasks like software updates or patching. The AWS-managed solution is a NAT Gateway, but this service incurs hourly and data processing fees and is not free-tier eligible. For development, testing, or low-traffic workloads, a **NAT Instance** is a far more cost-effective design.
  * **Success Criteria:**
    1.  Using the VPC from Lab 3, launch a new `t3.micro` EC2 instance into the **Public Subnet**. Use a standard Amazon Linux AMI. This will be the "NAT Instance."
    2.  Ensure this instance has a Public IP and a Security Group that allows SSH from the local IP.
    3.  Select the running NAT Instance in the EC2 console. Navigate to "Actions" -\> "Networking" -\> "Change source/destination check" and **disable** this feature.
    4.  Navigate to the VPC console and select the "Private Route Table."
    5.  Edit the routes. Add a new route: for Destination `0.0.0.0/0`, set the Target to the **Instance ID** of the NAT Instance.
    6.  SSH into the public bastion host (from Lab 3), and from there, SSH into the Private instance (from Lab 3).
    7.  Verification 1: From the Private instance, execute `ping google.com`. The ping should now be successful. The traffic is being routed from the private subnet to the NAT instance, which then forwards it to the Internet Gateway.
    8.  Verification 2: Verify that the Private instance is *still* inaccessible via SSH from the public internet.
  * **Services Involved:** Amazon EC2, VPC, Route Tables, Security Groups.
  * **Tips:**
      * **Architectural Insight: The NAT Instance vs. Gateway Tradeoff.** This is a classic SAA-C03 design choice:
          * **NAT Gateway:** Managed by AWS, redundant within an AZ, and scales to 100 Gbps. It is the "resilient" and "high-performance" choice, but it is *expensive*.
          * **NAT Instance:** An EC2 instance managed by the user. It is *cheap* (it can use a `t3.micro` instance, which is free-tier eligible). However, it is a *single point of failure* and a performance bottleneck (limited by the instance type's bandwidth). The exam will test the ability to choose the right one for a given scenario (e.g., "cost-sensitive dev environment" vs. "high-availability production workload").
      * **Source/Destination Check:** This is the most common point of failure in this lab. By default, an EC2 instance verifies that it is the source or destination of any traffic it handles. A NAT instance acts as a router, handling traffic *for other instances*. Disabling this check is mandatory for it to function as a network address translator.

## Section 7: Lab 5 (Medium-Hard): Designing a Resilient 2-Tier Application

  * **Introduction:** This lab combines networking and database design, addressing **Domain 1 (Secure)** and **Domain 2 (Resilient)**. This pattern—a public-facing web tier communicating with a secure, private database tier—is one of the most common and fundamental architectures on the SAA-C03 exam.
  * **Success Criteria:**
    1.  Modify the VPC from Lab 3 to be Multi-AZ. Ensure it has two public subnets and two private subnets, with one pair in (e.g.) `us-east-1a` and the other in `us-east-1b`.
    2.  Launch a `t3.micro` EC2 instance (the "Web Server") into one of the **public subnets**.
    3.  Create a new Security Group named `web-sg`. Attach it to the Web Server. This SG must allow inbound SSH (Port 22) from the local IP and HTTP (Port 80) from anywhere (`0.0.0.0/0`).
    4.  Create a "DB Subnet Group" in the RDS console that includes the two **private subnets**.
    5.  Launch an Amazon RDS (MySQL) `db.t3.micro` instance.
    6.  During creation, assign it to the new DB Subnet Group (which places it in the private subnets).
    7.  Crucially, set the "Publicly accessible" option to **No**.
    8.  Create a *new* Security Group named `db-sg` and assign it to the RDS instance.
    9.  Edit the inbound rules for `db-sg`. Add a rule that allows `MySQL/Aurora` (Port 3306) traffic. For the "Source" of this rule, do *not* enter an IP address; instead, search for and select the `web-sg` security group.
    10. Verification 1: SSH into the public Web Server. From there, install the `mysql` client (e.g., `sudo yum install mysql`) and successfully connect to the RDS database using its database endpoint DNS name.
    11. Verification 2: Attempt to connect to the RDS database endpoint from the local machine (using a local MySQL client). The connection must time out, proving the database is not exposed to the internet.
  * **Services Involved:** Amazon EC2, Amazon VPC, Subnets, Amazon RDS, Security Groups.
  * **Tips:**
      * **Cost Warning:** This lab is a common source of unexpected bills. Be *meticulous* during the RDS creation process.
        1.  **Instance Class:** Select `db.t3.micro` or `db.t4g.micro`.
        2.  **Storage:** Set the allocated storage to 20 GB of General Purpose (gp2) SSD. The free tier *only* includes 20 GB.
        3.  **Availability:** Under "Availability & durability," select "Do not create a standby instance." The free tier is for Single-AZ *only*. Multi-AZ deployments are not free.
      * **Security Groups as References:** The most important architectural concept in this lab is referencing one security group (`web-sg`) as the *source* for an inbound rule in another (`db-sg`). This is a dynamic, secure, and scalable pattern. It means *any* instance in the `web-sg` group is automatically granted database access. This is far superior to hard-coding the web server's private IP, which would break as soon as the instance was replaced or scaled.

## Section 8: Lab 6 (Hard): Designing High-Availability & Scalability

  * **Introduction:** This lab evolves the 2-tier application from Lab 5 to be fully resilient and elastic, addressing **Domain 2 (Resilient)** and **Domain 3 (High-Performing)**. A single web server in one AZ is a single point of failure. This lab builds a system that can withstand an instance failure and automatically scale to meet demand. This is achieved by deploying instances across multiple AZs behind an Application Load Balancer (ALB) and managing them with an Auto Scaling Group (ASG).
  * **Success Criteria:**
    1.  Create a **Launch Template**. Configure it with:
          * Amazon Linux AMI.
          * `t3.micro` instance type.
          * The `web-sg` Security Group (from Lab 5).
          * A User Data script to install and run a simple web server:bash
            \#\!/bin/bash
            yum update -y
            yum install -y httpd
            systemctl start httpd
            systemctl enable httpd
            echo "\<h1\>Hello from $(hostname -f)\</h1\>" \> /var/www/html/index.html
            ```
            ```
    2.  Create a **Target Group** (in the EC2 console) that listens on HTTP Port 80, using the VPC from Lab 3.
    3.  Create an **Application Load Balancer (ALB)**.
          * Set it to "internet-facing."
          * Map it to the two **public subnets** in different AZs.
          * Configure its listener on HTTP Port 80 to forward traffic to the new Target Group.
    4.  Create an **Auto Scaling Group (ASG)**.
          * Configure it to use the new Launch Template.
          * Configure it to span the same two **public subnets** as the ALB.
          * Under "Load balancing," attach it to the Target Group created in step 2.
          * Set its group size: Desired 2, Min 2, Max 4.
    5.  Verification 1: Wait 3-5 minutes. Access the ALB's DNS name in a web browser. The "Hello from..." page should appear.
    6.  Verification 2: Refresh the browser repeatedly. The hostname in the "Hello from..." message should change, proving the ALB is balancing traffic between the two instances.
    7.  Verification 3 (Resilience): Go to the EC2 Instances console. Manually select one of the two web instances and **terminate** it.
    8.  Verification 4: Observe the ASG's "Activity" and "Instance management" tabs. Within minutes, the ASG will detect the termination, launch a new, healthy instance to replace it, and the new instance will be automatically registered with the ALB.
  * **Services Involved:** Amazon EC2, Auto Scaling Group (ASG), Launch Template, Application Load Balancer (ALB), Amazon VPC.
  * **Tips:**
      * **Cost:** The ALB provides 750 free hours/month. Running two `t3.micro` instances will consume the 750 free EC2 hours twice as fast (750 / 2 = 375 hours of runtime for the pair). This lab is free *only if* run for a short duration and then immediately torn down.
      * **Launch Template vs. Configuration:** Launch Templates are the modern, recommended standard for defining ASG instances. Launch Configurations are a legacy feature. The exam will expect knowledge of Launch Templates.
      * **Health Checks:** This architecture demonstrates two distinct types of health checks.
        1.  **ALB Health Check:** The ALB pings the instances (e.g., on `/index.html`) to determine if they are healthy enough to receive traffic. If an instance fails, the ALB routes traffic *away* from it.
        2.  **ASG Health Check:** The ASG monitors the EC2 instance's system status. If an instance fails (or is terminated, as in the lab), the ASG *terminates and replaces* it.

## Section 9: Lab 7 (Hard): Designing Decoupled, Event-Driven Architectures

  * **Introduction:** This lab focuses on **Domain 2: Design Resilient Architectures**. Tightly coupled systems, where services make direct, synchronous calls to each other, are brittle. If the receiving service fails, the calling service also fails. This lab builds a *loosely coupled*, *asynchronous* architecture using AWS messaging services. This specific "fan-out" pattern (one event triggering multiple, parallel actions) is a powerful and highly resilient design.
  * **Success Criteria:**
    1.  Create an Amazon S3 bucket (e.g., `saa-fanout-source-bucket`).
    2.  Create an Amazon SNS (Simple Notification Service) Topic (e.g., `ImageUploadTopic`).
    3.  Create two Amazon SQS (Simple Queue Service) Standard Queues (e.g., `ImageResizeQueue` and `ImageAnalyticsQueue`).
    4.  Create a simple AWS Lambda function (`AnalyticsLogger`) with a basic execution role that allows it to write to CloudWatch Logs.
    5.  Configure the `ImageAnalyticsQueue` SQS queue as an event source trigger for the `AnalyticsLogger` Lambda function.
    6.  **Subscribe** both SQS queues (`ImageResizeQueue` and `ImageAnalyticsQueue`) to the `ImageUploadTopic` SNS topic. This creates the fan-out.
    7.  Configure an **S3 Event Notification** on the S3 bucket. Set this notification to trigger on "All object create events" (`s3:ObjectCreated:*`) and to send the notification to the `ImageUploadTopic` SNS topic.
    8.  Upload a test image file to the S3 bucket.
    9.  Verification 1: Navigate to the SQS console. Check both `ImageResizeQueue` and `ImageAnalyticsQueue`. Both queues should show "Messages available: 1."
    10. Verification 2: Navigate to CloudWatch Logs for the `AnalyticsLogger` function. A new log stream should exist, containing the S3 event message (forwarded by SNS and SQS).
  * **Services Involved:** Amazon S3, Amazon SNS, Amazon SQS, AWS Lambda, IAM.
  * **Tips:**
      * **Cost:** This entire architecture is **100% free** to build and run at low scale, as it falls entirely within the "Always Free" tier. This includes 1 million Lambda requests, 1 million SQS requests, 1 million SNS publishes, and 5 GB of S3 storage every month, indefinitely.
      * **Architectural Insight: The 3 Pillars of Resilience:**
        1.  **Decoupling:** The S3 bucket (the "publisher") is completely unaware of the services that process the image. It only sends one message to an SNS topic. This allows adding or removing consumers (like a new `ImageModerationQueue`) without *any* changes to the S3 bucket.
        2.  **Fan-Out:** SNS is responsible for message distribution. It takes the single S3 event and delivers a *copy* to *all* of its subscribers (the two SQS queues).
        3.  **Durability:** SQS provides the durable buffer. If the `AnalyticsLogger` Lambda function fails (e.g., due to a code error), the message is *not lost*. SQS retains the message until it is successfully processed. For even greater resilience, a Dead-Letter Queue (DLQ) could be configured on the SQS queue to hold messages that fail repeatedly. This is a core SAA-C03 concept for building fault-tolerant systems.

## Section 10: Lab 8 (Hard): Designing a High-Performing Serverless API

  * **Introduction:** This lab directly addresses **Domain 3 (High-Performing)** and **Domain 4 (Cost-Optimized)**. This architecture is the modern, serverless alternative to the traditional 2-tier application built in Lab 5. Instead of dedicated EC2 servers (compute) and an RDS instance (database), this design uses Amazon API Gateway (the "front door"), AWS Lambda (the "compute"), and Amazon DynamoDB (the "database").
  * **Success Criteria:**
    1.  Create an Amazon **DynamoDB** table (e.g., `MusicLibrary`).
    2.  Configure the table with a Partition key of `Artist` (Type: String) and a Sort key of `SongTitle` (Type: String). Use "On-demand" capacity mode.
    3.  Create an **IAM Role** for Lambda. Attach policies that grant `dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:Scan`, and `dynamodb:DeleteItem` permissions specifically for the new table.
    4.  Create an **AWS Lambda Function** (e.g., `CrudApiHandler`) using Python or Node.js. Attach the IAM Role created in step 3.
    5.  Add code to the function that inspects the incoming event from API Gateway. The code should:
          * If `event['httpMethod'] == 'POST'`, parse the `body` and perform a `dynamodb.put_item()` operation.
          * If `event['httpMethod'] == 'GET'` and a path parameter `Artist` is present, perform a `dynamodb.query()` operation.
          * If `event['httpMethod'] == 'GET'` and no path parameter is present, perform a `dynamodb.scan()` operation.
          * Return a correctly formatted HTTP response (e.g., `{'statusCode': 200, 'body':...}`).
    6.  Create an **Amazon API Gateway (HTTP API)**, which is simpler and cheaper than a REST API.
    7.  Create routes and attach them to a single Lambda integration pointing to the `CrudApiHandler` function:
          * `POST /music`
          * `GET /music`
          * `GET /music/{Artist}` (The `{Artist}` denotes a path parameter).
    8.  Use an API testing tool (like Postman or `curl`) and the API's "Invoke URL."
    9.  Verification 1: `POST` a JSON payload (e.g., `{"Artist": "Queen", "SongTitle": "Bohemian Rhapsody"}`) to the `/music` endpoint. A 200 OK response should be received, and the item should appear in the DynamoDB table.
    10. Verification 2: `GET` the `/music` endpoint. A JSON list of all items in the table should be returned.
    11. Verification 3: `GET` the `/music/Queen` endpoint. A JSON list containing *only* items for the artist "Queen" should be returned.
  * **Services Involved:** Amazon API Gateway, AWS Lambda, Amazon DynamoDB, IAM.
  * **Tips:**
      * **Cost:** Like Lab 7, this serverless architecture is **100% free** at low scale due to the generous "Always Free" tiers for Lambda (1M requests), DynamoDB (25 GB), and API Gateway (1M requests for REST APIs, HTTP APIs are even cheaper).
      * **Performance:** The SAA-C03 exam places heavy emphasis on database performance. The EC2/RDS model (Lab 5) is limited by the instance size of both the web server and the database. This serverless stack (Lab 8) scales automatically. DynamoDB, in particular, is designed to deliver consistent, single-digit millisecond latency at any scale.
      * **Architectural Choice:** This lab and Lab 6 provide the two most important *contrasting* patterns for the exam:
          * **Lab 6 (EC2/ALB/RDS):** A "traditional" virtualized architecture. It is suitable for stateful applications, legacy systems, or when full control over the operating system is required.
          * **Lab 8 (API-GW/Lambda/DDB):** A "modern" serverless architecture. It is ideal for event-driven, microservice-based, or unpredictable workloads. It requires no server management ("No-Ops") and follows a strict pay-for-what-you-use model.

## Section 11: Consolidated Lab Cleanup (Your "$0 Bill" Guarantee)

  * **Introduction:** This final section is a practical exercise in **Domain 4: Design Cost-Optimised Architectures**. A core skill of a solutions architect is decommissioning resources to prevent costs. Failure to clean up is the most common reason for unexpected charges. Resources must be deleted in the *reverse order of their dependency*.

  * **Step-by-Step Decommissioning Guide:**

    1.  **Lab 8 (Serverless):**

          * Delete the API Gateway HTTP API.
          * Delete the `CrudApiHandler` Lambda function.
          * Delete the `MusicLibrary` DynamoDB table.
          * Delete the associated IAM Role.

    2.  **Lab 7 (Decoupling):**

          * Navigate to the S3 bucket -\> Properties -\> Event Notifications. Delete the event notification.
          * Delete the `AnalyticsLogger` Lambda function.
          * Delete the `ImageResizeQueue` and `ImageAnalyticsQueue` SQS queues.
          * Delete the `ImageUploadTopic` SNS topic.
          * Empty the `saa-fanout-source-bucket` S3 bucket, then delete the bucket.
          * Delete the associated IAM Role.

    3.  **Lab 6 (HA/Scaling):**

          * Delete the Application Load Balancer (ALB).
          * Delete the associated Target Group.
          * Delete the Auto Scaling Group (ASG). *Tip: First, edit the ASG and set Min, Max, and Desired capacity to 0. Wait for the instances to terminate, then delete the group.*
          * Verify the EC2 instances have been terminated.
          * Delete the Launch Template.

    4.  **Lab 5 (2-Tier App):**

          * Delete the Amazon RDS database. When prompted, **skip final snapshot**. *This is critical, as snapshots cost money*.
          * Terminate the "Web Server" `t3.micro` EC2 instance.
          * Delete the `web-sg` and `db-sg` Security Groups. *Note: SGs can only be deleted if they are not attached to any resources.*

    5.  **Lab 4 (NAT Instance):**

          * Terminate the "NAT Instance" EC2 instance.
          * If an Elastic IP was allocated, navigate to the "Elastic IPs" section of the EC2 console, select the IP, and **release** it. *An unassociated Elastic IP will incur charges.*

    6.  **Lab 3 (VPC):**

          * Terminate any remaining EC2 instances from this lab.
          * In the VPC Console, select the Internet Gateway (IGW) and **detach** it from the custom VPC.
          * Delete the Internet Gateway (IGW).
          * Delete the custom Route Tables. *Note: The "main" route table for the VPC cannot be deleted, but it will be deleted with the VPC itself.*
          * Delete the Public and Private Subnets.
          * Finally, delete the Custom VPC.

    7.  **Lab 2 (S3/CloudFront):**

          * In the CloudFront console, select the distribution and click **Disable**. This change can take 15-20 minutes to propagate.
          * Once the status is "Disabled," select the distribution and **delete** it.
          * In the S3 console, **empty** the static website bucket, then **delete** the bucket.

    8.  **Lab 1 (IAM):**

          * Delete the `dev-user` and `readonly-user`.
          * Detach the managed policies from the `Developers` and `Auditors` groups.
          * Delete the `Developers` and `Auditors` groups.

    9.  **Lab 0 (Billing Alarm):**

          * Navigate to CloudWatch -\> Alarms. Select the billing alarm and delete it.

  * **Final Verification:** After 24 hours, check the AWS Billing and Cost Management console to ensure all charges have ceased and the bill remains at $0.00. This diligence is the hallmark of a professional architect.