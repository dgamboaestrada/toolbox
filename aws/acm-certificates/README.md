# ACM Certificates Search

Script to find AWS Certificate Manager (ACM) certificates by domain name, Subject Alternative Names (SANs), or serial number, across multiple AWS profiles and regions.

## Available Scripts

### `acm-certificates.sh`

Find ACM certificates by domain, SAN substring, or serial number with detailed certificate information.

**Features:**
- Search by certificate domain name (exact match)
- Search by SAN substring
- Search by certificate serial number (hex)
- Combine filters with AND logic (all must match)
- Display certificate status, validity dates, issuers
- Show in-use count and renewal eligibility
- Query across multiple AWS profiles
- Multiple output formats: text, JSON, YAML

**Usage:**
```bash
./acm-certificates.sh [OPTIONS]
```

**Arguments (at least one required):**

| Flag | Required | Description |
|------|----------|-------------|
| `--domain=DOMAIN` | One required | Certificate common name (exact domain match) |
| `--san-contains=TEXT` | One required | Substring to search in SANs |
| `--serial=SERIAL` | One required | Certificate serial number (hex format) |
| `--profile=PROFILE` | No | AWS profiles (comma-separated, default: `default`) |
| `--region=REGION` | No | AWS region (default: `us-east-1`) |
| `--output=FORMAT` | No | Output format: `text` (default), `json`, or `yaml` |
| `--verbose` | No | Enable verbose/debug output |

**Examples:**
```bash
# Search by domain
./acm-certificates.sh --domain=example.com

# Search by SAN substring
./acm-certificates.sh --san-contains=api.example.com

# Search by serial number
./acm-certificates.sh --serial=a1b2c3d4e5f6

# Search across multiple profiles
./acm-certificates.sh --domain=example.com --profile=prod,qa

# Combine filters (AND logic - both must match)
./acm-certificates.sh --domain=example.com --san-contains=www

# Output as JSON
./acm-certificates.sh --domain=example.com --output=json

# Verbose output
./acm-certificates.sh --domain=example.com --verbose
```

**Output example (text format):**
```
Certificate: example.com
  ARN: arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
  Status: ISSUED, Type: AMAZON_ISSUED
  Valid: 2024-01-15 00:00:00+00:00 to 2025-01-15 00:00:00+00:00
  Serial: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4
  SANs: example.com, www.example.com, api.example.com
  In Use By: 2 resource(s)
  Renewal: INELIGIBLE
  Profile: prod
```

## Certificate Status Values

- `PENDING_VALIDATION` - Awaiting validation
- `ISSUED` - Successfully issued and active
- `INACTIVE` - Exists but not in use
- `EXPIRED` - Certificate has expired
- `VALIDATION_TIMED_OUT` - Validation process timed out
- `REVOKED` - Certificate has been revoked
- `FAILED` - Certificate request failed

## Prerequisites

1. **AWS CLI installed and configured:**
   ```bash
   aws configure
   ```

2. **Required IAM permissions:**
   - `acm:ListCertificates`
   - `acm:DescribeCertificate`

3. **Required tools:**
   - `jq` for JSON parsing

## Installation

### macOS (with Homebrew):
```bash
brew install awscli jq
```

### Ubuntu/Debian:
```bash
sudo apt update && sudo apt install awscli jq
```

### CentOS/RHEL:
```bash
sudo yum install awscli jq
```

## Multi-Profile Queries

Search across multiple AWS profiles with comma-separated values:

```bash
# Search across prod, qa, and dev simultaneously
./acm-certificates.sh --domain=example.com --profile=prod,qa,dev
```

## Output Formats

### Text (default)
Human-readable format with certificate details.

### JSON
Machine-readable format suitable for scripting and automation:
```bash
./acm-certificates.sh --domain=example.com --output=json
```

### YAML
YAML format output:
```bash
./acm-certificates.sh --domain=example.com --output=yaml
```

## Search Logic

### Single Filter
If only one filter is specified, all certificates matching that filter are returned:
```bash
# Returns all certificates with domain example.com
./acm-certificates.sh --domain=example.com
```

### Multiple Filters
When multiple filters are specified, they are combined with AND logic (all must match):
```bash
# Returns only certificates with domain example.com 
# AND containing "api" in SANs
./acm-certificates.sh --domain=example.com --san-contains=api
```

## Troubleshooting

### Error: "AWS CLI is not installed"
```bash
brew install awscli  # macOS
# or
sudo apt install awscli  # Ubuntu/Debian
```

### Error: "jq: command not found"
```bash
brew install jq  # macOS
# or
sudo apt install jq  # Ubuntu/Debian
```

### Error: "Cannot verify credentials"
```bash
aws sts get-caller-identity
aws configure
```

### Error: "Access Denied"
Verify your IAM user/role has these permissions:
- `acm:ListCertificates`
- `acm:DescribeCertificate`

### Error: "At least one filter is required"
Specify at least one of:
- `--domain=DOMAIN`
- `--san-contains=TEXT`
- `--serial=SERIAL`

### No certificates found
- Verify the domain/SAN/serial spelling is correct
- Confirm the certificate exists in ACM
- Check you are querying the correct profile/region
- Use `aws acm list-certificates` to see available certificates

## Common Use Cases

### Find all certificates for a domain
```bash
./acm-certificates.sh --domain=example.com
```

### Check if a certificate is in use
```bash
./acm-certificates.sh --domain=example.com --output=json | jq '.[] | {domain_name, in_use_by}'
```

### Find certificates expiring soon
```bash
./acm-certificates.sh --domain=example.com --output=json | jq '.[] | {domain_name, not_after}'
```

### Find wildcard certificates
```bash
./acm-certificates.sh --san-contains=example.com
```

### Verify certificate across environments
```bash
./acm-certificates.sh --domain=example.com --profile=prod,staging,qa
```

### Export certificate details for compliance
```bash
./acm-certificates.sh --domain=example.com --output=json > cert-details.json
```

## Exit Codes

- `0` - Success; certificate(s) found
- `1` - No certificates found or error occurred
