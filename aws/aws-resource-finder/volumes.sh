#!/bin/bash
# Description: Find EBS volumes by ID
# Author: Daniel Gamboa (converted from aws-resource-finder)
# Usage: ./volumes.sh <volume-id> [OPTIONS]

set -euo pipefail

show_help() {
    cat << EOF
Usage: $(basename "$0") <volume-id> [OPTIONS]

Description:
    Finds EBS volumes by volume ID across one or more AWS profiles and regions.

Required Arguments:
    <volume-id>                 Volume ID to search (e.g., vol-1234567890abcdef0)

Optional Arguments:
    --profile=PROFILE           AWS CLI profile(s), comma-separated (default: default)
    --region=REGION             AWS region (default: us-east-1)
    --output=FORMAT             Output format: text|json|yaml (default: text)
    --verbose                   Enable verbose output

Examples:
    # Search for volume in default profile
    $(basename "$0") vol-1234567890abcdef0

    # Search across multiple profiles
    $(basename "$0") vol-1234567890abcdef0 --profile=prod,qa,dev

    # Search in specific region
    $(basename "$0") vol-1234567890abcdef0 --region=eu-west-1

    # Output as JSON
    $(basename "$0") vol-1234567890abcdef0 --output=json

EOF
    exit 0
}

# Defaults
VOLUME_ID=""
PROFILE="default"
REGION="us-east-1"
OUTPUT="text"
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --region=*)
            REGION="${1#*=}"
            shift
            ;;
        --output=*)
            OUTPUT="${1#*=}"
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
            if [ -z "$VOLUME_ID" ]; then
                VOLUME_ID="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$VOLUME_ID" ]; then
    echo "Error: volume-id is required"
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

# Function to query volumes in a profile
query_profile() {
    local profile=$1
    local region=$2
    local vol_id=$3

    local aws_opts="--profile $profile --region $region"

    # Describe volume
    local volume=$(aws ec2 describe-volumes $aws_opts \
        --volume-ids "$vol_id" \
        --query "Volumes[0]" \
        --output json 2>/dev/null || echo "null")

    if [ "$volume" != "null" ]; then
        echo "$volume" | jq --arg profile "$profile" '
            {
                profile: $profile,
                id: .VolumeId,
                state: .State,
                size_gb: .Size,
                az: .AvailabilityZone,
                type: .VolumeType,
                iops: .Iops,
                throughput: .Throughput,
                encrypted: .Encrypted,
                kms_key_id: .KmsKeyId,
                attachments: (.Attachments | map({
                    instance_id: .InstanceId,
                    device: .Device,
                    state: .State
                })),
                tags: (.Tags // [] | map({key: .Key, value: .Value}))
            }
        '
    fi
}

# Process each profile and collect results
declare -a all_volumes
for prof in ${PROFILE//,/ }; do
    prof=$(echo "$prof" | xargs)  # trim whitespace
    if [ "$VERBOSE" = true ]; then
        echo "Querying profile: $prof" >&2
    fi
    result=$(query_profile "$prof" "$REGION" "$VOLUME_ID")
    if [ -n "$result" ] && [ "$result" != "null" ]; then
        all_volumes+=("$result")
    fi
done

# Output
if [ ${#all_volumes[@]} -eq 0 ]; then
    echo "No volumes found: $VOLUME_ID" >&2
    exit 1
fi

if [ "$OUTPUT" = "json" ]; then
    echo "["
    first=true
    for volume in "${all_volumes[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "$volume"
    done
    echo ""
    echo "]"
elif [ "$OUTPUT" = "yaml" ]; then
    echo "volumes:"
    for volume in "${all_volumes[@]}"; do
        echo "$volume" | jq '.' | sed 's/^/  /'
    done
else
    # text output
    for volume in "${all_volumes[@]}"; do
        echo "$volume" | jq -r '
            "Volume: \(.id) (\(.state))\n" +
            "  Size: \(.size_gb)GiB, Type: \(.type), AZ: \(.az)\n" +
            "  IOPS: \(.iops), Throughput: \(.throughput) MB/s\n" +
            "  Encrypted: \(.encrypted)" + (if .kms_key_id then ", KMS: \(.kms_key_id)" else "" end) + "\n" +
            (if .attachments and (.attachments | length) > 0 then
                "  Attachments: " + (.attachments | map("\(.instance_id) at \(.device) (\(.state))") | join(", ")) + "\n"
            else
                "  Attachments: None\n"
            end) +
            (if .tags and (.tags | length) > 0 then "  Tags: " + (.tags | map("\(.key)=\(.value)") | join(", ")) + "\n" else "" end) +
            "  Profile: \(.profile)\n"
        '
    done
fi
