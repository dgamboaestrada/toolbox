#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOMAIN=""
CERTIFICATE_ARN=""
REGION="us-east-1"
ELB_ENDPOINT=""

# Help function
usage() {
    cat << EOF
Usage: $0 -d DOMAIN -a CERTIFICATE_ARN [-r REGION] [-e ELB_ENDPOINT]

Options:
  -d DOMAIN              Domain name to validate (e.g., api.example.com)
  -a CERTIFICATE_ARN     AWS ACM Certificate ARN
  -r REGION              AWS region (default: us-east-1)
  -e ELB_ENDPOINT        ELB endpoint (optional, default: uses domain)
  -h                     Show this help message

Example:
  $0 -d api.example.com -a "arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012"

EOF
    exit 1
}

# Parse arguments
while getopts "d:a:r:e:h" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        a) CERTIFICATE_ARN="$OPTARG" ;;
        r) REGION="$OPTARG" ;;
        e) ELB_ENDPOINT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [[ -z "$DOMAIN" || -z "$CERTIFICATE_ARN" ]]; then
    echo -e "${RED}Error: Domain (-d) and Certificate ARN (-a) are required${NC}"
    usage
fi

# Use domain as endpoint if not specified
ENDPOINT="${ELB_ENDPOINT:-$DOMAIN}"

echo -e "${BLUE}=== SSL Certificate Validation ===${NC}"
echo -e "${BLUE}Domain: ${GREEN}$DOMAIN${NC}"
echo -e "${BLUE}Endpoint: ${GREEN}$ENDPOINT${NC}"
echo -e "${BLUE}Region: ${GREEN}$REGION${NC}"
echo -e "${BLUE}Certificate ARN: ${GREEN}$CERTIFICATE_ARN${NC}"
echo ""

# Step 1: Get serial number from OpenSSL
echo -e "${YELLOW}[1/3] Fetching certificate from $ENDPOINT:443...${NC}"
OPENSSL_SERIAL=$(echo | openssl s_client -connect "$ENDPOINT:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -serial 2>/dev/null || echo "")

if [[ -z "$OPENSSL_SERIAL" ]]; then
    echo -e "${RED}✗ Failed to retrieve certificate from $ENDPOINT${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Certificate retrieved${NC}"
echo -e "  Serial: ${YELLOW}$OPENSSL_SERIAL${NC}"

# Step 2: Get certificate details from AWS ACM
echo ""
echo -e "${YELLOW}[2/3] Fetching certificate details from AWS ACM...${NC}"

ACM_DATA=$(aws acm describe-certificate \
    --certificate-arn "$CERTIFICATE_ARN" \
    --region "$REGION" \
    --output json 2>/dev/null || echo "")

if [[ -z "$ACM_DATA" ]]; then
    echo -e "${RED}✗ Failed to retrieve certificate from AWS ACM${NC}"
    exit 1
fi

ACM_SERIAL=$(echo "$ACM_DATA" | jq -r '.Certificate.Serial // empty' 2>/dev/null || echo "")
ACM_DOMAIN=$(echo "$ACM_DATA" | jq -r '.Certificate.DomainName // empty' 2>/dev/null || echo "")
ACM_STATUS=$(echo "$ACM_DATA" | jq -r '.Certificate.Status // empty' 2>/dev/null || echo "")
ACM_NOT_BEFORE=$(echo "$ACM_DATA" | jq -r '.Certificate.NotBefore // empty' 2>/dev/null || echo "")
ACM_NOT_AFTER=$(echo "$ACM_DATA" | jq -r '.Certificate.NotAfter // empty' 2>/dev/null || echo "")
ACM_ISSUER=$(echo "$ACM_DATA" | jq -r '.Certificate.Issuer // empty' 2>/dev/null || echo "")

echo -e "${GREEN}✓ ACM certificate data retrieved${NC}"

# Step 3: Compare and validate
echo ""
echo -e "${YELLOW}[3/3] Validating certificate...${NC}"
echo ""

# Validation results
declare -i PASS=0
declare -i TOTAL=0

# Check 1: Serial Number match
# Normalize both serials: remove colons, remove "serial=" prefix, and convert to lowercase for comparison
ACM_SERIAL_NORMALIZED=$(echo "$ACM_SERIAL" | tr -d ':' | tr 'A-Z' 'a-z')
OPENSSL_SERIAL_NORMALIZED=$(echo "$OPENSSL_SERIAL" | sed 's/^serial=//' | tr 'A-Z' 'a-z')

if [[ "$ACM_SERIAL_NORMALIZED" == "$OPENSSL_SERIAL_NORMALIZED" ]]; then
    echo -e "${GREEN}✓ Serial Number matches${NC}"
    echo -e "  OpenSSL: ${YELLOW}$OPENSSL_SERIAL${NC}"
    echo -e "  ACM:     ${YELLOW}$ACM_SERIAL${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Serial Number mismatch${NC}"
    echo -e "  OpenSSL: ${YELLOW}$OPENSSL_SERIAL${NC}"
    echo -e "  ACM:     ${YELLOW}$ACM_SERIAL${NC}"
    echo -e "  OpenSSL (normalized): ${YELLOW}$OPENSSL_SERIAL_NORMALIZED${NC}"
    echo -e "  ACM (normalized):     ${YELLOW}$ACM_SERIAL_NORMALIZED${NC}"
fi
((TOTAL++))

# Check 2: Domain match
if [[ "$DOMAIN" == "$ACM_DOMAIN" ]]; then
    echo -e "${GREEN}✓ Domain name matches${NC}"
    echo -e "  Expected: ${YELLOW}$DOMAIN${NC}"
    echo -e "  ACM:      ${YELLOW}$ACM_DOMAIN${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Domain mismatch${NC}"
    echo -e "  Expected: ${YELLOW}$DOMAIN${NC}"
    echo -e "  ACM:      ${YELLOW}$ACM_DOMAIN${NC}"
fi
((TOTAL++))

# Check 3: Certificate Status
if [[ "$ACM_STATUS" == "ISSUED" ]]; then
    echo -e "${GREEN}✓ Certificate Status is ISSUED${NC}"
    echo -e "  Status: ${YELLOW}$ACM_STATUS${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Certificate Status is not ISSUED${NC}"
    echo -e "  Status: ${YELLOW}$ACM_STATUS${NC}"
fi
((TOTAL++))

# Check 4: Certificate Validity (Not Before)
if [[ -n "$ACM_NOT_BEFORE" ]]; then
    echo -e "${GREEN}✓ Certificate Valid From${NC}"
    echo -e "  Date: ${YELLOW}$ACM_NOT_BEFORE${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Could not retrieve NotBefore date${NC}"
fi
((TOTAL++))

# Check 5: Certificate Validity (Not After)
CURRENT_DATE=$(date +%s)
# Extract just the date part without timezone info and try different parsing methods
NOT_AFTER_DATE_CLEAN=$(echo "$ACM_NOT_AFTER" | sed 's/T.*//')
NOT_AFTER_DATE=$(date -d "$NOT_AFTER_DATE_CLEAN" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$NOT_AFTER_DATE_CLEAN" +%s 2>/dev/null || echo "0")

if [[ "$NOT_AFTER_DATE" -gt "$CURRENT_DATE" ]]; then
    echo -e "${GREEN}✓ Certificate is still valid${NC}"
    echo -e "  Expires: ${YELLOW}$ACM_NOT_AFTER${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Certificate has expired or invalid date parsing${NC}"
    echo -e "  Expires: ${YELLOW}$ACM_NOT_AFTER${NC}"
    echo -e "  Current: ${YELLOW}$(date)${NC}"
fi
((TOTAL++))

# Summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Issuer: ${YELLOW}$ACM_ISSUER${NC}"
echo ""

if [[ $PASS -eq $TOTAL ]]; then
    echo -e "${GREEN}✓ All validations passed ($PASS/$TOTAL)${NC}"
    exit 0
else
    echo -e "${RED}✗ Some validations failed ($PASS/$TOTAL)${NC}"
    exit 1
fi
