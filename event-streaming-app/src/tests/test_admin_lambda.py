import unittest
import json
from unittest.mock import patch, MagicMock
import boto3
import os
import uuid

# Assuming admin_lambda.py is in the parent directory or accessible via sys.path
# If not, you might need to adjust the import path.
# For simplicity, let's assume it's importable.
import sys
sys.path.append('event-streaming-app/src/admin_lambda/') # Adjust if necessary
from admin_lambda import lambda_handler, get_dynamodb_summary, trigger_lambda_function

class TestAdminLambda(unittest.TestCase):

    def setUp(self):
        # Mocking AWS services
        self.mock_dynamodb = patch('admin_lambda.boto3.resource').start()
        self.mock_lambda_client = patch('admin_lambda.boto3.client').start()
        
        # Mocking the DynamoDB table and its methods
        self.mock_table = MagicMock()
        self.mock_dynamodb.return_value.Table.return_value = self.mock_table
        
        # Mocking the Lambda client's invoke method
        self.mock_lambda_client.return_value.invoke.return_value = {'StatusCode': 202}

        # Mocking uuid.uuid4 for predictable job IDs in tests
        self.mock_uuid = patch('admin_lambda.uuid.uuid4').start()
        self.mock_uuid.return_value = 'mock-uuid-1234'

        # Set environment variables if needed by the lambda function
        os.environ['PROGRAMMES_TABLE_NAME'] = 'MockProgrammesTable'
        
        # Ensure the correct table name is used in the lambda function
        # This might be implicitly handled if the lambda function reads it correctly
        # but good to be aware of.

        self.addCleanup(patch.stopall)

    def test_get_dynamodb_summary_success(self):
        # Mocking the DynamoDB table's item_count attribute
        self.mock_table.item_count = {'ItemCount': 100}
        
        # Mocking os.environ.get for PROGRAMMES_TABLE_NAME
        with patch.dict(os.environ, {'PROGRAMMES_TABLE_NAME': 'MockProgrammesTable'}):
            summary, status_code = get_dynamodb_summary()
        
        self.assertEqual(status_code, 200)
        self.assertIn('tables', summary)
        self.assertEqual(len(summary['tables']), 1)
        self.assertEqual(summary['tables']['name'], 'MockProgrammesTable')
        self.assertEqual(summary['tables']['item_count'], 100)
        self.assertEqual(summary['tables']['size_bytes'], 'N/A')
        self.assertIn('message', summary)

    def test_get_dynamodb_summary_table_not_found(self):
        # Mocking ResourceNotFoundException for the table
        self.mock_dynamodb.return_value.Table.side_effect = boto3.meta.client.exceptions.ResourceNotFoundException({}, 'GetItem')
        
        with patch.dict(os.environ, {'PROGRAMMES_TABLE_NAME': 'NonExistentTable'}):
            summary, status_code = get_dynamodb_summary()
        
        self.assertEqual(status_code, 404)
        self.assertIn('message', summary)
        self.assertIn("DynamoDB table 'NonExistentTable' not found.", summary['message'])

    def test_get_dynamodb_summary_exception(self):
        # Mocking a general exception during summary retrieval
        self.mock_table.item_count.side_effect = Exception("Some error")
        
        with patch.dict(os.environ, {'PROGRAMMES_TABLE_NAME': 'MockProgrammesTable'}):
            summary, status_code = get_dynamodb_summary()
        
        self.assertEqual(status_code, 500)
        self.assertIn('message', summary)
        self.assertIn("Error retrieving DynamoDB summary: Some error", summary['message'])

    def test_trigger_lambda_function_success(self):
        mock_payload = {"key": "value"}
        response, status_code = trigger_lambda_function("MockLambdaFunction", mock_payload)
        
        self.assertEqual(status_code, 202)
        self.assertIn('message', response)
        self.assertIn('job_id', response)
        self.assertEqual(response['job_id'], 'mock-uuid-1234')
        
        self.mock_lambda_client.return_value.invoke.assert_called_once_with(
            FunctionName='MockLambdaFunction',
            InvocationType='Event',
            Payload=json.dumps({"key": "value", "job_id": "mock-uuid-1234"})
        )

    def test_trigger_lambda_function_not_found(self):
        self.mock_lambda_client.return_value.invoke.side_effect = boto3.client('lambda').exceptions.ResourceNotFoundException({}, 'Invoke')
        
        response, status_code = trigger_lambda_function("NonExistentLambda")
        
        self.assertEqual(status_code, 404)
        self.assertIn('message', response)
        self.assertNotIn('job_id', response) # Job ID should not be returned on error

    def test_trigger_lambda_function_exception(self):
        self.mock_lambda_client.return_value.invoke.side_effect = Exception("Invoke error")
        
        response, status_code = trigger_lambda_function("MockLambdaFunction")
        
        self.assertEqual(status_code, 500)
        self.assertIn('message', response)
        self.assertNotIn('job_id', response) # Job ID should not be returned on error

    # Test cases for lambda_handler would be more complex, involving mocking the event object
    # and checking the returned response structure and status codes.
    # For now, focusing on the helper functions.

if __name__ == '__main__':
    unittest.main()