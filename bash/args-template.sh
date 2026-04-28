#!/bin/bash
# Description: Template script for parsing positional arguments with default values
# Author: Daniel Gamboa
# Usage: ./positional-arguments-template.sh <arg1> [arg2] [arg3]

# Function to show help
show_help() {
    cat << EOF
Usage: $(basename "$0") ARG1 [ARG2] [ARG3]

Description:
    Template script demonstrating positional argument parsing with required and optional parameters.

Arguments:
    ARG1            First argument (required)
    ARG2            Second argument (optional, default: default-value-2)
    ARG3            Third argument (optional, default: default-value-3)

Options:
    -h, --help      Show this help message and exit

Examples:
    # Using only required argument
    $(basename "$0") my-value

    # Using two arguments
    $(basename "$0") value1 value2

    # Using all arguments
    $(basename "$0") value1 value2 value3

Notes:
    - Arguments must be provided in order
    - To skip an optional argument, you must provide its default value or all previous arguments

EOF
    exit 0
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
fi

# Parse positional arguments
ARG1="$1"
ARG2="${2:-default-value-2}"
ARG3="${3:-default-value-3}"

# Validate required arguments
if [ -z "$ARG1" ]; then
    echo "Error: ARG1 is required"
    echo ""
    show_help
fi

# Check for too many arguments
if [ $# -gt 3 ]; then
    echo "Error: Too many arguments provided (expected maximum 3, got $#)"
    echo ""
    show_help
fi

# Display configuration
echo "Script execution with the following parameters:"
echo "  ARG1: $ARG1"
echo "  ARG2: $ARG2"
echo "  ARG3: $ARG3"
echo ""

# Your script logic goes here
echo "Executing main script logic..."
echo "Processing with ARG1=$ARG1, ARG2=$ARG2, ARG3=$ARG3"

# Example: conditional logic based on arguments
if [ "$ARG2" = "default-value-2" ]; then
    echo "Note: Using default value for ARG2"
fi

if [ "$ARG3" = "default-value-3" ]; then
    echo "Note: Using default value for ARG3"
fi

echo ""
echo "Script completed successfully!"
