# Event Streaming app

## Rough plan



## Step 1 - Initial set up

To get started I wanted to log in securely from my laptop and so set up IAM Identity Center as described in more detail [here](../identity/IAM-Identity-Center.MD)

I then checked this works with:

```bash
aws sts get-caller-identity --profile streaming
{
"UserId": "AROA2SWQYMDM4VPUQEQLJ:edoatley",
"Account": "727361020121",
"Arn": "arn:aws:sts::727361020121:assumed-role/AWSReservedSSO_AdministratorAccess_2953d82af9279092/edoatley"
}
```

## Step 2 - Shared infrastructure set up

1. set up some shared infrastructure using this [CloudFormation template](resources/shared-infra.yaml)

2. Deployed the shared infrastructure with:

```bash
aws cloudformation deploy \
--template-file ./resources/shared-infra.yaml \
--stack-name uk-tv-guide-shared-infra \
--capabilities CAPABILITY_IAM \
--profile streaming
```

## Step 3 - Periodic Ingestion Lambda (basic deployment)

1. set up this [Periodic Ingestion CloudFormation template](resources/periodic-ingestion.yaml) to deploy the resources
   associated with our first function called **PeriodicUKTVDataIngestionFunction**

2. Built the app using sam:

```bash
sam build --template-file ./resources/periodic-ingestion.yaml --profile streaming
```

3. Run a local test with a [test event](./events/periodic_ingestion.json) and [environment config](./env/periodic_ingestion.json):

```bash
sam local invoke PeriodicDataIngestionFunction \
  --template-file ./resources/periodic-ingestion.yaml \
  --event ./events/periodic_ingestion.json \
  --env-vars ./env/periodic_ingestion.json \
  --profile streaming
```

which gave the expected output:

```output
Invoking app.lambda_handler (python3.9)                                                                                                                                                                                                                                                                                                                                                                                                   
Unknown 404 - Unable to check if base image is current.                                                                                                                                                                                                                                                                                                                                                                                   
                                                                                                                                                                                                                                                                                                                                                                                                                                          
Possible incompatible Docker engine clone employed. Consider `--skip-pull-image` for improved speed, the tradeoff being not running the latest image.                                                                                                                                                                                                                                                                                     
Removing rapid images for repo public.ecr.aws/sam/emulation-python3.9                                                                                                                                                                                                                                                                                                                                                                     
Building image..........................
Using local image: public.ecr.aws/lambda/python:3.9-rapid-x86_64.                                                                                                                                                                                                                                                                                                                                                                         
                                                                                                                                                                                                                                                                                                                                                                                                                                          
Mounting /Users/edoatley/source/aws-notes/event-streaming-app/src/periodic_ingestion as /var/task:ro,delegated, inside runtime container                                                                                                                                                                                                                                                                                                  
START RequestId: 82ff0db6-af9d-485d-b0d5-198c16ac06ce Version: $LATEST
Received event: {"source": "aws.events", "detail-type": "Scheduled Event", "resources": ["arn:aws:events:eu-west-2:123456789012:rule/DailyUKTVDataIngestionTrigger"], "time": "2024-07-29T10:00:00Z"}
Kinesis Stream Name from env: ProgrammeDataStream
Successfully sent data to Kinesis. SequenceNumber: 49664244735039333844253464507911923352226958350235992098
END RequestId: 46c18a47-e404-4000-b4c5-36f90cd87b0a
REPORT RequestId: 46c18a47-e404-4000-b4c5-36f90cd87b0a  Init Duration: 0.04 ms  Duration: 365.61 ms     Billed Duration: 366 ms Memory Size: 256 MB     Max Memory Used: 256 MB 
{"statusCode": 200, "body": "{\"message\": \"Data ingested successfully\", \"sequenceNumber\": \"49664244735039333844253464507911923352226958350235992098\"}"}
```

4. Deploy the lambda

```bash
# First time need to define the config hence --guided
sam deploy --guided --profile streaming --capabilities CAPABILITY_NAMED_IAM
# Thereafter can reference the config file
sam deploy --profile streaming --capabilities CAPABILITY_NAMED_IAM
```

Which starts the deployment and we can confirm the changes:

```output
Initiating deployment                                                                                                                                                                                                                                                                                                                                                                                                                     
=====================                                                                                                                                                                                                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                                                                                                                                                                                                          
                                                                                                                                                                                                                                                                                                                                                                                                                                          
        File with same data already exists at sam-local-deploy-periodic-ingestion/a319233ae11dd237131e40c023c8dd98.template, skipping upload                                                                                                                                                                                                                                                                                              


Waiting for changeset to be created..

CloudFormation stack changeset
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Operation                                                                                                 LogicalResourceId                                                                                         ResourceType                                                                                              Replacement                                                                                             
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+ Add                                                                                                     DataIngestionLambdaRole                                                                                   AWS::IAM::Role                                                                                            N/A                                                                                                     
+ Add                                                                                                     PeriodicDataIngestionFunctionScheduledTriggerPermission                                                   AWS::Lambda::Permission                                                                                   N/A                                                                                                     
+ Add                                                                                                     PeriodicDataIngestionFunctionScheduledTrigger                                                             AWS::Events::Rule                                                                                         N/A                                                                                                     
+ Add                                                                                                     PeriodicDataIngestionFunction                                                                             AWS::Lambda::Function                                                                                     N/A                                                                                                     
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                          

Changeset created successfully. arn:aws:cloudformation:eu-west-2:727361020121:changeSet/samcli-deploy1749907838/954f1210-32f8-4a6c-82cc-af651fd9a9cd


Previewing CloudFormation changeset before deployment                                                                                                                                                                                                                                                                                                                                                                                     
======================================================
Deploy this changeset? [y/N]: y
```

and after some time the deployment completes:

```output
CloudFormation outputs from deployed stack
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Outputs                                                                                                                                                                                                                                                                                                                                                                                                                               
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Key                 PeriodicDataIngestionFunctionName                                                                                                                                                                                                                                                                                                                                                                                 
Description         Name of the Periodic Data Ingestion Lambda function                                                                                                                                                                                                                                                                                                                                                               
Value               PeriodicUKTVDataIngestionFunction                                                                                                                                                                                                                                                                                                                                                                                 

Key                 PeriodicDataIngestionFunctionArn                                                                                                                                                                                                                                                                                                                                                                                  
Description         ARN of the Periodic Data Ingestion Lambda function                                                                                                                                                                                                                                                                                                                                                                
Value               arn:aws:lambda:eu-west-2:727361020121:function:PeriodicUKTVDataIngestionFunction                                                                                                                                                                                                                                                                                                                                  
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                          

Successfully created/updated stack - sam-local-deploy-periodic-ingestion in eu-west-2
```

5. Test the deployed Lambda function

```bash
sam remote invoke PeriodicUKTVDataIngestionFunction \
  --event ./events/periodic_ingestion.json \
  --profile streaming  
```

which gave the expected output:

```output
Invoking Lambda Function PeriodicDataIngestionFunction                                                                                                                                                                                                                                                                                                                                                                                    
Auto converting value './events/periodic_ingestion.json' into JSON '"./events/periodic_ingestion.json"'. If you don't want auto-conversion, please provide a JSON string as event                                                                                                                                                                                                                                                         
START RequestId: 4e8c16d3-8fda-431f-bdc9-119be66c8582 Version: $LATEST
Received event: "./events/periodic_ingestion.json"
Kinesis Stream Name from env: ProgrammeDataStream
Successfully sent data to Kinesis. SequenceNumber: 49664244735039333844253464868252815627300673180592504866
END RequestId: 4e8c16d3-8fda-431f-bdc9-119be66c8582
REPORT RequestId: 4e8c16d3-8fda-431f-bdc9-119be66c8582  Duration: 113.79 ms     Billed Duration: 114 ms Memory Size: 256 MB     Max Memory Used: 77 MB  Init Duration: 440.69 ms        
{"statusCode": 200, "body": "{\"message\": \"Data ingested successfully\", \"sequenceNumber\": \"49664244735039333844253464868252815627300673180592504866\"}"}%     
```

6. To save cost we can now undeploy it so we can work on the next steps

```bash
sam delete --profile streaming
```

and check that works:

```output
        Are you sure you want to delete the stack sam-local-deploy-periodic-ingestion in the region eu-west-2 ? [y/N]: y
        Are you sure you want to delete the folder sam-local-deploy-periodic-ingestion in S3 which contains the artifacts? [y/N]: n
        Do you want to delete the template file a319233ae11dd237131e40c023c8dd98.template in S3? [y/N]: n
        - Deleting S3 object with key sam-local-deploy-periodic-ingestion/7eb695ca20af3d630911a8a0a50b87f7                                                                                                                                                                                                                                                                                                                                
        - Deleting Cloudformation stack sam-local-deploy-periodic-ingestion

Deleted successfully
```

## Step 4 - WatchMode integration

For this service to really work we need a source of TV information for which we will leverage [Watchmode](https://api.watchmode.com/)


This service offers a vast number of APIs but some of the ones of interest for us:

- `/v1/changes/new_titles/` - [Changes > New Titles] (https://api.watchmode.com/docs#new-titles)
- `/v1/title/{title_id}/details/` - [Title Details API](https://api.watchmode.com/docs#title-details)

It also leverages it's own IDs for actors and movies as described [here](https://api.watchmode.com/docs#id-mapping) the CSV files referenced:

- https://api.watchmode.com/datasets/title_id_map.csv
- https://api.watchmode.com/datasets/person_id_map.csv

Could be a good source of test data and help understand the service better.

## Cleanup

Delete the shared resources:

```bash
aws cloudformation delete-stack \
  --stack-name uk-tv-guide-shared-infra \
  --profile streaming
```
