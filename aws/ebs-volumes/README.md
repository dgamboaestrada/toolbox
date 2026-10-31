# EBS Volumes Search

Script to find EBS (Elastic Block Store) volumes by volume ID, across multiple AWS profiles and regions.

## Available Scripts

### `volumes.sh`

Find EBS volumes by volume ID with detailed information including size, type, IOPS, attachments, and tags.

**Features:**
- Search volumes by volume ID
- Display volume state, size, type, IOPS, throughput
- Show volume attachments (EC2 instances)
- Display encryption status and KMS key
- Query across multiple AWS profiles
- Multiple output formats: text, JSON, YAML

**Usage:**
```bash
./volumes.sh <volume-id> [OPTIONS]
```

**Arguments:**

| Flag | Required | Description |
|------|----------|-------------|
| `<volume-id>` | Yes | Volume ID to search (e.g., `vol-1234567890abcdef0`) |
| `--profile=PROFILE` | No | AWS profiles (comma-separated, default: `default`) |
| `--region=REGION` | No | AWS region (default: `us-east-1`) |
| `--output=FORMAT` | No | Output format: `text` (default), `json`, or `yaml` |
| `--verbose` | No | Enable verbose/debug output |

**Examples:**
```bash
# Search for volume in default profile and region
./volumes.sh vol-1234567890abcdef0

# Search across multiple profiles
./volumes.sh vol-1234567890abcdef0 --profile=prod,qa,dev

# Search in specific region
./volumes.sh vol-1234567890abcdef0 --region=eu-west-1

# Output as JSON
./volumes.sh vol-1234567890abcdef0 --output=json

# Verbose output with debug information
./volumes.sh vol-1234567890abcdef0 --verbose
```

**Output example (text format):**
```
Volume: vol-1234567890abcdef0 (in-use)
  Size: 100GiB, Type: gp3, AZ: us-east-1a
  IOPS: 3000, Throughput: 125 MB/s
  Encrypted: true, KMS: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
  Attachments: i-0987654321abcdef0 at /dev/xvda (attached)
  Tags: Environment=production, Service=database
  Profile: prod
```

## Prerequisites

1. **AWS CLI installed and configured:**
   ```bash
   aws configure
   ```

2. **Required IAM permissions:**
   - `ec2:DescribeVolumes`
   - `ec2:DescribeTags` (optional, for tag display)

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
./volumes.sh vol-1234567890abcdef0 --profile=prod,qa,dev
```

## Output Formats

### Text (default)
Human-readable format with volume details on multiple lines.

### JSON
Machine-readable format suitable for scripting and automation:
```bash
./volumes.sh vol-1234567890abcdef0 --output=json
```

### YAML
YAML format output:
```bash
./volumes.sh vol-1234567890abcdef0 --output=yaml
```

## Volume States

- **creating** - Volume is being created
- **available** - Volume is available and not attached
- **in-use** - Volume is attached to an EC2 instance
- **deleting** - Volume is being deleted
- **deleted** - Volume has been deleted
- **error** - An error occurred

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
- `ec2:DescribeVolumes`

### Volume not found
- Verify the volume ID is correct (format: `vol-xxxxxxxx`)
- Confirm you are querying the correct region
- Check the profile has access to the volume
- Volume might be in a different AWS account or region

## Common Use Cases

### Check volume attachment details
```bash
./volumes.sh vol-1234567890abcdef0 --output=json | jq '.[] | {id, attachments}'
```

### Find volumes across all environments
```bash
./volumes.sh vol-1234567890abcdef0 --profile=prod,staging,qa
```

### Export volume information as JSON for compliance
```bash
./volumes.sh vol-1234567890abcdef0 --output=json > volume-details.json
```

### Check encryption status
```bash
./volumes.sh vol-1234567890abcdef0 --output=json | jq '.[] | {id, encrypted, kms_key_id}'
```

### Verify volume is in correct AZ
```bash
./volumes.sh vol-1234567890abcdef0 --output=text | grep "AZ:"
```

## Exit Codes

- `0` - Success; volume found
- `1` - Volume not found or error occurred
