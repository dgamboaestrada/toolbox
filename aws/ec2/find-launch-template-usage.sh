#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <launch-template-id> [region]" >&2
  echo "Example: $0 lt-0123456789abcdef0 us-east-1" >&2
  exit 1
fi

launch_template_id="$1"
region="${2:-${AWS_REGION:-us-east-1}}"

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
asgs=$(aws autoscaling describe-auto-scaling-groups --region "$region" --query "AutoScalingGroups[?LaunchTemplate.LaunchTemplateId=='${launch_template_id}'].AutoScalingGroupName" --output text)

if [[ -z "$asgs" ]]; then
  echo "❌ ASGs: No resources found"
else
  for asg in $asgs; do
    echo "ASG Name: $asg"
    echo "Console URL: https://${region}.console.aws.amazon.com/ec2/home?region=${region}#AutoScalingGroupDetails:id=${asg}"
    
    # Check for LBs and TGs for this specific ASG
    lbs=$(aws autoscaling describe-auto-scaling-groups --region "$region" --auto-scaling-group-names "$asg" --query "AutoScalingGroups[0].LoadBalancerNames" --output text | tr '\t' ' ')
    tgs=$(aws autoscaling describe-auto-scaling-groups --region "$region" --auto-scaling-group-names "$asg" --query "AutoScalingGroups[0].TargetGroupARNs" --output text | tr '\t' ' ')

    if [[ -n "${lbs// /}" && "$lbs" != "None" ]]; then
      echo "  - Load Balancers:"
      for lb in $lbs; do
        echo "    * $lb (URL: https://${region}.console.aws.amazon.com/ec2/v2/home?region=${region}#LoadBalancers:search=${lb})"
      done
    fi

    if [[ -n "${tgs// /}" && "$tgs" != "None" ]]; then
      echo "  - Target Groups:"
      for tg in $tgs; do
        # Extract name from ARN if possible for the search link
        tg_name=$(echo "$tg" | cut -d'/' -f2 || echo "$tg")
        echo "    * $tg"
        echo "      (URL: https://${region}.console.aws.amazon.com/ec2/v2/home?region=${region}#TargetGroups:search=${tg_name})"
      done
    fi
    echo "-------------------------------------------"
  done
fi

echo ""
echo "=== EC2 Fleet Requests ==="
check_resources "EC2 Fleets" "aws ec2 describe-fleets --region '$region' --query \"Fleets[?LaunchTemplateConfigs[?LaunchTemplateSpecification.LaunchTemplateId=='${launch_template_id}']].[FleetId,FleetState]\" --output table"

echo ""
echo "=== Spot Fleet Requests ==="
check_resources "Spot Fleets" "aws ec2 describe-spot-fleet-requests --region '$region' --query \"SpotFleetRequestConfigs[?SpotFleetRequestConfig.LaunchTemplateConfigs[?LaunchTemplateSpecification.LaunchTemplateId=='${launch_template_id}']].[SpotFleetRequestId,SpotFleetRequestState]\" --output table"

echo ""
echo "✓ Search completed for launch template: $launch_template_id"
