#!/bin/bash
# Update the codebuild secondary source to a specified source version
# Filter projects that have a specific secondary source identifier with a current source version
# Usage: ./script.sh <source-identifier> <source-version> [--current-source-version <version>] [--project-prefix <prefix>] [--dry-run]
# Example: ./script.sh PIPELINE-SCRIPTS v2.7.1 --current-source-version main --project-prefix terraform- --dry-run

# Function to show usage
show_usage() {
    echo "Usage: $0 <source-identifier> <source-version> [--current-source-version <version>] [--project-prefix <prefix>] [--dry-run]"
    echo "  source-identifier:       Required. The secondary source identifier to filter and update (e.g., PIPELINE-SCRIPTS)"
    echo "  source-version:          Required. The new source version to update to (e.g., v2.7.1)"
    echo "  --current-source-version Optional. Filter by current source version (default: main)"
    echo "  --project-prefix         Optional. Filter projects by name prefix (default: \"\")"
    echo "  --dry-run:               Optional. Preview changes without making actual updates"
    echo ""
    echo "Examples:"
    echo "  $0 PIPELINE-SCRIPTS v2.7.1"
    echo "  $0 PIPELINE-SCRIPTS v2.8.0 --dry-run"
    echo "  $0 PIPELINE-SCRIPTS v2.8.0 --current-source-version develop --dry-run"
    echo "  $0 MY-SCRIPTS v1.2.3 --current-source-version main --project-prefix my-app-"
    echo "  $0 PIPELINE-SCRIPTS v2.8.0 --project-prefix '' --dry-run  # No prefix filter"
    exit 1
}

# Check if minimum arguments are provided
if [ $# -lt 2 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
fi

# Parse arguments
SOURCE_IDENTIFIER=""
SOURCE_VERSION=""
CURRENT_SOURCE_VERSION="main"  # Default value
PROJECT_PREFIX=""    # Default value
DRY_RUN_MODE=false
positional_count=0

i=1
while [ $i -le $# ]; do
    case "${!i}" in
        --dry-run)
            DRY_RUN_MODE=true
            ;;
        --current-source-version)
            i=$((i + 1))
            if [ $i -le $# ]; then
                CURRENT_SOURCE_VERSION="${!i}"
            else
                echo "Error: --current-source-version requires a value"
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
            else
                echo "Error: Too many positional arguments. Expected: <source-identifier> <source-version>"
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

echo "Updating CodeBuild projects:"
echo "  Source Identifier: $SOURCE_IDENTIFIER"
echo "  Current Source Version Filter: $CURRENT_SOURCE_VERSION"
echo "  New Source Version: $SOURCE_VERSION"
echo "  Project Prefix Filter: $PROJECT_PREFIX"
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
    # Get the project details including secondary sources
    project_details=$(aws codebuild batch-get-projects --names $project --query 'projects[0]' --output json)

    # First check if project has the specified secondary source at all
    has_secondary_source=$(echo "$project_details" | jq -r '.secondarySources[]? | select(.sourceIdentifier == "'$SOURCE_IDENTIFIER'") | .sourceIdentifier')

    if [ "$has_secondary_source" = "$SOURCE_IDENTIFIER" ]; then
        # Get the sourceVersion from secondarySourceVersions (not secondarySources)
        source_version=$(echo "$project_details" | jq -r '.secondarySourceVersions[]? | select(.sourceIdentifier == "'$SOURCE_IDENTIFIER'") | .sourceVersion // "null"')

        if [ "$source_version" = "$CURRENT_SOURCE_VERSION" ]; then
            echo "Project $project has $SOURCE_IDENTIFIER secondary source with $CURRENT_SOURCE_VERSION version"

            # Count as candidate to update (dry-run or real run)
            updated_count=$((updated_count + 1))

            if [ "$DRY_RUN_MODE" = true ]; then
                echo "  [DRY-RUN] Would update secondary source to version $SOURCE_VERSION"
                echo "  [DRY-RUN] Command: aws codebuild update-project --name $project --secondary-source-versions '[{\"sourceIdentifier\": \"$SOURCE_IDENTIFIER\", \"sourceVersion\": \"$SOURCE_VERSION\"}]'"
            else
                # Update secondary source version to the specified version
                aws codebuild update-project --name $project --secondary-source-versions '[{"sourceIdentifier": "'$SOURCE_IDENTIFIER'", "sourceVersion": "'$SOURCE_VERSION'"}]' > /dev/null
                echo "Updated $project secondary source $SOURCE_IDENTIFIER to version $SOURCE_VERSION"
            fi
        else
            echo "Project $project has $SOURCE_IDENTIFIER but sourceVersion is '$source_version', not '$CURRENT_SOURCE_VERSION'"
            skipped_count=$((skipped_count + 1))
        fi
    else
        echo "Project $project does not have $SOURCE_IDENTIFIER secondary source"
        skipped_count=$((skipped_count + 1))
    fi
    sleep 1
done

echo "============================================="
echo "Summary"
echo "- Projects to update: $updated_count"
echo "- Projects not matching condition: $skipped_count"
