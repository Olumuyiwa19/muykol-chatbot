#!/bin/bash

# ECR Utility Script for Faith-Based Motivator Chatbot
# This script provides utilities for working with the ECR repository

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
AWS_PROFILE=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
ECR Utility Script for Faith-Based Motivator Chatbot

Usage: $0 [OPTIONS] COMMAND

OPTIONS:
    -e, --environment ENV    Environment (dev, staging, prod) [default: dev]
    -r, --region REGION      AWS region [default: us-east-1]
    -p, --profile PROFILE    AWS profile to use
    -h, --help              Show this help message

COMMANDS:
    login                   Login to ECR registry
    build                   Build Docker image for backend
    tag TAG                 Tag the latest built image
    push [TAG]              Push image to ECR (optionally with specific tag)
    pull [TAG]              Pull image from ECR (optionally with specific tag)
    list                    List images in ECR repository
    scan TAG                Trigger vulnerability scan for specific tag
    scan-results TAG        Get vulnerability scan results for specific tag
    cleanup                 Remove old/untagged local images
    info                    Show ECR repository information

EXAMPLES:
    $0 -e dev login
    $0 -e dev build
    $0 -e dev tag v1.0.0
    $0 -e dev push v1.0.0
    $0 -e staging pull latest
    $0 -e prod list
    $0 -e prod scan v1.0.0
    $0 cleanup

EOF
}

# Function to get ECR repository URI from SSM
get_ecr_repository_uri() {
    local env=$1
    local param_name="/chatbot/${env}/ecr/repository-uri"
    
    print_info "Getting ECR repository URI for environment: $env"
    
    local aws_cmd="aws ssm get-parameter --name '$param_name' --query 'Parameter.Value' --output text"
    if [[ -n "$AWS_PROFILE" ]]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        aws_cmd="$aws_cmd --region $AWS_REGION"
    fi
    
    local repository_uri
    repository_uri=$(eval $aws_cmd 2>/dev/null)
    
    if [[ $? -ne 0 || -z "$repository_uri" ]]; then
        print_error "Failed to get ECR repository URI. Make sure the infrastructure is deployed."
        print_info "Parameter name: $param_name"
        exit 1
    fi
    
    echo "$repository_uri"
}

# Function to get AWS account ID
get_aws_account_id() {
    local aws_cmd="aws sts get-caller-identity --query 'Account' --output text"
    if [[ -n "$AWS_PROFILE" ]]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    
    local account_id
    account_id=$(eval $aws_cmd 2>/dev/null)
    
    if [[ $? -ne 0 || -z "$account_id" ]]; then
        print_error "Failed to get AWS account ID. Check your AWS credentials."
        exit 1
    fi
    
    echo "$account_id"
}

# Function to login to ECR
ecr_login() {
    print_info "Logging in to ECR registry..."
    
    local account_id
    account_id=$(get_aws_account_id)
    
    local aws_cmd="aws ecr get-login-password"
    if [[ -n "$AWS_PROFILE" ]]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        aws_cmd="$aws_cmd --region $AWS_REGION"
    fi
    
    eval $aws_cmd | docker login --username AWS --password-stdin "${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully logged in to ECR"
    else
        print_error "Failed to login to ECR"
        exit 1
    fi
}

# Function to build Docker image
build_image() {
    print_info "Building Docker image for backend..."
    
    if [[ ! -f "$BACKEND_DIR/Dockerfile" ]]; then
        print_error "Dockerfile not found at $BACKEND_DIR/Dockerfile"
        exit 1
    fi
    
    cd "$BACKEND_DIR"
    
    local image_name="${ENVIRONMENT}-chatbot-backend"
    docker build -t "$image_name:latest" .
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully built image: $image_name:latest"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# Function to tag image
tag_image() {
    local tag=$1
    if [[ -z "$tag" ]]; then
        print_error "Tag is required"
        exit 1
    fi
    
    local repository_uri
    repository_uri=$(get_ecr_repository_uri "$ENVIRONMENT")
    
    local local_image="${ENVIRONMENT}-chatbot-backend:latest"
    local remote_image="${repository_uri}:${tag}"
    
    print_info "Tagging image: $local_image -> $remote_image"
    
    docker tag "$local_image" "$remote_image"
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully tagged image: $remote_image"
    else
        print_error "Failed to tag image"
        exit 1
    fi
}

# Function to push image
push_image() {
    local tag=${1:-"latest"}
    
    local repository_uri
    repository_uri=$(get_ecr_repository_uri "$ENVIRONMENT")
    
    local remote_image="${repository_uri}:${tag}"
    
    # Check if image exists locally
    if ! docker image inspect "$remote_image" >/dev/null 2>&1; then
        print_warning "Image $remote_image not found locally. Attempting to tag from latest..."
        local local_image="${ENVIRONMENT}-chatbot-backend:latest"
        if docker image inspect "$local_image" >/dev/null 2>&1; then
            docker tag "$local_image" "$remote_image"
        else
            print_error "No local image found to push. Build the image first."
            exit 1
        fi
    fi
    
    print_info "Pushing image: $remote_image"
    
    docker push "$remote_image"
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully pushed image: $remote_image"
    else
        print_error "Failed to push image"
        exit 1
    fi
}

# Function to pull image
pull_image() {
    local tag=${1:-"latest"}
    
    local repository_uri
    repository_uri=$(get_ecr_repository_uri "$ENVIRONMENT")
    
    local remote_image="${repository_uri}:${tag}"
    
    print_info "Pulling image: $remote_image"
    
    docker pull "$remote_image"
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully pulled image: $remote_image"
    else
        print_error "Failed to pull image"
        exit 1
    fi
}

# Function to list images
list_images() {
    print_info "Listing images in ECR repository..."
    
    local repository_name="${ENVIRONMENT}-chatbot-backend"
    
    local aws_cmd="aws ecr describe-images --repository-name '$repository_name' --query 'imageDetails[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' --output table"
    if [[ -n "$AWS_PROFILE" ]]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        aws_cmd="$aws_cmd --region $AWS_REGION"
    fi
    
    eval $aws_cmd
}

# Function to trigger vulnerability scan
trigger_scan() {
    local tag=$1
    if [[ -z "$tag" ]]; then
        print_error "Tag is required for vulnerability scan"
        exit 1
    fi
    
    local repository_name="${ENVIRONMENT}-chatbot-backend"
    
    print_info "Triggering vulnerability scan for image: $repository_name:$tag"
    
    local aws_cmd="aws ecr start-image-scan --repository-name '$repository_name' --image-id imageTag='$tag'"
    if [[ -n "$AWS_PROFILE" ]]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        aws_cmd="$aws_cmd --region $AWS_REGION"
    fi
    
    eval $aws_cmd
    
    if [[ $? -eq 0 ]]; then
        print_success "Vulnerability scan triggered for $repository_name:$tag"
        print_info "Use 'scan-results $tag' to check results once scan is complete"
    else
        print_error "Failed to trigger vulnerability scan"
        exit 1
    fi
}

# Function to get scan results
get_scan_results() {
    local tag=$1
    if [[ -z "$tag" ]]; then
        print_error "Tag is required for scan results"
        exit 1
    fi
    
    local repository_name="${ENVIRONMENT}-chatbot-backend"
    
    print_info "Getting vulnerability scan results for image: $repository_name:$tag"
    
    local aws_cmd="aws ecr describe-image-scan-findings --repository-name '$repository_name' --image-id imageTag='$tag'"
    if [[ -n "$AWS_PROFILE" ]]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        aws_cmd="$aws_cmd --region $AWS_REGION"
    fi
    
    eval $aws_cmd
}

# Function to cleanup local images
cleanup_images() {
    print_info "Cleaning up old and untagged local Docker images..."
    
    # Remove dangling images
    local dangling_images
    dangling_images=$(docker images -f "dangling=true" -q)
    if [[ -n "$dangling_images" ]]; then
        print_info "Removing dangling images..."
        docker rmi $dangling_images
    fi
    
    # Remove old chatbot images (keep latest 3)
    local old_images
    old_images=$(docker images "${ENVIRONMENT}-chatbot-backend" --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" | tail -n +2 | sort -k2 -r | tail -n +4 | cut -f1)
    if [[ -n "$old_images" ]]; then
        print_info "Removing old chatbot images..."
        echo "$old_images" | xargs -r docker rmi
    fi
    
    print_success "Cleanup completed"
}

# Function to show repository info
show_info() {
    print_info "ECR Repository Information for environment: $ENVIRONMENT"
    
    local repository_uri
    repository_uri=$(get_ecr_repository_uri "$ENVIRONMENT")
    
    local repository_name="${ENVIRONMENT}-chatbot-backend"
    
    echo "Repository Name: $repository_name"
    echo "Repository URI: $repository_uri"
    echo "AWS Region: $AWS_REGION"
    echo "Environment: $ENVIRONMENT"
    
    if [[ -n "$AWS_PROFILE" ]]; then
        echo "AWS Profile: $AWS_PROFILE"
    fi
    
    print_info "Getting repository details..."
    
    local aws_cmd="aws ecr describe-repositories --repository-names '$repository_name'"
    if [[ -n "$AWS_PROFILE" ]]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        aws_cmd="$aws_cmd --region $AWS_REGION"
    fi
    
    eval $aws_cmd
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -p|--profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    exit 1
fi

# Get command
COMMAND=$1
shift

# Execute command
case $COMMAND in
    login)
        ecr_login
        ;;
    build)
        build_image
        ;;
    tag)
        if [[ $# -eq 0 ]]; then
            print_error "Tag is required"
            show_usage
            exit 1
        fi
        tag_image "$1"
        ;;
    push)
        push_image "$1"
        ;;
    pull)
        pull_image "$1"
        ;;
    list)
        list_images
        ;;
    scan)
        if [[ $# -eq 0 ]]; then
            print_error "Tag is required for vulnerability scan"
            show_usage
            exit 1
        fi
        trigger_scan "$1"
        ;;
    scan-results)
        if [[ $# -eq 0 ]]; then
            print_error "Tag is required for scan results"
            show_usage
            exit 1
        fi
        get_scan_results "$1"
        ;;
    cleanup)
        cleanup_images
        ;;
    info)
        show_info
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac