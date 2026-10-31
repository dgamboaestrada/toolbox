#!/bin/bash
# Description: Search AWS ACM certificates by serial number
# Author: Daniel Gamboa
# Usage: ./acm-search-by-serial.sh --serial=XX:XX:... [OPTIONS]

show_help() {
    cat << EOF
Usage: $(basename "$0") --serial=SERIAL [OPTIONS]

Description:
    Searches AWS ACM certificates for one matching the given serial number.
    The serial can be provided with or without colons and is case-insensitive
    (e.g. "4f:19:a8:c2:d3:83:e5:b7:01:f4:9c:e2:11:06:b9:8e" or
    "4F19A8C2D383E5B701F49CE21106B98E").

Required Arguments:
    --serial=SERIAL              Certificate serial number to search for

Optional Arguments:
    --region=REGION               AWS region (default: current configured region)
    --profile=PROFILE             AWS CLI profile to use
    --status=STATUS                Filter by certificate status. Options:
                                   PENDING_VALIDATION, ISSUED, INACTIVE, EXPIRED,
                                   VALIDATION_TIMED_OUT, REVOKED, FAILED
                                   (default: all statuses)

Other Options:
    -h, --help                    Show this help message and exit

Examples:
    # Search by serial (with colons)
    $(basename "$0") --serial=4f:19:a8:c2:d3:83:e5:b7:01:f4:9c:e2:11:06:b9:8e

    # Search by serial (no colons, mixed case)
    $(basename "$0") --serial=4F19A8C2D383E5B701F49CE21106B98E

    # Search in a specific region/profile
    $(basename "$0") --serial=4F19A8C2D383E5B701F49CE21106B98E --region=us-west-2 --profile=my-profile

    # Restrict search to issued certificates only
    $(basename "$0") --serial=4F19A8C2D383E5B701F49CE21106B98E --status=ISSUED

EOF
    exit 0
}

# Default values
SERIAL=""
REGION=""
PROFILE=""
STATUS_FILTER=""

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --serial=*)
            SERIAL="${arg#*=}"
            ;;
        --region=*)
            REGION="${arg#*=}"
            ;;
        --profile=*)
            PROFILE="${arg#*=}"
            ;;
        --status=*)
            STATUS_FILTER="${arg#*=}"
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown argument '$arg'"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$SERIAL" ]; then
    echo "Error: --serial is required"
    echo ""
    show_help
fi

# Validate status filter
VALID_STATUSES=("PENDING_VALIDATION" "ISSUED" "INACTIVE" "EXPIRED" "VALIDATION_TIMED_OUT" "REVOKED" "FAILED")
if [ -n "$STATUS_FILTER" ]; then
    valid=false
    for s in "${VALID_STATUSES[@]}"; do
        if [ "$STATUS_FILTER" = "$s" ]; then
            valid=true
            break
        fi
    done
    if [ "$valid" = false ]; then
        echo "Error: Invalid status '$STATUS_FILTER'"
        echo "Valid statuses: ${VALID_STATUSES[*]}"
        exit 1
    fi
fi

# Check dependencies
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    echo "Install it with:"
    echo "  macOS:          brew install jq"
    echo "  Ubuntu/Debian:  sudo apt install jq"
    echo "  CentOS/RHEL:    sudo yum install jq"
    exit 1
fi

# Normalize target serial: strip colons, uppercase
TARGET_SERIAL=$(echo "$SERIAL" | tr -d ':' | tr '[:lower:]' '[:upper:]')

# Build base AWS CLI command
AWS_CMD="aws acm"
[ -n "$PROFILE" ] && AWS_CMD="$AWS_CMD --profile $PROFILE"
[ -n "$REGION" ]  && AWS_CMD="$AWS_CMD --region $REGION"

# Verify AWS credentials
if ! $AWS_CMD list-certificates --max-items 1 &> /dev/null; then
    echo "Error: Cannot connect to AWS ACM. Check your credentials and region."
    exit 1
fi

echo "================================================"
echo "ACM CERTIFICATE SEARCH BY SERIAL"
echo "================================================"
echo "Serial:         $SERIAL"
[ -n "$STATUS_FILTER" ] && echo "Status filter:  $STATUS_FILTER"
[ -n "$REGION" ]        && echo "Region:         $REGION"
[ -n "$PROFILE" ]       && echo "Profile:        $PROFILE"
echo "================================================"
echo ""

# List all certificates (paginated)
LIST_CMD="$AWS_CMD list-certificates --max-items 1000"
[ -n "$STATUS_FILTER" ] && LIST_CMD="$LIST_CMD --certificate-statuses $STATUS_FILTER"

echo "Fetching certificates..."
cert_arns=$($LIST_CMD --query 'CertificateSummaryList[].CertificateArn' --output text 2>/dev/null | tr '\t' '\n')

if [ -z "$cert_arns" ]; then
    echo "No certificates found."
    exit 0
fi

total=0
matched_arn=""
matched_json=""

while IFS= read -r arn; do
    [ -z "$arn" ] && continue
    total=$((total + 1))

    cert_json=$($AWS_CMD describe-certificate --certificate-arn "$arn" --query 'Certificate' --output json 2>/dev/null)
    [ $? -ne 0 ] && continue

    cert_serial_raw=$(echo "$cert_json" | jq -r '.Serial // ""')
    cert_serial_norm=$(echo "$cert_serial_raw" | tr -d ':' | tr '[:lower:]' '[:upper:]')

    if [ "$cert_serial_norm" = "$TARGET_SERIAL" ]; then
        matched_arn="$arn"
        matched_json="$cert_json"
        break
    fi
done <<< "$cert_arns"

echo "================================================"
echo "SUMMARY"
echo "================================================"
echo "Certificates scanned: $total"

if [ -z "$matched_arn" ]; then
    echo "Certificates matched: 0"
    echo "================================================"
    echo ""
    echo "No certificate found with serial: $SERIAL"
    exit 1
fi

echo "Certificates matched: 1"
echo "================================================"
echo ""

cert_domain=$(echo "$matched_json"   | jq -r '.DomainName // "N/A"')
cert_sans=$(echo "$matched_json"     | jq -r '.SubjectAlternativeNames[]? // empty')
cert_status=$(echo "$matched_json"   | jq -r '.Status // "UNKNOWN"')
cert_type=$(echo "$matched_json"     | jq -r '.Type // "UNKNOWN"')
cert_subject=$(echo "$matched_json"  | jq -r '.Subject // "N/A"')
cert_issuer=$(echo "$matched_json"   | jq -r '.Issuer // "N/A"')
cert_serial=$(echo "$matched_json"   | jq -r '.Serial // "N/A"')
cert_not_before=$(echo "$matched_json" | jq -r '.NotBefore // "N/A"')
cert_not_after=$(echo "$matched_json"  | jq -r '.NotAfter // "N/A"')
cert_key_algo=$(echo "$matched_json" | jq -r '.KeyAlgorithm // "N/A"')
cert_sig_algo=$(echo "$matched_json" | jq -r '.SignatureAlgorithm // "N/A"')
cert_renewal=$(echo "$matched_json"  | jq -r '.RenewalEligibility // "N/A"')
cert_in_use=$(echo "$matched_json"   | jq -r '[.InUseBy[]?] | length')

echo "Certificate found"
echo "  ARN:              $matched_arn"
echo "  Domain:            $cert_domain"
echo "  Serial:            $cert_serial"
echo "  Status:            $cert_status"
echo "  Type:              $cert_type"
echo "  Subject:           $cert_subject"
echo "  Issuer:            $cert_issuer"
echo "  Valid from:        $cert_not_before"
echo "  Valid until:       $cert_not_after"
echo "  Key algorithm:     $cert_key_algo"
echo "  Signature:         $cert_sig_algo"
echo "  Renewal eligible:  $cert_renewal"
echo "  In use by:         $cert_in_use resource(s)"
if [ -n "$cert_sans" ]; then
    echo "  SANs:"
    while IFS= read -r san; do
        echo "    - $san"
    done <<< "$cert_sans"
fi

exit 0
