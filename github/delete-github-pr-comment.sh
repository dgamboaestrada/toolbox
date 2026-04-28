#!/bin/bash
#
# Script to delete comments from a GitHub Pull Request
#
# Usage:
#   ./delete-github-pr-comment.sh [OPTIONS]
#
# Options:
#   -o, --owner OWNER       Repository owner (or use GITHUB_OWNER)
#   -r, --repo REPO         Repository name (or use GITHUB_REPO)
#   -p, --pr NUMBER         Pull Request number (or use GITHUB_PR_ISSUE_NUMBER)
#   -t, --token TOKEN       GitHub token (or use GITHUB_TOKEN)
#   -s, --search TEXT       Text to search for in the comment (default: "NPM Registry Validation Failed")
#   -h, --help             Show this help message
#
# Environment variables:
#   GITHUB_OWNER            Repository owner
#   GITHUB_REPO             Repository name
#   GITHUB_PR_ISSUE_NUMBER  Pull Request number
#   GITHUB_TOKEN            GitHub authentication token
#
# Example:
#   export GITHUB_OWNER=myorg
#   export GITHUB_REPO=myrepo
#   export GITHUB_PR_ISSUE_NUMBER=123
#   export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
#   ./delete-github-pr-comment.sh --search "NPM Registry Validation Failed"

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[1;36m'
readonly END='\033[0m'

# Default values
SEARCH_TEXT="${SEARCH_TEXT:-NPM Registry Validation Failed}"

# Function to show help
show_help() {
    cat << EOF
Script to delete comments from a GitHub Pull Request

Usage:
    $0 [OPTIONS]

Options:
    -o, --owner OWNER       Repository owner (or use GITHUB_OWNER)
    -r, --repo REPO         Repository name (or use GITHUB_REPO)
    -p, --pr NUMBER         Pull Request number (or use GITHUB_PR_ISSUE_NUMBER)
    -t, --token TOKEN       GitHub token (or use GITHUB_TOKEN)
    -s, --search TEXT       Text to search for in the comment (default: "NPM Registry Validation Failed")
    -h, --help             Show this help message

Environment variables:
    GITHUB_OWNER            Repository owner
    GITHUB_REPO             Repository name
    GITHUB_PR_ISSUE_NUMBER  Pull Request number
    GITHUB_TOKEN            GitHub authentication token

Examples:
    # Using environment variables
    export GITHUB_OWNER=myorg
    export GITHUB_REPO=myrepo
    export GITHUB_PR_ISSUE_NUMBER=123
    export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
    $0 --search "NPM Registry Validation Failed"

    # Using parameters
    $0 --owner myorg --repo myrepo --pr 123 --token ghp_xxxx --search "Error message"
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--owner)
            GITHUB_OWNER="$2"
            shift 2
            ;;
        -r|--repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        -p|--pr)
            GITHUB_PR_ISSUE_NUMBER="$2"
            shift 2
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -s|--search)
            SEARCH_TEXT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${END}" >&2
            show_help
            exit 1
            ;;
    esac
done

# Validate required variables
if [ -z "${GITHUB_OWNER:-}" ]; then
    echo -e "${RED}Error: GITHUB_OWNER is not defined${END}" >&2
    echo "Use -o/--owner or export the GITHUB_OWNER variable"
    exit 1
fi

if [ -z "${GITHUB_REPO:-}" ]; then
    echo -e "${RED}Error: GITHUB_REPO is not defined${END}" >&2
    echo "Use -r/--repo or export the GITHUB_REPO variable"
    exit 1
fi

if [ -z "${GITHUB_PR_ISSUE_NUMBER:-}" ]; then
    echo -e "${RED}Error: GITHUB_PR_ISSUE_NUMBER is not defined${END}" >&2
    echo "Use -p/--pr or export the GITHUB_PR_ISSUE_NUMBER variable"
    exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -e "${RED}Error: GITHUB_TOKEN is not defined${END}" >&2
    echo "Use -t/--token or export the GITHUB_TOKEN variable"
    exit 1
fi

# Verify that curl and jq are available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed${END}" >&2
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${END}" >&2
    exit 1
fi

echo -e "${CYAN}Searching for comments in PR #${GITHUB_PR_ISSUE_NUMBER}...${END}"

# Get list of PR comments
COMMENTS_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues/${GITHUB_PR_ISSUE_NUMBER}/comments"
COMMENTS=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
                 -H "Accept: application/vnd.github.v3+json" \
                 "${COMMENTS_URL}")

# Verify if there was an error in the request
if echo "${COMMENTS}" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "${COMMENTS}" | jq -r '.message')
    echo -e "${RED}Error getting comments: ${ERROR_MSG}${END}" >&2
    exit 1
fi

# Search for the comment containing the specified text
COMMENT_ID=$(echo "${COMMENTS}" | jq -r --arg search "${SEARCH_TEXT}" \
    '.[] | select(.body | contains($search)) | .id' | head -n1)

if [ -n "${COMMENT_ID}" ] && [ "${COMMENT_ID}" != "null" ]; then
    echo -e "${YELLOW}Comment found (ID: ${COMMENT_ID})${END}"
    echo -e "${CYAN}Deleting comment...${END}"

    DELETE_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues/comments/${COMMENT_ID}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${DELETE_URL}")

    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)

    if [ "${HTTP_CODE}" = "204" ]; then
        echo -e "${GREEN}✅ Comment deleted successfully (ID: ${COMMENT_ID})${END}"
        exit 0
    else
        echo -e "${RED}Error deleting comment. HTTP Status: ${HTTP_CODE}${END}" >&2
        echo "${RESPONSE}" | head -n-1 | jq '.' 2>/dev/null || echo "${RESPONSE}" | head -n-1
        exit 1
    fi
else
    echo -e "${YELLOW}No comment found with the text: '${SEARCH_TEXT}'${END}"
    exit 0
fi

