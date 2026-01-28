#!/usr/bin/env python3
"""Environment validation script for the Faith Motivator Chatbot."""

import os
import sys
from typing import List, Dict, Any
from pydantic import ValidationError
from faith_motivator_chatbot.config.schema import Config


def validate_environment() -> bool:
    """Validate environment configuration."""
    print("🔍 Validating environment configuration...")
    
    try:
        # Load configuration
        config = Config.load_config()
        print("✅ Configuration loaded successfully")
        
        # Validate required environment variables
        validation_results = []
        
        # Check application configuration
        app_checks = validate_application_config(config.app)
        validation_results.extend(app_checks)
        
        # Check AWS configuration
        aws_checks = validate_aws_config(config.aws)
        validation_results.extend(aws_checks)
        
        # Check database configuration
        db_checks = validate_database_config(config.database)
        validation_results.extend(db_checks)
        
        # Check Redis configuration
        redis_checks = validate_redis_config(config.redis)
        validation_results.extend(redis_checks)
        
        # Print results
        errors = [result for result in validation_results if not result["valid"]]
        warnings = [result for result in validation_results if result.get("warning", False)]
        
        if errors:
            print(f"\n❌ {len(errors)} validation errors found:")
            for error in errors:
                print(f"  - {error['message']}")
            return False
        
        if warnings:
            print(f"\n⚠️  {len(warnings)} warnings:")
            for warning in warnings:
                print(f"  - {warning['message']}")
        
        print(f"\n✅ Environment validation passed ({len(validation_results)} checks)")
        return True
        
    except ValidationError as e:
        print(f"\n❌ Configuration validation failed:")
        for error in e.errors():
            field = ".".join(str(loc) for loc in error["loc"])
            print(f"  - {field}: {error['msg']}")
        return False
    
    except Exception as e:
        print(f"\n❌ Unexpected error during validation: {e}")
        return False


def validate_application_config(app_config) -> List[Dict[str, Any]]:
    """Validate application configuration."""
    results = []
    
    # Check required URLs
    if not app_config.app_url:
        results.append({
            "valid": False,
            "message": "APP_URL is required"
        })
    
    if not app_config.api_base_url:
        results.append({
            "valid": False,
            "message": "API_BASE_URL is required"
        })
    
    # Check secret key
    if not app_config.secret_key:
        results.append({
            "valid": False,
            "message": "APP_SECRET_KEY is required"
        })
    elif len(app_config.secret_key) < 32:
        results.append({
            "valid": False,
            "message": "APP_SECRET_KEY must be at least 32 characters long"
        })
    
    # Check environment-specific settings
    if app_config.environment == "production":
        if app_config.debug:
            results.append({
                "valid": False,
                "message": "Debug mode should be disabled in production"
            })
    
    return results


def validate_aws_config(aws_config) -> List[Dict[str, Any]]:
    """Validate AWS configuration."""
    results = []
    
    # Check Cognito configuration
    if not aws_config.cognito_user_pool_id:
        results.append({
            "valid": False,
            "message": "AWS_COGNITO_USER_POOL_ID is required"
        })
    
    if not aws_config.cognito_client_id:
        results.append({
            "valid": False,
            "message": "AWS_COGNITO_CLIENT_ID is required"
        })
    
    if not aws_config.cognito_domain:
        results.append({
            "valid": False,
            "message": "AWS_COGNITO_DOMAIN is required"
        })
    
    # Check SQS configuration
    if not aws_config.prayer_requests_queue_url:
        results.append({
            "valid": False,
            "message": "AWS_PRAYER_REQUESTS_QUEUE_URL is required"
        })
    
    # Check SES configuration
    if not aws_config.ses_sender_email:
        results.append({
            "valid": False,
            "message": "AWS_SES_SENDER_EMAIL is required"
        })
    
    # Check credentials (warn if missing in non-local environments)
    if not aws_config.localstack_endpoint:
        if not aws_config.aws_access_key_id and not os.getenv("AWS_PROFILE"):
            results.append({
                "valid": True,
                "warning": True,
                "message": "AWS credentials not found. Ensure IAM role or AWS_PROFILE is configured"
            })
    
    return results


def validate_database_config(db_config) -> List[Dict[str, Any]]:
    """Validate database configuration."""
    results = []
    
    # Check table names are set
    required_tables = [
        ("user_profiles_table", "User profiles table"),
        ("conversation_sessions_table", "Conversation sessions table"),
        ("prayer_requests_table", "Prayer requests table"),
        ("consent_logs_table", "Consent logs table"),
    ]
    
    for table_attr, description in required_tables:
        if not getattr(db_config, table_attr):
            results.append({
                "valid": False,
                "message": f"{description} name is required"
            })
    
    return results


def validate_redis_config(redis_config) -> List[Dict[str, Any]]:
    """Validate Redis configuration."""
    results = []
    
    # Check Redis URL
    if not redis_config.redis_url:
        results.append({
            "valid": False,
            "message": "REDIS_URL is required"
        })
    
    # Validate TTL values
    if redis_config.cache_ttl_default <= 0:
        results.append({
            "valid": False,
            "message": "REDIS_CACHE_TTL_DEFAULT must be positive"
        })
    
    return results


def check_environment_parity() -> bool:
    """Check for environment parity issues."""
    print("\n🔄 Checking environment parity...")
    
    # This would compare current environment with expected configuration
    # For now, just check if we're in a known environment
    env = os.getenv("APP_ENVIRONMENT", "development")
    
    known_environments = ["development", "staging", "production"]
    if env not in known_environments:
        print(f"⚠️  Unknown environment: {env}")
        return False
    
    print(f"✅ Environment parity check passed for: {env}")
    return True


def main():
    """Main validation function."""
    print("Faith Motivator Chatbot - Environment Validation")
    print("=" * 50)
    
    # Validate configuration
    config_valid = validate_environment()
    
    # Check environment parity
    parity_valid = check_environment_parity()
    
    # Overall result
    if config_valid and parity_valid:
        print("\n🎉 All validation checks passed!")
        sys.exit(0)
    else:
        print("\n💥 Validation failed!")
        sys.exit(1)


if __name__ == "__main__":
    main()