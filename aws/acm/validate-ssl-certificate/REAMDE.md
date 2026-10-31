# SSL Certificate Validation Script

Automated script to validate SSL certificates on AWS ELB and ACM using `openssl s_client`.

## Features

- ✅ Retrieves SSL certificate from endpoint (ELB, domain, etc.)
- ✅ Compares with certificate registered in AWS ACM
- ✅ Validates Serial Number, Domain Name, Status, and Expiration Dates
- ✅ Colored output for easy reading
- ✅ Robust error handling

## Requirements

- `bash` 4.0+
- `openssl`
- `aws cli` v2
- `jq`
- AWS credentials configured

## Installation

```bash
chmod +x validate-ssl-certificate.sh
```

## Usage

### Basic Syntax

```bash
./validate-ssl-certificate.sh -d DOMAIN -a CERTIFICATE_ARN [-r REGION] [-e ELB_ENDPOINT]
```

### Options

| Option              | Required | Description                                      |
| ------------------- | -------- | ------------------------------------------------ |
| `-d DOMAIN`         | Yes      | Domain to validate (e.g., api.example.com)       |
| `-a CERTIFICATE_ARN` | Yes     | Full AWS ACM certificate ARN                     |
| `-r REGION`         | No       | AWS region (default: us-east-1)                  |
| `-e ELB_ENDPOINT`   | No       | ELB endpoint (default: uses domain)              |
| `-h`                | No       | Show help message                                |

### Examples

#### 1. Simple domain validation

```bash
./validate-ssl-certificate.sh \
  -d api.example.com \
  -a "arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012"
```

#### 2. Validation using ELB endpoint

```bash
./validate-ssl-certificate.sh \
  -d api.example.com \
  -a "arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012" \
  -e "elb-xxxxx.us-east-1.elb.amazonaws.com"
```

#### 3. Validation in another region

```bash
./validate-ssl-certificate.sh \
  -d web.example.com \
  -a "arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012" \
  -r us-east-1
```

## Example Output

```
=== SSL Certificate Validation ===
Domain: api.example.com
Endpoint: api.example.com
Region: us-east-1
Certificate ARN: arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012

[1/3] Fetching certificate from api.example.com:443...
✓ Certificate retrieved
  Serial: 01BBBBBBBBBBBBBBBBBBBBBBBBBBBB

[2/3] Fetching certificate details from AWS ACM...
✓ ACM certificate data retrieved

[3/3] Validating certificate...

✓ Serial Number matches
  OpenSSL: 01BBBBBBBBBBBBBBBBBBBBBBBBBBBB
  ACM:     01:bb:bb:bb:bb:bb:bb:bb:bb:bb:bb:bb:bb:bb:bb:bb
✓ Domain name matches
  Expected: api.example.com
  ACM:      api.example.com
✓ Certificate Status is ISSUED
  Status: ISSUED
✓ Certificate Valid From
  Date: 2025-01-15T00:00:00Z
✓ Certificate is still valid
  Expires: 2026-01-15T23:59:59Z

=== Summary ===
Issuer: Amazon

✓ All validations passed (5/5)
```

## Validations Performed

1. **Serial Number**: Verifies that the certificate serial number in use matches the one registered in ACM
2. **Domain Name**: Validates that the expected domain matches the certificate
3. **Certificate Status**: Checks that the status is `ISSUED`
4. **Valid From**: Shows the date from which the certificate is valid
5. **Valid Until**: Verifies that the certificate has not expired

## Exit Codes

| Code | Meaning                          |
| ---- | -------------------------------- |
| 0    | All validations passed           |
| 1    | One or more validations failed   |

## Use Cases

### Post-deployment Validation

```bash
# Validate certificate after infrastructure changes
./validate-ssl-certificate.sh \
  -d api.example.com \
  -a "arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012"
```

### In a CI/CD Pipeline

```bash
#!/bin/bash

# Validate certificate after applying Terraform
if ./validate-ssl-certificate.sh \
  -d api.example.com \
  -a "$CERTIFICATE_ARN"; then
  echo "✓ Certificate validation successful"
  exit 0
else
  echo "✗ Certificate validation failed"
  exit 1
fi
```

## Troubleshooting

### Error: "Failed to retrieve certificate"

**Cause**: The endpoint is not accessible or is using a different port

**Solution**: Use `-e` to specify the correct ELB endpoint

```bash
./validate-ssl-certificate.sh \
  -d api.example.com \
  -a "arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012" \
  -e "elb-xxxxx.us-east-1.elb.amazonaws.com"
```

### Error: "Failed to retrieve certificate from AWS ACM"

**Cause**: The ARN is incorrect or AWS credentials do not have permissions

**Solution**: Verify the ARN and permissions

```bash
aws acm describe-certificate --certificate-arn "arn:aws:acm:us-east-1:111111111111:certificate/12345678-1234-1234-1234-123456789012" --region us-east-1
```

### Error: "jq: command not found"

**Cause**: jq is not installed

**Solution**: Install jq

```bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq

# Linux (RHEL/CentOS)
sudo yum install jq
```
