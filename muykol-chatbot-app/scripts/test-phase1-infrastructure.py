#!/usr/bin/env python3
"""
Test Phase 1 Infrastructure Implementation with LocalStack
Simulates the Terraform infrastructure locally for development and testing
"""

import boto3
import json
import time
import sys
import os
from datetime import datetime, timezone
from typing import Dict, List, Optional
import requests
from botocore.exceptions import ClientError

class Phase1InfrastructureTester:
    """Test Phase 1 infrastructure components with LocalStack"""
    
    def __init__(self, endpoint_url: str = "http://localhost:4566"):
        self.endpoint_url = endpoint_url
        self.region = "us-east-1"
        
        # Initialize AWS clients for LocalStack
        self.dynamodb = boto3.client(
            'dynamodb',
            endpoint_url=endpoint_url,
            region_name=self.region,
            aws_access_key_id='test',
            aws_secret_access_key='test'
        )
        
        self.sqs = boto3.client(
            'sqs',
            endpoint_url=endpoint_url,
            region_name=self.region,
            aws_access_key_id='test',
            aws_secret_access_key='test'
        )
        
        self.ses = boto3.client(
            'ses',
            endpoint_url=endpoint_url,
            region_name=self.region,
            aws_access_key_id='test',
            aws_secret_access_key='test'
        )
        
        self.cognito = boto3.client(
            'cognito-idp',
            endpoint_url=endpoint_url,
            region_name=self.region,
            aws_access_key_id='test',
            aws_secret_access_key='test'
        )
        
        self.secrets = boto3.client(
            'secretsmanager',
            endpoint_url=endpoint_url,
            region_name=self.region,
            aws_access_key_id='test',
            aws_secret_access_key='test'
        )
        
        self.test_results = []
    
    def log_test(self, test_name: str, success: bool, details: str = ""):
        """Log test result"""
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status}: {test_name}")
        if details:
            print(f"   Details: {details}")
        
        self.test_results.append({
            "test": test_name,
            "success": success,
            "details": details,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
    
    def wait_for_localstack(self, timeout: int = 60) -> bool:
        """Wait for LocalStack to be ready"""
        print("🔄 Waiting for LocalStack to be ready...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                response = requests.get(f"{self.endpoint_url}/_localstack/health")
                if response.status_code == 200:
                    health = response.json()
                    services = health.get('services', {})
                    
                    required_services = ['dynamodb', 'sqs', 'ses', 'cognito-idp', 'secretsmanager']
                    all_ready = all(services.get(service) == 'available' for service in required_services)
                    
                    if all_ready:
                        print("✅ LocalStack is ready!")
                        return True
                        
            except requests.RequestException:
                pass
            
            time.sleep(2)
        
        print("❌ LocalStack failed to start within timeout")
        return False
    
    def test_dynamodb_tables(self) -> bool:
        """Test DynamoDB table creation and operations"""
        print("\n🗄️  Testing DynamoDB Tables...")
        
        tables_to_test = [
            "FaithChatbot-UserProfiles",
            "FaithChatbot-ConversationSessions", 
            "FaithChatbot-PrayerRequests",
            "FaithChatbot-ConsentLogs"
        ]
        
        all_passed = True
        
        for table_name in tables_to_test:
            try:
                # Test table exists
                response = self.dynamodb.describe_table(TableName=table_name)
                table_status = response['Table']['TableStatus']
                
                self.log_test(
                    f"DynamoDB table {table_name} exists",
                    table_status == 'ACTIVE',
                    f"Status: {table_status}"
                )
                
                if table_status != 'ACTIVE':
                    all_passed = False
                    
            except ClientError as e:
                self.log_test(f"DynamoDB table {table_name} exists", False, str(e))
                all_passed = False
        
        # Test CRUD operations on UserProfiles table
        try:
            test_user_id = f"test-user-{int(time.time())}"
            
            # Create user profile
            self.dynamodb.put_item(
                TableName="FaithChatbot-UserProfiles",
                Item={
                    'user_id': {'S': test_user_id},
                    'email': {'S': 'test@faithchatbot.local'},
                    'given_name': {'S': 'Test'},
                    'family_name': {'S': 'User'},
                    'created_at': {'S': datetime.now(timezone.utc).isoformat()},
                    'prayer_connect_consent': {'BOOL': False}
                }
            )
            
            # Read user profile
            response = self.dynamodb.get_item(
                TableName="FaithChatbot-UserProfiles",
                Key={'user_id': {'S': test_user_id}}
            )
            
            user_exists = 'Item' in response
            self.log_test("DynamoDB CRUD operations", user_exists, "User profile created and retrieved")
            
            if not user_exists:
                all_passed = False
                
        except ClientError as e:
            self.log_test("DynamoDB CRUD operations", False, str(e))
            all_passed = False
        
        return all_passed
    
    def test_sqs_queues(self) -> bool:
        """Test SQS queue creation and operations"""
        print("\n📨 Testing SQS Queues...")
        
        queues_to_test = [
            "FaithChatbot-PrayerRequests",
            "FaithChatbot-PrayerRequests-DLQ"
        ]
        
        all_passed = True
        
        for queue_name in queues_to_test:
            try:
                # Test queue exists
                response = self.sqs.get_queue_url(QueueName=queue_name)
                queue_url = response['QueueUrl']
                
                self.log_test(f"SQS queue {queue_name} exists", True, f"URL: {queue_url}")
                
                # Test queue attributes
                attrs = self.sqs.get_queue_attributes(
                    QueueUrl=queue_url,
                    AttributeNames=['All']
                )
                
                attributes = attrs['Attributes']
                self.log_test(
                    f"SQS queue {queue_name} attributes",
                    'VisibilityTimeoutSeconds' in attributes,
                    f"Visibility timeout: {attributes.get('VisibilityTimeoutSeconds', 'N/A')}"
                )
                
            except ClientError as e:
                self.log_test(f"SQS queue {queue_name} exists", False, str(e))
                all_passed = False
        
        # Test message operations
        try:
            queue_url = self.sqs.get_queue_url(QueueName="FaithChatbot-PrayerRequests")['QueueUrl']
            
            # Send test message
            test_message = {
                "user_id": "test-user-123",
                "prayer_text": "Test prayer request",
                "consent_given": True,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            
            self.sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(test_message)
            )
            
            # Receive message
            response = self.sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=1)
            message_received = 'Messages' in response and len(response['Messages']) > 0
            
            self.log_test("SQS message operations", message_received, "Message sent and received")
            
            if not message_received:
                all_passed = False
                
        except ClientError as e:
            self.log_test("SQS message operations", False, str(e))
            all_passed = False
        
        return all_passed
    
    def test_ses_configuration(self) -> bool:
        """Test SES email configuration"""
        print("\n📧 Testing SES Configuration...")
        
        all_passed = True
        
        try:
            # Test verified email addresses
            response = self.ses.list_verified_email_addresses()
            verified_emails = response.get('VerifiedEmailAddresses', [])
            
            required_emails = ['noreply@faithchatbot.local']
            emails_verified = all(email in verified_emails for email in required_emails)
            
            self.log_test(
                "SES verified email addresses",
                emails_verified,
                f"Verified: {verified_emails}"
            )
            
            if not emails_verified:
                all_passed = False
            
            # Test email templates
            templates_response = self.ses.list_templates()
            templates = [t['Name'] for t in templates_response.get('TemplatesMetadata', [])]
            
            required_templates = ['WelcomeEmail', 'PrayerRequestNotification']
            templates_exist = all(template in templates for template in required_templates)
            
            self.log_test(
                "SES email templates",
                templates_exist,
                f"Templates: {templates}"
            )
            
            if not templates_exist:
                all_passed = False
            
            # Test sending email
            self.ses.send_email(
                Source='noreply@faithchatbot.local',
                Destination={'ToAddresses': ['test@example.com']},
                Message={
                    'Subject': {'Data': 'Test Email from Faith Motivator'},
                    'Body': {'Text': {'Data': 'This is a test email to verify SES functionality.'}}
                }
            )
            
            self.log_test("SES send email", True, "Test email sent successfully")
            
        except ClientError as e:
            self.log_test("SES configuration", False, str(e))
            all_passed = False
        
        return all_passed
    
    def test_cognito_user_pool(self) -> bool:
        """Test Cognito User Pool configuration"""
        print("\n👤 Testing Cognito User Pool...")
        
        all_passed = True
        
        try:
            # List user pools
            response = self.cognito.list_user_pools(MaxResults=10)
            user_pools = response.get('UserPools', [])
            
            faith_pool = next((pool for pool in user_pools if 'FaithChatbot' in pool['Name']), None)
            
            if faith_pool:
                user_pool_id = faith_pool['Id']
                self.log_test("Cognito User Pool exists", True, f"Pool ID: {user_pool_id}")
                
                # Test user pool configuration
                pool_details = self.cognito.describe_user_pool(UserPoolId=user_pool_id)
                pool_config = pool_details['UserPool']
                
                # Check password policy
                password_policy = pool_config.get('Policies', {}).get('PasswordPolicy', {})
                min_length_ok = password_policy.get('MinimumLength', 0) >= 8
                
                self.log_test(
                    "Cognito password policy",
                    min_length_ok,
                    f"Min length: {password_policy.get('MinimumLength', 'N/A')}"
                )
                
                # Test user pool clients
                clients_response = self.cognito.list_user_pool_clients(UserPoolId=user_pool_id)
                clients = clients_response.get('UserPoolClients', [])
                
                self.log_test(
                    "Cognito User Pool clients",
                    len(clients) > 0,
                    f"Clients: {len(clients)}"
                )
                
                # Test user creation
                test_username = f"testuser-{int(time.time())}@faithchatbot.local"
                
                try:
                    self.cognito.admin_create_user(
                        UserPoolId=user_pool_id,
                        Username=test_username,
                        UserAttributes=[
                            {'Name': 'email', 'Value': test_username},
                            {'Name': 'email_verified', 'Value': 'true'}
                        ],
                        TemporaryPassword='TempPass123!',
                        MessageAction='SUPPRESS'
                    )
                    
                    self.log_test("Cognito user creation", True, f"User: {test_username}")
                    
                except ClientError as e:
                    if e.response['Error']['Code'] != 'UsernameExistsException':
                        self.log_test("Cognito user creation", False, str(e))
                        all_passed = False
                
            else:
                self.log_test("Cognito User Pool exists", False, "No FaithChatbot user pool found")
                all_passed = False
                
        except ClientError as e:
            self.log_test("Cognito User Pool", False, str(e))
            all_passed = False
        
        return all_passed
    
    def test_secrets_manager(self) -> bool:
        """Test Secrets Manager configuration"""
        print("\n🔐 Testing Secrets Manager...")
        
        all_passed = True
        
        required_secrets = [
            "faith-chatbot/database-config",
            "faith-chatbot/api-keys",
            "faith-chatbot/jwt-config",
            "faith-chatbot/email-config"
        ]
        
        for secret_name in required_secrets:
            try:
                # Test secret exists
                self.secrets.describe_secret(SecretId=secret_name)
                self.log_test(f"Secret {secret_name} exists", True)
                
                # Test secret retrieval
                secret_value = self.secrets.get_secret_value(SecretId=secret_name)
                secret_data = json.loads(secret_value['SecretString'])
                
                self.log_test(
                    f"Secret {secret_name} retrieval",
                    len(secret_data) > 0,
                    f"Keys: {list(secret_data.keys())}"
                )
                
            except ClientError as e:
                self.log_test(f"Secret {secret_name}", False, str(e))
                all_passed = False
        
        return all_passed
    
    def test_integration_scenarios(self) -> bool:
        """Test end-to-end integration scenarios"""
        print("\n🔄 Testing Integration Scenarios...")
        
        all_passed = True
        
        try:
            # Scenario 1: User registration and first conversation
            user_id = f"integration-user-{int(time.time())}"
            session_id = f"session-{int(time.time())}"
            
            # Create user profile
            self.dynamodb.put_item(
                TableName="FaithChatbot-UserProfiles",
                Item={
                    'user_id': {'S': user_id},
                    'email': {'S': f'{user_id}@faithchatbot.local'},
                    'given_name': {'S': 'Integration'},
                    'family_name': {'S': 'Test'},
                    'created_at': {'S': datetime.now(timezone.utc).isoformat()},
                    'prayer_connect_consent': {'BOOL': False}
                }
            )
            
            # Create conversation session
            self.dynamodb.put_item(
                TableName="FaithChatbot-ConversationSessions",
                Item={
                    'session_id': {'S': session_id},
                    'user_id': {'S': user_id},
                    'created_at': {'S': datetime.now(timezone.utc).isoformat()},
                    'status': {'S': 'active'},
                    'message_count': {'N': '0'}
                }
            )
            
            # Create prayer request
            request_id = f"prayer-{int(time.time())}"
            self.dynamodb.put_item(
                TableName="FaithChatbot-PrayerRequests",
                Item={
                    'request_id': {'S': request_id},
                    'user_id': {'S': user_id},
                    'prayer_text': {'S': 'Integration test prayer request'},
                    'status': {'S': 'pending'},
                    'created_at': {'S': datetime.now(timezone.utc).isoformat()},
                    'consent_given': {'BOOL': True}
                }
            )
            
            # Send prayer request to queue
            queue_url = self.sqs.get_queue_url(QueueName="FaithChatbot-PrayerRequests")['QueueUrl']
            self.sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps({
                    "request_id": request_id,
                    "user_id": user_id,
                    "prayer_text": "Integration test prayer request",
                    "timestamp": datetime.now(timezone.utc).isoformat()
                })
            )
            
            # Log consent
            consent_id = f"consent-{int(time.time())}"
            self.dynamodb.put_item(
                TableName="FaithChatbot-ConsentLogs",
                Item={
                    'log_id': {'S': consent_id},
                    'user_id': {'S': user_id},
                    'consent_type': {'S': 'prayer_connect'},
                    'consent_given': {'BOOL': True},
                    'timestamp': {'S': datetime.now(timezone.utc).isoformat()},
                    'ip_address': {'S': '127.0.0.1'},
                    'user_agent': {'S': 'Integration Test'}
                }
            )
            
            self.log_test("Integration scenario: User workflow", True, "Complete user workflow executed")
            
        except Exception as e:
            self.log_test("Integration scenario: User workflow", False, str(e))
            all_passed = False
        
        return all_passed
    
    def run_all_tests(self) -> bool:
        """Run all infrastructure tests"""
        print("🚀 Starting Phase 1 Infrastructure Tests...")
        print("=" * 60)
        
        if not self.wait_for_localstack():
            return False
        
        test_methods = [
            self.test_dynamodb_tables,
            self.test_sqs_queues,
            self.test_ses_configuration,
            self.test_cognito_user_pool,
            self.test_secrets_manager,
            self.test_integration_scenarios
        ]
        
        all_passed = True
        for test_method in test_methods:
            if not test_method():
                all_passed = False
        
        # Print summary
        print("\n" + "=" * 60)
        print("📊 Test Results Summary")
        print("=" * 60)
        
        passed = sum(1 for result in self.test_results if result['success'])
        failed = len(self.test_results) - passed
        
        print(f"✅ Tests Passed: {passed}")
        print(f"❌ Tests Failed: {failed}")
        print(f"📊 Total Tests: {len(self.test_results)}")
        
        if all_passed:
            print("\n🎉 All tests passed! Phase 1 infrastructure is working correctly.")
        else:
            print("\n⚠️  Some tests failed. Please check the LocalStack setup.")
            print("\nFailed tests:")
            for result in self.test_results:
                if not result['success']:
                    print(f"  - {result['test']}: {result['details']}")
        
        # Save detailed results
        with open('/tmp/phase1-test-results.json', 'w') as f:
            json.dump({
                'summary': {
                    'total': len(self.test_results),
                    'passed': passed,
                    'failed': failed,
                    'success_rate': passed / len(self.test_results) * 100
                },
                'tests': self.test_results,
                'timestamp': datetime.now(timezone.utc).isoformat()
            }, f, indent=2)
        
        print(f"\n📄 Detailed results saved to /tmp/phase1-test-results.json")
        
        return all_passed

def main():
    """Main function"""
    endpoint_url = os.getenv('AWS_ENDPOINT_URL', 'http://localhost:4566')
    
    tester = Phase1InfrastructureTester(endpoint_url)
    success = tester.run_all_tests()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()