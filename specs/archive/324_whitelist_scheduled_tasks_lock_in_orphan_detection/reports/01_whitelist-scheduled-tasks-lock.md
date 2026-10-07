# Research Report: Task #324

**Task**: 324 - Whitelist scheduled_tasks.lock in orphan detection
**Started**: 2026-10-02T21:56:20Z
**Completed**: 2026-10-02T22:10:00Z
**Effort**: small (single-function pattern addition + doc table row + one test case)
**Dependencies**: None (task 323 is a concurrent sibling touching different files — no edit overlap)
**Sources/Inputs**: `lua/neotex/plugins/ai/shared/extensions/verify.lua`,
`agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`,
`agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`,
`agent-system/extensions/core/scripts/verify-deploy.sh`, `specs/reviews/review-2026-10-02.md`,
`specs/archive/317_post_deploy_reconcile_completed_tasks_ledger/`
**Artifacts**: this report
**Standards**: report-format.md, source-store-deploy-boundary.md

## Executive Summary

- `is_runtime_artifact()` in `lua/neotex/plugins/ai/shared/extensions/verify.lua` (lines 869-884)
  needs exactly one new branch: `rel == "scheduled_tasks.lock"`. The lock file lives at the
  `.claude/` tree root (confirmed by `find_orphans`'s calling convention — `rel` is already
  relative to `target_dir`, the same convention the existing `rel == "RESUME.md"` branch relies
  on), so no path prefix or wildcard is needed.
- No sibling lock files of the same class currently exist anywhere in the live `.claude/` tree,
  and no script in this repo (`agent-system/**`, `lua/**`) creates a file matching
  `*.lock`/`scheduled_tasks*` at the `.claude/` root — the creator is the external Claude Code
  scheduled-task/routine harness, not this repository's own copy engine or any of its scripts.
  **Recommendation: exact-match the single known filename rather than a glob** — there is no
  evidence of a naming family to generalize over, and the exclusion-contract doc's own stated
  principle is "do not add a class...without understanding which case it is."
- The exclusion-classes table to update is the **"Runtime artifact" row** (line 65) in
  `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` — add
  `scheduled_tasks.lock` to the Examples cell and one clause to the explanation, in the source
  store (never the deployed `.claude/context/patterns/deploy-orphan-detection.md` copy, per
  `rules/source-store-deploy-boundary.md`).
- **The task-250 cross-reference in this task's own description is mistaken** — see Findings
  below. The "sandbox orphan tmp file" note actually lives in task 317's archived artifacts, and
  it names a *different* file (`tmp/noop-bash-count-...`) that is unrelated to
  `scheduled_tasks.lock`. This does not change what to build; it only corrects the paper trail.
- A regression test case following the existing `tmp/workflow-active-test-canary` pattern in
  `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` (around line 145-191) is
  the direct way to satisfy acceptance criterion 4 ("green with a lock present, not merely
  absent").

## Context & Scope

Task 324 is a defect fix: `verify-deploy.sh` gate 13 (`find_orphans`, whole-tree orphan
detection) false-positives on `.claude/scheduled_tasks.lock`, a session-acquired runtime lock
file created by the Claude Code scheduled-task/routine mechanism (contents: `sessionId`, `pid`,
`acquiredAt`) — never by this repo's copy engine (`loader.copy_category`). The fix is narrowly
scoped: add one exclusion pattern, update its companion doc table, and verify gate 13 stays
green with the lock file present.

## Findings

### Existing Configuration — `is_runtime_artifact()`

`lua/neotex/plugins/ai/shared/extensions/verify.lua:869-884`:

```lua
local function is_runtime_artifact(rel)
  if rel:match("^tmp/workflow%-active%-") then
    return true
  end
  if rel == "RESUME.md" then
    return true
  end
  if rel:match("__pycache__/") or rel:match("%.pyc$") then
    return true
  end
  -- literature extension's Python virtualenv, provisioned on first use by the declared script
  -- literature-pyenv-provision.sh itself -- the venv's own contents are never declared.
  if rel:match("^scripts/literature%-pyenv/venv/") then
    return true
  end
  return false
end
```

`rel` is confirmed (by `M.find_orphans`'s call site at line ~947, iterating
`scan_directory_recursive(target_dir)`) to already be relative to `target_dir` (`.claude` or
`.opencode`). The `rel == "RESUME.md"` branch is the direct precedent for a bare root-level
filename match — `.claude/scheduled_tasks.lock` is the same shape:
`rel == "scheduled_tasks.lock"`.

**Sibling-lock survey (dispatch step 2).** Searched the live `.claude/` tree root (currently no
lock file present — it is transient, created only while a scheduled/cron task holds it) and
grepped `agent-system/**` and `lua/**` for any script creating a `.lock` file directly under
`.claude/`'s root: none exists. The only `*.lock` artifacts this repo's own scripts create live
under `specs/` (`.events.lock`, `.errors.lock`, per-task `.lock/` directories — see
`agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`), a completely separate
class serving a different mechanism (orchestrator session-scoped runtime state, documented in
`context/standards/orchestrator-runtime-files.md`), not applicable here. There is therefore no
in-repo evidence of a naming family (e.g. per-schedule-id lock files) to generalize the pattern
over. Decision: **exact match `scheduled_tasks.lock`**, not a glob — matching the specificity of
the existing `RESUME.md` branch, and consistent with the exclusion-doc's own stated discipline
("Do not add a class to make a single anomalous path go away without understanding which case it
is").

### Companion Documentation — exclusion-classes table

`agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` line 65, the
**Runtime artifact** row:

```
| **Runtime artifact** | `tmp/workflow-active-*`, `RESUME.md`, `scripts/__pycache__/*.pyc`, `scripts/literature-pyenv/venv/**` | Created or populated at execution time by running commands/hooks/scripts, not by the copy engine. ... |
```

This is the row to extend: add `scheduled_tasks.lock` to the Examples cell, and extend the
explanation sentence with a clause parallel to the existing `tmp/workflow-active-*` clause
("`tmp/workflow-active-*` are session-lock files") — e.g. "`scheduled_tasks.lock` is a
session-acquired lock file written by the scheduled-task mechanism (sessionId/pid/acquiredAt),
never by the copy engine." **Edit target confirmed**: there are two files with this name —
`.claude/context/patterns/deploy-orphan-detection.md` (deployed copy — never edit) and
`agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` (source store — edit
here), per `rules/source-store-deploy-boundary.md`.

### Gate 13 call site

`agent-system/extensions/core/scripts/verify-deploy.sh:723-753` invokes
`manager.find_orphans(target_dir)` under headless nvim and prints `ORPHAN_FINDING orphan file:
<rel>` for anything not excluded. No changes needed here — the fix is entirely inside
`is_runtime_artifact()`'s classification, which this call site already consumes correctly.

### Test precedent for acceptance criterion 4

`agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh:145-191` already contains the
exact template to copy: Assertion B plants `tmp/workflow-active-test-canary` into the scratch
deployed tree after a real `deploy-headless.sh` run, re-invokes `find_orphans` via headless nvim,
and asserts the planted path is **excluded** (not reported as `ORPHAN_FINDING`). A new assertion
following this shape — plant `.claude/scheduled_tasks.lock` with placeholder JSON content, assert
it is excluded — directly satisfies dispatch acceptance criterion 4 ("Confirm gate 13 is green
with a scheduled-task lock present — not merely absent"), which a mere "the file happens to be
absent during today's manual run" check would not.

### Task-250 cross-reference — re-confirmed, and it is NOT the same file

The dispatch explicitly asks to re-confirm whether task 250's "sandbox orphan tmp file" note
describes the same orphan. It does not, and moreover the citation itself appears to misattribute
the number:

- No task directory numbered 250 exists in `specs/archive/` for this topic. The only task 250
  artifacts found (`specs/vault/01-vault/archive/250_embed_vault_detection_in_archive_stage/`,
  a much older vault-archived task from a prior numbering generation) have no mention of orphan
  detection, `scheduled_tasks.lock`, or "sandbox orphan" anywhere in their files.
- The literal phrase **"a sandbox orphan tmp file"** is found instead in
  `specs/archive/317_post_deploy_reconcile_completed_tasks_ledger/` (plan line 360 and the
  phase-4 handoff), where it names the file `tmp/noop-bash-count-...` explicitly: *"a sandbox
  orphan tmp file (tmp/noop-bash-count-...)"* — describing a transient test-harness tmp file,
  not a lock file, and not `.claude/scheduled_tasks.lock`.

**Conclusion**: the two notes describe two different orphan files entirely (a `tmp/noop-bash-
count-*` sandbox artifact recorded as out-of-scope by task 317, versus today's
`.claude/scheduled_tasks.lock`), and the citing task number in this task's own description
("Task 250") does not match where that phrase actually lives (task 317). This is a paper-trail
correction only — it does not change the fix, and `tmp/noop-bash-count-*` is explicitly out of
scope for task 324 (no evidence it's a recurring/current gate-13 finding; task 317 is already
completed and archived with it noted as pre-existing and unrelated to that task). No new task is
filed for it per this agent's constraints (context-gap tasks are disabled); if it resurfaces as a
live gate-13 finding it would need its own fresh verification, not a speculative pattern added
here.

### Recommendations

1. In `lua/neotex/plugins/ai/shared/extensions/verify.lua`, add to `is_runtime_artifact()`
   (immediately after the `rel == "RESUME.md"` branch, matching its shape):
   ```lua
   if rel == "scheduled_tasks.lock" then
     return true
   end
   ```
   Add a one-line comment above it mirroring the existing literature-venv comment style,
   explaining the file is session-acquired runtime state from the scheduled-task mechanism.
2. In `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` line 65, add
   `scheduled_tasks.lock` to the Runtime-artifact row's Examples list and extend the explanation
   clause as described above. Edit the source-store copy only.
3. Add one assertion to `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`
   following the `tmp/workflow-active-test-canary` template (plant, re-run `find_orphans`, assert
   excluded) to make "lock present -> still green" a durable regression check, not a one-time
   manual confirmation.
4. No change needed to `.claude/.gitignore` / its source
   (`agent-system/extensions/core/...gitignore` if one exists) — out of this task's explicit
   scope, and the file's git-tracking status is orthogonal to gate 13's deploy-tree scan. Noting
   only as an aside: `scheduled_tasks.lock` is not currently gitignored at the project root
   either, so an accidental `git add -A` while a schedule is running could track it — a separate,
   unfiled observation, not acted on here.

## Decisions

- Exact-match pattern (`rel == "scheduled_tasks.lock"`), not a glob, given no evidence of a
  naming family and the doc's own anti-speculation principle.
- Fix verified via a planted-file regression test addition (dispatch criterion 4), not only a
  manual one-off run.
- Task-250 citation treated as a documentation correction to surface in the plan/summary, not a
  blocking question — the underlying fix is unambiguous regardless of which task number first
  recorded the adjacent "sandbox orphan tmp file" note.

## Risks & Mitigations

- **Risk**: generalizing the pattern to a glob (e.g. `^scheduled_tasks.*%.lock$`) could
  accidentally swallow a future *real* orphan with a similar name. **Mitigation**: exact match,
  as decided above; revisit only if a genuine naming family is observed empirically (per the
  doc's own measurement-recipe discipline).
- **Risk**: editing the wrong (deployed) copy of `deploy-orphan-detection.md`.
  **Mitigation**: explicitly confirmed both file locations above; edit only
  `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`.
- **Risk**: declaring gate 13 green without the lock file actually present during verification
  (false confidence). **Mitigation**: the planted-file test case (recommendation 3) exercises the
  present-case directly, satisfying acceptance criterion 4 without depending on a scheduled task
  happening to be mid-execution during manual `verify-deploy.sh` runs.

## Context Extension Recommendations

None — this is a narrow, well-precedented defect fix (`is_runtime_artifact()` already documents
its own extension pattern and the companion doc already exists and is actively maintained for
exactly this purpose).

## Appendix

### Search queries / commands used

- `grep -n "is_runtime_artifact\|local function is_runtime" lua/neotex/plugins/ai/shared/extensions/verify.lua`
- `sed -n '866,1010p' lua/neotex/plugins/ai/shared/extensions/verify.lua` (is_runtime_artifact, find_orphans)
- `find . -iname "deploy-orphan-detection.md"` (confirmed source + deployed copy both exist)
- `grep -rn "scheduled_tasks.lock" .` (repo-wide; only TODO.md/state.json/ROADMAP.md/review doc —
  no creator script in-repo)
- `grep -rln "sandbox orphan tmp file" specs/` (resolved the task-250 cross-reference to task 317)
- `find specs/archive -maxdepth 1 -iname "250_*"` / `git log --all --oneline | grep "task 250"`
  (confirmed no archived task 317-shape content under number 250; found the unrelated vault-era
  task 250 instead)
- `grep -n "RESUME.md\|workflow-active" agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`
  (located the regression-test template to extend)
- `grep -n "gate 13\|find_orphans" agent-system/extensions/core/scripts/verify-deploy.sh`
  (confirmed gate 13 call site needs no change)

### References

- `lua/neotex/plugins/ai/shared/extensions/verify.lua:869-884` (`is_runtime_artifact`)
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md:63-67` (exclusion
  table, Runtime-artifact row)
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh:145-191` (test template)
- `agent-system/extensions/core/scripts/verify-deploy.sh:723-753` (gate 13 call site)
- `specs/reviews/review-2026-10-02.md:61-80` (originating review finding)
- `specs/archive/317_post_deploy_reconcile_completed_tasks_ledger/plans/01_reconcile-ledger-and-commit.md:360`
  (source of the misattributed "sandbox orphan tmp file" phrase)
