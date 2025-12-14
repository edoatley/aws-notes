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

### Web Console

1. Create a bucket `edo-secure-static-website-lab2`:

![Create-Bucket](images/Create-Bucket.jpg)
![Create-Bucket-2](images/Create-Bucket-2.jpg)

2. Upload [index.html](./index.html)

![Upload-To-Bucket](images/Upload-To-Bucket.jpg)
![Upload-To-Bucket-2](images/Upload-To-Bucket-2.jpg)

3. Check direct url https://edo-secure-static-website-lab2.s3.eu-west-2.amazonaws.com/index.html is not accessible:

![Direct-Url-Not-Accessible](images/Direct-Url-Not-Accessible.jpg)

4. Create CloudFront Distibution:

   - Choose Plan ![CloudFront-Distribution-1](./images/CloudFront-Distribution-1.jpg)
   - Name distribution `edo-secure-static-website-cf-dist` ![CloudFront-Distribution-2](./images/CloudFront-Distribution-2.jpg)
   - Define Origin ![CloudFront-Distribution-3a](./images/CloudFront-Distribution-3a.jpg) ![CloudFront-Distribution-3b](./images/CloudFront-Distribution-3b.jpg) 
   - Set WAF settings if applicable ![CloudFront-Distribution-4](./images/CloudFront-Distribution-4.jpg)
   - Create distribution: ![CloudFront-Distribution-5](./images/CloudFront-Distribution-5.jpg)
   - Check origin protections and wait for deployment to complete ![CloudFront-Distribution-6](./images/CloudFront-Distribution-6.jpg)

5. Observe / Validate the bucket policy created:

![Bucket-Policy](images/Bucket-Policy.jpg)

6. Navigate to the [index.html](https://dvsxbr2xs8zlk.cloudfront.net/index.html)

![Website-via-CloudFront](images/Website-via-CloudFront.jpg)

7. Check the direct link is still inaccessible

8. Cleanup
 - Delete the CloudFront distribution
 - Empty the s3 bucket
 - Delete the S3 bucket

### CloudFormation

#### Generate from web console

1. Navigate to CloudFormation then IaC Generator
2. Trigger a scan of all resources
3. Create a template and seelct resources
4. Download the [generated template](Static-Website-With-CloudFront-template.yaml)

#### Build from scratch

_Add CFN link and any CLI/SDK commands here._




