#!/bin/bash
# Description: Find Route53 hosted zones by domain name
# Author: Daniel Gamboa (converted from aws-resource-finder)
# Usage: ./route53-zones.sh <domain-name> [OPTIONS]

set -euo pipefail

show_help() {
    cat << EOF
Usage: $(basename "$0") <domain-name> [OPTIONS]

Description:
    Finds Route53 hosted zones by domain name across one or more AWS profiles.

Required Arguments:
    <domain-name>               Domain name to search (e.g., example.com)

Optional Arguments:
    --profile=PROFILE           AWS CLI profile(s), comma-separated (default: default)
    --region=REGION             AWS region (default: us-east-1)
    --output=FORMAT             Output format: text|json|yaml (default: text)
    --verbose                   Enable verbose output

Examples:
    # Search for hosted zone
    $(basename "$0") example.com

    # Search across multiple profiles
    $(basename "$0") example.com --profile=prod,qa

    # Output as JSON
    $(basename "$0") example.com --output=json

EOF
    exit 0
}

# Defaults
DOMAIN=""
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
            if [ -z "$DOMAIN" ]; then
                DOMAIN="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo "Error: domain-name is required"
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

# Ensure domain ends with a dot for Route53
DOMAIN_WITH_DOT="${DOMAIN%.}."\n"

# Function to query zones in a profile
query_profile() {
    local profile=$1
    local region=$2

    local aws_opts="--profile $profile --region $region"

    # Search for hosted zones by name
    local zones=$(aws route53 list-hosted-zones-by-name $aws_opts \
        --dns-name "$DOMAIN_WITH_DOT" \
        --query "HostedZones[?Name=='$DOMAIN_WITH_DOT']" \
        --output json 2>/dev/null || echo "[]")

    if [ "$(echo "$zones" | jq 'length')" -gt 0 ]; then
        echo "$zones" | jq --arg profile "$profile" '.[] |
            {
                profile: $profile,
                id: .Id,
                name: .Name,
                private_zone: .Config.PrivateZone,
                resource_record_set_count: .ResourceRecordSetCount
            }
        '
    fi
}

# Process each profile and collect results
declare -a all_zones
for prof in ${PROFILE//,/ }; do
    prof=$(echo "$prof" | xargs)  # trim whitespace
    if [ "$VERBOSE" = true ]; then
        echo "Querying profile: $prof" >&2
    fi
    while read -r zone; do
        [ -n "$zone" ] && all_zones+=("$zone")
    done < <(query_profile "$prof" "$REGION")
done

# Output
if [ ${#all_zones[@]} -eq 0 ]; then
    echo "No hosted zones found for $DOMAIN" >&2
    exit 1
fi

if [ "$OUTPUT" = "json" ]; then
    echo "["
    first=true
    for zone in "${all_zones[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "$zone"
    done
    echo ""
    echo "]"
elif [ "$OUTPUT" = "yaml" ]; then
    echo "zones:"
    for zone in "${all_zones[@]}"; do
        echo "$zone" | jq '.' | sed 's/^/  /'
    done
else
    # text output
    for zone in "${all_zones[@]}"; do
        echo "$zone" | jq -r '
            "Zone: \(.name) (id: \(.id))\n" +
            "  Private: \(.private_zone), Records: \(.resource_record_set_count)\n" +
            "  Profile: \(.profile)\n"
        '
    done
fi
