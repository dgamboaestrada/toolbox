#!/bin/bash

aws_profile=$1
aws_region=${2:-us-east-1}

if [ -z "$aws_profile" ]; then
    aws_profile="default"
fi

aws ec2 describe-instances --profile $aws_profile --region $aws_region --query 'Reservations[*].Instances[*].{InstanceId:InstanceId, PublicIpAddress:PublicIpAddress, PrivateIpAddress:PrivateIpAddress, State:State.Name, Name:Tags[?Key==`Name`].Value|[0]}' --output table