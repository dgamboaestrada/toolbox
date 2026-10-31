#!/bin/bash
# Description: Find target groups by target ID (instance/ip/lambda)
# Author: Daniel Gamboa (converted from aws-resource-finder)
# Usage: ./target-groups-by-target.sh <target-id> [OPTIONS]

set -euo pipefail

show_help() {
    cat << EOF
Usage: $(basename "$0") <target-id> [OPTIONS]

Description:
    Finds ELBv2 target groups containing a specific target (instance, IP, or Lambda)
    across one or more AWS profiles and regions.

Required Arguments:
    <target-id>                 Target ID to search (instance ID, IP, or Lambda ARN)

Optional Arguments:
    --type=TYPE                 Target type: ip|instance|lambda (default: ip)
    --profile=PROFILE           AWS CLI profile(s), comma-separated (default: default)
    --region=REGION             AWS region (default: us-east-1)
    --tags                      Include target group tags in output
    --output=FORMAT             Output format: text|json|yaml (default: text)
    --lb-arn=ARN               Optional Load Balancer ARN to limit search
    --verbose                   Enable verbose output

Examples:
    # Search for IP in target groups
    $(basename "$0") 10.0.0.5

    # Search for instance ID with tags
    $(basename "$0") i-1234567890abcdef0 --tags --profile=prod

    # Search across multiple profiles
    $(basename "$0") 10.0.0.5 --profile=prod,qa,dev

    # Search for Lambda function
    $(basename "$0") arn:aws:lambda:us-east-1:123456789012:function:my-function --type=lambda

EOF
    exit 0
}

# Defaults
TARGET_ID=""
TARGET_TYPE="ip"
PROFILE="default"
REGION="us-east-1"
SHOW_TAGS=false
OUTPUT="text"
LB_ARN=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --type=*)
            TARGET_TYPE="${1#*=}"
            shift
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --region=*)
            REGION="${1#*=}"
            shift
            ;;
        --tags)
            SHOW_TAGS=true
            shift
            ;;
        --output=*)
            OUTPUT="${1#*=}"
            shift
            ;;
        --lb-arn=*)
            LB_ARN="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            exit 1
            ;;
        *)
            if [ -z "$TARGET_ID" ]; then
                TARGET_ID="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$TARGET_ID" ]; then
    echo "Error: target-id is required"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

# Function to query target groups in a profile
query_profile() {
    local profile=$1
    local region=$2

    local aws_opts="--profile $profile --region $region"

    # Get all target groups
    local tg_arns=$(aws elbv2 describe-target-groups $aws_opts \
        ${LB_ARN:+--load-balancer-arn "$LB_ARN"} \
        --query "TargetGroups[?TargetType=='$TARGET_TYPE'].TargetGroupArn" \
        --output text 2>/dev/null || echo "")

    if [ -z "$tg_arns" ]; then
        return 0
    fi

    # Search each target group for the target
    while read -r tg_arn; do
        [ -z "$tg_arn" ] && continue

        local targets=$(aws elbv2 describe-target-health $aws_opts \
            --target-group-arn "$tg_arn" \
            --query "TargetHealthDescriptions[?Target.Id=='$TARGET_ID']" \
            --output json 2>/dev/null || echo "[]")

        if [ "$(echo "$targets" | jq 'length')" -gt 0 ]; then
            local tg_info=$(aws elbv2 describe-target-groups $aws_opts \
                --target-group-arns "$tg_arn" \
                --query "TargetGroups[0]" \
                --output json 2>/dev/null)

            local tags=""
            if [ "$SHOW_TAGS" = true ]; then
                tags=$(aws elbv2 describe-tags $aws_opts \
                    --resource-arns "$tg_arn" \
                    --query "TagDescriptions[0].Tags" \
                    --output json 2>/dev/null || echo "[]")
            fi

            echo "$tg_info" | jq --arg targets "$targets" --arg tags "$tags" --arg profile "$profile" '
                {
                    profile: $profile,
                    target_group_arn: .TargetGroupArn,
                    target_group_name: .TargetGroupName,
                    target_type: .TargetType,
                    vpc_id: .VpcId,
                    targets: ($targets | fromjson | map({
                        target_id: .Target.Id,
                        port: .Target.Port,
                        state: .TargetHealth.State,
                        reason: .TargetHealth.Reason,
                        description: .TargetHealth.Description
                    })),
                    tags: (if $tags != "[]" then ($tags | fromjson) else [] end)
                }
            '
        fi
    done <<< "$tg_arns"
}

# Process each profile
results=()
for prof in ${PROFILE//,/ }; do
    prof=$(echo "$prof" | xargs)  # trim whitespace
    if [ "$VERBOSE" = true ]; then
        echo "Querying profile: $prof" >&2
    fi
    query_profile "$prof" "$REGION" | while read -r line; do
        [ -n "$line" ] && results+=("$line")
    done
done

# Collect all results
all_results=()
for prof in ${PROFILE//,/ }; do
    prof=$(echo "$prof" | xargs)
    query_profile "$prof" "$REGION" | while read -r line; do
        [ -n "$line" ] && all_results+=("$line")
    done
done

# Output
if [ "$OUTPUT" = "json" ]; then
    echo "["
    first=true
    for prof in ${PROFILE//,/ }; do
        prof=$(echo "$prof" | xargs)
        while read -r line; do
            if [ -n "$line" ]; then
                if [ "$first" = true ]; then
                    first=false
                else
                    echo ","
                fi
                echo -n "$line"
            fi
        done < <(query_profile "$prof" "$REGION")
    done
    echo ""
    echo "]"
elif [ "$OUTPUT" = "yaml" ]; then
    echo "results:"
    for prof in ${PROFILE//,/ }; do
        prof=$(echo "$prof" | xargs)
        query_profile "$prof" "$REGION" | jq -r 'tostring'
    done
else
    # text output
    for prof in ${PROFILE//,/ }; do
        prof=$(echo "$prof" | xargs)
        query_profile "$prof" "$REGION" | jq -r '
            "Profile: \(.profile)\n" +
            "  TG: \(.target_group_name) (\(.target_group_arn))\n" +
            "  Type: \(.target_type), VPC: \(.vpc_id)\n" +
            (.targets | map("  Target: \(.target_id):\(.port) state=\(.state)") | join("\n")) +
            (if .tags and (.tags | length) > 0 then "\n  Tags: " + (.tags | map("\(.key)=\(.value)") | join(", ")) else "" end) +
            "\n"
        '
    done
fi
