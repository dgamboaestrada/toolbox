#!/bin/bash
# Description: Find EC2 network interfaces by IP address
# Author: Daniel Gamboa (converted from aws-resource-finder)
# Usage: ./network-interfaces.sh <ip-address> [OPTIONS]

set -euo pipefail

show_help() {
    cat << EOF
Usage: $(basename "$0") <ip-address> [OPTIONS]

Description:
    Finds EC2 network interfaces by private or public IP address across one or
    more AWS profiles and regions.

Required Arguments:
    <ip-address>                IP address to search (private or public)

Optional Arguments:
    --profile=PROFILE           AWS CLI profile(s), comma-separated (default: default)
    --region=REGION             AWS region (default: us-east-1)
    --output=FORMAT             Output format: text|json|yaml (default: text)
    --verbose                   Enable verbose output

Examples:
    # Search for private IP
    $(basename "$0") 10.0.1.50

    # Search for public IP
    $(basename "$0") 203.0.113.42

    # Search across multiple profiles
    $(basename "$0") 10.0.1.50 --profile=prod,qa,dev

    # Output as JSON
    $(basename "$0") 10.0.1.50 --output=json

EOF
    exit 0
}

# Defaults
IP_ADDRESS=""
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
            if [ -z "$IP_ADDRESS" ]; then
                IP_ADDRESS="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$IP_ADDRESS" ]; then
    echo "Error: ip-address is required"
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

# Function to query network interfaces in a profile
query_profile() {
    local profile=$1
    local region=$2
    local ip=$3

    local aws_opts="--profile $profile --region $region"

    # Search by private IP
    local private_enis=$(aws ec2 describe-network-interfaces $aws_opts \
        --filters "Name=private-ip-address,Values=$ip" \
        --query "NetworkInterfaces" \
        --output json 2>/dev/null || echo "[]")

    # Search by public/elastic IP
    local public_enis=$(aws ec2 describe-network-interfaces $aws_opts \
        --filters "Name=association.public-ip,Values=$ip" \
        --query "NetworkInterfaces" \
        --output json 2>/dev/null || echo "[]")

    # Combine and deduplicate by interface ID
    local all_enis=$(echo "$private_enis $public_enis" | jq -s 'add | unique_by(.NetworkInterfaceId)')

    if [ "$(echo "$all_enis" | jq 'length')" -gt 0 ]; then
        echo "$all_enis" | jq --arg profile "$profile" '.[] |
            {
                profile: $profile,
                id: .NetworkInterfaceId,
                status: .Status,
                private_ip: .PrivateIpAddress,
                public_ip: .Association.PublicIp // null,
                subnet_id: .SubnetId,
                vpc_id: .VpcId,
                attachment_instance_id: .Attachment.InstanceId // null,
                description: .Description,
                groups: (.Groups | map({id: .GroupId, name: .GroupName})),
                tags: (.Tags // [] | map({key: .Key, value: .Value}))
            }
        '
    fi
}

# Process each profile and collect results
declare -a all_enis
for prof in ${PROFILE//,/ }; do
    prof=$(echo "$prof" | xargs)  # trim whitespace
    if [ "$VERBOSE" = true ]; then
        echo "Querying profile: $prof" >&2
    fi
    while read -r eni; do
        [ -n "$eni" ] && all_enis+=("$eni")
    done < <(query_profile "$prof" "$REGION" "$IP_ADDRESS")
done

# Output
if [ ${#all_enis[@]} -eq 0 ]; then
    echo "No network interfaces found for IP: $IP_ADDRESS" >&2
    exit 1
fi

if [ "$OUTPUT" = "json" ]; then
    echo "["
    first=true
    for eni in "${all_enis[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "$eni"
    done
    echo ""
    echo "]"
elif [ "$OUTPUT" = "yaml" ]; then
    echo "network_interfaces:"
    for eni in "${all_enis[@]}"; do
        echo "$eni" | jq '.' | sed 's/^/  /'
    done
else
    # text output
    for eni in "${all_enis[@]}"; do
        echo "$eni" | jq -r '
            "ENI: \(.id) (\(.status))\n" +
            "  Private IP: \(.private_ip)" + (if .public_ip then ", Public IP: \(.public_ip)" else "" end) + "\n" +
            "  VPC: \(.vpc_id), Subnet: \(.subnet_id)\n" +
            (if .attachment_instance_id then "  Attached to: \(.attachment_instance_id)\n" else "" end) +
            (if .description then "  Description: \(.description)\n" else "" end) +
            (if .groups and (.groups | length) > 0 then "  Security Groups: " + (.groups | map("\(.name) (\(.id))") | join(", ")) + "\n" else "" end) +
            (if .tags and (.tags | length) > 0 then "  Tags: " + (.tags | map("\(.key)=\(.value)") | join(", ")) + "\n" else "" end) +
            "  Profile: \(.profile)\n"
        '
    done
fi
