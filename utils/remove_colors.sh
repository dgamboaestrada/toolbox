#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <input_file> [output_file]"
    echo "Removes ANSI escape codes from a text file."
    echo "If output_file is not provided, outputs to stdout."
    exit 1
fi

input_file="$1"
output_file="$2"

regex_ansi=$'\033\[[0-9;]*[a-zA-Z]'

if [ -n "$output_file" ]; then
    sed "s/$regex_ansi//g" "$input_file" > "$output_file"
    echo "Cleaned file saved to: $output_file"
else
    sed "s/$regex_ansi//g" "$input_file"
fi