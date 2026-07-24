#!/usr/bin/env bash

info_status="[INFO]"
info_status_pad=$(printf '%*s' "${#info_status}" '')
warning_status="[WARNING]"
warning_status_pad=$(printf '%*s' "${#warning_status}" '')
error_status="[ERROR]"
error_status_pad=$(printf '%*s' "${#error_status}" '')
indent="    "

# Remove all arguments that are just whitespace
remove_whitespace_args() {
    local trimmed_args=()
    for a in "$@"; do
        if [[ "$a" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        trimmed_args+=("$a")
    done
    # Print quoted arguments for easy restoration with eval
    if [[ ${#trimmed_args[@]} -gt 0 ]]; then
        printf '%q ' "${trimmed_args[@]}"
    fi
}

# Trims the value passed to it
trim_val() {
    local trimmed_val="${1#"${1%%[![:space:]]*}"}"
    trimmed_val="${trimmed_val%"${trimmed_val##*[![:space:]]}"}"
    echo "$trimmed_val"
}

# Get argument type, whether it's just a regular argument or an option
get_arg_type() {
    local arg_type="argument"
    if [[ "$1" == -* ]]; then
        arg_type="option"
    fi
    echo "$arg_type"
}

# Print the usage of a certain command or option when an invalid argument is given
print_usage() {
    local type=$1
    local name=$2
    local example_arg=$3
    echo "$error_status Missing required argument for $type $name" >&2
    echo "$error_status_pad Example usage in .pre-commit-hooks.yaml:" >&2
    echo "$error_status_pad ${indent}args: [\"$name\", \"<$example_arg>\"]" >&2
}

# Get severity level based off the arg passed to it
get_severity() {
    if [[ $1 -eq 1 ]]; then
        echo "$warning_status"
    else
        echo "$error_status"
    fi
}

# Check if an array contains an element
contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Parse flags that take in arguments and set global vars shift_count and parsed_val
parse_flag_value() {
    # Get hook name, array name, and flag name from args
    local array_name="$1"
    shift

    # Case 1: Option followed by value
    if [[ $# -ge 1 && -n "$1" ]]; then
        if ! contains_element "$1" $(eval echo "\${${array_name}[@]}"); then
            shift_count=2
            parsed_val="$1"
        else
            shift_count=2
            parsed_val=""
        fi
        return 0
    fi

    # Case 2: Missing arg for option
    parsed_val="${1:-<no arg passed>}"
    shift_count=1
    return 1
}