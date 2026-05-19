#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <launch-template-id> [region]" >&2
  echo "Example: $0 lt-0123456789abcdef0 us-east-1" >&2
  exit 1
fi

launch_template_id="$1"
region="${2:-us-east-1}"

if [[ ! "$launch_template_id" =~ ^lt- ]]; then
  echo "Error: Invalid launch template ID format: $launch_template_id" >&2
  exit 1
fi

check_resources() {
  local label="$1"
  local output
  output=$(eval "$2" 2>/dev/null || true)

  if [[ -z "$output" ]] || [[ "$output" == "[]" ]] || [[ $(echo "$output" | wc -l) -le 2 ]]; then
    echo "❌ $label: No resources found"
  else
    echo "$output"
  fi
}

echo "Searching for resources using launch template: $launch_template_id (region: $region)"
echo ""

echo "=== Auto Scaling Groups ==="
check_resources "ASGs" "aws autoscaling describe-auto-scaling-groups --region '$region' --query \"AutoScalingGroups[?LaunchTemplate.LaunchTemplateId=='${launch_template_id}'].[AutoScalingGroupName,LaunchTemplate.LaunchTemplateId]\" --output table"

echo ""
echo "=== EC2 Fleet Requests ==="
check_resources "EC2 Fleets" "aws ec2 describe-fleets --region '$region' --query \"Fleets[?LaunchTemplateConfigs[?LaunchTemplateSpecification.LaunchTemplateId=='${launch_template_id}']].[FleetId,FleetState]\" --output table"

echo ""
echo "=== Spot Fleet Requests ==="
check_resources "Spot Fleets" "aws ec2 describe-spot-fleet-requests --region '$region' --query \"SpotFleetRequestConfigs[?SpotFleetRequestConfig.LaunchTemplateConfigs[?LaunchTemplateSpecification.LaunchTemplateId=='${launch_template_id}']].[SpotFleetRequestId,SpotFleetRequestState]\" --output table"

echo ""
echo "✓ Search completed for launch template: $launch_template_id"
