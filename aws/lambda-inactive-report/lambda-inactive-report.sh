#!/bin/bash

# Script to detect Lambda functions that haven't been executed in 90+ days
# Author: Generated script for AWS Lambda monitoring
# Date: $(date +%Y-%m-%d)
# Usage: ./lambda-inactive-report.sh [days] [output_format] [custom_name]
#   days: Number of days to check (default: 90)
#   output_format: txt (default) or csv
#   custom_name: Custom name for the report file (optional)

set -e

# Configuration
DAYS_THRESHOLD=${1:-90}  # Default 90 days, but can be passed as parameter
OUTPUT_FORMAT=${2:-txt}  # Default txt format, can be csv
CUSTOM_NAME=${3:-""}     # Custom name for the report file (optional)

# Validate output format
if [[ "$OUTPUT_FORMAT" != "txt" && "$OUTPUT_FORMAT" != "csv" ]]; then
    echo "❌ Error: Invalid output format. Use 'txt' or 'csv'"
    echo "Usage: $0 [days] [output_format] [custom_name]"
    echo "  days: Number of days to check (default: 90)"
    echo "  output_format: txt (default) or csv"
    echo "  custom_name: Custom name for the report file (optional)"
    exit 1
fi

# Set output file based on format and custom name
if [[ -n "$CUSTOM_NAME" ]]; then
    # Use custom name
    if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        OUTPUT_FILE="${CUSTOM_NAME}.csv"
    else
        OUTPUT_FILE="${CUSTOM_NAME}.txt"
    fi
else
    # Use default timestamp-based name
    if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        OUTPUT_FILE="lambda-inactive-report-$(date +%Y%m%d-%H%M%S).csv"
    else
        OUTPUT_FILE="lambda-inactive-report-$(date +%Y%m%d-%H%M%S).txt"
    fi
fi

echo "================================================"
echo "INACTIVE LAMBDA FUNCTIONS REPORT"
echo "================================================"
echo "Analysis period: last $DAYS_THRESHOLD days"
echo "Output format: $OUTPUT_FORMAT"
echo "Output file: $OUTPUT_FILE"
echo "Generation date: $(date)"
echo "================================================"
echo

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is not installed"
    echo "jq is required for JSON processing. Please install it:"
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt install jq"
    echo "  CentOS/RHEL: sudo yum install jq"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: Cannot verify AWS credentials"
    echo "Run 'aws configure' to configure your credentials"
    exit 1
fi

echo "✅ AWS CLI configured correctly"
echo

# Create output file
if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
    # CSV header
    echo "Function Name,Runtime,Last Modified,Invocations,Status,Description" > "$OUTPUT_FILE"
else
    # Text format header
    {
        echo "================================================"
        echo "INACTIVE LAMBDA FUNCTIONS REPORT"
        echo "================================================"
        echo "Analysis period: last $DAYS_THRESHOLD days"
        echo "Generation date: $(date)"
        echo "================================================"
        echo
    } > "$OUTPUT_FILE"
fi

# Counters
total_functions=0
inactive_functions=0
active_functions=0
error_functions=0

echo "Getting list of Lambda functions..."
if [[ "$OUTPUT_FORMAT" != "csv" ]]; then
    echo "Getting list of Lambda functions..." >> "$OUTPUT_FILE"
fi

# Get all lambdas
lambda_functions=$(aws lambda list-functions --query 'Functions[].FunctionName' --output text | tr '\t' '\n')

while IFS= read -r function_name; do
    if [ -z "$function_name" ]; then
        continue
    fi

    total_functions=$((total_functions + 1))
    echo "Checking: $function_name"

    # Calculate timestamps for CloudWatch
    end_time=$(date -u +"%Y-%m-%dT%H:%M:%S")
    start_time=$(date -u -v-${DAYS_THRESHOLD}d +"%Y-%m-%dT%H:%M:%S")

    # Get invocation metrics for the specified period
    invocations=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Invocations \
        --dimensions Name=FunctionName,Value="$function_name" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 86400 \
        --statistics Sum \
        --query 'Datapoints[].Sum' \
        --output text 2>/dev/null)

    # Calculate total invocations
    total_invocations=$(echo "$invocations" | awk '{sum+=$1} END {print sum+0}')

    # Get additional function information
    function_info=$(aws lambda get-function --function-name "$function_name" --query 'Configuration.{Runtime:Runtime,LastModified:LastModified,Description:Description}' --output json 2>/dev/null)
    if [ $? -eq 0 ]; then
        runtime=$(echo "$function_info" | jq -r '.Runtime // "N/A"')
        last_modified=$(echo "$function_info" | jq -r '.LastModified // "N/A"')
        description=$(echo "$function_info" | jq -r '.Description // "N/A"')
    else
        runtime="N/A"
        last_modified="N/A"
        description="N/A"
    fi

    if [ "$total_invocations" -eq 0 ]; then
        inactive_functions=$((inactive_functions + 1))
        echo "❌ $function_name - No executions in last $DAYS_THRESHOLD days"

        if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
            # CSV format - escape commas and quotes in description
            description_escaped=$(echo "$description" | sed 's/"/""/g')
            echo "\"$function_name\",\"$runtime\",\"$last_modified\",$total_invocations,Inactive,\"$description_escaped\"" >> "$OUTPUT_FILE"
        else
            # Text format
            echo "❌ $function_name - No executions in last $DAYS_THRESHOLD days" >> "$OUTPUT_FILE"
            echo "   Runtime: $runtime" >> "$OUTPUT_FILE"
            echo "   Last Modified: $last_modified" >> "$OUTPUT_FILE"
            echo "   Description: $description" >> "$OUTPUT_FILE"
            echo >> "$OUTPUT_FILE"
        fi

        echo "   Runtime: $runtime"
        echo "   Last Modified: $last_modified"
        echo "   Description: $description"
        echo
    else
        active_functions=$((active_functions + 1))
        echo "✅ $function_name - $total_invocations total invocations"

        if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
            # CSV format - escape commas and quotes in description
            description_escaped=$(echo "$description" | sed 's/"/""/g')
            echo "\"$function_name\",\"$runtime\",\"$last_modified\",$total_invocations,Active,\"$description_escaped\"" >> "$OUTPUT_FILE"
        else
            # Text format
            echo "✅ $function_name - $total_invocations total invocations" >> "$OUTPUT_FILE"
        fi
    fi

done <<< "$lambda_functions"

# Generate final summary
echo "================================================"
echo "FINAL SUMMARY"
echo "================================================"
echo "Total functions analyzed: $total_functions"
echo "Active functions: $active_functions"
echo "Inactive functions: $inactive_functions"
echo "Functions with errors: $error_functions"
echo "================================================"

# Add summary to file based on format
if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
    # CSV format - add summary as comments
    {
        echo ""
        echo "# SUMMARY"
        echo "# Total functions analyzed: $total_functions"
        echo "# Active functions: $active_functions"
        echo "# Inactive functions: $inactive_functions"
        echo "# Functions with errors: $error_functions"
    } >> "$OUTPUT_FILE"
else
    # Text format
    {
        echo
        echo "================================================"
        echo "FINAL SUMMARY"
        echo "================================================"
        echo "Total functions analyzed: $total_functions"
        echo "Active functions: $active_functions"
        echo "Inactive functions: $inactive_functions"
        echo "Functions with errors: $error_functions"
        echo "================================================"
    } >> "$OUTPUT_FILE"
fi

echo
echo "✅ Report completed and saved to: $OUTPUT_FILE"

# Show suggestions if there are inactive functions
if [ $inactive_functions -gt 0 ]; then
    echo
    echo "💡 SUGGESTIONS:"
    echo "- Review inactive functions to determine if they can be deleted"
fi
