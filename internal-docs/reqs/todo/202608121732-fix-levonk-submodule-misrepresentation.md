# Handoff: Fix levonk submodule misrepresentation (tree instead of commit)

## Git State

- **Parent repo HEAD**: `6dfc532c86f20ca82cc9ae081c8e72be6dbb7e81`
- **Submodule (levonk) HEAD**: `60b9d953dc980ad49cbaed8884882e1d4fc9c9bc`
- **Date captured**: 2026-08-12 17:32 PT

## Required Reading

Before any other action, read `/Users/micro/p/gh/levonk/infrahub/AGENTS.md` — it is the root of this project's progressively-disclosed informational files (JIT index, binding contracts, conventions). Follow its Usage Protocol and re-read the chain for any path you touch. Pay special attention to the submodule rules — the AGENTS.md explicitly says "NEVER convert git submodules to regular directories."

## Current State

### The problem

The `levonk/` directory is tracked in the parent repo as a **regular directory (`040000 tree`)** instead of a **git submodule (`160000 commit`)**. This means every file inside `levonk/` is tracked directly in the parent repo's object database, rather than the parent repo pointing to a submodule commit hash.

This was **not caused by our session** — it's a pre-existing issue.

### When it happened

Commit `9704d5e058ae6cef9a936e589cf8d55c010be7c9` (HEAD~17, dated Aug 9 2026) — "fix: remove client-specific data from shared/ (ADR-20260624001 compliance)" — accidentally converted `levonk/` from a submodule to a regular tree. That commit added 28 `levonk/` files directly into the parent repo (including `levonk/.gitignore`, `levonk/AGENTS.md`, `levonk/README.md`, `levonk/SERVICES.md`, etc.).

Verification:
```
HEAD~18 (9e9cb79b): 160000 commit  ← correct (submodule)
HEAD~17 (9704d5e0): 040000 tree    ← broken (converted to tree)
HEAD~16 through HEAD: all 040000 tree
```

Every commit since (17 commits including ours) has tracked `levonk/` files directly in the parent repo.

### What's safe (will NOT be lost)

1. **Submodule commit `60b9d95`** is safely stored in the submodule's own git database at `.git/modules/levonk/`. It has the correct remote (`git@github-l:levonk/priv-infra.git`) and is on branch `master`. This commit contains our inventory change (making `macos_gui_user` optional).

2. **Parent commit `6dfc532`** tracked the `levonk/active/02-config/ansible/inventories/macos-hosts.yml` file directly (as a tree file). The content is preserved in the parent repo's object database, but the tracking method is wrong.

### What needs to happen

The submodule structure must be restored so the parent repo tracks `levonk/` as a `160000 commit` pointing to the submodule's HEAD. This requires:

1. **Remove the tree-tracked `levonk/` files from the parent repo's index** (without deleting the working tree or the submodule's `.git/modules/levonk/` database).
2. **Re-add `levonk/` as a submodule** pointing to commit `60b9d95` (current submodule HEAD).
3. **Verify** that `git ls-tree HEAD levonk` shows `160000 commit` (not `040000 tree`).
4. **Verify** that `git submodule status` shows the submodule.
5. **Verify** that the working tree under `levonk/` is unchanged (all files still present).

### Danger zones

- **DO NOT** `rm -rf levonk/` or delete `.git/modules/levonk/` — this would destroy the submodule's git database and our commit.
- **DO NOT** `git rm levonk/` without first ensuring the submodule's git database at `.git/modules/levonk/` is preserved.
- **DO NOT** use `git submodule add` as a fresh add — it may try to re-clone instead of reusing the existing `.git/modules/levonk/` database.
- The AGENTS.md has strict rules about submodules — read them before proceeding.

## Project Overview

The infrahub repo uses `levonk/` as a private git submodule (URL: `git@github-l:levonk/priv-infra.git`, branch: `master`). The `.gitmodules` file still has the correct entry. The `.git/config` still has `submodule.levonk.url` and `submodule.levonk.active`. The submodule's git database at `.git/modules/levonk/` is intact. Only the parent repo's **index/tree tracking** is wrong — it tracks files instead of a commit hash.

## Key Decisions

- Our session's changes (macos-xcode multi-user App Store sign-in detection) are complete and committed in both repos.
- The submodule misrepresentation is a pre-existing issue that should be fixed before pushing, to avoid propagating the broken state to the remote.
- The fix should preserve all working tree files and the submodule's git database.

## Technical Context

### Repo structure
- Parent repo: `/Users/micro/p/gh/levonk/infrahub` (public, `git@github-l:levonk/infrahub.git`)
- Submodule: `levonk/` → `git@github-l:levonk/priv-infra.git` (private)
- `.gitmodules` entry: correct (path=levonk, url=git@github-l:levonk/priv-infra.git, branch=master)
- `.git/modules/levonk/`: intact (submodule's git database, on branch master, HEAD=60b9d95)
- `levonk/.git`: file containing `gitdir: ../.git/modules/levonk` (correct gitfile)

### What's broken
- `git ls-tree HEAD levonk` → `040000 tree 35dc53090e393506b09e6a9b108e2aaa56eafed4` (should be `160000 commit <sha>`)
- `git submodule status` → empty output (should show `+60b9d95... levonk (master)`)
- Parent repo has 28+ levonk/ files tracked directly in its object database

### Suggested fix approach (verify before executing)
```bash
# 1. Remove levonk/ from the parent repo's index (keep working tree)
git rm --cached -r levonk/

# 2. Re-add as submodule (should reuse existing .git/modules/levonk/)
git submodule add --force git@github-l:levonk/priv-infra.git levonk

# 3. Pin submodule to the correct commit
cd levonk && git checkout 60b9d95 && cd ..

# 4. Stage and commit
git add levonk .gitmodules
git commit -m "fix: restore levonk as git submodule (was accidentally converted to tree in 9704d5e)"

# 5. Verify
git ls-tree HEAD levonk  # should show 160000 commit
git submodule status     # should show the submodule
```

**IMPORTANT**: Test this on a backup branch first (`git checkout -b fix-submodule-test`). Verify the working tree under `levonk/` is unchanged after the fix. If `git submodule add` tries to re-clone instead of reusing `.git/modules/levonk/`, stop and investigate — the existing database must be preserved.

### Verification commands
```bash
git ls-tree HEAD levonk                    # expect: 160000 commit <sha>
git submodule status                       # expect: 60b9d95... levonk (master)
ls levonk/active/02-config/ansible/inventories/macos-hosts.yml  # expect: file exists
cd levonk && git log --oneline -1          # expect: 60b9d95
cd levonk && git status                    # expect: clean working tree
```

## Next Steps

1. **Read AGENTS.md** — follow the submodule rules before attempting any fix.
2. **Create a backup branch** — `git checkout -b fix-submodule-test` before doing anything.
3. **Fix the submodule tracking** — remove `levonk/` from index as tree, re-add as submodule pointing to `60b9d95`.
4. **Verify** — `git ls-tree HEAD levonk` shows `160000 commit`, `git submodule status` works, working tree unchanged.
5. **Commit the fix** — with a clear message explaining the broken state was inherited from commit `9704d5e`.
6. **Consider history** — 17 commits have the broken tree tracking. Decide whether to fix only going forward (recommended) or rewrite history (risky, requires force-push coordination). Forward-fix is safer.
7. **Do NOT push** until the user confirms the fix is correct.

## Definition of Done

Mark legend:
- `[ ]` pending
- `[~]` in progress
- `[x]` done (verified)
- `[!]` blocked (blocker in parentheses)

Maintenance protocol:
1. Verify in-progress `[~]` tasks are actually being worked — check `git status`, `git diff`, running processes. Demote stale `[~]` to `[ ]`.
2. Start the first available `[ ]` task in priority order.
3. Prefer subagents for parallel work when tasks are independent (no shared file writes).
4. Mark `[x]` only after verifying success criteria (build passes, test passes, file exists).
5. Record blockers inline: `- [!] {task blocked (reason)}`.
6. Append newly discovered tasks as `[ ]` in priority order. Mark obsolete tasks `[x]` with a note.

- [ ] Read AGENTS.md submodule rules before attempting any fix
- [ ] Create a backup branch (`git checkout -b fix-submodule-test`)
- [ ] Remove `levonk/` from parent repo index as tree (`git rm --cached -r levonk/`)
- [ ] Re-add `levonk/` as submodule pointing to commit `60b9d95`
- [ ] Verify `git ls-tree HEAD levonk` shows `160000 commit` (not `040000 tree`)
- [ ] Verify `git submodule status` shows the submodule
- [ ] Verify working tree under `levonk/` is unchanged (all files present, `git status` clean in submodule)
- [ ] Commit the fix with a descriptive message
- [ ] Do NOT push — wait for user confirmation

## Success Criteria

- `git ls-tree HEAD levonk` outputs `160000 commit <sha>` (not `040000 tree`)
- `git submodule status` shows `60b9d95... levonk (master)` (or similar)
- All files under `levonk/` are still present in the working tree
- `cd levonk && git status` shows a clean working tree
- `cd levonk && git log --oneline -1` shows `60b9d95`
- No data loss — the submodule's git database at `.git/modules/levonk/` is intact

## Open Questions

- Should the 17 commits of broken history be rewritten (interactive rebase / filter-branch) or fixed forward-only? Forward-fix is recommended — history rewriting risks losing data and requires force-push coordination.
- Are there other clones of this repo that need the same fix? If so, a clean `git submodule update --init --recursive` after pulling the fix commit should resolve them.

## Do Not

- **DO NOT** `rm -rf levonk/` — this destroys the working tree
- **DO NOT** delete `.git/modules/levonk/` — this destroys the submodule's git database and commit `60b9d95`
- **DO NOT** `git push --force` without explicit user confirmation
- **DO NOT** use `git submodule deinit` — it may remove the submodule's git database
- **DO NOT** add AI attribution to commits (per AGENTS.md rules)

## Suggested Skills

- `git-repository-management` — for safe commit workflow
- `monorepo-extractor` — may have relevant patterns for submodule/tree manipulation

## Additional Context

### Our session's work (already committed, safe)

The macos-xcode role changes are complete and committed:
- Parent commit `6dfc532`: "feat(macos-xcode): multi-user App Store sign-in detection for mas" (7 files: bootstrap script, xcode role tasks/defaults/README/handlers/meta)
- Submodule commit `60b9d95`: "feat(macos): add optional macos_gui_user variable for xcode role" (1 file: inventory)

These commits are safe and will not be lost when the submodule tracking is fixed — the content is in both the object databases and the working tree.

### Pre-existing uncommitted changes (not ours, not part of this handoff)

The working tree has other uncommitted changes that predate our session and are unrelated to the submodule fix:
- `justfile` — macOS recipes (bootstrap, configure, install-xcode)
- `shared/active/02-config/ansible/infrastructure/apps.yml` — Xcode variables
- `shared/active/02-config/ansible/playbooks/configure-macos-host.yml` — xcode role include
- `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/middlewares.yml.j2` — unrelated
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/tasks/main.yml` — unrelated
- `internal-docs/feature/2026/08/dnshub/` — untracked, unrelated
- `internal-docs/research/service/dnshub/` — untracked, unrelated

These should be left as-is — they are not part of this handoff's scope.
