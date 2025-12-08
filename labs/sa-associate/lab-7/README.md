# Lab 7: Designing Decoupled, Event-Driven Architectures (Hard)

## Objective
Build an event-driven fan-out pattern where S3 object creation triggers SNS, which fans out to multiple SQS queues, with Lambda processing messages.

## Success Criteria
- S3 bucket created (e.g., `saa-fanout-source-bucket`).
- SNS topic created (e.g., `ImageUploadTopic`).
- Two SQS queues created (e.g., `ImageResizeQueue`, `ImageAnalyticsQueue`).
- Lambda function (`AnalyticsLogger`) with execution role writing to CloudWatch Logs.
- `ImageAnalyticsQueue` configured as event source for the Lambda function.
- Both SQS queues subscribed to the SNS topic.
- S3 event notification on object create sends events to the SNS topic.
- Uploading a test object results in one message in each queue and a CloudWatch log entry from Lambda.

## Services Involved
- Amazon S3
- Amazon SNS
- Amazon SQS
- AWS Lambda
- AWS IAM

## Tips
- This is fully within always-free limits at low scale; clean up to avoid clutter.
- Decoupling via SNS + SQS improves resilience and enables easy fan-out to new consumers.
- Consider DLQs on SQS for production-grade resilience.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._


