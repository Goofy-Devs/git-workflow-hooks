#!/usr/bin/env python3

import argparse
import hook_utils as hu
import subprocess
import sys
import os

def main():
    # Extract submodules
    proc = subprocess.run(
        ["git", "config", "--file", ".gitmodules", "--get-regexp", r"\.path$"],
        capture_output=True,
        text=True,
    )
    if not proc.returncode:
        submodule_paths = { line.split(maxsplit=2)[1] for line in proc.stdout.splitlines() if line }
    else:
        submodule_paths = set()

    if not len(submodule_paths):
        print(f"{hu.WARNING} No submodules found\n")
        sys.exit(0)

    # Declare valid options/flags and parse arguments 
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument(
        "--always-pass",
        action="store_true",
        help="The hook will always pass unless there is a problem with the arguments given",
    )
    arg_parser.add_argument(
        "--submodule-path", 
        nargs='+', 
        choices=submodule_paths,
        metavar="PATH",
        help="One or more submodule paths to process",
    )
    args = arg_parser.parse_args()

    # Helper vars
    severity = hu.WARNING if args.always_pass else hu.ERROR # Set serverity level of output
    outdated = False # Flag that indicates if any submodules checked are outdated
    remote_branch = os.getenv("SUBMODULE_REMOTE_BRANCH") or "HEAD" # Get remote branch to compare current branch with

    # If specific submodule paths are provided, use those instead of checking every submodule (default)
    if args.submodule_path:
        submodule_paths = args.submodule_path

    for path in submodule_paths:
        # Check if submodule is initialized and obtain current hash that's staged
        proc = subprocess.run(
            ["git", "ls-files", "--stage", "--", path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        out = proc.stdout.split(maxsplit=2)
        pinned = out[1] if len(out) > 1 else ""
        if not pinned:
            print(f"{hu.WARNING} Submodule '{path}' listed in .gitmodules but not initialised, skipping...\n")
            continue

        # Obtain remote url for submodule
        proc = subprocess.run(
            ["git", "config", "--file", ".gitmodules", f"submodule.{path}.url"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        raw_url = proc.stdout.strip()
        if not raw_url:
            print(f"{hu.WARNING} Could not read remote URL for submodule '{path}', skipping...")
            continue

        # If the url obtained is relative, make it concrete
        if raw_url.startswith("../"):
            proc = subprocess.run(
                ["git", "remote", "get-url", "origin"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            parent_remote = proc.stdout.strip()

            if parent_remote:
                # Strip everything after the last '/'
                parent_base = parent_remote.rsplit('/', 1)[0]
                # Add the parent base to the raw url
                raw_url = f"{parent_base}/{raw_url.removeprefix('../')}"

        # Fetch the remote's hash
        proc = subprocess.run(
            ["git", "ls-remote", raw_url, remote_branch],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        out = proc.stdout.split(maxsplit=1)
        remote_sha = out[0] if out else ""
        if not remote_sha:
            print(f"{hu.WARNING} Could not reach remote for submodule '{path}', skipping...\n")
            continue

        # Continue if submodule is up to date
        if pinned == remote_sha:
            continue

        # Indicate that there's at lease one outdated submodule
        outdated = True

        print(f"{severity} Submodule '{path}' is out of date")
        print(f"{hu.INDENT}Current : {pinned}")
        print(f"{hu.INDENT}Remote  : {remote_sha}")
        print(f"{hu.INDENT}To update, run: {hu.HIGHLIGHTS.get('reverse', '')}git submodule update --remote {path} && git add {path}\n{hu.TEXT_RESET}")
    
    if not args.always_pass and outdated:
        sys.exit(1)
    sys.exit(0)

if __name__== "__main__":
    main()