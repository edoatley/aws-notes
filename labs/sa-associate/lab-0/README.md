# Lab 0: Billing Alarm (Mandatory)

## Objective
Create a cost-protection billing alarm in `us-east-1` that emails when estimated charges exceed a low threshold.

## Success Criteria
- CloudWatch billing alarm monitors `EstimatedCharges` in `us-east-1`.
- Alarm threshold set (e.g., $5.00 USD).
- SNS topic created and set as alarm action.
- Email subscription for the SNS topic confirmed.
- Notification email received after confirmation.

## Services Involved
- Amazon CloudWatch
- Amazon SNS

## Tips
- Billing metrics publish only to `us-east-1`.
- Alarm is free within CloudWatch always-free custom metrics.
- SNS email subscriptions require manual email confirmation.

## Solution

### Web Console

1. Navigate to us-east-1 in the Region dropdown
2. Go to **Cloudwatch**
3. Click **Create Alarm**
4. Select `EstimatedCharges` then click **Select Metric**:

 ![Create Alarm](./images/Create-Alarm.jpg)

5. Set a threshold of $5 and click **Next**:

![Threshold](./images/Threshold.jpg)

6. Click **Add Notification** and complete the SNS details:

![Add-Notification](./images/Add-Notification.jpg)

7. Click **Create Topic** then **Next**
8. Add alarm details and click **Next**:

![Alarm-Details](./images/Alarm-Details.jpg)

9. Click **Create Alarm**

10. Observe the Warning:

> This action sends a message to an SNS topic with an endpoint that is pending confirmation. It will not work as expected until the endpoint is confirmed. Look for a subscription confirmation email or review the topic in SNS.

11. Find the topic in SNS:

![SNS Topic](./images/SNS-Topic.jpg)

12. Acknowledge the subscription request email
13. Observe the subsription is confirmed:

![SNS-Sub-Confirmation](./images/SNS-Sub-Confirmation.jpg)

### CloudFormation

_Add your implementation notes, console steps, and any CLI/SDK commands here._


