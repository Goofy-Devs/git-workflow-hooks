#!/usr/bin/env bash

hook_name="check-submodules"

# Import script(s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/script_utils.sh"

# Remove arguments that are just whitespace
eval "set -- $(remove_whitespace_args "$@")"

# Parse arguments
always_pass=0
submodule_paths_args=()
while [[ $# -gt 0 ]]; do
  trimmed_arg=$(trim_val "$1")
  case "$trimmed_arg" in
    --submodule-path) 
      parse_flag_value "submodule_paths_args" "${@:2}"
      if [[ $shift_count -eq 1 ]]; then
        print_usage "option" "$1" "submodule_path"
        exit 1
      elif [[ -n "$parsed_val" ]]; then
        submodule_paths_args+=("$parsed_val")
      fi
      shift "${shift_count}"
      ;;
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

# Flag to check if any submodules checked are outdated
outdated=0

remote_branch="${SUBMODULE_REMOTE_BRANCH:-HEAD}"

# ── Collect all submodule paths from .gitmodules ─────────────────────────────
if [[ ! -f .gitmodules ]]; then
  exit 0  # No submodules in this repo — nothing to do
fi

submodule_paths=()
while IFS= read -r line; do
  submodule_paths+=("$line")
done < <(git config --file .gitmodules --get-regexp '\.path$' | awk '{print $2}')

if [[ ${#submodule_paths[@]} -eq 0 ]]; then
  exit 0
fi

# Filter out submodule args that aren't in .gitmodules
valid_submodules_paths=()
for path in "${submodule_paths_args[@]}"; do
  if ! contains_element "$path" "${submodule_paths[@]}"; then
    echo "$error_status Submodule '$path' does not exist in .gitmodules" >&2
    exit 1
  fi
  valid_submodules_paths+=("$path")
done

if [[ ${#valid_submodules_paths[@]} -gt 0 ]]; then
  submodule_paths=("${valid_submodules_paths[@]}")
fi

# ── Check each submodule ──────────────────────────────────────────────────────
for path in "${submodule_paths[@]}"; do

  # 1. Pinned commit from the staging index (what will actually be committed).
  #    git ls-files --stage reads the index directly, avoiding the working-tree
  #    confusion that `git submodule status` has with the +/-/U prefix.
  pinned=$(git ls-files --stage -- "$path" 2>/dev/null \
           | awk '{print $2}') || true

  if [[ -z "$pinned" ]]; then
    echo "$warning_status Submodule '$path' listed in .gitmodules but not initialised, skipping..." >&2
    echo "" >&2
    continue
  fi

  # 2. Remote URL for this submodule
  # Resolve relative URLs against the parent remote's base
  raw_url=$(git config --file .gitmodules \
            "submodule.${path}.url" 2>/dev/null) || true

  if [[ -z "$raw_url" ]]; then
    echo "$warning_status Could not read remote URL for submodule '$path', skipping..." >&2
    echo "" >&2
    continue
  fi

  # Expand "../sibling" relative URLs using the parent's origin URL
  if [[ "$raw_url" == ../* ]]; then
    parent_remote=$(git remote get-url origin 2>/dev/null) || true
    if [[ -n "$parent_remote" ]]; then
      parent_base="${parent_remote%/*}"
      raw_url="${parent_base}/${raw_url#../}"
    fi
  fi

  # 3. Fetch remote HEAD (network call — fail silently if offline or auth fails)
  remote_sha=$(git ls-remote "$raw_url" "$remote_branch" 2>/dev/null \
               | awk '{print $1}') || true

  if [[ -z "$remote_sha" ]]; then
    echo "$warning_status Could not reach remote for submodule '$path', skipping..." >&2
    echo "" >&2
    continue  # Unreachable remote — do not block or warn
  fi

  # 4. Compare — check if submodule is up to date
  if [[ "$pinned" == "$remote_sha" ]]; then
    continue
  fi

  outdated=1

  # 5. Stale — warn the developer but do not block the commit.
  echo "$severity Submodule '$path' is out of date" >&2
  echo "${indent}Current : $pinned" >&2
  echo "${indent}Remote  : $remote_sha" >&2
  echo "${indent}To update, run: git submodule update --remote $path && git add $path" >&2
  echo "" >&2

done

if [[ $always_pass -eq 0 && $outdated -eq 1 ]]; then
    exit 1
fi

exit 0
