# ACM List by Domain

Script to search and list AWS ACM certificates filtered by main domain and/or additional domains (Subject Alternative Names).

## Available Scripts

### `acm-list-by-domain.sh`

Lists all ACM certificates that match a given domain. Supports wildcard matching and filtering by multiple SANs, certificate status, region, and AWS profile.

**Features:**
- Filters by main domain (exact match or wildcard)
- Filters by one or more additional domains (SANs) — all must be present
- Supports wildcard certificates (`*.example.com`)
- Optional filter by certificate status
- Displays ARN, status, type, issue date, expiry date, in-use count, and full SAN list
- Verifies AWS credentials before execution

**Usage:**
```bash
./acm-list-by-domain.sh --domain=DOMAIN [OPTIONS]
```

**Arguments:**

| Flag | Required | Description |
|------|----------|-------------|
| `--domain=DOMAIN` | Yes | Main domain to search (e.g. `example.com`) |
| `--additional=DOMAIN` | No | SAN to match — repeat for multiple |
| `--status=STATUS` | No | Filter by certificate status (see below) |
| `--region=REGION` | No | AWS region (default: configured region) |
| `--profile=PROFILE` | No | AWS CLI profile to use |

**Valid status values:**
`PENDING_VALIDATION`, `ISSUED`, `INACTIVE`, `EXPIRED`, `VALIDATION_TIMED_OUT`, `REVOKED`, `FAILED`

**Examples:**
```bash
# Search by main domain only
./acm-list-by-domain.sh --domain=example.com

# Search by main domain and one SAN
./acm-list-by-domain.sh --domain=example.com --additional=www.example.com

# Search by main domain and multiple SANs
./acm-list-by-domain.sh --domain=example.com \
  --additional=www.example.com \
  --additional=api.example.com

# Filter only issued certificates in a specific region
./acm-list-by-domain.sh --domain=example.com --status=ISSUED --region=us-east-1

# Use a specific AWS profile
./acm-list-by-domain.sh --domain=example.com --profile=my-profile
```

**Output example:**
```
================================================
ACM CERTIFICATE SEARCH
================================================
Main domain:     example.com
Additional SANs: www.example.com
Status filter:   ISSUED
================================================

Fetching certificates...

Certificate #1
  ARN:        arn:aws:acm:us-east-1:123456789012:certificate/abc123
  Domain:     example.com
  Status:     ISSUED
  Type:       AMAZON_ISSUED
  Issued:     2024-01-15T10:00:00Z
  Expires:    2025-01-15T10:00:00Z
  In use by:  2 resource(s)
  SANs:
    - example.com
    - www.example.com
    - api.example.com

================================================
SUMMARY
================================================
Certificates scanned: 42
Certificates matched: 1
================================================
```

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

## Troubleshooting

### Error: "Cannot connect to AWS ACM"
```bash
# Verify credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

### Error: "jq: command not found"
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

### Error: "Access Denied"
Ensure your IAM user/role has the following permissions:
- `acm:ListCertificates`
- `acm:DescribeCertificate`

### No certificates returned
- Verify the domain spelling matches exactly what is stored in ACM
- Try without `--additional` to confirm the main domain exists
- Check you are querying the correct region (`--region`)

## Notes

- The script scans up to 1000 certificates per run. For accounts with more certificates, pagination support may need to be added using `--starting-token`.
- Wildcard certificates (`*.example.com`) are matched against both `*.DOMAIN` and `DOMAIN` inputs.
- The script exits with code `0` if at least one certificate matched, `1` otherwise — useful for scripting and CI/CD pipelines.
