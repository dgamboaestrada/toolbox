# ELBv2 Target Groups Search

Script to find ELBv2 (Application/Network Load Balancer) target groups by target ID, across multiple AWS profiles and regions.

## Available Scripts

### `target-groups-by-target.sh`

Find target groups containing a specific target (EC2 instance, IP address, or Lambda function).

**Features:**
- Search by target ID (instance ID, IP address, or Lambda ARN)
- Support for multiple target types: IP, instance, lambda
- Filter by specific Load Balancer ARN (optional)
- Include target group tags in results
- Query across multiple AWS profiles
- Multiple output formats: text, JSON, YAML

**Usage:**
```bash
./target-groups-by-target.sh <target-id> [OPTIONS]
```

**Arguments:**

| Flag | Required | Description |
|------|----------|-------------|
| `<target-id>` | Yes | Target ID to search (instance ID, IP, or Lambda ARN) |
| `--type=TYPE` | No | Target type: `ip` (default), `instance`, or `lambda` |
| `--profile=PROFILE` | No | AWS profiles (comma-separated, default: `default`) |
| `--region=REGION` | No | AWS region (default: `us-east-1`) |
| `--lb-arn=ARN` | No | Optional Load Balancer ARN to filter search |
| `--tags` | No | Include target group tags in output |
| `--output=FORMAT` | No | Output format: `text` (default), `json`, or `yaml` |
| `--verbose` | No | Enable verbose/debug output |

**Examples:**
```bash
# Search for IP in target groups
./target-groups-by-target.sh 10.0.0.5

# Search for EC2 instance with tags
./target-groups-by-target.sh i-1234567890abcdef0 --type=instance --tags

# Search across multiple profiles
./target-groups-by-target.sh 10.0.0.5 --profile=prod,qa,dev

# Search with specific Load Balancer
./target-groups-by-target.sh 10.0.0.5 --lb-arn=arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-lb/50dc6c495c0c9188

# Output as JSON
./target-groups-by-target.sh 10.0.0.5 --output=json

# Search for Lambda function
./target-groups-by-target.sh arn:aws:lambda:us-east-1:123456789012:function:my-function --type=lambda
```

**Output example (text format):**
```
Profile: prod
  TG: api-tg (arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api-tg/1234567890abcdef)
  Type: ip, VPC: vpc-1234567890abcdef
  Target: 10.0.0.5:8080 state=healthy
  Tags: Environment=production, Service=api
```

## Prerequisites

1. **AWS CLI installed and configured:**
   ```bash
   aws configure
   ```

2. **Required IAM permissions:**
   - `elasticloadbalancing:DescribeTargetGroups`
   - `elasticloadbalancing:DescribeTargetHealth`
   - `elasticloadbalancing:DescribeTags`

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
# Search in prod, qa, and dev environments simultaneously
./target-groups-by-target.sh 10.0.0.5 --profile=prod,qa,dev

# Output will show results from each profile
```

## Output Formats

### Text (default)
Human-readable format with resource details.

### JSON
Machine-readable format suitable for scripting:
```bash
./target-groups-by-target.sh 10.0.0.5 --output=json
```

### YAML
YAML format output:
```bash
./target-groups-by-target.sh 10.0.0.5 --output=yaml
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
- `elasticloadbalancing:DescribeTargetGroups`
- `elasticloadbalancing:DescribeTargetHealth`
- `elasticloadbalancing:DescribeTags`

### No target groups found
- Verify the target ID is correct
- Confirm the target type matches (`--type`)
- Check you are querying the correct region/profile
- Confirm the target is actually registered in a target group

## Common Use Cases

### Find which load balancer targets an IP
```bash
./target-groups-by-target.sh 10.0.1.50 --output=json
```

### Verify an instance is registered in target groups
```bash
./target-groups-by-target.sh i-1234567890abcdef0 --type=instance --tags
```

### Check target health across environments
```bash
./target-groups-by-target.sh 10.0.0.5 --profile=prod,staging,qa
```

## Exit Codes

- `0` - Success; target groups found
- `1` - Target not found or error occurred
