# Lab 8: Designing a High-Performing Serverless API (Hard)

## Objective
Build a serverless CRUD-style API using API Gateway HTTP API, Lambda, and DynamoDB with appropriate IAM permissions.

## Success Criteria
- DynamoDB table (e.g., `MusicLibrary`) with partition key `Artist` (String) and sort key `SongTitle` (String), on-demand capacity.
- IAM role for Lambda granting CRUD permissions on the table.
- Lambda function (`CrudApiHandler`) using the role; handles POST/GET logic per path and query.
- API Gateway HTTP API with routes: POST /music, GET /music, GET /music/{Artist}, integrated with the Lambda.
- POST to /music stores an item and returns 200 OK.
- GET /music returns all items; GET /music/{Artist} returns items for that artist.

## Services Involved
- Amazon API Gateway (HTTP API)
- AWS Lambda
- Amazon DynamoDB
- AWS IAM

## Tips
- HTTP API is simpler and cheaper than REST API; good fit for free tier.
- Validate request/response structures in Lambda; return proper HTTP status codes.
- DynamoDB on-demand simplifies capacity planning and stays within free limits at low scale.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._




