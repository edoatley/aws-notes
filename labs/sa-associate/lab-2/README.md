# Lab 2: Resilient Foundations - Secure Static Website Hosting (Easy)

## Objective
Deploy a private S3 bucket fronted by CloudFront with Origin Access Control (OAC) for secure static website delivery over HTTPS.

## Success Criteria
- Private S3 bucket created with "Block all public access" enabled.
- `index.html` uploaded to the bucket.
- Direct S3 object URL returns 403 Access Denied.
- CloudFront distribution created with the bucket as origin and OAC enabled.
- CloudFront-provided bucket policy applied to allow CloudFront to read objects.
- Accessing the CloudFront domain serves `index.html` over HTTPS.

## Services Involved
- Amazon S3
- Amazon CloudFront

## Tips
- Prefer OAC over legacy OAI for secure origin access.
- Bucket must stay private; CloudFront handles public delivery.
- CloudFront always-free tier is generous; keep costs low by cleaning up.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._



