#!/bin/bash
# List all CodeBuild projects that start with a given prefix
# Usage: ./list-codebuild-projects.sh <prefix> [aws-profile] [aws-region]
# Example: ./list-codebuild-projects.sh terraform-
# Example: ./list-codebuild-projects.sh terraform- my-profile
# Example: ./list-codebuild-projects.sh terraform- my-profile us-west-2

# Check if prefix argument is provided
if [ $# -eq 0 ]; then
    echo "Error: Prefix argument is required"
    echo "Usage: $0 <prefix> [aws-profile] [aws-region]"
    echo "Examples:"
    echo "  $0 terraform-"
    echo "  $0 terraform- my-profile"
    echo "  $0 terraform- my-profile us-west-2"
    echo ""
    echo "Default values:"
    echo "  aws-profile: default"
    echo "  aws-region: us-east-1"
    exit 1
fi

# Parse arguments with defaults
PREFIX="$1"
AWS_PROFILE="${2:-default}"
AWS_REGION="${3:-us-east-1}"

echo "Listing all CodeBuild projects with '$PREFIX' prefix..."
echo "AWS Profile: $AWS_PROFILE"
echo "AWS Region: $AWS_REGION"
echo "============================================="

projects=$(aws codebuild list-projects --profile "$AWS_PROFILE" --region "$AWS_REGION" --max-items 1000 --query "projects[?starts_with(@, \`$PREFIX\`)]" --output text)

if [ -z "$projects" ]; then
    echo "No CodeBuild projects found with '$PREFIX' prefix"
else
    echo "Found CodeBuild projects:"
    for project in $projects; do
        echo "- $project"
    done

    # Count the projects
    project_count=$(echo "$projects" | wc -w)
    echo "============================================="
    echo "Total projects found: $project_count"
fi