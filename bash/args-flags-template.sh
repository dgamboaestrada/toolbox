#!/bin/bash
# Description: Template script for parsing named arguments with default values
# Author: Daniel Gamboa
# Usage: ./args-flags-template.sh --arg1=value [--arg2=value] [--arg3=value]

# Function to show help
show_help() {
    cat << EOF
Usage: $(basename "$0") --arg1=VALUE [OPTIONS]

Description:
    Template script demonstrating argument parsing with required and optional parameters.

Required Arguments:
    --arg1=VALUE        First argument (required)

Optional Arguments:
    --arg2=VALUE        Second argument (default: default-value-2)
    --arg3=VALUE        Third argument (default: default-value-3)

Other Options:
    -h, --help          Show this help message and exit

Examples:
    # Using only required argument
    $(basename "$0") --arg1=my-value

    # Using all arguments
    $(basename "$0") --arg1=value1 --arg2=value2 --arg3=value3

    # Arguments can be in any order
    $(basename "$0") --arg3=value3 --arg1=value1 --arg2=value2

EOF
    exit 0
}

# Default values
ARG1=""
ARG2="default-value-2"
ARG3="default-value-3"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --arg1=*)
            ARG1="${arg#*=}"
            shift
            ;;
        --arg2=*)
            ARG2="${arg#*=}"
            shift
            ;;
        --arg3=*)
            ARG3="${arg#*=}"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown argument '$arg'"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$ARG1" ]; then
    echo "Error: --arg1 is required"
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
