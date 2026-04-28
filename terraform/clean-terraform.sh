#!/bin/bash
# Usage: ./clean-terraform.sh <workspace_dir> [-v]
# Description: Script to delete all .terraform directories in a given workspace directory.

# Base directory where to search for projects
workspace_dir="$1"

# Temporary file to store the total size
temp_file=/tmp/total_size.txt

# Verbose mode (optional)
verbose=false
if [[ "$#" -gt 1 && "$2" == "-v" ]]; then
    verbose=true
fi

# Function to calculate the total size of .terraform directories
function calculate_total_size() {
  local total_size=0
  find "$workspace_dir" -name ".terraform" -print0 | while read -rd '' dir; do
    size_mb=$(du -sm "$dir" | awk '{ print $1 }')
    if $verbose; then
      printf "%s: %.2f MB\n" "$dir" "$size_mb"
    fi

    # Add the size to the total
    total_size=$(echo "$total_size + $size_mb" | bc)

    # Write the total size to the temporary file
    echo "$total_size" > "$temp_file"
  done
}

# Block to ensure the temporary file is removed
trap 'rm -f "$temp_file"' EXIT

# Call the function to calculate the total size
calculate_total_size

# Read the total size from the temporary file
total_size_mb=$(cat "$temp_file")

# Display the estimated total size and ask the user
echo "Estimated total size to delete: $total_size_mb MB"
read -p "Do you want to delete the .terraform directories ($total_size_mb MB)? (y/n): " confirm

# Conditional to delete the directories
if [[ $confirm == "y" || $confirm == "Y" ]]; then
  # Command to delete the .terraform directories
  if $verbose; then
    find "$workspace_dir" -name ".terraform" -print0 | while read -rd '' dir; do
      echo "Deleting: $dir"
      rm -rf "$dir"
    done
  else
    find "$workspace_dir" -name ".terraform" -exec rm -rf {} +
  fi
  echo "Terraform directories deleted successfully."
else
  echo "Operation canceled."
fi
