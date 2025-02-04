#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check gh cli installation
check_gh_cli() {
    if ! command_exists gh; then
        echo "GitHub CLI (gh) is not installed."
        read -p "Would you like to install it using Homebrew? (y/n) " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            if command_exists brew; then
                brew install gh
            else
                echo "Error: Homebrew is not installed. Please install Homebrew first."
                exit 1
            fi
        else
            echo "Error: GitHub CLI is required for this script."
            exit 1
        fi
    fi

    # Check if authenticated with GitHub
    if ! gh auth status &>/dev/null; then
        echo "You need to authenticate with GitHub first."
        gh auth login
    fi
}

# Show usage instructions
show_usage() {
    echo "Usage: $0 <tag_name>"
    echo "Example: $0 v1.0.0"
    echo ""
    echo "This script will:"
    echo "1. Checkout the specified tag"
    echo "2. Create a new test render branch from the tag"
    echo "3. Create a random file with timestamp"
    echo "4. Commit and push the changes"
    echo "5. Create a PR using GitHub CLI"
    echo ""
    echo "Note: PR will be created with 'create-review-app' label"
    exit 1
}
if [ $# -ne 1 ]; then
    show_usage
fi

TAG_NAME="$1"
LABELS="create-review-app"
# Generate a unique branch name with timestamp
BRANCH_NAME="${TAG_NAME}-test-render-$(date +%Y%m%d%H%M%S)"

# Check for gh cli
check_gh_cli

# Ensure we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    exit 1
fi

# First checkout develop and get latest changes
echo "Checking out develop branch..."
if ! git checkout develop 2>/dev/null; then
    echo "Error: Failed to checkout develop branch"
    echo "Please ensure the develop branch exists and you have proper permissions"
    exit 1
fi

echo "Pulling latest changes from develop..."
if ! git pull origin develop 2>/dev/null; then
    echo "Error: Failed to pull latest changes from develop"
    echo "Please ensure you have proper access and your SSH/credentials are configured"
    exit 1
fi

# Check out the tag
echo "Checking out tag ${TAG_NAME}..."
if ! git checkout "$TAG_NAME" 2>/dev/null; then
    echo "Error: Failed to checkout tag ${TAG_NAME}"
    echo "Please ensure the tag exists and you have the latest tags:"
    echo "git fetch --all --tags"
    exit 1
fi

# Create and checkout new branch with timestamp
echo "Creating new branch ${BRANCH_NAME}..."
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Error: Branch ${BRANCH_NAME} already exists"
    echo "A new branch with timestamp will be created instead"
fi

if ! git checkout -b "$BRANCH_NAME"; then
    echo "Error: Failed to create branch ${BRANCH_NAME}"
    echo "Please ensure you have proper permissions and the branch name is valid"
    exit 1
fi

# Create random file with timestamp
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
RANDOM_FILE="random_file_${TIMESTAMP}.txt"
echo "Creating random file ${RANDOM_FILE}..."
echo "Random test content created at $(date)" > "$RANDOM_FILE"

# Add and commit changes
echo "Committing changes..."
git add "$RANDOM_FILE"
if ! git commit -m "Add random test file generated from ${TAG_NAME}"; then
    echo "Error: Failed to commit changes"
    exit 1
fi

# Push changes
echo "Pushing changes..."
if ! git push -u origin "$BRANCH_NAME"; then
    echo "Error: Failed to push changes"
    exit 1
fi

# Create PR
echo "Creating Pull Request..."
PR_URL=$(gh pr create \
    --title "DO NOT MERGE | Test Render | ${TAG_NAME}" \
    --body "Created a new branch from tag ${TAG_NAME} with test changes" \
    --label "$LABELS" \
    --base develop)

echo "Pull request created successfully!"
echo "PR URL: ${PR_URL}"

