# Implementation Plan: Declare migrate-state-legacy-fields.sh in core manifest

- **Task**: 323 - Declare migrate-state-legacy-fields.sh in core manifest
- **Status**: [NOT STARTED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/323_declare_migrate_state_legacy_fields_in_core_manifest/reports/01_declare-script-in-manifest.md
- **Artifacts**: plans/01_declare-script-in-manifest.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` is live, executable, and
git-tracked in the core extension's source store, but was never added to `provides.scripts` in
`agent-system/extensions/core/manifest.json`. `check-extension-docs.sh` therefore emits
`FAIL: script file on disk NOT in provides.scripts` for `[core]`, which is one of the two causes
of the current `verify-deploy.sh --skip-slow` regression from FAIL 1/33 to FAIL 2/33 (gate 3,
doc lint). The fix is a single string insertion into a flat JSON array, plus one substantive
README refresh that also clears the adjacent mtime-based `README.md older than manifest.json`
WARN. Done means: `[core]` is clean of that FAIL and that WARN, and `verify-deploy.sh --skip-slow`
gate 3 is green.

### Research Integration

Report `01_declare-script-in-manifest.md` independently reproduced both the FAIL and the WARN,
traced the three relevant `check-extension-docs.sh` checks, and resolved the three questions this
plan would otherwise have had to guess at:

- **Insertion point**: `provides.scripts` is a flat JSON string array of 199 entries, locally
  alphabetical; `"migrate-directory-padding.sh"` is present at index 65 and
  `"migrate-state-legacy-fields.sh"` belongs immediately after it. No consumer is
  ordering-sensitive (`check_undeclared_scripts`, Rule Q, does a membership-only `jq -e` test),
  so ordering is style, not function.
- **README WARN is a pure mtime comparison** (`check_readme_vs_manifest`, line ~979), not
  content-based. Any README edit saved *after* the manifest edit clears it. The genuinely stale
  "Scripts | 27" row in the Overview table and the matching `# 27 utility scripts` comment in the
  Architecture tree make a substantive edit available, so no no-op `touch` is needed or wanted.
- **One new ADVISORY is expected and is not a regression**: `check_core_deploy_advisory`
  (Rule O) will begin emitting `ADVISORY: core script never deployed:
  scripts/migrate-state-legacy-fields.sh`, because the script has never been copied to
  `.claude/scripts/`. `check-extension-docs.sh` exits non-zero only on FAIL, and gate 3 excludes
  ADVISORY lines from its FAIL extraction; its narrower `STRICT_CORE_DEPLOY=1` sub-check greps
  only for the literal `events-`, which this filename does not match. Deploying the script is
  explicitly out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Add `"migrate-state-legacy-fields.sh"` to `provides.scripts` in
  `agent-system/extensions/core/manifest.json` (the source store, never `.claude/**`).
- Refresh the stale script count in `agent-system/extensions/core/README.md`, resolving genuine
  content drift and clearing the mtime-based WARN in the same edit.
- Confirm `[core]` is clean in `check-extension-docs.sh` and that `verify-deploy.sh --skip-slow`
  gate 3 is green (overall FAIL count back to 1/33, the remaining failure belonging to sibling
  task 324).

**Non-Goals**:
- Deploying `migrate-state-legacy-fields.sh` to `.claude/scripts/`. The resulting ADVISORY is
  expected, non-blocking, and separately actionable.
- Writing an exhaustive per-script enumeration into README.md. The file is a
  representative-sample inventory by design; no sibling migration script (including
  `migrate-directory-padding.sh`) is named individually.
- Auditing or correcting the other stale counts in the README Overview table beyond the Scripts
  row (and its Architecture-tree twin). Out of scope for this defect.
- Touching anything in sibling task 324's territory
  (`lua/neotex/plugins/ai/shared/extensions/verify.lua`,
  `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`), or the gate 13
  orphan false positive.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing the deployed `.claude/manifest.json` / `.claude/README.md` instead of the source store; the fix appears to work then is silently wiped by the next deploy | H | M | `.claude-extensions.json`'s `extensions.core.source_dir` resolves to `agent-system/extensions/core`; edit only there, per `rules/source-store-deploy-boundary.md`. Both phases state the absolute source-store path. |
| Malformed JSON from a hand-edited array insertion | H | L | Validate with `jq empty` (or `python3 -m json.tool`) immediately after the edit, before any other step; Phase 1 verification requires it. |
| The expected post-fix ADVISORY is misread as a leftover defect and triggers an out-of-scope deploy | M | M | Research traced gate 3's FAIL-extraction and `STRICT_CORE_DEPLOY` logic: the advisory cannot regress gate 3. Recorded as a Non-Goal and in Phase 3's verification notes. |
| README edit is saved *before* the manifest edit, leaving the mtime WARN in place | L | M | Phase 2 depends on Phase 1 and is ordered after it; Phase 3 re-runs the check and would surface a surviving WARN. |
| A sibling task's concurrent edit lands in a shared file | M | L | No file overlap with task 324's declared scope. Still re-read each file immediately before editing and stage only this task's own hunks (explicit file paths, never a directory or glob `git add`). |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. Here the chain is strictly sequential:
Phase 2 must be saved after Phase 1 for the mtime WARN to clear, and Phase 3 verifies both.

---

### Phase 1: Declare the script in provides.scripts [NOT STARTED]

**Goal**: `agent-system/extensions/core/manifest.json` declares
`scripts/migrate-state-legacy-fields.sh`, clearing `check-extension-docs.sh`'s Rule Q FAIL for
`[core]`.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/manifest.json` immediately before editing (sibling
      task active this cycle).
- [ ] Confirm the script is still on disk, executable, and git-tracked:
      `git ls-files agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh`.
- [ ] Confirm `"migrate-state-legacy-fields.sh"` is still absent from `provides.scripts` and
      locate the current index of `"migrate-directory-padding.sh"`.
- [ ] Insert the string `"migrate-state-legacy-fields.sh"` into `provides.scripts` immediately
      after `"migrate-directory-padding.sh"`, matching the surrounding indentation exactly.
- [ ] Validate JSON: `jq empty agent-system/extensions/core/manifest.json`.
- [ ] Confirm membership: `jq -e '.provides.scripts | index("migrate-state-legacy-fields.sh")'`.
- [ ] Commit this phase's single file (explicit path, no directory or glob `git add`).

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Research observed `provides.scripts` holding exactly 199 entries, with
`"migrate-directory-padding.sh"` at index 65 and no `"migrate-state-legacy-fields.sh"` entry.
Treat all three as hypotheses: re-derive the count and both index positions with `jq` at
implementation time rather than editing by remembered line number. If the entry turns out to be
already present (a sibling or an intervening commit added it), stop and record that instead of
adding a duplicate.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add one string to `provides.scripts`

**Verification**:
- `jq empty agent-system/extensions/core/manifest.json` exits 0 (valid JSON).
- `jq -e '.provides.scripts | index("migrate-state-legacy-fields.sh")'` exits 0.
- `bash .claude/scripts/check-extension-docs.sh` no longer prints
  `FAIL: script file on disk NOT in provides.scripts: scripts/migrate-state-legacy-fields.sh`
  under `[core]`. (The `README.md older than manifest.json` WARN is still expected at this point
  — Phase 2 clears it. One new non-blocking `ADVISORY: core script never deployed` line is also
  expected and correct.)
- `git diff` for the file shows exactly one added line.

---

### Phase 2: Refresh the stale script count in core README.md [NOT STARTED]

**Goal**: `agent-system/extensions/core/README.md` reports a script count consistent with
`provides.scripts`, and its mtime is newer than `manifest.json`'s, clearing the drift WARN.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/README.md` immediately before editing.
- [ ] Recompute the authoritative count:
      `jq '.provides.scripts | length' agent-system/extensions/core/manifest.json`
      (expected 200 after Phase 1).
- [ ] Update the Overview table row `| Scripts | 27 | ... |` to the recomputed count, using the
      approximate style already present in neighboring rows (`15+ dirs`, `23+ files`) if an exact
      number would invite the same drift.
- [ ] Update the matching Architecture-tree comment `├── scripts/   # 27 utility scripts` (around
      line 109) to the same figure so the two do not disagree.
- [ ] Optionally add `migrate-state-legacy-fields.sh` to the tree's representative sample list; if
      skipped, note in the implementation summary that no sibling migration script is named there
      either, so the omission is intentional rather than an oversight.
- [ ] Confirm the README edit is saved after the Phase 1 manifest edit:
      `stat -c %Y` on both files, README newer.
- [ ] Commit this phase's single file (explicit path).

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: Research observed exactly two stale occurrences of the figure `27` for the
script count — the Overview table `| Scripts | 27 |` row and the Architecture-tree comment at
roughly line 109 — against an actual `provides.scripts` length of 199 (200 after Phase 1). Confirm
both at implementation time with `grep -n '27' agent-system/extensions/core/README.md` and the
`jq` length above; if a third occurrence or a different figure appears, update what is genuinely
stale about the script count and leave the other Overview rows alone (Non-Goal).

**Files to modify**:
- `agent-system/extensions/core/README.md` - refresh the script count in the Overview table and
  the Architecture tree comment

**Verification**:
- Diff read-through confirms every changed hunk lies in prose/table/comment text — no code, no
  front matter, no path or command string altered.
- `grep -n 'Scripts' agent-system/extensions/core/README.md` shows the refreshed count, matching
  the Architecture-tree comment.
- `stat -c %Y agent-system/extensions/core/README.md` is greater than
  `stat -c %Y agent-system/extensions/core/manifest.json`.
- `bash .claude/scripts/check-extension-docs.sh` no longer prints
  `WARN: README.md older than manifest.json (possible drift)` under `[core]`.

---

### Phase 3: Confirm the doc lint and deploy gate are green [NOT STARTED]

**Goal**: Evidence on record that `[core]` is clean and that the gate-3 half of the
`verify-deploy.sh --skip-slow` regression is resolved.

**Tasks**:
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and capture the full `[core]` block.
- [ ] Confirm `[core]` shows neither the Rule Q FAIL nor the README-drift WARN, and that the only
      new line is the expected non-blocking
      `ADVISORY: core script never deployed: scripts/migrate-state-legacy-fields.sh`.
- [ ] Run `bash .claude/scripts/verify-deploy.sh --skip-slow` and record gate 3's result plus the
      overall FAIL count.
- [ ] Confirm gate 3 is green. If the overall count is FAIL 1/33 rather than 0/33, confirm by
      reading the remaining failure that it is the gate-13 orphan false positive owned by sibling
      task 324 — not a new defect introduced here — and record that attribution.
- [ ] If any failure outside gate 3 and outside task 324's known orphan issue appears, STOP and
      report rather than widening scope (it may be a sibling's in-flight edit).

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- none planned (verification only; no file edits expected in this phase)

**Verification**:
- `check-extension-docs.sh` exits 0 and its `[core]` section contains no `FAIL:` and no
  `WARN: README.md older than manifest.json` line.
- `verify-deploy.sh --skip-slow` reports gate 3 (doc lint) as passing.
- The overall FAIL count is 1/33 or better, with any remaining failure explicitly attributed to
  the gate-13 orphan issue outside this task's scope.

---

## Testing & Validation

- [ ] `jq empty agent-system/extensions/core/manifest.json` exits 0.
- [ ] `jq -e '.provides.scripts | index("migrate-state-legacy-fields.sh")'` exits 0.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with a clean `[core]` section
      (one expected ADVISORY permitted).
- [ ] `bash .claude/scripts/verify-deploy.sh --skip-slow` gate 3 passes; overall FAIL count is
      1/33 or better with the remainder attributed to the out-of-scope gate-13 orphan issue.
- [ ] `git diff` across the task touches exactly two files, both under
      `agent-system/extensions/core/`, and nothing under `.claude/`.

## Artifacts & Outputs

- `agent-system/extensions/core/manifest.json` - one new `provides.scripts` entry
- `agent-system/extensions/core/README.md` - refreshed script count (Overview table +
  Architecture tree comment)
- `specs/323_declare_migrate_state_legacy_fields_in_core_manifest/summaries/01_*-summary.md` -
  implementation summary, recording the gate evidence and the intentional README-sample omission
  if Phase 2's optional step is skipped
- Two scoped commits (one per edit phase) following `task {N}: ...` conventions

## Rollback/Contingency

Both edits are small, additive, and independently revertible, and each is committed separately,
so recovery is `git revert` of the offending commit (or `git checkout <sha>~1 -- <file>` for the
single file) rather than any working-tree-discarding operation. No pre-emptive
`git-snapshot.sh` checkpoint is warranted for a two-line change; if a genuine rollback of
uncommitted work becomes necessary, follow `context/contracts/recovery.md`'s rollback rung for
the correct snapshot-then-rollback invocation shape rather than running a destructive git command
directly.

Contingency if `check-extension-docs.sh` still reports `[core]` FAIL after Phase 1: the cause is
almost certainly a path-form mismatch (the check compares the git-tracked path
`scripts/migrate-state-legacy-fields.sh` against bare filenames in `provides.scripts`) — re-read
`check_undeclared_scripts` around line 549 and match the exact string form the sibling
`migrate-directory-padding.sh` entry uses, rather than guessing a second form.
