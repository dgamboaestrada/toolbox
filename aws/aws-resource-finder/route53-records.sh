#!/bin/bash
# Description: Find Route53 records by name
# Author: Daniel Gamboa (converted from aws-resource-finder)
# Usage: ./route53-records.sh <record-name> [OPTIONS]

set -euo pipefail

show_help() {
    cat << EOF
Usage: $(basename "$0") <record-name> [OPTIONS]

Description:
    Finds Route53 records by name. Searches across all zones unless --zone-name
    is specified to limit the search to a specific hosted zone.

Required Arguments:
    <record-name>               Record name to search (e.g., api.example.com)

Optional Arguments:
    --zone-name=ZONE            Hosted zone name to limit search (e.g., example.com)
    --profile=PROFILE           AWS CLI profile(s), comma-separated (default: default)
    --region=REGION             AWS region (default: us-east-1)
    --output=FORMAT             Output format: text|json|yaml (default: text)
    --verbose                   Enable verbose output

Examples:
    # Search for record across all zones
    $(basename "$0") api.example.com

    # Search within specific zone
    $(basename "$0") api.example.com --zone-name=example.com

    # Search across multiple profiles
    $(basename "$0") api.example.com --profile=prod,qa

    # Output as JSON
    $(basename "$0") api.example.com --output=json

EOF
    exit 0
}

# Defaults
RECORD_NAME=""
ZONE_NAME=""
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
        --zone-name=*)
            ZONE_NAME="${1#*=}"
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
            if [ -z "$RECORD_NAME" ]; then
                RECORD_NAME="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$RECORD_NAME" ]; then
    echo "Error: record-name is required"
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

# Ensure names end with a dot for Route53
RECORD_NAME_DOT="${RECORD_NAME%.}."
ZONE_NAME_DOT="${ZONE_NAME%.}." 2>/dev/null || true

# Function to query records in a profile
query_profile() {
    local profile=$1
    local region=$2

    local aws_opts="--profile $profile --region $region"

    # Get hosted zones
    local zones
    if [ -n "$ZONE_NAME" ]; then
        zones=$(aws route53 list-hosted-zones-by-name $aws_opts \
            --dns-name "$ZONE_NAME_DOT" \
            --query "HostedZones[?Name=='$ZONE_NAME_DOT'].Id" \
            --output text 2>/dev/null || echo "")
    else
        zones=$(aws route53 list-hosted-zones $aws_opts \
            --query "HostedZones[].Id" \
            --output text 2>/dev/null || echo "")
    fi

    if [ -z "$zones" ]; then
        return 0
    fi

    # Search each zone for records
    while read -r zone_id; do
        [ -z "$zone_id" ] && continue

        if [ "$VERBOSE" = true ]; then
            echo "Searching zone: $zone_id" >&2
        fi

        # Get zone details
        local zone_info=$(aws route53 get-hosted-zone $aws_opts \
            --id "$zone_id" \
            --query "HostedZone" \
            --output json 2>/dev/null)

        # List records in zone and search for matches
        local records=$(aws route53 list-resource-record-sets $aws_opts \
            --hosted-zone-id "$zone_id" \
            --query "ResourceRecordSets[?Name=='$RECORD_NAME_DOT']" \
            --output json 2>/dev/null || echo "[]")

        if [ "$(echo "$records" | jq 'length')" -gt 0 ]; then
            echo "$records" | jq --arg profile "$profile" --argjson zone_info "$zone_info" '.[] |
                {
                    profile: $profile,
                    zone_id: $zone_info.Id,
                    zone_name: $zone_info.Name,
                    private_zone: $zone_info.Config.PrivateZone,
                    name: .Name,
                    type: .Type,
                    ttl: .TTL,
                    values: (.ResourceRecords // [] | map(.Value)),
                    alias_target: .AliasTarget.DNSName
                }
            '
        fi
    done <<< "$zones"
}

# Process each profile and collect results
declare -a all_records
for prof in ${PROFILE//,/ }; do
    prof=$(echo "$prof" | xargs)  # trim whitespace
    if [ "$VERBOSE" = true ]; then
        echo "Querying profile: $prof" >&2
    fi
    while read -r record; do
        [ -n "$record" ] && all_records+=("$record")
    done < <(query_profile "$prof" "$REGION")
done

# Output
if [ ${#all_records[@]} -eq 0 ]; then
    echo "No records found for $RECORD_NAME" >&2
    exit 1
fi

if [ "$OUTPUT" = "json" ]; then
    echo "["
    first=true
    for record in "${all_records[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "$record"
    done
    echo ""
    echo "]"
elif [ "$OUTPUT" = "yaml" ]; then
    echo "records:"
    for record in "${all_records[@]}"; do
        echo "$record" | jq '.' | sed 's/^/  /'
    done
else
    # text output
    for record in "${all_records[@]}"; do
        echo "$record" | jq -r '
            "Record: \(.name) \(.type)\n" +
            "  TTL: \(.ttl), Zone: \(.zone_name) (\(.zone_id))\n" +
            (if .values and (.values | length) > 0 then "  Values: \(.values | join(", "))\n" else "" end) +
            (if .alias_target then "  Alias: \(.alias_target)\n" else "" end) +
            "  Profile: \(.profile), Private: \(.private_zone)\n"
        '
    done
fi
