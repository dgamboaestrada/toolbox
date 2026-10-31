#!/bin/bash
# Description: Find ACM certificates by domain, SAN, or serial number
# Author: Daniel Gamboa (converted from aws-resource-finder)
# Usage: ./acm-certificates.sh [OPTIONS]

set -euo pipefail

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Description:
    Finds ACM certificates by domain name, Subject Alternative Names (SANs),
    or serial number across one or more AWS profiles and regions.

Optional Arguments (at least one required):
    --domain=DOMAIN             Certificate common name (exact domain match)
    --san-contains=TEXT         Substring to search within Subject Alternative Names
    --serial=SERIAL             Certificate serial number (hex format)
    --profile=PROFILE           AWS CLI profile(s), comma-separated (default: default)
    --region=REGION             AWS region (default: us-east-1)
    --output=FORMAT             Output format: text|json|yaml (default: text)
    --verbose                   Enable verbose output

Examples:
    # Search by domain
    $(basename "$0") --domain=example.com

    # Search by SAN substring
    $(basename "$0") --san-contains=example.com

    # Search by serial number
    $(basename "$0") --serial=a1b2c3d4e5f6

    # Search across multiple profiles
    $(basename "$0") --domain=example.com --profile=prod,qa

    # Output as JSON
    $(basename "$0") --domain=example.com --output=json

    # Combine filters (AND logic)
    $(basename "$0") --domain=example.com --san-contains=www

EOF
    exit 0
}

# Defaults
DOMAIN=""
SAN_CONTAINS=""
SERIAL=""
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
        --domain=*)
            DOMAIN="${1#*=}"
            shift
            ;;
        --san-contains=*)
            SAN_CONTAINS="${1#*=}"
            shift
            ;;
        --serial=*)
            SERIAL="${1#*=}"
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
            echo "Error: Unknown argument '$1'"
            exit 1
            ;;
    esac
done

# Validate: at least one filter required
if [ -z "$DOMAIN" ] && [ -z "$SAN_CONTAINS" ] && [ -z "$SERIAL" ]; then
    echo "Error: At least one of --domain, --san-contains, or --serial is required"
    echo ""
    show_help
fi

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

# Function to query certificates in a profile
query_profile() {
    local profile=$1
    local region=$2

    local aws_opts="--profile $profile --region $region"

    # List all certificates
    local cert_arns=$(aws acm list-certificates $aws_opts \
        --query "CertificateSummaryList[].CertificateArn" \
        --output text 2>/dev/null || echo "")

    if [ -z "$cert_arns" ]; then
        return 0
    fi

    # Search each certificate for matches
    while read -r arn; do
        [ -z "$arn" ] && continue

        local cert=$(aws acm describe-certificate $aws_opts \
            --certificate-arn "$arn" \
            --query "Certificate" \
            --output json 2>/dev/null || echo "null")

        if [ "$cert" = "null" ]; then
            continue
        fi

        # Check filters
        local domain_match=false
        local san_match=false
        local serial_match=false

        # Domain filter
        if [ -n "$DOMAIN" ]; then
            local cert_domain=$(echo "$cert" | jq -r '.DomainName // ""')
            if [ "$cert_domain" = "$DOMAIN" ]; then
                domain_match=true
            fi
        else
            domain_match=true  # No filter = match
        fi

        # SAN filter
        if [ -n "$SAN_CONTAINS" ]; then
            local san_match_result=$(echo "$cert" | jq --arg san "$SAN_CONTAINS" \
                '(.SubjectAlternativeNames // [] | map(. | contains($san)) | any)')
            if [ "$san_match_result" = "true" ]; then
                san_match=true
            fi
        else
            san_match=true  # No filter = match
        fi

        # Serial filter
        if [ -n "$SERIAL" ]; then
            local cert_serial=$(echo "$cert" | jq -r '.Serial // "" | ascii_downcase')
            local search_serial=$(echo "$SERIAL" | tr '[:upper:]' '[:lower:]')
            if [ "$cert_serial" = "$search_serial" ]; then
                serial_match=true
            fi
        else
            serial_match=true  # No filter = match
        fi

        # All filters must match (AND logic)
        if [ "$domain_match" = true ] && [ "$san_match" = true ] && [ "$serial_match" = true ]; then
            echo "$cert" | jq --arg profile "$profile" '
                {
                    profile: $profile,
                    arn: .CertificateArn,
                    domain_name: .DomainName,
                    status: .Status,
                    type: .Type,
                    serial: .Serial,
                    not_before: .NotBefore,
                    not_after: .NotAfter,
                    issuer: .Issuer,
                    sans: (.SubjectAlternativeNames // []),
                    in_use_by: (.InUseBy // []),
                    renewal_eligibility: .RenewalEligibility
                }
            '
        fi
    done <<< "$cert_arns"
}

# Process each profile and collect results
declare -a all_certs
for prof in ${PROFILE//,/ }; do
    prof=$(echo "$prof" | xargs)  # trim whitespace
    if [ "$VERBOSE" = true ]; then
        echo "Querying profile: $prof" >&2
    fi
    while read -r cert; do
        [ -n "$cert" ] && all_certs+=("$cert")
    done < <(query_profile "$prof" "$REGION")
done

# Output
if [ ${#all_certs[@]} -eq 0 ]; then
    filters="domain=$DOMAIN san=$SAN_CONTAINS serial=$SERIAL"
    echo "No certificates found matching: $filters" >&2
    exit 1
fi

if [ "$OUTPUT" = "json" ]; then
    echo "["
    first=true
    for cert in "${all_certs[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "$cert"
    done
    echo ""
    echo "]"
elif [ "$OUTPUT" = "yaml" ]; then
    echo "certificates:"
    for cert in "${all_certs[@]}"; do
        echo "$cert" | jq '.' | sed 's/^/  /'
    done
else
    # text output
    for cert in "${all_certs[@]}"; do
        echo "$cert" | jq -r '
            "Certificate: \(.domain_name)\n" +
            "  ARN: \(.arn)\n" +
            "  Status: \(.status), Type: \(.type)\n" +
            "  Valid: \(.not_before) to \(.not_after)\n" +
            "  Serial: \(.serial)\n" +
            (if .sans and (.sans | length) > 0 then "  SANs: " + (.sans | join(", ")) + "\n" else "" end) +
            (if .in_use_by and (.in_use_by | length) > 0 then "  In Use By: " + (.in_use_by | length | tostring) + " resource(s)\n" else "" end) +
            "  Renewal: \(.renewal_eligibility)\n" +
            "  Profile: \(.profile)\n"
        '
    done
fi
