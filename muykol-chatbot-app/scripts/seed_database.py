#!/usr/bin/env python3
"""Database seeding script for the Faith Motivator Chatbot."""

import asyncio
import json
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any
import boto3
from botocore.exceptions import ClientError


class DatabaseSeeder:
    """Database seeding utility for development and testing."""
    
    def __init__(self, endpoint_url: str = "http://localhost:4566"):
        """Initialize the database seeder."""
        self.dynamodb = boto3.resource(
            'dynamodb',
            endpoint_url=endpoint_url,
            region_name='us-east-1',
            aws_access_key_id='test',
            aws_secret_access_key='test'
        )
    
    async def seed_all_tables(self):
        """Seed all tables with test data."""
        print("🌱 Starting database seeding...")
        
        try:
            # Seed user profiles
            await self.seed_user_profiles()
            
            # Seed conversation sessions
            await self.seed_conversation_sessions()
            
            # Seed chat messages
            await self.seed_chat_messages()
            
            # Seed prayer requests
            await self.seed_prayer_requests()
            
            # Seed consent logs
            await self.seed_consent_logs()
            
            # Seed biblical content (if table exists)
            await self.seed_biblical_content()
            
            print("✅ Database seeding completed successfully!")
            
        except Exception as e:
            print(f"❌ Error during database seeding: {e}")
            raise
    
    async def seed_user_profiles(self):
        """Seed user profiles table with test data."""
        print("Seeding user profiles...")
        
        table = self.dynamodb.Table('FaithChatbot-UserProfiles')
        
        test_users = [
            {
                'user_id': 'user_001',
                'email': 'john.doe@example.com',
                'first_name': 'John',
                'last_name': 'Doe',
                'created_at': (datetime.now() - timedelta(days=30)).isoformat(),
                'last_active': datetime.now().isoformat(),
                'preferences': {
                    'notification_email': True,
                    'prayer_connect_enabled': True,
                    'weekly_encouragement': True,
                    'theme': 'light'
                },
                'consent_history': [
                    {
                        'type': 'privacy_policy',
                        'version': '1.0',
                        'consented_at': (datetime.now() - timedelta(days=30)).isoformat(),
                        'ip_address': '127.0.0.1'
                    },
                    {
                        'type': 'prayer_connect',
                        'version': '1.0',
                        'consented_at': (datetime.now() - timedelta(days=25)).isoformat(),
                        'ip_address': '127.0.0.1'
                    }
                ],
                'profile_completed': True,
                'email_verified': True
            },
            {
                'user_id': 'user_002',
                'email': 'jane.smith@example.com',
                'first_name': 'Jane',
                'last_name': 'Smith',
                'created_at': (datetime.now() - timedelta(days=15)).isoformat(),
                'last_active': (datetime.now() - timedelta(hours=2)).isoformat(),
                'preferences': {
                    'notification_email': False,
                    'prayer_connect_enabled': True,
                    'weekly_encouragement': False,
                    'theme': 'dark'
                },
                'consent_history': [
                    {
                        'type': 'privacy_policy',
                        'version': '1.0',
                        'consented_at': (datetime.now() - timedelta(days=15)).isoformat(),
                        'ip_address': '192.168.1.100'
                    }
                ],
                'profile_completed': True,
                'email_verified': True
            },
            {
                'user_id': 'user_003',
                'email': 'mike.johnson@example.com',
                'first_name': 'Mike',
                'last_name': 'Johnson',
                'created_at': (datetime.now() - timedelta(days=5)).isoformat(),
                'last_active': (datetime.now() - timedelta(minutes=30)).isoformat(),
                'preferences': {
                    'notification_email': True,
                    'prayer_connect_enabled': False,
                    'weekly_encouragement': True,
                    'theme': 'light'
                },
                'consent_history': [
                    {
                        'type': 'privacy_policy',
                        'version': '1.0',
                        'consented_at': (datetime.now() - timedelta(days=5)).isoformat(),
                        'ip_address': '10.0.0.50'
                    }
                ],
                'profile_completed': False,
                'email_verified': True
            }
        ]
        
        for user in test_users:
            try:
                table.put_item(Item=user)
                print(f"  ✓ Created user: {user['first_name']} {user['last_name']}")
            except ClientError as e:
                print(f"  ✗ Failed to create user {user['email']}: {e}")
    
    async def seed_conversation_sessions(self):
        """Seed conversation sessions table."""
        print("Seeding conversation sessions...")
        
        table = self.dynamodb.Table('FaithChatbot-ConversationSessions')
        
        sessions = [
            {
                'session_id': 'session_001',
                'user_id': 'user_001',
                'created_at': (datetime.now() - timedelta(days=2)).isoformat(),
                'updated_at': (datetime.now() - timedelta(days=2)).isoformat(),
                'status': 'completed',
                'message_count': 8,
                'emotion_classifications': ['anxiety', 'hope'],
                'biblical_themes': ['peace', 'trust', 'gods_love'],
                'session_summary': 'User discussed work-related anxiety and received biblical encouragement about trusting in God.'
            },
            {
                'session_id': 'session_002',
                'user_id': 'user_001',
                'created_at': (datetime.now() - timedelta(hours=6)).isoformat(),
                'updated_at': (datetime.now() - timedelta(hours=4)).isoformat(),
                'status': 'active',
                'message_count': 12,
                'emotion_classifications': ['gratitude', 'joy'],
                'biblical_themes': ['thanksgiving', 'praise'],
                'session_summary': 'User shared gratitude for answered prayers and discussed spiritual growth.'
            },
            {
                'session_id': 'session_003',
                'user_id': 'user_002',
                'created_at': (datetime.now() - timedelta(days=1)).isoformat(),
                'updated_at': (datetime.now() - timedelta(hours=8)).isoformat(),
                'status': 'completed',
                'message_count': 6,
                'emotion_classifications': ['sadness', 'hope'],
                'biblical_themes': ['comfort', 'healing'],
                'session_summary': 'User sought comfort during a difficult time and received biblical encouragement.'
            }
        ]
        
        for session in sessions:
            try:
                table.put_item(Item=session)
                print(f"  ✓ Created session: {session['session_id']}")
            except ClientError as e:
                print(f"  ✗ Failed to create session {session['session_id']}: {e}")
    
    async def seed_chat_messages(self):
        """Seed chat messages table."""
        print("Seeding chat messages...")
        
        table = self.dynamodb.Table('FaithChatbot-ChatMessages')
        
        messages = [
            # Session 1 messages
            {
                'session_id': 'session_001',
                'message_id': 'msg_001_001',
                'timestamp': (datetime.now() - timedelta(days=2, hours=1)).isoformat(),
                'role': 'user',
                'content': "I'm feeling really anxious about my job situation. I don't know if I'll be able to keep up with all the demands.",
                'emotion_classification': 'anxiety',
                'user_id': 'user_001'
            },
            {
                'session_id': 'session_001',
                'message_id': 'msg_001_002',
                'timestamp': (datetime.now() - timedelta(days=2, hours=1, minutes=-2)).isoformat(),
                'role': 'assistant',
                'content': "I understand that work anxiety can feel overwhelming. Let me share some biblical encouragement with you. In Philippians 4:6-7, we're reminded: 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.'",
                'biblical_references': ['Philippians 4:6-7'],
                'biblical_themes': ['peace', 'trust', 'prayer'],
                'response_type': 'biblical_encouragement'
            },
            # Session 2 messages
            {
                'session_id': 'session_002',
                'message_id': 'msg_002_001',
                'timestamp': (datetime.now() - timedelta(hours=6)).isoformat(),
                'role': 'user',
                'content': "I wanted to share some good news! The situation I was praying about last week has been resolved in such a beautiful way. I can really see God's hand in it.",
                'emotion_classification': 'gratitude',
                'user_id': 'user_001'
            },
            {
                'session_id': 'session_002',
                'message_id': 'msg_002_002',
                'timestamp': (datetime.now() - timedelta(hours=6, minutes=-3)).isoformat(),
                'role': 'assistant',
                'content': "What wonderful news! It's beautiful to see how God works in our lives. As it says in 1 Thessalonians 5:18, 'Give thanks in all circumstances; for this is God's will for you in Christ Jesus.' Your gratitude is a testimony to God's faithfulness.",
                'biblical_references': ['1 Thessalonians 5:18'],
                'biblical_themes': ['gratitude', 'gods_faithfulness'],
                'response_type': 'celebration'
            }
        ]
        
        for message in messages:
            try:
                table.put_item(Item=message)
                print(f"  ✓ Created message: {message['message_id']}")
            except ClientError as e:
                print(f"  ✗ Failed to create message {message['message_id']}: {e}")
    
    async def seed_prayer_requests(self):
        """Seed prayer requests table."""
        print("Seeding prayer requests...")
        
        table = self.dynamodb.Table('FaithChatbot-PrayerRequests')
        
        prayer_requests = [
            {
                'request_id': 'prayer_001',
                'user_id': 'user_001',
                'created_at': (datetime.now() - timedelta(days=3)).isoformat(),
                'updated_at': (datetime.now() - timedelta(days=1)).isoformat(),
                'status': 'active',
                'prayer_text': 'Please pray for my family as we navigate some financial challenges. We trust in God\'s provision but could use your prayers for wisdom and peace.',
                'consent_given': True,
                'consent_timestamp': (datetime.now() - timedelta(days=3)).isoformat(),
                'prayer_count': 15,
                'responses': [
                    {
                        'responder_id': 'volunteer_001',
                        'response_text': 'Praying for God\'s provision and peace for your family. Trust in His perfect timing.',
                        'timestamp': (datetime.now() - timedelta(days=2)).isoformat()
                    }
                ],
                'tags': ['financial', 'family', 'provision']
            },
            {
                'request_id': 'prayer_002',
                'user_id': 'user_002',
                'created_at': (datetime.now() - timedelta(days=1)).isoformat(),
                'updated_at': (datetime.now() - timedelta(hours=12)).isoformat(),
                'status': 'active',
                'prayer_text': 'I\'m going through a difficult time with my health. Please pray for healing and strength to face each day with hope.',
                'consent_given': True,
                'consent_timestamp': (datetime.now() - timedelta(days=1)).isoformat(),
                'prayer_count': 8,
                'responses': [],
                'tags': ['health', 'healing', 'strength']
            }
        ]
        
        for request in prayer_requests:
            try:
                table.put_item(Item=request)
                print(f"  ✓ Created prayer request: {request['request_id']}")
            except ClientError as e:
                print(f"  ✗ Failed to create prayer request {request['request_id']}: {e}")
    
    async def seed_consent_logs(self):
        """Seed consent logs table."""
        print("Seeding consent logs...")
        
        table = self.dynamodb.Table('FaithChatbot-ConsentLogs')
        
        consent_logs = [
            {
                'log_id': str(uuid.uuid4()),
                'user_id': 'user_001',
                'timestamp': (datetime.now() - timedelta(days=30)).isoformat(),
                'consent_type': 'privacy_policy',
                'consent_version': '1.0',
                'action': 'granted',
                'ip_address': '127.0.0.1',
                'user_agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            },
            {
                'log_id': str(uuid.uuid4()),
                'user_id': 'user_001',
                'timestamp': (datetime.now() - timedelta(days=25)).isoformat(),
                'consent_type': 'prayer_connect',
                'consent_version': '1.0',
                'action': 'granted',
                'ip_address': '127.0.0.1',
                'user_agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            },
            {
                'log_id': str(uuid.uuid4()),
                'user_id': 'user_002',
                'timestamp': (datetime.now() - timedelta(days=15)).isoformat(),
                'consent_type': 'privacy_policy',
                'consent_version': '1.0',
                'action': 'granted',
                'ip_address': '192.168.1.100',
                'user_agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15'
            }
        ]
        
        for log in consent_logs:
            try:
                table.put_item(Item=log)
                print(f"  ✓ Created consent log: {log['log_id'][:8]}...")
            except ClientError as e:
                print(f"  ✗ Failed to create consent log: {e}")
    
    async def seed_biblical_content(self):
        """Seed biblical content for emotion matching."""
        print("Seeding biblical content...")
        
        # This would typically be stored in S3 or a separate table
        # For now, we'll create a simple structure
        biblical_content = {
            'anxiety': {
                'verses': [
                    {
                        'reference': 'Philippians 4:6-7',
                        'text': 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.',
                        'theme': 'peace_and_trust'
                    },
                    {
                        'reference': 'Matthew 6:25-26',
                        'text': 'Therefore I tell you, do not worry about your life, what you will eat or drink; or about your body, what you will wear. Is not life more than food, and the body more than clothes? Look at the birds of the air; they do not sow or reap or store away in barns, and yet your heavenly Father feeds them. Are you not much more valuable than they?',
                        'theme': 'gods_provision'
                    }
                ],
                'reflections': [
                    'God invites us to bring our worries to Him in prayer, knowing that His peace surpasses our understanding.',
                    'When anxiety overwhelms us, we can remember that we are precious to God and He cares for our every need.'
                ],
                'action_steps': [
                    'Take 3 deep breaths and speak this worry aloud to God in prayer',
                    'Write down one thing you\'re grateful for today',
                    'Spend 5 minutes in quiet reflection on God\'s faithfulness'
                ]
            },
            'gratitude': {
                'verses': [
                    {
                        'reference': '1 Thessalonians 5:18',
                        'text': 'Give thanks in all circumstances; for this is God\'s will for you in Christ Jesus.',
                        'theme': 'thanksgiving'
                    },
                    {
                        'reference': 'Psalm 100:4',
                        'text': 'Enter his gates with thanksgiving and his courts with praise; give thanks to him and praise his name.',
                        'theme': 'praise'
                    }
                ],
                'reflections': [
                    'Gratitude transforms our perspective and draws us closer to God\'s heart.',
                    'Even in difficult times, we can find reasons to thank God for His faithfulness.'
                ],
                'action_steps': [
                    'Write down three things you\'re grateful for today',
                    'Share your gratitude with someone who has blessed you',
                    'Spend time in worship, thanking God for His goodness'
                ]
            }
        }
        
        # In a real implementation, this would be stored in S3 or DynamoDB
        print("  ✓ Biblical content structure created (would be stored in S3)")


async def main():
    """Main seeding function."""
    seeder = DatabaseSeeder()
    await seeder.seed_all_tables()


if __name__ == "__main__":
    asyncio.run(main())