# AWS Resource Finder Scripts

Bash equivalents of the [aws-resource-finder](https://github.com/dgamboaestrada/aws-resource-finder) Ruby CLI tool. These scripts find AWS resources (target groups, Route53 zones/records, network interfaces, volumes, and ACM certificates) across multiple AWS profiles and regions.

## Scripts

### 1. `target-groups-by-target.sh`
Find ELBv2 target groups containing a specific target (instance, IP, or Lambda function).

```bash
./target-groups-by-target.sh <target-id> [OPTIONS]

# Examples
./target-groups-by-target.sh 10.0.0.5
./target-groups-by-target.sh i-1234567890abcdef0 --type=instance --profile=prod
./target-groups-by-target.sh 10.0.0.5 --profile=prod,qa,dev --tags --output=json
```

**Options:**
- `--type=TYPE` - Target type: `ip` (default), `instance`, or `lambda`
- `--profile=PROFILE` - AWS profiles (comma-separated, default: `default`)
- `--region=REGION` - AWS region (default: `us-east-1`)
- `--tags` - Include target group tags in output
- `--output=FORMAT` - Output format: `text` (default), `json`, or `yaml`
- `--lb-arn=ARN` - Optional Load Balancer ARN to limit search
- `--verbose` - Enable verbose output

---

### 2. `route53-zones.sh`
Find Route53 hosted zones by domain name.

```bash
./route53-zones.sh <domain-name> [OPTIONS]

# Examples
./route53-zones.sh example.com
./route53-zones.sh example.com --profile=prod,qa
./route53-zones.sh example.com --output=json
```

**Options:**
- `--profile=PROFILE` - AWS profiles (comma-separated, default: `default`)
- `--region=REGION` - AWS region (default: `us-east-1`)
- `--output=FORMAT` - Output format: `text` (default), `json`, or `yaml`
- `--verbose` - Enable verbose output

---

### 3. `route53-records.sh`
Find Route53 records by name. Optionally limit search to a specific hosted zone.

```bash
./route53-records.sh <record-name> [OPTIONS]

# Examples
./route53-records.sh api.example.com
./route53-records.sh api.example.com --zone-name=example.com
./route53-records.sh api.example.com --profile=prod,qa --output=json
```

**Options:**
- `--zone-name=ZONE` - Hosted zone name to limit search
- `--profile=PROFILE` - AWS profiles (comma-separated, default: `default`)
- `--region=REGION` - AWS region (default: `us-east-1`)
- `--output=FORMAT` - Output format: `text` (default), `json`, or `yaml`
- `--verbose` - Enable verbose output

---

### 4. `network-interfaces.sh`
Find EC2 network interfaces by private or public IP address.

```bash
./network-interfaces.sh <ip-address> [OPTIONS]

# Examples
./network-interfaces.sh 10.0.1.50
./network-interfaces.sh 203.0.113.42
./network-interfaces.sh 10.0.1.50 --profile=prod,qa,dev --output=json
```

**Options:**
- `--profile=PROFILE` - AWS profiles (comma-separated, default: `default`)
- `--region=REGION` - AWS region (default: `us-east-1`)
- `--output=FORMAT` - Output format: `text` (default), `json`, or `yaml`
- `--verbose` - Enable verbose output

---

### 5. `volumes.sh`
Find EBS volumes by volume ID.

```bash
./volumes.sh <volume-id> [OPTIONS]

# Examples
./volumes.sh vol-1234567890abcdef0
./volumes.sh vol-1234567890abcdef0 --profile=prod,qa,dev
./volumes.sh vol-1234567890abcdef0 --region=eu-west-1 --output=json
```

**Options:**
- `--profile=PROFILE` - AWS profiles (comma-separated, default: `default`)
- `--region=REGION` - AWS region (default: `us-east-1`)
- `--output=FORMAT` - Output format: `text` (default), `json`, or `yaml`
- `--verbose` - Enable verbose output

---

### 6. `acm-certificates.sh`
Find ACM certificates by domain, Subject Alternative Names (SANs), or serial number.

```bash
./acm-certificates.sh [OPTIONS]

# Examples
./acm-certificates.sh --domain=example.com
./acm-certificates.sh --san-contains=api.example.com
./acm-certificates.sh --serial=a1b2c3d4e5f6
./acm-certificates.sh --domain=example.com --profile=prod,qa --output=json
```

**Options (at least one required):**
- `--domain=DOMAIN` - Certificate common name (exact match)
- `--san-contains=TEXT` - Substring to search in SANs
- `--serial=SERIAL` - Certificate serial number (hex)
- `--profile=PROFILE` - AWS profiles (comma-separated, default: `default`)
- `--region=REGION` - AWS region (default: `us-east-1`)
- `--output=FORMAT` - Output format: `text` (default), `json`, or `yaml`
- `--verbose` - Enable verbose output

---

## Global Options

All scripts support these options:

| Option | Description | Default |
|--------|-------------|---------|
| `--profile=PROFILE` | AWS CLI profile(s), comma-separated | `default` |
| `--region=REGION` | AWS region | `us-east-1` |
| `--output=FORMAT` | Output format: `text`, `json`, or `yaml` | `text` |
| `--verbose` | Enable verbose/debug output | Off |
| `-h, --help` | Show help message | - |

### Multi-Profile Queries

All scripts support searching across multiple AWS profiles with comma-separated values:

```bash
./target-groups-by-target.sh 10.0.0.5 --profile=prod,qa,dev
./volumes.sh vol-123456 --profile=prod,staging,dev
```

Output will show results from each profile, making it easy to find resources across environments.

---

## Output Formats

### Text (default)
Human-readable output with resource details on multiple lines.

```bash
./target-groups-by-target.sh 10.0.0.5
```

### JSON
Structured JSON output suitable for scripting and automation.

```bash
./target-groups-by-target.sh 10.0.0.5 --output=json
```

### YAML
YAML format output.

```bash
./target-groups-by-target.sh 10.0.0.5 --output=yaml
```

---

## Requirements

- **AWS CLI v2** - Must be installed and configured
- **jq** - JSON processor for parsing AWS API responses
- **bash 4+** - Shell environment

### Install Dependencies

**macOS:**
```bash
brew install awscli jq
```

**Ubuntu/Debian:**
```bash
sudo apt install awscli jq
```

**CentOS/RHEL:**
```bash
sudo yum install awscli jq
```

---

## AWS Credentials

Scripts use the standard AWS CLI credential chain:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. AWS credentials file (`~/.aws/credentials`)
3. AWS config file with SSO (`~/.aws/config`)
4. IAM instance profile (on EC2)

### Configure AWS CLI

```bash
aws configure --profile prod
aws configure sso --profile prod
```

---

## Common Use Cases

### Find which load balancer targets an IP
```bash
./target-groups-by-target.sh 10.0.1.50 --output=json
```

### Check if a certificate is in use across multiple regions
```bash
./acm-certificates.sh --domain=api.example.com --region=us-east-1
./acm-certificates.sh --domain=api.example.com --region=eu-west-1
```

### Find DNS records across all environments
```bash
./route53-records.sh api.example.com --profile=prod,qa,dev
```

### Locate a volume and its attachments
```bash
./volumes.sh vol-0123456789abcdef0 --profile=prod,staging
```

### Find network interface by public IP
```bash
./network-interfaces.sh 203.0.113.42 --output=json
```

---

## Differences from Ruby aws-resource-finder

These bash scripts are functionally equivalent to the original Ruby tool with these changes:

1. **Installation** - No Ruby/Bundler setup required; uses AWS CLI and bash
2. **Speed** - Bash scripts may be slightly faster for single queries
3. **Dependencies** - Requires AWS CLI v2 and jq instead of Ruby gems
4. **Output** - Same three formats (text, JSON, YAML) are supported
5. **Multi-profile** - Comma-separated profiles work the same way
6. **Error handling** - Exit codes 0 (success) or 1 (not found/error)

---

## Exit Codes

- `0` - Success; resources found
- `1` - No resources found, error occurred, or invalid arguments

---

## Troubleshooting

### "AWS CLI is not installed"
Install AWS CLI v2 from https://aws.amazon.com/cli/

### "jq is not installed"
Install jq using your package manager (see Requirements section)

### "Missing AWS credentials"
Configure AWS CLI credentials:
```bash
aws configure
# or
aws configure sso --profile prod
```

### "UnrecognizedClientException" or credential errors
Ensure your AWS credentials are valid and have appropriate permissions:

- EC2: `ec2:DescribeNetworkInterfaces`, `ec2:DescribeVolumes`
- ELBv2: `elasticloadbalancing:DescribeTargetGroups`, `elasticloadbalancing:DescribeTargetHealth`
- Route53: `route53:ListHostedZones`, `route53:ListResourceRecordSets`
- ACM: `acm:ListCertificates`, `acm:DescribeCertificate`

### Region not found
Ensure the region is valid: `aws ec2 describe-regions --query 'Regions[].RegionName'`

---

## Development

These scripts were converted from the Ruby aws-resource-finder tool to provide a shell-based alternative without Ruby dependencies.

Related project: https://github.com/dgamboaestrada/aws-resource-finder
