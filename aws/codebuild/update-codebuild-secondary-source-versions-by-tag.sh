#!/bin/bash
# Update the codebuild secondary source to a specified source version
# Filter projects that have a specific AWS tag key-value pair
# Usage: ./script.sh <source-identifier> <source-version> <tag-key> [--tag-value <value>] [--project-prefix <prefix>] [--dry-run]
# Example: ./script.sh PIPELINE-SCRIPTS v2.7.1 ModuleVersion --tag-value "1.0" --project-prefix terraform- --dry-run

# Function to show usage
show_usage() {
    echo "Usage: $0 <source-identifier> <source-version> <tag-key> [--tag-value <value>] [--project-prefix <prefix>] [--dry-run]"
    echo "  source-identifier: Required. The secondary source identifier to update (e.g., PIPELINE-SCRIPTS)"
    echo "  source-version:    Required. The new source version to update to (e.g., v2.7.1)"
    echo "  tag-key:           Required. The AWS tag key to filter by (e.g., ModuleVersion)"
    echo "  --tag-value        Optional. Filter by specific tag value. If not specified, filters by tag presence only"
    echo "  --project-prefix   Optional. Filter projects by name prefix (default: no prefix filter)"
    echo "  --dry-run:         Optional. Preview changes without making actual updates"
    echo ""
    echo "Examples:"
    echo "  $0 PIPELINE-SCRIPTS v2.7.1 ModuleVersion"
    echo "  $0 PIPELINE-SCRIPTS v2.8.0 ModuleVersion --tag-value \"1.0\" --dry-run"
    echo "  $0 MY-SCRIPTS v1.2.3 Environment --tag-value prod --project-prefix terraform-"
    echo "  $0 PIPELINE-SCRIPTS v2.8.0 ModuleVersion --project-prefix my-app- --dry-run"
    exit 1
}

# Check if minimum arguments are provided
if [ $# -lt 3 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
fi

# Parse arguments
SOURCE_IDENTIFIER=""
SOURCE_VERSION=""
TAG_KEY=""
TAG_VALUE=""  # Optional - if empty, will filter by tag presence only
PROJECT_PREFIX=""  # Optional - if empty, no prefix filter
DRY_RUN_MODE=false
positional_count=0

i=1
while [ $i -le $# ]; do
    case "${!i}" in
        --dry-run)
            DRY_RUN_MODE=true
            ;;
        --tag-value)
            i=$((i + 1))
            if [ $i -le $# ]; then
                TAG_VALUE="${!i}"
            else
                echo "Error: --tag-value requires a value"
                show_usage
            fi
            ;;
        --project-prefix)
            i=$((i + 1))
            if [ $i -le $# ]; then
                PROJECT_PREFIX="${!i}"
            else
                echo "Error: --project-prefix requires a value"
                show_usage
            fi
            ;;
        --help|-h)
            show_usage
            ;;
        -*)
            echo "Error: Unknown option ${!i}"
            show_usage
            ;;
        *)
            positional_count=$((positional_count + 1))
            if [ $positional_count -eq 1 ]; then
                SOURCE_IDENTIFIER="${!i}"
            elif [ $positional_count -eq 2 ]; then
                SOURCE_VERSION="${!i}"
            elif [ $positional_count -eq 3 ]; then
                TAG_KEY="${!i}"
            else
                echo "Error: Too many positional arguments. Expected: <source-identifier> <source-version> <tag-key>"
                show_usage
            fi
            ;;
    esac
    i=$((i + 1))
done

# Validate that required parameters were provided
if [ -z "$SOURCE_IDENTIFIER" ]; then
    echo "Error: Source identifier is required"
    show_usage
fi

if [ -z "$SOURCE_VERSION" ]; then
    echo "Error: Source version is required"
    show_usage
fi

if [ -z "$TAG_KEY" ]; then
    echo "Error: Tag key is required"
    show_usage
fi

echo "Updating CodeBuild projects:"
echo "  Source Identifier: $SOURCE_IDENTIFIER"
echo "  New Source Version: $SOURCE_VERSION"
echo "  Tag Key Filter: $TAG_KEY"
if [ -n "$TAG_VALUE" ]; then
    echo "  Tag Value Filter: $TAG_VALUE"
else
    echo "  Tag Value Filter: (any value - filter by presence only)"
fi
echo "  Project Prefix Filter: ${PROJECT_PREFIX:-"(no prefix filter)"}"
if [ "$DRY_RUN_MODE" = true ]; then
    echo "DRY RUN MODE: No changes will be made to AWS resources"
fi
echo "============================================="

# Get all CodeBuild projects in the account
export AWS_PROFILE=default
export AWS_REGION=us-east-1

# Build the query based on whether a prefix filter is specified
if [ -n "$PROJECT_PREFIX" ]; then
    codebuild_projects=$(aws codebuild list-projects --max-items 1000 --query "projects[?starts_with(@, \`$PROJECT_PREFIX\`)]" --output text)
    echo "Found projects with prefix '$PROJECT_PREFIX': $codebuild_projects"
else
    codebuild_projects=$(aws codebuild list-projects --max-items 1000 --query 'projects' --output text)
    echo "Found all projects: $codebuild_projects"
fi
echo "============================================="

# Counters
updated_count=0
skipped_count=0

for project in $codebuild_projects; do
    # Get the project tags
    project_tags=$(aws codebuild batch-get-projects --names $project --query 'projects[0].tags' --output json)

    # Check if project has the specified tag
    if [ -n "$TAG_VALUE" ]; then
        # Filter by both tag key and value
        tag_match=$(echo "$project_tags" | jq -e ".[] | select(.key == \"$TAG_KEY\" and .value == \"$TAG_VALUE\")" 2>/dev/null)
        filter_desc="$TAG_KEY=$TAG_VALUE"
    else
        # Filter by tag key presence only
        tag_match=$(echo "$project_tags" | jq -e ".[] | select(.key == \"$TAG_KEY\")" 2>/dev/null)
        filter_desc="$TAG_KEY (any value)"
    fi

    if [ -n "$tag_match" ]; then
        echo "Project $project has tag $filter_desc"

        # Count as candidate to update (dry-run or real run)
        updated_count=$((updated_count + 1))

        if [ "$DRY_RUN_MODE" = true ]; then
            echo "  [DRY-RUN] Would update secondary source to version $SOURCE_VERSION"
            echo "  [DRY-RUN] Command: aws codebuild update-project --name $project --secondary-source-versions '[{\"sourceIdentifier\": \"$SOURCE_IDENTIFIER\", \"sourceVersion\": \"$SOURCE_VERSION\"}]'"
        else
            # Update secondary source version to the specified version
            aws codebuild update-project --name $project --secondary-source-versions "[{\"sourceIdentifier\": \"$SOURCE_IDENTIFIER\", \"sourceVersion\": \"$SOURCE_VERSION\"}]" > /dev/null
            echo "Updated $project secondary source $SOURCE_IDENTIFIER to version $SOURCE_VERSION"
        fi
    else
        echo "Project $project does not have tag $filter_desc"
        skipped_count=$((skipped_count + 1))
    fi
    sleep 1
done

echo "============================================="
echo "Summary"
echo "- Projects to update: $updated_count"
echo "- Projects not matching condition: $skipped_count"