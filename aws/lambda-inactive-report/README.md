# AWS Lambda Monitoring Scripts

This directory contains scripts to monitor and detect inactive Lambda functions in AWS.

## Available Scripts

### `lambda-inactive-report.sh` - Lambda Functions Report
Complete script that generates a detailed report of all Lambda functions that haven't been executed in a specific period.

**Features:**
- Generates detailed report with additional information (runtime, last modified, description)
- Supports both text and CSV output formats
- Saves report to a file with timestamp
- Includes counters and final summary
- Verifies AWS credentials before execution

**Usage:**
```bash
# Use default period (90 days) and text format
./lambda-inactive-report.sh

# Specify custom period (e.g., 60 days) with text format
./lambda-inactive-report.sh 60

# Use default period (90 days) with CSV format
./lambda-inactive-report.sh 90 csv

# Specify custom period (60 days) with CSV format
./lambda-inactive-report.sh 60 csv

# Use custom name for the report file
./lambda-inactive-report.sh 90 txt production-report
./lambda-inactive-report.sh 60 csv staging-lambdas
```

**Output:**
- Console report
- File: `lambda-inactive-report-YYYYMMDD-HHMMSS.txt` (text format, default name)
- File: `lambda-inactive-report-YYYYMMDD-HHMMSS.csv` (CSV format, default name)
- File: `custom-name.txt` (text format, custom name)
- File: `custom-name.csv` (CSV format, custom name)

## Prerequisites

1. **AWS CLI installed and configured:**
   ```bash
   aws configure
   ```

2. **Required permissions:**
   - `lambda:ListFunctions`
   - `lambda:GetFunction`
   - `cloudwatch:GetMetricStatistics`

3. **Required tools:**
   - `jq` for JSON parsing (required for processing Lambda function details)

## Prerequisites Installation

### macOS (with Homebrew):
```bash
brew install awscli jq
```

### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install awscli jq
```

### CentOS/RHEL:
```bash
sudo yum install awscli jq
# or for newer versions:
sudo dnf install awscli jq
```

## Usage Examples

### Complete report for functions not executed in 60 days (text format):
```bash
./lambda-inactive-report.sh 60
```

### Complete report in CSV format for Excel import (90 days default):
```bash
./lambda-inactive-report.sh 90 csv
```

### Complete report for 30 days in CSV format:
```bash
./lambda-inactive-report.sh 30 csv
```

### Custom named reports for different environments:
```bash
# Production environment report
./lambda-inactive-report.sh 90 csv production-lambdas

# Staging environment report
./lambda-inactive-report.sh 60 txt staging-report

# Development environment report
./lambda-inactive-report.sh 30 csv dev-lambdas

# Monthly report with specific date
./lambda-inactive-report.sh 90 csv monthly-report-october
```

### Verify credentials before execution:
```bash
aws sts get-caller-identity
```

## CSV Format Details

When using CSV format (`csv` parameter), the output file contains:

- **Headers**: Function Name, Runtime, Last Modified, Invocations, Status, Description
- **Data**: Each Lambda function as a row with proper CSV escaping
- **Summary**: Added as comments at the end of the file

### CSV Example:
```csv
Function Name,Runtime,Last Modified,Invocations,Status,Description
"test-lambda-janitor-repoecr","N/A","2025-08-19T05:01:56.000+0000",0,Inactive,""
"pharos-lrm-updates-receiver-fifo-dev","N/A","2025-10-20T04:06:55.000+0000",579,Active,""

# SUMMARY
# Total functions analyzed: 169
# Active functions: 45
# Inactive functions: 124
# Functions with errors: 0
```

This CSV format can be directly imported into Excel, Google Sheets, or any spreadsheet application.

## Results Interpretation

- **❌** = Lambda function not executed in the specified period
- **✅** = Lambda function executed at least once in the specified period

## Troubleshooting

### Error: "AWS CLI is not installed"
```bash
# Install AWS CLI
pip install awscli
# or
brew install awscli
```

### Error: "jq: command not found"
```bash
# Install jq (required for JSON processing)
# macOS:
brew install jq

# Ubuntu/Debian:
sudo apt install jq

# CentOS/RHEL:
sudo yum install jq
# or
sudo dnf install jq
```

### Error: "Cannot verify credentials"
```bash
# Configure credentials
aws configure
# Enter Access Key ID, Secret Access Key, default region
```

### Error: "Access Denied"
Verify that the user/role has the necessary permissions:
- `lambda:ListFunctions`
- `lambda:GetFunction`
- `cloudwatch:GetMetricStatistics`

## Important Notes

1. **API call costs:** Scripts make multiple calls to AWS APIs. In accounts with many Lambda functions, this may generate minimal costs.

2. **CloudWatch limits:** CloudWatch has limits on metrics. For very large accounts, consider using pagination.

3. **Functions without logs:** Some functions may not have metrics if they have never been executed.

4. **Regions:** Scripts check the default configured region. To check multiple regions, run the script with different AWS profiles.

## Automation

To run these scripts automatically, you can:

1. **Weekly cron job:**
   ```bash
   # Edit crontab
   crontab -e

   # Add line to run every Monday at 9 AM (90 days default)
   0 9 * * 1 /path/to/misc/scripts/lambda-inactive-report.sh
   ```

2. **CI/CD integration:**
   - Add as step in pipeline
   - Send reports via email/Slack
   - Create automatic alerts
