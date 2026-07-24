#!/usr/bin/env bash

hook_name="check-main"

# Import script(s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/script_utils.sh"

# Remove arguments that are just whitespace
eval "set -- $(remove_whitespace_args "$@")"

# Parse arguments
always_pass=0
while [[ $# -gt 0 ]]; do
    trimmed_arg=$(trim_val "$1")
    case "$trimmed_arg" in
    --always-pass)
        always_pass=1
        shift
        ;;
    *) 
        arg_type="$(get_arg_type "$1")"
        echo "$error_status Invalid $arg_type for $hook_name: '$1'" >&2
        exit 1
        ;;
    esac
done

# Get output severity level
severity="$(get_severity "$always_pass")"

# Flag to check if current branch is outdated
outdated=0

# pre-commit sets GIT_DIR; derive the worktree root from it
repo_root=$(git rev-parse --show-toplevel)

# Extract repo's name from repo_root
repo_name=$(basename "$repo_root")

# Target branch to check conflicts against
target_branch="origin/main"

# Silently fetch latest main
if ! git -C "$repo_root" fetch origin main >/dev/null 2>&1; then
    echo "$warning_status Could not reach remote for '$repo_name', skipping..." >&2
    exit 0
fi

# Perform an in-memory merge test against HEAD
conflict_output=$(git -C "$repo_root" merge-tree --write-tree HEAD "$target_branch" 2>&1 | grep -i "CONFLICT")

if [[ -n "$conflict_output" ]]; then
    outdated=1
    branch_name=$(git branch --show-current)
    echo "$severity Current branch '$branch_name' conflicts with '$target_branch':" >&2
    echo "$conflict_output" | sed "s/^/${indent}/" >&2
fi

if [[ $always_pass -eq 0 && $outdated -eq 1 ]]; then
    exit 1
fi

exit 0
