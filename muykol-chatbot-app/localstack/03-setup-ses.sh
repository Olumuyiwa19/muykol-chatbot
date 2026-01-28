#!/bin/bash

echo "Setting up SES for Faith Motivator Chatbot..."

# Wait for SES service to be ready
echo "Waiting for SES service to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"ses": "available"'; do
    echo "Waiting for SES service..."
    sleep 2
done

echo "SES service is ready. Setting up email configuration..."

# Verify email addresses for local development
echo "Verifying sender email addresses..."

# Main sender email
awslocal ses verify-email-identity \
  --email-address noreply@faithchatbot.local \
  --region us-east-1

# Support email
awslocal ses verify-email-identity \
  --email-address support@faithchatbot.local \
  --region us-east-1

# Prayer team email
awslocal ses verify-email-identity \
  --email-address prayers@faithchatbot.local \
  --region us-east-1

# Test email for development
awslocal ses verify-email-identity \
  --email-address test@example.com \
  --region us-east-1

echo "✅ Email addresses verified successfully!"

# Create email templates
echo "Creating email templates..."

# Welcome email template
awslocal ses create-template \
  --template '{
    "TemplateName": "WelcomeEmail",
    "Subject": "Welcome to Faith Motivator Chatbot",
    "HtmlPart": "<html><body><h1>Welcome {{name}}!</h1><p>Thank you for joining our faith community. We are here to support you on your spiritual journey.</p><p>Blessings,<br>The Faith Motivator Team</p></body></html>",
    "TextPart": "Welcome {{name}}!\n\nThank you for joining our faith community. We are here to support you on your spiritual journey.\n\nBlessings,\nThe Faith Motivator Team"
  }' \
  --region us-east-1

# Prayer request notification template
awslocal ses create-template \
  --template '{
    "TemplateName": "PrayerRequestNotification",
    "Subject": "New Prayer Request - Faith Motivator",
    "HtmlPart": "<html><body><h2>New Prayer Request</h2><p>A member of our community has requested prayer:</p><blockquote>{{prayer_text}}</blockquote><p>Please take a moment to pray for this request.</p><p>In faith,<br>The Faith Motivator Team</p></body></html>",
    "TextPart": "New Prayer Request\n\nA member of our community has requested prayer:\n\n{{prayer_text}}\n\nPlease take a moment to pray for this request.\n\nIn faith,\nThe Faith Motivator Team"
  }' \
  --region us-east-1

# Data export ready template
awslocal ses create-template \
  --template '{
    "TemplateName": "DataExportReady",
    "Subject": "Your Data Export is Ready - Faith Motivator",
    "HtmlPart": "<html><body><h2>Your Data Export is Ready</h2><p>Hello {{name}},</p><p>Your requested data export has been prepared and is available for download.</p><p>The export includes:</p><ul><li>Chat conversation history</li><li>Prayer requests and responses</li><li>Account information and preferences</li></ul><p>Download link: <a href=\"{{download_url}}\">Download Your Data</a></p><p>This link will expire in 7 days for security purposes.</p><p>Blessings,<br>The Faith Motivator Team</p></body></html>",
    "TextPart": "Your Data Export is Ready\n\nHello {{name}},\n\nYour requested data export has been prepared and is available for download.\n\nThe export includes:\n- Chat conversation history\n- Prayer requests and responses\n- Account information and preferences\n\nDownload link: {{download_url}}\n\nThis link will expire in 7 days for security purposes.\n\nBlessings,\nThe Faith Motivator Team"
  }' \
  --region us-east-1

echo "✅ Email templates created successfully!"

# List verified email addresses
echo "Listing verified email addresses:"
awslocal ses list-verified-email-addresses --region us-east-1

# List email templates
echo "Listing email templates:"
awslocal ses list-templates --region us-east-1

echo "✅ SES setup completed successfully!"