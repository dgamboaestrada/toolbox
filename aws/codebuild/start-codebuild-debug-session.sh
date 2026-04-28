#!/bin/bash
# Description: Start a CodeBuild debug session.
# Usage: ./start-codebuild-debug-session.sh <project-name> <aws-profile> [aws-region] [source-version]
# Note: To add a breakpoint, add the following line to your buildspec.yml file: codebuild-breakpoint

PROJECT_NAME="$1"
AWS_PROFILE="$2"
AWS_REGION="${3:-us-east-1}"
SOURCE_VERSION="${4:-main}"

# Check if required parameters are provided
if [ -z "$PROJECT_NAME" ] || [ -z "$AWS_PROFILE" ]; then
    echo "Error: Project name and AWS profile are required"
    echo "Usage: $0 <project-name> <aws-profile> [aws-region] [source-version]"
    exit 1
fi

aws codebuild start-build --project-name $PROJECT_NAME --source-version $SOURCE_VERSION \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --debug-session-enabled \
  --environment-variables-override "[
    {
      \"name\": \"key1\",
      \"value\": \"value\"
    },
    {
      \"name\": \"key2\",
      \"value\": \"value2\"
    },
    {
      \"name\": \"key3\",
      \"value\": \"value3\"
    }
  ]"
