#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <input_file> [output_file]"
    echo "Extracts the Terraform plan actions and removes ANSI colors."
    exit 1
fi

input_file="$1"
output_file="$2"
regex_ansi=$'\033\[[0-9;]*[a-zA-Z]'

# 1. Remove ANSI colors
# 2. Keep only from 'Terraform will perform the following actions:' to the end
# 3. Delete the block from 'Saved the plan to:' to 'Releasing state lock'
clean_terraform_plan() {
    sed "s/$regex_ansi//g" "$input_file" | \
    sed -n '/^Terraform will perform the following actions:/,$p' | \
    sed '/^Saved the plan to:/,/^Releasing state lock/ d'
}

if [ -n "$output_file" ]; then
    clean_terraform_plan > "$output_file"
    echo "Cleaned plan saved to: $output_file"
else
    clean_terraform_plan
fi
