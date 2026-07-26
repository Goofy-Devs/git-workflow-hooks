# git-workflow-hooks

A shared [pre-commit](https://pre-commit.com/) hook repository that provides automated checks for projects using Git submodules. Hooks run on every `git commit` to surface common issues before they reach CI.

---

## Hooks

### `check-submodules`

Checks every submodule declared in `.gitmodules` and **blocks the commit** by default if the designated submodule is pinned to a commit that is behind the remote HEAD.

**Problem it solves:** Submodules are pinned to a specific commit in the parent repo's index. When the submodule moves forward — new features, bug fixes, or breaking changes — the parent repo silently falls behind. Without a local check, stale submodule pointers only surface as confusing build or runtime failures in CI, which can take significant time to diagnose and trace back to a version mismatch.

**What it does:**

- Reads all submodule paths from `.gitmodules` automatically — no configuration needed when submodules are added
    - If you want to only check certain submodules, you can use the `--submodule-path` flag and pass in submodule paths that matches the path in `.gitmodules` right after (e.g., `--submodule-path submodule_1_path submodule_2_path` or `--submodule-path submodule_1_path --submodule-path submodule_2_path`).
    - For paths with white space(s), surround them in quotes (e.g., `--submodule-path "my module"`)
- Reads the pinned SHA directly from the git staging index (`git ls-files --stage`)
- Calls `git ls-remote` against the submodule's remote to get the current HEAD SHA — read-only, no working tree writes, works even if the submodule is not initialised locally
- If the designated submodule is stale, it fails, prints the current SHA, remote SHA, and the exact fix command.
    - If you don't want a stale module to block the commit, pass the `--always-pass` flag and set `verbose` to `true` for the warning(s) to print.
- Offline-safe: if the remote is unreachable the hook skips it but prints out a warning that it could not reach the remote.

**Example output when a submodule is stale:**

Without `--always-pass`:
```
check-submodules.........................................................Failed
- hook id: check-submodules
- duration: 0.58s
- exit code: 1

[ERROR] Submodule 'test_submodule' is out of date
    Current : <example hash 1>
    Remote  : <example hash 2>
    To update, run: git submodule update --remote test_submodule && git add test_submodule
```

With `--always-pass`:
```
check-submodules.........................................................Passed
- hook id: check-submodules
- duration: 0.56s

[WARNING] Submodule 'test_submodule' is out of date
    Current : <example hash 1>
    Remote  : <example hash 2>
    To update, run: git submodule update --remote test_submodule && git add test_submodule
```

**To fix:** run the printed command, then re-commit:

```bash
git submodule update --remote test_submodule 
git add test_submodule
git commit -m "your message"
```

**Environment variable overrides:**

| Variable | Default | Purpose |
|---|---|---|
| `SUBMODULE_REMOTE_BRANCH` | `HEAD` | Remote ref to compare against |

---

### `check-main`

Performs an **in-memory merge test** against `origin/main` and **blocks the commit** by default if conflicts are detected.

**Problem it solves:** Merge conflicts with `main` are easier to resolve when caught early — while the context is fresh and the diff is small. Without a local check, conflicts only surface during PR review or CI, requiring a context switch back to a branch that may be days old.

**What it does:**

- Fetches `origin/main` silently
- Uses `git merge-tree --write-tree` to test the merge in memory — no working tree modifications, no side effects
- If conflicts exist: **exits 1** (fails) and prints the conflicting files
    - If you don't want a merge conflict to block the commit, pass the `--always-pass` flag and set `verbose` to `true` for the warning(s) to print.
- Offline-safe: if the remote is unreachable the hook still passes but prints out a warning that it could not reach the remote. To see this warning, you must set `verbose` to `true`. 

**Example output when a conflict is detected:**

Without `--always-pass`:
```
check-main...............................................................Failed
- hook id: check-main
- duration: 0.65s
- exit code: 1

[ERROR] Current branch 'test_branch' conflicts with 'origin/main':
    CONFLICT (content): Merge conflict in <file_path 1>
    CONFLICT (content): Merge conflict in <file_path 2>
    CONFLICT (content): Merge conflict in <file_path 3>
    CONFLICT (content): Merge conflict in <file_path 4>
To resolve conflicts, merge or rebase: 
    * Merge: git fetch origin && git merge origin/main 
    * Rebase: git fetch origin && git rebase origin/main
After resolving the conflicts, push your changes to origin: 
    * After merge: git push -u origin test_branch
    * After rebase: git push -u origin test_branch --force-with-lease
```

With `--always-pass`:
```
check-main...............................................................Passed
- hook id: check-main
- duration: 0.63s

[WARNING] Current branch 'test_branch' conflicts with 'origin/main':
    CONFLICT (content): Merge conflict in <file_path 1>
    CONFLICT (content): Merge conflict in <file_path 2>
    CONFLICT (content): Merge conflict in <file_path 3>
    CONFLICT (content): Merge conflict in <file_path 4>
To resolve conflicts, merge or rebase: 
    * Merge: git fetch origin && git merge origin/main 
    * Rebase: git fetch origin && git rebase origin/main
After resolving the conflicts, push your changes to origin: 
    * After merge: git push -u origin test_branch
    * After rebase: git push -u origin test_branch --force-with-lease
```

**To fix:** rebase or merge `main` into your branch, resolve conflicts, then re-commit:

```bash
git fetch origin
git rebase origin/main
# resolve any conflicts
git add .
git commit -m "your message"
```

---

## Usage

**Add the following to your project's `.pre-commit-config.yaml`:**

If you want failures to block commits:
```yaml
- repo: https://github.com/Goofy-Devs/git-workflow-hooks
  rev: <tag-or-sha>
  hooks:
  - id: check-submodules
  - id: check-main
```
- Note: If you want to know if a submodule's remote or main's remote could not be reached, you need to add `verbose: true` to each hook like so:
    ```yaml
    - repo: https://github.com/Goofy-Devs/git-workflow-hooks
      rev: <tag-or-sha>
      hooks:
      - id: check-submodules
        verbose: true
      - id: check-main
        verbose: true
    ```

If you want failures to never block commits:
```yaml
- repo: https://github.com/Goofy-Devs/git-workflow-hooks
  rev: <tag-or-sha>
  hooks:
  - id: check-submodules
    args: ["--always-pass"]
    verbose: true
  - id: check-main
    args: ["--always-pass"]
    verbose: true
```
- Note: It's very important that you include `verbose: true` because these hooks will always pass, and `pre-commit` is silent on pass by default. This setting allows warnings to print even on passes.

If you want to check only certain submodules:
```yaml
- repo: https://github.com/Goofy-Devs/git-workflow-hooks
  rev: <tag-or-sha>
  hooks:
  - id: check-submodules
    args: ["--always-pass", "--submodule-path", "submodule_1_path", "submodule_2_path"]
    verbose: true
```
- Note that the argument(s) passed to `--submodule-path` must match the submodule path in `.gitmodules`.

Then install pre-commit and the hooks:

```bash
pip install pre-commit
pre-commit install
```

Both hooks will run automatically on every `git commit`. To run them manually against all files:

```bash
pre-commit run --all-files
```

---

## Requirements

- [pre-commit](https://pre-commit.com/) >= 2.0
- git >= 2.38 (required by `check-main` for `git merge-tree --write-tree`)
- Python >= 3.9 (required for `str.removeprefix` used in `check-submodules`)
- Network access to submodule remotes (for `check-submodules`; degrades silently if offline)
