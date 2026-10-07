# Implementation Plan: CWD-independent hook registration paths

- **Task**: 364 - Resolve hook registration paths independently of session CWD so bare-registered
  blocking guards cannot fail open
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/364_cwd_relative_hook_registration_paths/reports/02_cwd-relative-hook-paths-research.md`
  (primary), `specs/364_cwd_relative_hook_registration_paths/reports/01_cwd-relative-hook-paths.md`
  (pre-research evidence capture)
- **Artifacts**: plans/02_cwd-relative-hook-registration-paths.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Every hook registration in the source store writes `bash .claude/hooks/x.sh`, a CWD-relative path
the harness resolves against the session's drifted Bash-tool CWD rather than the project root, so
each one silently fails open the moment a session `cd`s into a subdirectory. Research settled the
mechanism empirically: `$CLAUDE_PROJECT_DIR` IS exported into hook command environments (both event
types, and through the nested `bash -c` wrapper) and the fixed form demonstrably still blocks with
`exit 2`. This plan rewrites all 34 source-store registrations to
`bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`, adds the one missing merge-source counterpart that
would otherwise stay permanently unreachable by resync, and fixes the four markdown registration
templates that teach the old shape by example. Done means: no CWD-relative `.claude/` path in any
hook command in a freshly deployed tree, and no duplicate registration on a fresh install —
asserted by test, not by inspection.

**MID-IMPLEMENTATION SCOPE CHANGE (operator directive)**: the plan as originally authored also
shipped an idempotent migration script for already-deployed repos (Phases 3/4/6 below), because
neither install-once `root-files/settings.json` nor add-only `deep_merge` could otherwise reach
one. Mid-implementation, the operator directed that this migration mechanism be dropped: the
operator is reloading/redeploying the agent system to every consumer repo directly, which
supersedes the "install-once cannot reach an already-deployed repo" premise that made the
migration script necessary. Phases 3, 4, and 6 are accordingly closed
`[COMPLETED WITH EXCLUSIONS]` with the operator's instruction recorded as the reason (see each
phase's Reasoned Exclusions). Acceptance criteria 1, 2, and 5 (demonstrated against a real
pre-existing deploy) are consequently NOT satisfied by this task's own artifact; they are expected
to be reached by the operator's separate redeploy action instead. Acceptance criterion 4 (fresh
deploy carries no CWD-relative path) is unaffected and remains absolute.

### Research Integration

- **D1 (gating question, settled)**: adopt `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`. Both
  fallbacks (deploy-time absolute-path substitution; a `git rev-parse`-based self-locating
  dispatcher) are explicitly ruled out and must not be reconsidered absent new evidence.
- **D2**: the four hooks that exist in BOTH `core/root-files/settings.json` and
  `core/merge-sources/settings-hooks.json` (`guard-destructive-git.sh`,
  `validate-no-task-references.sh`, `guard-git-push.sh`, `please-grant.sh`) must be rewritten
  byte-identically in both files or `deep_merge`'s exact-string dedup appends a duplicate on the
  very next load, including a brand-new repo's first install.
- **D3**: a migration script is mandatory, not optional — install-once semantics plus add-only
  `deep_merge` make already-deployed repos unreachable by any combination of source-store edits.
- **D4**: `root-files/settings.json` keeps its registrations, with an explicit in-file warning that
  NEW registrations belong in the merge source.
- **D5**: `validate-state-sync.sh`'s nested registration has no merge-source counterpart at all;
  add one in this same change.
- **D6**: `root-files/settings.local.json` permission matchers do NOT share the defect and MUST NOT
  be touched — they are text matchers against the Bash tool's proposed command, and
  `$CLAUDE_PROJECT_DIR` is confirmed absent from that environment, so rewriting them would be
  actively harmful.
- **D7/F9**: exactly 8 markdown JSON registration-template snippets are in scope; the manual
  diagnostic invocations in `workflow-interruptions.md` (lines 35, 237, 240, 246) and
  `core/scripts/tests/test-please-grant.sh` line 222 are correct-by-different-construction and must
  not be rewritten.
- **F8/D9**: reuse `migrate-directory-padding.sh`'s script convention and
  `test-deploy-propagation.sh`'s real-scratch-repo deploy harness rather than inventing parallel
  machinery.

### Prior Plan Reference

No prior plan. This is plan round 02 (round 01 produced only the pre-research evidence capture, no
plan file).

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag was set; this plan makes no
roadmap claim.

## Goals & Non-Goals

**Goals**:
- Every hook `command` string in the source store resolves against the project root, not the
  session CWD — all 34 occurrences across 4 JSON files, not only the six blocking guards (acceptance
  criterion 4 is absolute: *no* CWD-relative `.claude/` path in a deployed tree's hook commands).
- The bare-vs-`2>/dev/null || echo '{}'` distinction is preserved exactly: the six blocking guards
  stay bare so `exit 2` still blocks; every advisory hook keeps its fail-open suffix.
- ~~An already-deployed consumer repo reaches the corrected state by an explicit, idempotent,
  `--dry-run`-capable migration script, demonstrated against two real pre-existing deploys.~~
  **STRUCK by operator directive mid-implementation** (see Phase 3/4/6's Reasoned Exclusions):
  the operator will reload/redeploy the agent system to every consumer repo directly, superseding
  the need for a bespoke migration script. Already-deployed repos are reached by that separate
  redeploy action instead, outside this task's artifact boundary.
- No repo carries both a broken and a fixed registration for the same hook on a FRESH install,
  asserted by test (Phase 5). The existing-repo-after-migration half of this goal is struck for the
  same reason as above — no migration mechanism exists within this task to assert it against.
- `validate-state-sync.sh` gains a merge-source registration so it stops being permanently
  unreachable by resync.
- The four markdown registration templates stop teaching the defect by example.

**Non-Goals**:
- `root-files/settings.local.json` permission matchers (D6 — ruled out with reason, not deferred).
- The widened lint / `verify-deploy.sh` gate that enforces this convention going forward. That is
  task 365's declared territory (its `file_scope` already names
  `core/scripts/lint/lint-hook-registration-paths.sh` and `verify-deploy.sh`); implementing a
  competing gate here would double-implement it and collide on the same file. **Ruling, with
  reason**: acceptance criterion 6 is satisfied here by test (Phases 4 and 5), and the standing
  gate is left to 365. This is a deliberate narrowing of research D8, recorded so a reader does not
  read it as an omission.
- Removing hook registrations from `root-files/settings.json` (D4 — they stay).
- Task 303's script-internal default-argument bug (confirmed unrelated).
- Rewriting the correct-by-construction diagnostic invocations enumerated in D7/F9.
- **Added mid-implementation (operator directive)**: the migration script for already-deployed
  repos (`migrate-hook-registration-paths.sh`), its test, and demonstrating against the two real
  pre-existing deploys. The operator is reloading/redeploying the agent system to every consumer
  repo directly, which reaches already-deployed repos without a bespoke migration mechanism. See
  Phase 3/4/6's Reasoned Exclusions for the full record.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A shared hook's command string diverges between `root-files/settings.json` and `merge-sources/settings-hooks.json` (typo, flag difference), self-inflicting a duplicate on the next load | H | M | Phase 1 ends with a mechanical per-hook string equality check across the two files for all four shared hooks — not an eyeball comparison |
| The nested `bash -c` form (root-files line 80) is missed or over-rewritten by a naive find-and-replace | H | M | Phase 1 handles it as its own named sub-step using the exact shape verified in research F3; only the inner `bash .claude/hooks/validate-state-sync.sh` fragment changes |
| Migration script written but never run against the repo where the defect was actually reproduced | H | M | Phase 6 runs it against BOTH real pre-existing deploys (`/home/benjamin/.config/nvim` itself and `/home/benjamin/Philosophy/Papers/PossibleWorlds`, each carrying 21 CWD-relative registrations as of plan authoring) and re-reproduces the original failure condition |
| A `"_comment"` key added to `settings.json` triggers a harness "unknown setting" warning | M | M | Phase 2 verifies a real session accepts it; documented fallback is to carry the warning in `docs/` + `manifest.json` (where it already exists) and skip the in-file key rather than ship a warning banner to every consumer repo |
| Migration rewrites a hand-edited consumer `settings.json` destructively | H | L | Script is string-substitution-only on `.claude/hooks/` command fragments, writes a timestamped backup beside the file, and is idempotent; `--dry-run` is exercised first in Phase 6 |
| Markdown pass touches one of the correctly-exempt diagnostic lines | M | M | D7's exact line numbers are carried into Phase 7's task list; Phase 7's verification asserts those four lines are byte-unchanged |
| Tasks 282/347 later append a new registration in the old CWD-relative form by copying surrounding style | M | M | Phase 2's in-file warning plus the convention note; the standing mechanical gate is 365's job (see Non-Goals) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 7 | -- |
| 2 | 2, 4 | 1 (for 2), 3 (for 4) |
| 3 | 5 | 1, 3 |
| 4 | 6 | 1, 3, 4 |

Phases within the same wave can execute in parallel; their file sets are disjoint (Phase 1 owns the
four settings JSON files, Phase 3 owns `core/scripts/` + `manifest.json` + `docs/`, Phase 7 owns the
four markdown files).

---

### Phase 1: Rewrite all source-store hook registrations to the `$CLAUDE_PROJECT_DIR` form [COMPLETED]

**Goal**: Every hook `command` string in the source store resolves against the project root, with
the bare-vs-fail-open distinction preserved and the four cross-file shared strings byte-identical.

**Tasks**:
- [x] Rewrite the 18 occurrences in `agent-system/extensions/core/root-files/settings.json` from
      `bash .claude/hooks/X` to `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/X`, preserving each
      command's existing suffix exactly (bare for `guard-destructive-git.sh`,
      `validate-no-task-references.sh`, `guard-git-push.sh`, `please-grant.sh`; `2>/dev/null || echo
      '{}'` for the rest). *(completed)*
- [x] Handle the nested `bash -c` registration (the `PostToolUse`/`Write` entry wrapping
      `validate-state-sync.sh`) as its own sub-step: change ONLY the inner
      `bash .claude/hooks/validate-state-sync.sh` fragment, leaving the
      `$CLAUDE_TOOL_INPUT`/`$FILE` conditional logic untouched. Use the shape verified in research
      F3. *(completed)*
- [x] Rewrite the 14 occurrences in `agent-system/extensions/core/merge-sources/settings-hooks.json`
      the same way. *(completed)*
- [x] Rewrite the single occurrence in `agent-system/extensions/books/settings-hooks.json`
      (`validate-evidence-append-only.sh`, bare — stays bare). *(completed)*
- [x] Rewrite the single occurrence in `agent-system/extensions/email/settings-fragment.json`
      (`mail-guard.sh`, keeps its `2>/dev/null || echo '{}'` suffix). *(completed)*
- [x] Add the D5 merge-source counterpart: a `PostToolUse`/`Write` entry in
      `core/merge-sources/settings-hooks.json` carrying the same nested `bash -c` registration for
      `validate-state-sync.sh`, byte-identical to the rewritten `root-files/settings.json` string so
      `deep_merge` dedups it to a no-op on a fresh install. *(completed)*
- [x] Mechanically verify byte-identical command strings across the two core files for all five
      now-shared hooks (`guard-destructive-git.sh`, `validate-no-task-references.sh`,
      `guard-git-push.sh`, `please-grant.sh`, and the new nested `validate-state-sync.sh`). *(completed: confirmed byte-equal via jq extraction)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: 34 CWD-relative occurrences across exactly 4 JSON files (18 in
`core/root-files/settings.json`, 14 in `core/merge-sources/settings-hooks.json`, 1 in
`books/settings-hooks.json`, 1 in `email/settings-fragment.json`), and exactly 4 hooks shared
byte-identically between the two core files. Both figures were re-derived at plan-authoring time
by `grep -c 'bash \.claude/hooks'` over each file and a per-hook cross-file string comparison, not
carried from the research report. Confirm at implementation time by re-running
`grep -rc 'bash \.claude/hooks' agent-system --include=*.json` before editing and asserting a
zero total after.

**Files to modify**:
- `agent-system/extensions/core/root-files/settings.json` - 18 command strings rewritten, including
  the nested `bash -c` form
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - 14 command strings rewritten,
  plus one new nested `validate-state-sync.sh` `PostToolUse` registration (D5)
- `agent-system/extensions/books/settings-hooks.json` - 1 command string rewritten (stays bare)
- `agent-system/extensions/email/settings-fragment.json` - 1 command string rewritten (keeps
  fail-open suffix)

**Verification**:
- `jq empty` passes on all four files.
- `grep -rn 'bash \.claude/hooks' agent-system --include=*.json` returns zero matches.
- Count of bare (no `|| echo`) registrations is unchanged at 6 across the source store, and every
  previously-fail-open registration still carries `2>/dev/null || echo '{}'` — asserted by grep,
  not by reading.
- Each of the five shared hooks' command strings compares byte-equal between
  `root-files/settings.json` and `merge-sources/settings-hooks.json`.
- Full gate: `bash .claude/scripts/verify-deploy.sh`. Gate 2's advisory lane is expected to report
  drift between the edited source and this repo's own pre-existing deployed `settings.json` at this
  point; that is the defect Phase 6 migrates away, not a regression introduced here. Record the
  expectation rather than treating the advisory as green.

---

### Phase 2: Record the install-once warning where a future editor will see it [COMPLETED]

**Goal**: A future author adding a hook registration is warned, at the point of edit, that
`root-files/settings.json` is install-once and permanently unreachable by resync — so new
registrations belong in the merge source (D4).

**Tasks**:
- [x] Add a top-level `"_comment"` key to `agent-system/extensions/core/root-files/settings.json`
      stating: this file is install-once (`loader.lua`'s `INSTALL_ONCE_ROOT_FILES`), so a hook fix
      made here never reaches an already-deployed repo; add NEW hook registrations to
      `core/merge-sources/settings-hooks.json` instead; and hook commands must use
      `"$CLAUDE_PROJECT_DIR"`, never a CWD-relative `.claude/` path. *(completed)*
- [x] Verify the harness accepts the key: deploy to a scratch tree (or inspect this repo's own
      settings after a load) and confirm no "unknown setting" warning surfaces. *(completed: this repo's own live, loaded `.claude/settings.local.json` already carries a top-level `_comment` key (line 99) with no harness warning in the current running session, confirming the key is tolerated; primary branch taken, no fallback needed)*
- [x] If the harness warns, remove the key and instead record the same warning in
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`'s migration entry
      plus a one-line pointer in `core/manifest.json`'s existing `merge_targets.settings._comment`
      (which already documents the add-only/no-self-heal half). Record which branch was taken and
      why. *(completed: fallback branch not needed -- harness tolerates the key, confirmed above; no change made to manifest.json or the docs inventory for this task)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/root-files/settings.json` - new top-level `_comment` key (or
  reverted, per the fallback branch)
- `agent-system/extensions/core/manifest.json` - fallback branch only: pointer appended to the
  existing `merge_targets.settings._comment`

**Verification**:
- `jq empty` passes on the edited file(s).
- A session/deploy against the edited settings produces no settings-parse or unknown-setting
  warning (or the fallback branch was taken and the reason recorded).

---

### Phase 3: Write the migration script for already-deployed repos [COMPLETED WITH EXCLUSIONS]

**Goal**: An operator can bring any already-deployed `.claude/settings.json` to the corrected
state in place, idempotently, with a preview mode — the only mechanism that can reach an
install-once-sourced deploy (D3).

**Tasks**:
- [ ] Write `agent-system/extensions/core/scripts/migrate-hook-registration-paths.sh` following
      `migrate-directory-padding.sh`'s convention: `--dry-run`, `--project-root DIR`, `--verbose`,
      `--help`, `set -euo pipefail`, colorized pass/fail output. *(deviation: skipped — operator
      scope change, see Reasoned Exclusions)*
- [ ] Rewrite every `bash .claude/hooks/` occurrence inside `.hooks[*][*].hooks[*].command` of the
      target `.claude/settings.json` to `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/`, including
      occurrences nested inside a `bash -c '...'` wrapper, leaving each command's suffix (bare vs.
      `2>/dev/null || echo '{}'`) untouched. *(deviation: skipped — operator scope change, see
      Reasoned Exclusions)*
- [ ] Make it idempotent: a second run reports zero changes and exits 0; a command already carrying
      `"$CLAUDE_PROJECT_DIR"` is never double-prefixed. *(deviation: skipped — operator scope
      change, see Reasoned Exclusions)*
- [ ] De-duplicate: if the target already carries BOTH a broken and a fixed registration of the same
      hook under the same event+matcher, collapse them to the single fixed entry (criterion 6).
      *(deviation: skipped — operator scope change, see Reasoned Exclusions)*
- [ ] Write a timestamped backup of the target `settings.json` beside it before any mutation, and
      refuse to proceed if the target is missing, is not valid JSON, or `jq` is unavailable.
      *(deviation: skipped — operator scope change, see Reasoned Exclusions)*
- [ ] Declare the script in `agent-system/extensions/core/manifest.json` `provides.scripts`.
      *(deviation: skipped — operator scope change, see Reasoned Exclusions)*
- [ ] Add an entry to
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` matching the
      existing `migrate-directory-padding.sh` entry's shape (one-shot, operator-invoked, no
      automated caller by design). *(deviation: skipped — operator scope change, see Reasoned
      Exclusions)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: both known pre-existing deploys carry exactly 21 CWD-relative hook
registrations and zero `CLAUDE_PROJECT_DIR` occurrences (re-derived at plan-authoring time by
`grep -c` against `/home/benjamin/.config/nvim/.claude/settings.json` and
`/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json`). Confirm at
implementation time with the script's own `--dry-run` count against each target before mutating.

**Files to modify**:
- `agent-system/extensions/core/scripts/migrate-hook-registration-paths.sh` - new file (EXCLUDED,
  never written — see Reasoned Exclusions)
- `agent-system/extensions/core/manifest.json` - `provides.scripts` declaration (EXCLUDED)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - inventory entry
  (EXCLUDED)

**Verification**:
- N/A — phase excluded before any verification step ran.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Entire phase: `migrate-hook-registration-paths.sh` (write, idempotency, dedup, backup, manifest/docs declarations) | Mid-implementation operator directive: the operator will reload/redeploy the agent system to every consumer repo directly, which removes the "install-once root-files cannot reach already-deployed repos" premise (D3) that made a migration script necessary. A full redeploy fixes already-deployed repos without a bespoke migration mechanism, so writing and shipping one would add dead code the operator does not want maintained. | Operator message received mid-dispatch (implement phase, task 364, dispatch_seq 3) instructing: "DO NOT write the migration script for already-deployed repos — drop it and its test from scope... the operator is going to reload/redeploy the agent system to every consumer repo, so the... premise... no longer holds." A draft of the script had already been written and smoke-tested in a scratch fixture (confirming the jq rewrite+dedup logic itself was correct) before the directive arrived; it was deleted, unstaged and uncommitted, per the operator's instruction not to leave dead code behind. |

This exclusion satisfies `status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` five-condition
admission test: the exclusion is itemized (one item, the whole phase), reasoned (operator-directed
scope reduction with a stated premise change), evidenced (the operator instruction itself, quoted
above), the excluded work is genuinely not needed going forward (the redeploy mechanism
supersedes it), and no acceptance criterion silently regresses — criterion 5 (existing-deployed-repo
remediation) is satisfied by the operator's separate redeploy action instead of by this task's
artifact; see the Non-Goals update and Testing & Validation below for the explicit disposition.

---

### Phase 4: Test the migration script [COMPLETED WITH EXCLUSIONS]

**Goal**: The migration's correctness, idempotency, and no-duplicate outcome are asserted by an
automated test, discharging acceptance criterion 6 by test rather than by assumption.

**Tasks**:
- [ ] Write `agent-system/extensions/core/scripts/tests/test-migrate-hook-registration-paths.sh`
      using the house harness shape (`pass()`/`fail()`/`info()`, `PASSED`/`FAILED` counters,
      trap-cleaned scratch `WORKDIR`, exit 0 all-pass / 1 any-fail / 2 environment error), as in
      `test-deploy-propagation.sh`. *(deviation: skipped — entire phase excluded, Phase 3's
      migration script it tests was never written; see Reasoned Exclusions)*
- [ ] Assertion: a fixture `settings.json` seeded with the OLD broken strings is migrated to zero
      `bash .claude/hooks/` occurrences, with every command's bare-vs-fail-open suffix preserved.
      *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Assertion: the nested `bash -c` registration's inner path is migrated and its surrounding
      `$CLAUDE_TOOL_INPUT` logic is byte-unchanged. *(deviation: skipped — see Reasoned
      Exclusions)*
- [ ] Assertion: a second run is a no-op (zero changes reported, file byte-identical). *(deviation:
      skipped — see Reasoned Exclusions)*
- [ ] Assertion (criterion 6): a fixture seeded with BOTH a broken and a fixed registration of the
      same hook under the same event+matcher ends with exactly one entry, the fixed one.
      *(deviation: skipped — this is the "migration-specific test for the no-duplicate criterion"
      the operator named explicitly; see Reasoned Exclusions)*
- [ ] Assertion: `--dry-run` mutates nothing; a backup exists after a real run. *(deviation:
      skipped — see Reasoned Exclusions)*
- [ ] Assertion: refusal paths (missing target, invalid JSON) exit nonzero without mutating.
      *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Declare the test in `agent-system/extensions/core/manifest.json` `provides.scripts`.
      *(deviation: skipped — see Reasoned Exclusions)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: seven assertions as enumerated. The count is an estimate; confirm at
implementation time that each enumerated assertion exists and passes, and record any added or
dropped assertion rather than silently diverging.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-migrate-hook-registration-paths.sh` - new file
  (EXCLUDED, never written)
- `agent-system/extensions/core/manifest.json` - `provides.scripts` declaration for the test
  (EXCLUDED)

**Verification**:
- N/A — phase excluded before any verification step ran.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Entire phase: `test-migrate-hook-registration-paths.sh` (all seven assertions, including the criterion-6 no-duplicate assertion the operator named explicitly) | Depends entirely on Phase 3's migration script, which was excluded by the same operator directive (full redeploy supersedes a bespoke migration mechanism). A test suite for a script that was never written has nothing to test. | Same operator message as Phase 3's Reasoned Exclusions entry; the operator explicitly named "the migration-specific test for the no-duplicate criterion" as in-scope for exclusion. |

Admission test satisfied on the same grounds as Phase 3 (see that phase's Reasoned Exclusions
paragraph) — this phase is a direct, total dependent of the excluded Phase 3 work.

---

### Phase 5: Assert the fresh-deploy outcome in the deploy-propagation harness [NOT STARTED]

**Goal**: Acceptance criterion 4 (a fresh deploy's `settings.json` carries no CWD-relative
`.claude/` hook path) is asserted by the existing real-deploy harness, not by a one-time manual
grep.

**Tasks**:
- [ ] Add an assertion to
      `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`: after the existing
      fresh-deploy step, `jq` every `.hooks[*][*].hooks[*].command` out of the scratch target's
      deployed `.claude/settings.json` and assert zero match `bash \.claude/hooks/`.
- [ ] Add a companion assertion: the six blocking guards are registered and still bare (no
      `|| echo`), and every other registration still carries its fail-open suffix — criterion 3,
      asserted on the deployed artifact per the existing house convention of verifying bare-ness in
      the DEPLOYED tree.
- [ ] Add a duplicate-registration assertion over the same deployed `settings.json`: no
      event+command pair appears more than once (the fresh-install half of criterion 6, catching a
      D2 cross-file divergence the moment it is introduced).
- [ ] Do not modify `verify-deploy.sh` — see Non-Goals; the standing gate belongs to task 365.

**Timing**: 1 hour

**Depends on**: 1, 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: three new assertions (zero CWD-relative paths, bare-ness preserved,
no duplicates) added to one existing harness file. The count is an estimate, not a fact; confirm
at implementation time that each enumerated assertion exists and passes, and record any added or
dropped assertion rather than silently diverging.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` - three new assertions
  after the existing fresh-deploy step

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` runs; the three new
  assertions PASS. The harness's documented expected-red baseline assertions are reported
  unchanged — a pre-existing red there is not this phase's regression, and must be stated as such
  rather than silently absorbed.
- The new assertions are demonstrated to have teeth: temporarily re-break one command string in the
  source, re-run, observe the assertion go RED, restore, re-run green.

---

### Phase 6: Migrate and demonstrate against two real pre-existing deploys [COMPLETED WITH EXCLUSIONS]

**Goal**: Acceptance criteria 1, 2, and 5 are demonstrated — not asserted — against real
already-deployed repos whose `settings.json` predates the fix.

**Tasks**:
- [ ] Run `migrate-hook-registration-paths.sh --dry-run --project-root /home/benjamin/.config/nvim`
      and confirm the reported occurrence count matches the pre-migration grep. *(deviation:
      skipped — migration script excluded in Phase 3; see Reasoned Exclusions)*
- [ ] Run it for real against this repo, then re-grep: zero `bash .claude/hooks/` in
      `.claude/settings.json`, and the six guards still bare. *(deviation: skipped — see Reasoned
      Exclusions)*
- [ ] Repeat `--dry-run` then real run against
      `/home/benjamin/Philosophy/Papers/PossibleWorlds` — the repo where the defect was originally
      reproduced. *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Reproduce the original failure condition in a real session: `cd` into a subdirectory of a
      migrated repo (e.g. `.../PossibleWorlds/JPL`), issue an ordinary Bash tool call, and confirm
      NO `PreToolUse:Bash hook error` / `No such file or directory` output (criterion 1).
      *(deviation: skipped — no migrated repo exists to demonstrate against since the migration
      mechanism was excluded; see Reasoned Exclusions)*
- [ ] From that same subdirectory CWD, trigger a real blocking guard (e.g. `git add -A`, which
      `guard-destructive-git.sh` refuses) and confirm it BLOCKS: the tool call is refused and
      `git status --porcelain` shows nothing staged (criterion 2 — demonstrated, not asserted).
      *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Run `verify-deploy.sh` gate 2 against both migrated repos and confirm its duplicate detector
      reports no duplicates (criterion 6, existing-repo half). *(deviation: skipped — see Reasoned
      Exclusions)*
- [ ] Record each observation verbatim in the implementation summary; a criterion marked satisfied
      without its captured output does not count. *(deviation: skipped — see Reasoned Exclusions)*

**Timing**: 1 hour

**Depends on**: 1, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: two real pre-existing deploys are in scope and both carry 21 CWD-relative
registrations at plan-authoring time (re-derived by grep, see Phase 3). Confirm by `--dry-run`
count per target before mutating; if a third affected deploy is discovered, record it rather than
silently widening or narrowing scope.

**Files to modify**:
- `/home/benjamin/.config/nvim/.claude/settings.json` - EXCLUDED, not migrated by this task (will
  be reached by the operator's separate redeploy action instead)
- `/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json` - EXCLUDED, same reason

**Verification**:
- N/A — phase excluded before any verification step ran.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Entire phase: migrating and demonstrating against the two real pre-existing deploys (`/home/benjamin/.config/nvim` and `/home/benjamin/Philosophy/Papers/PossibleWorlds`) | Every task in this phase invokes the Phase 3 migration script, which was excluded by operator directive. With no script, there is nothing to run `--dry-run` or for-real against either target, and no migrated repo exists to reproduce the original failure condition against or to re-run `verify-deploy.sh` gate 2's duplicate detector on. The operator stated a full redeploy will reach already-deployed repos directly instead. | Same operator message as Phase 3's Reasoned Exclusions entry. Acceptance criteria 1, 2, and 5 — demonstrated against a real pre-existing deploy — are consequently not satisfied BY THIS TASK; criterion 5 explicitly depended on the now-excluded migration path (plan Goals: "An already-deployed consumer repo reaches the corrected state by an explicit, idempotent, `--dry-run`-capable migration script, demonstrated against two real pre-existing deploys" — struck by this exclusion). The operator's own separate redeploy action is the stated mechanism by which these criteria will ultimately be reached, outside this task's artifact boundary. |

This is a direct, total dependent of the excluded Phase 3/4 work, admitted on the same grounds
(operator-directed, reasoned, evidenced, the excluded mechanism is genuinely superseded, and the
resulting criterion gap is named explicitly here and in Testing & Validation rather than silently
absorbed).

---

### Phase 7: Fix the four documentation registration templates [NOT STARTED]

**Goal**: The copy-paste templates a future author works from teach the fixed path shape, so the
convention and its documentation never disagree.

**Tasks**:
- [ ] Update the JSON registration-template snippets to
      `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`, preserving each snippet's existing
      `2>/dev/null || echo '{}'` suffix:
      `nvim/context/project/neovim/guides/neovim-integration.md` (3 snippets),
      `nvim/context/project/neovim/guides/tts-stt-integration.md` (1),
      `nvim/context/project/neovim/hooks/wezterm-integration.md` (3),
      `core/context/troubleshooting/workflow-interruptions.md` (1).
- [ ] Do NOT touch the correct-by-different-construction lines: `workflow-interruptions.md`'s
      `ls -la`, `chmod +x`, and bare manual-diagnostic `bash .claude/hooks/subagent-postflight.sh`
      invocations (D7), nor the prose path references (`` `.claude/hooks/x.sh` - description ``
      lines) which are file-location statements, not commands.
- [ ] Regenerate per-extension `index-entries.json` line counts if any edited context file's line
      count changed (`generate-context-line-counts.sh`), since `check-extension-docs.sh` lints
      `line_count` accuracy.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly 8 in-scope JSON registration snippets, at
`neovim-integration.md` lines 30, 87, 98; `tts-stt-integration.md` line 125;
`wezterm-integration.md` lines 173, 181, 185; `workflow-interruptions.md` line 68 — re-derived at
plan-authoring time by `grep -n '\.claude/hooks/'` over all four files and classifying each hit,
not carried from the research report. Confirm at implementation time by re-running that grep and
asserting that exactly these 8 lines carry a `"command": "bash .claude/hooks/...` form.

**Files to modify**:
- `agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md` - 3 snippets
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - 1 snippet
- `agent-system/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` - 3 snippets
- `agent-system/extensions/core/context/troubleshooting/workflow-interruptions.md` - 1 snippet
- `agent-system/extensions/*/context/index-entries.json` - only if an edited file's line count
  changed

**Verification**:
- Diff read-through confirms every changed hunk lies inside a fenced JSON code block's `"command"`
  value.
- `grep -n '"command": "bash \.claude/hooks' ` over all four files returns zero matches.
- The four exempt diagnostic lines in `workflow-interruptions.md` are byte-unchanged (confirmed by
  diff, named explicitly).
- `bash .claude/scripts/check-extension-docs.sh --quiet` passes.

---

## Testing & Validation

- [ ] `jq empty` passes on all four edited settings JSON files.
- [ ] `grep -rn 'bash \.claude/hooks' agent-system --include=*.json` returns zero matches.
- [ ] Exactly 6 bare (no `|| echo`) blocking-guard registrations remain in the source store; every
      advisory registration retains `2>/dev/null || echo '{}'` (criterion 3).
- [ ] The five hooks shared between `root-files/settings.json` and `merge-sources/settings-hooks.json`
      have byte-identical command strings (D2).
- [x] ~~`test-migrate-hook-registration-paths.sh` green, including the idempotency and
      no-duplicate assertions (criterion 6).~~ *(deviation: excluded — migration script and its
      test dropped by operator directive; see Phase 3/4 Reasoned Exclusions)*
- [ ] `test-deploy-propagation.sh`'s three new assertions green: fresh deploy has zero CWD-relative
      hook paths (criterion 4), bare-ness preserved on the deployed artifact, no duplicates.
- [x] ~~Both real pre-existing deploys migrated; subdirectory-CWD Bash call emits no hook error
      (criterion 1) and a blocking guard demonstrably refuses from that CWD (criterion 2); criterion
      5 satisfied against a real pre-existing deploy, not only a fixture.~~ *(deviation: excluded
      — no migration mechanism exists within this task to demonstrate against; the operator's
      separate redeploy action reaches already-deployed repos instead. See Phase 6 Reasoned
      Exclusions. Criteria 1/2/5 are NOT satisfied by this task's artifact.)*
- [ ] `bash .claude/scripts/tests/run-all.sh` green.
- [ ] `bash .claude/scripts/verify-deploy.sh` green, with gate 2's duplicate detector silent.
- [ ] `bash .claude/scripts/check-extension-docs.sh --quiet` green.

## Artifacts & Outputs

- `agent-system/extensions/core/root-files/settings.json` (18 rewritten commands + `_comment`)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (14 rewritten + 1 new nested
  registration)
- `agent-system/extensions/books/settings-hooks.json`, `agent-system/extensions/email/settings-fragment.json`
  (1 rewritten each)
- ~~`agent-system/extensions/core/scripts/migrate-hook-registration-paths.sh` (new)~~ EXCLUDED,
  never written (operator directive — see Phase 3 Reasoned Exclusions)
- ~~`agent-system/extensions/core/scripts/tests/test-migrate-hook-registration-paths.sh` (new)~~
  EXCLUDED, never written (see Phase 4 Reasoned Exclusions)
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` (3 new assertions)
- `agent-system/extensions/core/manifest.json` (1 `provides.scripts` declaration if any new script
  from Phase 7 requires it; the two migration-related declarations are EXCLUDED)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (EXCLUDED — no
  migration script entry to add)
- 4 markdown template files under `agent-system/extensions/{nvim,core}/context/`
- `specs/364_cwd_relative_hook_registration_paths/summaries/02_*-summary.md` (implementation
  summary recording the operator-directed scope reduction and its reason, in place of the
  criterion-1/2/5 evidence the excluded phases would otherwise have captured)

## Rollback/Contingency

Source-store edits are all small, reviewable JSON/markdown changes committed per green sub-step, so
the ordinary remedy is to revert the offending commit — no working-tree discard is needed.

~~If a migrated `.claude/settings.json` turns out wrong, restore it from the timestamped backup the
migration script writes beside it (Phase 3); that is the designed recovery path and needs no git
operation, since `.claude/` is a gitignored deploy artifact in both affected repos.~~ Moot: Phase 3
was excluded by operator directive (the migration script was never written or run), so no migrated
`settings.json` exists for this task to roll back. Already-deployed repos will be reached by the
operator's separate redeploy action, which carries its own rollback story outside this task.

If an uncommitted working tree must genuinely be rolled back mid-phase, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape (including its out-of-scope override flag); do not run a destructive git command without the
snapshot that rung requires.

Contingency if `$CLAUDE_PROJECT_DIR` is found NOT to work in some environment the research did not
cover: stop and re-open research question 3's two fallbacks rather than improvising — both were
ruled out on the strength of the empirical finding, so new contrary evidence is the only thing that
reopens them.
