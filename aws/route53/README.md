# Route53 Zone and Record Search

Scripts to find Route53 hosted zones and DNS records by name, across multiple AWS profiles and regions.

## Available Scripts

### `route53-zones.sh`

Find Route53 hosted zones by domain name.

**Features:**
- Search hosted zones by exact domain name
- Query across multiple AWS profiles
- Shows zone ID, name, and private/public status
- Multiple output formats: text, JSON, YAML

**Usage:**
```bash
./route53-zones.sh <domain-name> [OPTIONS]
```

**Arguments:**

| Flag | Required | Description |
|------|----------|-------------|
| `<domain-name>` | Yes | Domain name to search (e.g., `example.com`) |
| `--profile=PROFILE` | No | AWS profiles (comma-separated, default: `default`) |
| `--region=REGION` | No | AWS region (default: `us-east-1`) |
| `--output=FORMAT` | No | Output format: `text` (default), `json`, or `yaml` |
| `--verbose` | No | Enable verbose/debug output |

**Examples:**
```bash
# Search for hosted zone
./route53-zones.sh example.com

# Search across multiple profiles
./route53-zones.sh example.com --profile=prod,qa

# Output as JSON
./route53-zones.sh example.com --output=json
```

---

### `route53-records.sh`

Find Route53 DNS records by name. Optionally limit search to a specific hosted zone.

**Features:**
- Search records by name across all zones or specific zone
- Shows record type, TTL, values, and alias targets
- Support for zone filtering (`--zone-name`)
- Query across multiple AWS profiles
- Multiple output formats: text, JSON, YAML

**Usage:**
```bash
./route53-records.sh <record-name> [OPTIONS]
```

**Arguments:**

| Flag | Required | Description |
|------|----------|-------------|
| `<record-name>` | Yes | Record name to search (e.g., `api.example.com`) |
| `--zone-name=ZONE` | No | Hosted zone name to limit search (e.g., `example.com`) |
| `--profile=PROFILE` | No | AWS profiles (comma-separated, default: `default`) |
| `--region=REGION` | No | AWS region (default: `us-east-1`) |
| `--output=FORMAT` | No | Output format: `text` (default), `json`, or `yaml` |
| `--verbose` | No | Enable verbose/debug output |

**Examples:**
```bash
# Search for record across all zones
./route53-records.sh api.example.com

# Search within specific zone
./route53-records.sh api.example.com --zone-name=example.com

# Search across multiple profiles
./route53-records.sh api.example.com --profile=prod,qa

# Output as JSON
./route53-records.sh api.example.com --output=json
```

**Output example (text format):**
```
Zone: example.com. (id: /hostedzone/Z1234567890ABC)
  Private: false, Records: 42
  Profile: prod

Record: api.example.com. A
  TTL: 300, Zone: example.com. (/hostedzone/Z1234567890ABC)
  Values: 10.0.1.50, 10.0.1.51
  Profile: prod, Private: false
```

## Prerequisites

1. **AWS CLI installed and configured:**
   ```bash
   aws configure
   ```

2. **Required IAM permissions:**
   - `route53:ListHostedZones`
   - `route53:ListHostedZonesByName`
   - `route53:ListResourceRecordSets`
   - `route53:GetHostedZone`

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
./route53-zones.sh example.com --profile=prod,qa,dev
./route53-records.sh api.example.com --profile=prod,qa,dev
```

## Output Formats

### Text (default)
Human-readable format with DNS record details.

### JSON
Machine-readable format suitable for scripting and automation.

### YAML
YAML format output for configuration management.

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
- `route53:ListHostedZones`
- `route53:ListHostedZonesByName`
- `route53:ListResourceRecordSets`
- `route53:GetHostedZone`

### No hosted zones or records found
- Verify the domain/record name is spelled correctly
- Confirm the zone exists: `aws route53 list-hosted-zones`
- Check you are querying the correct profile/region
- Ensure the records are actually configured

## Common Use Cases

### Find hosted zone ID for a domain
```bash
./route53-zones.sh example.com --output=json | jq '.[] | {name, id}'
```

### List all A records for a domain
```bash
./route53-records.sh example.com --zone-name=example.com
```

### Check DNS across multiple environments
```bash
./route53-records.sh api.example.com --profile=prod,staging,qa
```

### Export records as JSON for backup
```bash
./route53-records.sh example.com --output=json > example-records.json
```

## Exit Codes

- `0` - Success; zones/records found
- `1` - No zones/records found or error occurred
