#!/bin/bash
# Description: List AWS ACM certificates filtered by main domain and/or additional domains (SANs)
# Author: Daniel Gamboa
# Usage: ./acm-list-by-domain.sh --domain=example.com [OPTIONS]

show_help() {
    cat << EOF
Usage: $(basename "$0") --domain=DOMAIN [OPTIONS]

Description:
    Lists AWS ACM certificates that match a main domain and/or additional
    domains (Subject Alternative Names). All provided domains must be present
    in the certificate for it to be included in the results.

Required Arguments:
    --domain=DOMAIN             Main domain to search (e.g. example.com)

Optional Arguments:
    --additional=DOMAIN         Additional domain (SAN) to match. Can be
                                specified multiple times for multiple SANs.
    --region=REGION             AWS region (default: current configured region)
    --profile=PROFILE           AWS CLI profile to use
    --status=STATUS             Filter by certificate status. Options:
                                PENDING_VALIDATION, ISSUED, INACTIVE, EXPIRED,
                                VALIDATION_TIMED_OUT, REVOKED, FAILED
                                (default: all statuses)

Other Options:
    -h, --help                  Show this help message and exit

Examples:
    # Search by main domain only
    $(basename "$0") --domain=example.com

    # Search by main domain and one SAN
    $(basename "$0") --domain=example.com --additional=www.example.com

    # Search by main domain and multiple SANs
    $(basename "$0") --domain=example.com --additional=www.example.com --additional=api.example.com

    # Filter only issued certificates in a specific region
    $(basename "$0") --domain=example.com --status=ISSUED --region=us-east-1

    # Use a specific AWS profile
    $(basename "$0") --domain=example.com --profile=my-profile

EOF
    exit 0
}

# Default values
DOMAIN=""
ADDITIONAL_DOMAINS=()
REGION=""
PROFILE=""
STATUS_FILTER=""

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --domain=*)
            DOMAIN="${arg#*=}"
            ;;
        --additional=*)
            ADDITIONAL_DOMAINS+=("${arg#*=}")
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
if [ -z "$DOMAIN" ]; then
    echo "Error: --domain is required"
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
echo "ACM CERTIFICATE SEARCH"
echo "================================================"
echo "Main domain:    $DOMAIN"
if [ ${#ADDITIONAL_DOMAINS[@]} -gt 0 ]; then
    echo "Additional SANs: ${ADDITIONAL_DOMAINS[*]}"
fi
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
matched=0

while IFS= read -r arn; do
    [ -z "$arn" ] && continue
    total=$((total + 1))

    # Get full certificate details
    cert_json=$($AWS_CMD describe-certificate --certificate-arn "$arn" --query 'Certificate' --output json 2>/dev/null)
    [ $? -ne 0 ] && continue

    cert_domain=$(echo "$cert_json"    | jq -r '.DomainName // ""')
    cert_sans=$(echo "$cert_json"      | jq -r '.SubjectAlternativeNames[]? // empty')
    cert_status=$(echo "$cert_json"    | jq -r '.Status // "UNKNOWN"')
    cert_type=$(echo "$cert_json"      | jq -r '.Type // "UNKNOWN"')
    cert_expiry=$(echo "$cert_json"    | jq -r '.NotAfter // "N/A"')
    cert_issued=$(echo "$cert_json"    | jq -r '.IssuedAt // "N/A"')
    cert_in_use=$(echo "$cert_json"    | jq -r '[.InUseBy[]?] | length')

    # Build full list of domains on the certificate (domain + SANs, deduplicated)
    all_cert_domains=$(printf '%s\n%s' "$cert_domain" "$cert_sans" | sort -u | grep -v '^$')

    # Check main domain match (exact or wildcard)
    domain_match=false
    while IFS= read -r d; do
        if [ "$d" = "$DOMAIN" ] || [ "$d" = "*.$DOMAIN" ]; then
            domain_match=true
            break
        fi
        # Wildcard on the certificate side: *.example.com matches www.example.com
        if [[ "$d" == \** ]]; then
            wildcard_base="${d#\*.}"
            # DOMAIN matches *.wildcard_base if DOMAIN ends with .wildcard_base
            if [[ "$DOMAIN" == *".$wildcard_base" ]] || [ "$DOMAIN" = "$wildcard_base" ]; then
                domain_match=true
                break
            fi
        fi
    done <<< "$all_cert_domains"

    [ "$domain_match" = false ] && continue

    # Check additional domains (all must match)
    all_sans_match=true
    for san in "${ADDITIONAL_DOMAINS[@]}"; do
        san_found=false
        while IFS= read -r d; do
            if [ "$d" = "$san" ] || [ "$d" = "*.$san" ]; then
                san_found=true
                break
            fi
            if [[ "$d" == \** ]]; then
                wildcard_base="${d#\*.}"
                if [[ "$san" == *".$wildcard_base" ]] || [ "$san" = "$wildcard_base" ]; then
                    san_found=true
                    break
                fi
            fi
        done <<< "$all_cert_domains"

        if [ "$san_found" = false ]; then
            all_sans_match=false
            break
        fi
    done

    [ "$all_sans_match" = false ] && continue

    # Certificate matched — print details
    matched=$((matched + 1))

    echo "Certificate #$matched"
    echo "  ARN:        $arn"
    echo "  Domain:     $cert_domain"
    echo "  Status:     $cert_status"
    echo "  Type:       $cert_type"
    echo "  Issued:     $cert_issued"
    echo "  Expires:    $cert_expiry"
    echo "  In use by:  $cert_in_use resource(s)"
    echo "  SANs:"
    while IFS= read -r san; do
        echo "    - $san"
    done <<< "$cert_sans"
    echo ""

done <<< "$cert_arns"

echo "================================================"
echo "SUMMARY"
echo "================================================"
echo "Certificates scanned: $total"
echo "Certificates matched: $matched"
echo "================================================"

[ $matched -eq 0 ] && exit 1
exit 0
