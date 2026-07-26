#!/usr/bin/env python3

import argparse
import hook_utils as hu
import os
import subprocess
import sys

def main():
    arg_parser = argparse.ArgumentParser()

    # Declare valid options/flags and parse arguments 
    arg_parser.add_argument(
        "--always-pass",
        action="store_true",
        help="The hook will always pass unless there is a problem with the arguments given",
    )
    args = arg_parser.parse_args()

    # Helper vars
    severity = hu.WARNING if args.always_pass else hu.ERROR # Set serverity level of output
    conflict = False # Flag that indicates whether there's a merge conflict with origin/main

    # Get root of repo
    proc = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    repo_root = proc.stdout.strip()

    # Get name of the repo
    repo_name = os.path.basename(repo_root)

    # Set target branch as origin/main
    target_branch = "origin/main"

    # Fetch the latest main
    proc = subprocess.run(
        ["git", "-C", repo_root, "fetch", "origin", "main"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if proc.returncode:
        print(f"{hu.WARNING} Could not reach remote for '{repo_name}', skipping...")
        sys.exit(0)

    # Perform an in-memory merge test against HEAD
    proc = subprocess.run(
        ["git", "-C", repo_root, "merge-tree", "--write-tree", "HEAD", target_branch],
        capture_output=True,
        text=True,
    )
    out = proc.stdout + proc.stderr
    conflict_output = "\n".join([ (hu.INDENT + line) for line in out.splitlines() if "merge conflict" in line.lower() ])

    # If there are merge conflicts, indicate where the conflicts are happening and how to fix them
    if conflict_output:
        conflict = True
        proc = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
        )
        branch_name = proc.stdout.strip()
        print(f"{severity} Current branch '{branch_name}' conflicts with '{target_branch}':")
        print(conflict_output)
        print(f"To resolve conflicts, run: {hu.HIGHLIGHTS.get('reverse', '')}git fetch origin && git merge main{hu.TEXT_RESET} or {hu.HIGHLIGHTS.get('reverse', '')}git fetch origin && git rebase main{hu.TEXT_RESET}")
        print(f"After resolving the conflicts, run: {hu.HIGHLIGHTS.get('reverse', '')}git push -u origin {branch_name}{hu.TEXT_RESET}")

    if not args.always_pass and conflict:
        sys.exit(1)
    sys.exit(0)

if __name__== "__main__":
    main()