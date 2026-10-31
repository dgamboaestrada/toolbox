# EC2 Scripts

Scripts to search and manage AWS EC2 resources including launch templates, instances, and network interfaces.

## Available Scripts

### `find-launch-template-usage.sh`

Find all AWS resources using a specific EC2 launch template, including Auto Scaling Groups, EC2 Fleets, Spot Fleets, and Load Balancers.

**Features:**
- Resolve launch template by ID or name
- Find all Auto Scaling Groups using the template
- List Load Balancers and Target Groups attached to ASGs
- Search EC2 Fleet Requests using the template
- Search Spot Fleet Requests using the template
- Generate AWS console links for quick access
- Error handling for missing templates

**Usage:**
```bash
./find-launch-template-usage.sh <launch-template-id|launch-template-name> [region]
```

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<lt-id or name>` | Yes | Launch template ID (lt-xxxxx) or name |
| `[region]` | No | AWS region (default: `us-east-1` or `$AWS_REGION`) |

**Examples:**
```bash
# Search by template ID
./find-launch-template-usage.sh lt-0123456789abcdef0

# Search by template name in specific region
./find-launch-template-usage.sh my-template us-east-1

# Search in eu-west-1
./find-launch-template-usage.sh lt-0123456789abcdef0 eu-west-1
```

**Output example:**
```
Searching for resources using launch template: my-template (lt-0123456789abcdef0) (region: us-east-1)

=== EC2 Launch Template ===
Launch Template Console URL: https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LaunchTemplateDetails:launchTemplateId=lt-0123456789abcdef0

=== Auto Scaling Groups ===
ASG Name: my-app-asg
Console URL: https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#AutoScalingGroupDetails:id=my-app-asg
  - Load Balancers:
    * my-app-lb
  - Target Groups:
    * arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-app-tg/1234567890abcdef

=== EC2 Fleet Requests ===
❌ EC2 Fleets: No resources found

=== Spot Fleet Requests ===
❌ Spot Fleets: No resources found

✓ Search completed for launch template: lt-0123456789abcdef0
```

---

### `list_ec2_instaces.sh`

List EC2 instances with key information including instance ID, IPs, state, and name.

**Features:**
- List all EC2 instances in region
- Display instance ID, public/private IPs, state, and name
- Formatted table output
- Query specific AWS profile and region

**Usage:**
```bash
./list_ec2_instaces.sh [profile] [region]
```

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `[profile]` | No | AWS CLI profile (default: `default`) |
| `[region]` | No | AWS region (default: `us-east-1`) |

**Examples:**
```bash
# List instances in default profile and region
./list_ec2_instaces.sh

# List instances in specific profile
./list_ec2_instaces.sh prod

# List instances in specific profile and region
./list_ec2_instaces.sh prod eu-west-1
```

**Output example:**
```
--------+---------------------+------------------+------------------+---------+--------
Instance| PublicIpAddress     | PrivateIpAddress | State             | Name    |
--------+---------------------+------------------+------------------+---------+--------
i-0123  | 203.0.113.42        | 10.0.1.50        | running           | web-01  |
i-0456  | None                | 10.0.2.100       | running           | db-01   |
--------+---------------------+------------------+------------------+---------+--------
```

---

### `network-interfaces.sh`

Find EC2 network interfaces (ENIs) by private or public IP address.

**Features:**
- Search network interfaces by private IP
- Search network interfaces by public/elastic IP
- Show ENI ID, status, subnet, VPC, security groups, and tags
- Query across multiple AWS profiles
- Multiple output formats: text, JSON, YAML
- Deduplicate results

**Usage:**
```bash
./network-interfaces.sh <ip-address> [OPTIONS]
```

**Arguments:**

| Flag | Required | Description |
|------|----------|-------------|
| `<ip-address>` | Yes | IP address to search (private or public) |
| `--profile=PROFILE` | No | AWS profiles (comma-separated, default: `default`) |
| `--region=REGION` | No | AWS region (default: `us-east-1`) |
| `--output=FORMAT` | No | Output format: `text` (default), `json`, or `yaml` |
| `--verbose` | No | Enable verbose/debug output |

**Examples:**
```bash
# Search for private IP
./network-interfaces.sh 10.0.1.50

# Search for public IP
./network-interfaces.sh 203.0.113.42

# Search across multiple profiles
./network-interfaces.sh 10.0.1.50 --profile=prod,qa,dev

# Output as JSON
./network-interfaces.sh 10.0.1.50 --output=json
```

**Output example (text format):**
```
ENI: eni-0123456789abcdef0 (available)
  Private IP: 10.0.1.50, Public IP: 203.0.113.42
  VPC: vpc-1234567890abcdef, Subnet: subnet-1234567890abcdef
  Attached to: i-0987654321abcdef0
  Description: Primary network interface
  Security Groups: default (sg-12345678), web-sg (sg-87654321)
  Tags: Environment=production, Service=api
  Profile: prod
```

---

## Prerequisites

1. **AWS CLI installed and configured:**
   ```bash
   aws configure
   ```

2. **Required IAM permissions vary by script:**
   - `find-launch-template-usage.sh`:
     - `ec2:DescribeLaunchTemplates`
     - `autoscaling:DescribeAutoScalingGroups`
     - `ec2:DescribeFleets`
     - `ec2:DescribeSpotFleetRequests`
   - `list_ec2_instaces.sh`:
     - `ec2:DescribeInstances`
   - `network-interfaces.sh`:
     - `ec2:DescribeNetworkInterfaces`

3. **Required tools:**
   - `jq` (for JSON parsing, required by `network-interfaces.sh`)

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

## Output Formats

### Text (default)
Human-readable output with resource details.

### JSON
Machine-readable format for scripting and automation (network-interfaces.sh only):
```bash
./network-interfaces.sh 10.0.1.50 --output=json
```

### YAML
YAML format output (network-interfaces.sh only):
```bash
./network-interfaces.sh 10.0.1.50 --output=yaml
```

## Troubleshooting

### Error: "AWS CLI is not installed"
```bash
brew install awscli  # macOS
# or
sudo apt install awscli  # Ubuntu/Debian
```

### Error: "jq: command not found" (network-interfaces.sh)
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
Verify your IAM user/role has the required permissions for the script you're running.

### Launch template not found
- Verify the template ID or name is correct
- Check you are querying the correct region
- Template might be in a different AWS account

### No instances or ENIs found
- Verify the filter criteria (profile, region, IP address)
- Confirm the instance/ENI exists
- Check IAM permissions

## Common Use Cases

### Find which instances use a launch template
```bash
./find-launch-template-usage.sh my-template us-east-1
```

### List all running instances in production
```bash
./list_ec2_instaces.sh prod us-east-1
```

### Find ENI by IP address across all environments
```bash
./network-interfaces.sh 10.0.1.50 --profile=prod,staging,qa
```

### Export network interfaces as JSON
```bash
./network-interfaces.sh 10.0.1.50 --output=json > eni-details.json
```

## Exit Codes

- `0` - Success; resources found or command completed
- `1` - Resources not found, error occurred, or invalid arguments
