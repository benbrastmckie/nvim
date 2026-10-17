# Implementation Plan: Task #400

- **Task**: 400 - Task-number allocation staleness undetected
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 379 (confirmed already landed in this repository -- imposes no wait)
- **Research Inputs**: specs/400_task_number_allocation_staleness_undetected/reports/01_allocation-staleness-detection.md
- **Artifacts**: plans/01_allocation-staleness-detection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two layers close the allocation-staleness defect, each at a different point in the lifecycle of a
task number. A new archive-aware base-mode check in `validate-state.sh` makes a counter that has
fallen behind the numbers actually in use a FAIL-level finding of the standard gate (it becomes
blocking at `verify-deploy.sh` gate 10, which already runs `validate-state.sh --deep` against the
live `specs/state.json`), and the `--deep`-only uniqueness check is promoted to base mode so an
existing duplicate is no longer invisible to an ordinary run. A new `--allocate-into NAME` flag in
`state-write.sh` moves the allocation itself inside the `specs/.scope-lock` critical section, so
the number is read from the live file under the same mutex that serializes the write, refuses to
issue a number the counter has already fallen behind, and refuses to apply a transform that
allocates without advancing the counter. Done when both layers are landed, covered by their own
suites, redeployed, and the full gate set is clean.

### Research Integration

The research report verified the diagnosed mechanism against the scripts and settled four facts
this plan builds on directly:

- `state-write.sh` runs the caller's jq filter against the live file *after* acquiring the mutex
  (`jq "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" "$STATE_FILE"`, line ~458-460), and already assembles
  an `EFFECTIVE_FILTER` prefix of `as $NAME` bindings for spilled `--argjson`/`--argjson-file`
  values (line ~310-321). That prefix chain is the seam `--allocate-into` extends; nothing new has
  to be invented to bind a value under the mutex.
- No check anywhere in `validate-state.sh` compares `next_project_number` against
  `max(project_number)`. Base-mode Check 2 tests presence only; Check 6 type-checks each entry;
  Check D1 (the only uniqueness check) is inside the `if [[ "$DEEP" == "true" ]]` block.
- Check D3 already reads the sibling archive's terminal arrays as a union
  (`archived_projects`/`abandoned_projects`/`completed_projects`, line ~1180-1186). The new bound
  reuses that union rather than hand-rolling a second archive reader.
- Task 379 is already landed here (`--archive` mode, Checks A1-A6, live in the source store), so
  the declared dependency imposes no wait.

Two research recommendations are narrowed or extended at plan time, with reasons recorded under
Decisions below: per-caller migration is deliberately excluded, and `--allocate-into` is given a
staleness refusal and a counter-advance assertion rather than being a bare in-mutex read.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch (`roadmap_path` absent, `roadmap_flag` not set),
so no roadmap review/update phases are included.

## Goals & Non-Goals

**Goals**:

- A stale `next_project_number` (one that is not strictly greater than every number in use, active
  or archived) is a FAIL-level finding of a base-mode `validate-state.sh` run, and therefore of
  `verify-deploy.sh` gate 10.
- The bound is archive-aware: it unions `archived_projects`, `abandoned_projects` and
  `completed_projects` from the sibling `specs/archive/state.json`, so a reader that consulted only
  one of those arrays cannot compute the wrong bound.
- An existing duplicate `project_number` in `active_projects` is reported by a base-mode run, not
  only under `--deep`.
- `state-write.sh` gains an allocation primitive that reads the counter inside the
  `specs/.scope-lock` critical section, refuses to issue a stale number, and refuses a transform
  that allocates without advancing the counter.
- Both layers are covered by the existing suites that own their subjects
  (`scripts/tests/test-validate-state.sh`, `scripts/test-state-write-concurrency.sh`), including a
  fixture that asserts the two layers agree on one shared staleness shape.

**Non-Goals**:

- Migrating any of the seven hand-rolled per-caller allocation sites to the new primitive. See
  Decisions for why, and Artifacts & Outputs for the follow-up this leaves named.
- Repairing the BimodalLogic incident data (already recovered and verified).
- Repairing `context/contracts/conclusion-stage.md` Step 4c's unbound `$new_task_num` or its
  unpopulated `new_task_dir_paths` array (owned by task 402, which depends on this record).
- Changing the vault-operation renumbering in `skills/skill-todo/`.
- Extending `context/patterns/task-lock.md` with the allocation convention (the research's Context
  Extension Recommendation). That file is claimed by task 419 (`not_started`); adding it here would
  be an unordered overlap requiring a dependency edge.
- A shared library for the bound computation. `state-write.sh` is standalone by design --
  `scripts/test-state-write-concurrency.sh` copies it byte-for-byte into an isolated temp root with
  an explicit, short list of sibling scripts, and a new `lib/` dependency would break that
  fixture's copy list. The bound expression is therefore deliberately duplicated across the two
  scripts, with a cross-reference comment in each naming the other and a drift fixture asserting
  they agree (Phase 3).

## Decisions

- **Both layers are adopted, and each closes something the other cannot.** Layer 1 (the validator)
  fires regardless of how a staleness arose -- a hand edit, a caller that never migrates, a
  dropped increment -- and is the only place the archive-aware bound belongs, because requirement 3
  is a read-time property of the validator. Layer 2 (the allocator) is the only thing that can
  close the read-then-write race between two concurrent, individually-correct callers, which no
  amount of after-the-fact detection can prevent. Neither subsumes the other.
- **Per-caller migration is excluded.** Every file in the dispatch's conditional-scope list carries
  at least two non-terminal claimants: `commands/task.md` (328 `planned`; 384, 407, 435, 438
  `not_started`), `skills/skill-spawn/SKILL.md`, `skills/skill-fix-it/SKILL.md` and
  `skills/skill-project-overview/SKILL.md` (328, 384, 435), plus the conflicts the dispatch already
  names for `context/contracts/conclusion-stage.md` and `agents/meta-builder-agent.md` (391) and
  `commands/review.md` (313). Adding any of them would require a dependency edge serializing this
  record behind a not-started record, which the dispatch's "NARROW OR ADD AT PLAN TIME" wording
  explicitly permits declining. The primitive lands documented and tested; migration is a separate
  record's work, and task 402 already carries the edge that makes Step 4c's repair call it.
- **Layer 2 does more than bind the counter in-mutex.** A bare in-mutex read would leave two of the
  dispatch's own observations unaddressed: it would happily issue a number from an
  already-stale counter (so staleness would still be detected only later, by Layer 1, after the
  number was used), and it would not notice a caller that allocates and forgets to advance the
  counter -- which is exactly the Step 4c omission. `--allocate-into` therefore (a) refuses when
  the counter is not strictly greater than every number in use, and (b) refuses a transform whose
  result does not advance `next_project_number` past its input value. Both refusals are
  fail-closed: no write lands.
- **The allocator refuses rather than self-correcting.** Allocating `max+1` with a warning would
  avoid blocking work, but a stale counter can also mean something else is wrong (a mid-flight
  vault operation, a hand edit, a partially-applied archival), and silently absorbing it is the
  posture this record exists to remove. The refusal names the computed correct value and the repair
  invocation, so the fix is one command.
- **The bound reads `specs/archive/state.json` and deliberately not `specs/vault/**`.** A vault
  operation (`commands/todo.md` Step 5.7) moves `specs/archive/` into `specs/vault/{NN-vault}/`,
  renumbers active tasks down by 1000, and resets the counter to `max_active + 1` -- recycling the
  vacated number space is the point of the operation. Counting vaulted numbers in the bound would
  make every post-vault state permanently fail the check. Measured against the live tree: counter
  444, active max 443, archive union max 392 (held in `completed_projects`; `archived_projects`
  maxes at 267 and `abandoned_projects` is empty) -- the check passes today, and the figures
  requirement 3 cites still hold.
- **Base-mode uniqueness: promote Check D1 rather than duplicate it.** Base-mode checks run before
  the `--deep` block in a `--deep` run, so moving the check up loses no `--deep` coverage and
  cannot double-report. The existing fixture at `test-validate-state.sh:269-305` invokes `--deep`
  and greps `"Duplicate project_number: 1"`; keeping the message text identical leaves it passing
  unchanged, and a new fixture asserts the same file now also fails without `--deep`.
- **Coverage lands in the two existing suites, not a new file.** `scripts/test-state-write-concurrency.sh`
  (flat, 536 lines, 9 cases) already owns `state-write.sh`: isolated temp root, byte-for-byte script
  copies, fixtured `specs/state.json` *and* `specs/archive/state.json`, and existing usage-refusal
  cases. Adding cases there avoids a new script file, which would require registering it in
  `agent-system/extensions/core/manifest.json` (`check-extension-docs.sh` Rule Q fails on an
  undeclared script) -- a file claimed by 282, 313, 435 and 436, all `not_started`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new base-mode FAIL breaks a consumer that treats base-mode exit 0 as a hard gate | H | L | Phase 6 enumerates every base-mode caller (`skill-base.sh`, `update-task-status.sh`, `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`, `lib/common.sh`, `lib/file-scope-overlap.sh`, `migrate-state-legacy-fields.sh`, `verify-deploy.sh` gate 10, `scripts/tests/test-init-specs.sh`) and records its posture. The live tree passes the new check today (444 > 443), so no consumer sees a new FAIL on landing; where one would, the tightening is the intended effect of requirement 2, not a regression |
| Existing `test-validate-state.sh` fixtures newly fail Check 12 | M | L | Measured before planning: all 35 parseable heredoc fixtures in that suite that carry both `next_project_number` and `active_projects` already have a counter strictly greater than their max -- zero would newly fail. Phase 3 re-runs the whole suite to confirm against the fixtures that measurement could not parse |
| Gate 10 is already timeout-prone (30s budget, `known-failures.txt:33`) and Check 12 adds work to every run | M | M | Constrain Check 12 to exactly two `jq` invocations (one per file), no shell loops, no git round trip -- the same cost class as Check D1. Phase 6 records gate 10's observed wall time |
| The duplicated bound expression drifts between `validate-state.sh` and `state-write.sh` | M | M | A cross-reference comment in each naming the other as the sibling that must stay in sync, plus Phase 3's drift fixture asserting both reject one shared fixture shape for the same reason |
| `--allocate-into` silently shadows a caller's own `--arg`/`--argjson` binding of the same NAME | M | L | Reject a NAME that collides with any name already bound via `--arg`/`--argjson`/`--argjson-file`, and reject a caller NAME in the reserved `__alloc_` namespace, following the existing `check_spill_name_unique` precedent |
| `--allocate-into` used with `--init` would bind against `jq -n` null input | M | L | Hard usage refusal (exit 1) for the flag combination, with a case in Phase 5 alongside the suite's existing `--init`/`--regen-todo` refusal cases |
| `--slurpfile` against a non-existent sibling archive makes jq fail at startup | M | M | Add the slurpfile only when the file exists, and bind `--argjson __alloc_archive '[]'` otherwise, so the absent-archive path is an empty bound rather than a startup failure |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 5 | 1 (for 2), 4 (for 5) |
| 3 | 3 | 1, 2 |
| 4 | 6 | 3, 5 |

Phases within the same wave can execute in parallel. Phases 1-3 and 4-5 touch disjoint files, so
waves 1 and 2 each contain one validator-side and one allocator-side phase.

---

### Phase 1: Archive-aware counter-staleness check in validate-state.sh [COMPLETED]

**Goal**: A base-mode `validate-state.sh` run FAILs when `next_project_number` is not strictly
greater than every `project_number` in use, counting both `active_projects` and the sibling
archive's terminal arrays.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/validate-state.sh` immediately before editing
      (sibling dispatches are live on this working tree this cycle). *(completed)*
- [x] Add "Check 12: next_project_number vs. max in-use project_number (archive-aware)" after
      Check 11's closing block and before `fi  # end of: if _base_shape_ok`, so it runs in base
      mode under the same `_base_shape_ok` guard Checks 4-11 use and never runs in `--archive`
      mode (where the target file has no counter to validate). *(completed)*
- [x] Resolve the archive sibling with the Check D3 idiom, computed locally because `state_dir` is
      not assigned until line ~1147 inside the `--deep` block:
      `_c12_state_dir="$(cd "$(dirname "$STATE_FILE")" && pwd)"`, then
      `_c12_archive="$_c12_state_dir/archive/state.json"`. *(completed)*
- [x] Compute the active max with one `jq` call over `$STATE_FILE`
      (`[.active_projects[].project_number] | map(select(type == "number")) | max // 0`) and the
      archive max with one `jq` call over the sibling, unioning
      `archived_projects`/`abandoned_projects`/`completed_projects` exactly as Check D3 does,
      guarded by `[[ -f "$_c12_archive" ]]` and defaulting to 0 when absent. No shell loops. *(completed)*
- [x] `log_fail` when the counter is absent or non-numeric (Check 2 only tests presence), and
      `log_fail` when it is not strictly greater than the combined max. The message names the
      counter value, the active max, the archive max, which archive array supplied it, the correct
      value (`combined_max + 1`), and the one-line `state-write.sh` repair invocation. *(completed)*
- [x] `log_pass` on the clean path, naming the counter and the combined max so a passing run still
      shows the margin. *(completed)*
- [x] Add a comment stating that `specs/vault/**` is deliberately excluded from the bound, with
      the recycling rationale from Decisions, and a cross-reference naming
      `scripts/state-write.sh`'s `--allocate-into` bound as the sibling expression that must stay
      in sync. *(completed)*
- [x] Update the script's own header check inventory to list Check 12. *(completed)*
- [x] Confirm the live tree still passes: `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json`. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: A new base-mode FAIL is visible to every base-mode consumer, so the
enumerated one-hop dependent set is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh,test-init-specs.sh,test-update-task-status.sh,test-skill-base-lifecycle.sh`
plus `bash .claude/scripts/verify-deploy.sh --only-gate 10`.

**Scope Hypothesis**: The insertion point is immediately after Check 11 and before
`fi  # end of: if _base_shape_ok` (around line 1116 in the current file), and `state_dir` is first
assigned at line ~1147 inside the `--deep` block. Confirm both by reading the file at
implementation time rather than trusting these line numbers.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - add Check 12 in base mode; update the header check inventory

**Verification**:
- `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` exits 0 and prints a Check 12 PASS line naming counter 444 and combined max 443.
- A scratch fixture with a counter equal to its active max FAILs with the new message; a scratch fixture whose only high number lives in the archive's `completed_projects` also FAILs.
- `run-all.sh --only test-validate-state.sh,test-init-specs.sh,test-update-task-status.sh,test-skill-base-lifecycle.sh` is green.
- `verify-deploy.sh --only-gate 10` passes.

---

### Phase 2: Promote the project_number uniqueness check to base mode [COMPLETED]

**Goal**: A duplicate `project_number` in `active_projects` is reported by a plain
`validate-state.sh` run, not only under `--deep`.

**Tasks**:
- [x] Re-read `validate-state.sh` immediately before editing. *(completed)*
- [x] Move the Check D1 body out of the `if [[ "$DEEP" == "true" ]]` block into base mode, beside
      Check 12, under the same `_base_shape_ok` guard. Keep the `log_fail` text byte-identical
      (`Duplicate project_number: $p`) so the existing `--deep` fixture at
      `test-validate-state.sh:269-305` keeps passing unchanged. *(completed)*
- [x] Leave a comment at D1's former position recording that uniqueness is now a base-mode check
      and that a `--deep` run still covers it (base-mode checks run first), so no reader concludes
      the check was dropped. *(completed)*
- [x] Update the script header's base-mode/`--deep` check inventory accordingly. *(completed)*
- [x] Confirm no double-reporting: a `--deep` run against a duplicate fixture emits the finding
      exactly once. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: Promoting a FAIL into base mode changes what every base-mode consumer
sees, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh,test-init-specs.sh,test-update-task-status.sh,test-skill-base-lifecycle.sh`
plus `bash .claude/scripts/verify-deploy.sh --only-gate 10`.

**Scope Hypothesis**: Check D1's body is at roughly lines 1135-1144, immediately after the
`--deep` block opens. Confirm by reading the file; Phase 1 will have shifted line numbers.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - relocate the uniqueness check to base mode; update the header inventory

**Verification**:
- The existing duplicate fixture FAILs both with and without `--deep`, with exactly one finding per duplicated number in each mode.
- `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` still exits 0.
- `run-all.sh --only test-validate-state.sh,test-init-specs.sh,test-update-task-status.sh,test-skill-base-lifecycle.sh` is green.

---

### Phase 3: Fixtures for Check 12, base-mode uniqueness, and layer agreement [NOT STARTED]

**Goal**: `scripts/tests/test-validate-state.sh` covers the new check's positive path, the
incident shape, the archive-array bug requirement 3 names, and the agreement between the two
layers.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-validate-state.sh` immediately
      before editing.
- [ ] Add a clearly headed fixture section following the suite's existing idiom (`cat >
      "$WORKDIR/..." <<'JSON'` heredocs, `out=$(...)`/`rc=$?`, `pass`/`fail`/`info`), with a
      validator-capability guard matching the `ARCHIVE_VALIDATOR` precedent (grep the candidate
      validator for `Check 12` and `info`-SKIP loudly rather than fail when it is absent).
- [ ] Fixture (a): counter strictly greater than the active max, no sibling archive -> exit 0 and a
      Check 12 PASS line.
- [ ] Fixture (b): the 2026-10-13 incident shape -- counter equal to a number already present in
      `active_projects` -> nonzero exit and the named Check 12 FAIL, asserting the message carries
      the correct `max + 1` value.
- [ ] Fixture (c): requirement 3's own shape -- counter greater than the active max, with a
      sibling `archive/state.json` whose true max lives in `completed_projects` while
      `archived_projects` holds a strictly lower number and `abandoned_projects` is empty -> FAIL.
      Assert the message names the `completed_projects`-supplied bound, so a validator that read
      only `archived_projects` fails this case.
- [ ] Fixture (d): the same state as (c) but with the counter one past the archive bound -> exit 0,
      proving (c) was the bound and not a blanket archive-presence failure.
- [ ] Fixture (e): a non-numeric `next_project_number` -> FAIL (Check 2's presence test alone
      would pass it).
- [ ] Fixture (f): the existing duplicate-`project_number` fixture run WITHOUT `--deep` -> nonzero
      exit and the named finding; the base-mode promotion's regression guard.
- [ ] Fixture (g): layer-agreement drift guard -- take fixture (c)'s state and archive, run the
      deployed `state-write.sh` with `--allocate-into` against it, and assert it refuses for the
      same reason the validator FAILs. Follow the suite's existing deployed-`state-write.sh`
      precedent (lines ~679-684, ~979-980): `info`-SKIP when no deployed copy exists yet rather
      than failing.
- [ ] Update the suite's header comment, which currently describes four seeded defect fixtures, to
      describe the current fixture set.
- [ ] Run the full suite and confirm every pre-existing case still passes.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production surface, covered
by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh`.

**Scope Hypothesis**: Seven new fixtures (a)-(g) are expected to suffice for requirement 4;
confirm at implementation time that no pre-existing fixture already covers one of them and that
none of the suite's non-heredoc-built fixtures newly trips Check 12.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - add the Check 12 / base-mode-uniqueness / layer-agreement fixtures; refresh the header comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0 with every new fixture reporting PASS and no pre-existing case regressed.
- Temporarily reverting Phase 1's archive union to read only `archived_projects` makes fixture (c) FAIL, confirming the fixture actually tests the array coverage.

---

### Phase 4: --allocate-into primitive in state-write.sh [COMPLETED]

**Goal**: `state-write.sh --allocate-into NAME` binds `$NAME` to the live file's
`next_project_number` inside the `specs/.scope-lock` critical section, refuses a stale counter, and
refuses a transform that allocates without advancing the counter.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/state-write.sh` immediately before editing. *(completed)*
- [x] Parse `--allocate-into NAME` in the existing `while`/`case` argument loop. Validate NAME
      against `^[A-Za-z_][A-Za-z0-9_]*$`, reject the reserved `__alloc_` prefix, and reject a NAME
      that collides with any name already bound via `--arg`/`--argjson`/`--argjson-file` -- which
      means tracking those names as they are parsed, following the `check_spill_name_unique`
      precedent. Each rejection is exit 1 with a message naming both the NAME and the conflict. *(completed)*
- [x] Refuse `--allocate-into` together with `--init` (exit 1): the `--init` transform runs
      `jq -n` against null input, where the binding could only ever be null. *(completed)*
- [x] When the flag is set, bind the archive sibling for jq: `--slurpfile __alloc_archive
      "$(dirname "$STATE_FILE")/archive/state.json"` when that file exists, else
      `--argjson __alloc_archive '[]'`. jq resolves `--slurpfile` when it runs, which is inside the
      mutex, so this read is serialized by the same lock -- `state-write.sh` is the single
      mutex-guarded writer for the archive as well as the live file. *(completed)*
- [x] Extend the `EFFECTIVE_FILTER` assembly (currently the spill-prefix block at ~line 310-321)
      so the allocation prefix is appended after any spill prefix and immediately before the
      caller's filter. The prefix must, in order: compute the combined max over
      `active_projects[].project_number` unioned with the archive's
      `archived_projects`/`abandoned_projects`/`completed_projects` numbers; bind the counter,
      raising `error(...)` when it is absent or not a number; and raise `error(...)` when the
      counter is not strictly greater than the combined max, otherwise bind it as `$NAME`. Each
      `error()` message names the file, the counter, the combined max, the correct value and the
      repair invocation. A jq `error()` makes the transform fail, which the existing
      `transform_status` handling already turns into an abort with no write -- fail-closed by
      construction. *(completed)*
- [x] Add the counter-advance assertion: when the flag was used, capture the pre-transform counter
      inside the mutex (one `jq` read of `$STATE_FILE`, after `acquire_mutex`) and, after the
      transform succeeds, abort before the atomic move unless the staged file's
      `next_project_number` is strictly greater than that value. The message must say that the
      filter allocated a number without advancing the counter and name both values. Apply the same
      assertion on the `--dry-run` preview path so a dry run reports the same refusal. *(completed)*
- [x] Add a comment naming `scripts/validate-state.sh`'s Check 12 as the sibling bound expression
      that must stay in sync, and stating that `specs/vault/**` is deliberately excluded. *(completed)*
- [x] Update the usage string (line ~193) and the header's flag documentation (line ~25 and the
      per-flag block around lines 50-64) with the new flag, its two refusals, and a worked
      caller example showing the filter advancing the counter. *(completed)*
- [x] Confirm no existing invocation changes behavior: with the flag absent, `EFFECTIVE_FILTER`
      and `JQ_ARGS` must be byte-identical to before. *(completed)*

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `state-write.sh` is the single writer every state mutation routes through,
so its enumerated direct dependents are covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-state-write-concurrency.sh,test-validate-state.sh,test-update-task-status.sh,test-manage-topics-create-order.sh,test-skill-base-lifecycle.sh`.

**Scope Hypothesis**: The three edit sites are the argument `case` loop (~line 196-290), the
`EFFECTIVE_FILTER` assembly (~line 310-321), and the transform/staging block (~line 441-470);
the header and usage string add two more. Confirm each by reading the file at implementation time.

**Files to modify**:
- `agent-system/extensions/core/scripts/state-write.sh` - add `--allocate-into`, its two refusals, the counter-advance assertion, and the header/usage documentation

**Verification**:
- An ad hoc isolated-temp-root run shows `--allocate-into` binding the counter, the caller's filter advancing it, and the write landing.
- The same against a stale-counter fixture exits nonzero with the named refusal and leaves the target byte-identical.
- A filter that allocates but omits the counter advance exits nonzero with the named assertion failure and leaves the target byte-identical.
- `run-all.sh --only test-state-write-concurrency.sh,test-validate-state.sh,test-update-task-status.sh,test-manage-topics-create-order.sh,test-skill-base-lifecycle.sh` is green (every existing `state-write.sh` caller unaffected).

---

### Phase 5: Allocation cases in test-state-write-concurrency.sh [NOT STARTED]

**Goal**: `scripts/test-state-write-concurrency.sh` proves the allocation primitive's serialization
property, both refusals, and its usage errors.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` immediately
      before editing, and confirm the fixture's copy list already carries every script the new
      cases need (no new sibling dependency may be introduced).
- [ ] Case 10 (the requirement-1 case): two concurrent `--allocate-into` invocations against the
      same fixture, each allocating one number and advancing the counter. Assert both writes land,
      the two allocated numbers are distinct, the counter advanced by exactly two, and no duplicate
      `project_number` exists afterwards. Control interleaving with the suite's existing
      transform-cost idiom (a heavy jq `range` computation), never a wall-clock `sleep`.
- [ ] Case 11: stale counter (equal to a number already in `active_projects`) -> nonzero exit, the
      named refusal, target byte-identical.
- [ ] Case 12: archive-aware bound -- counter above the fixture's active max but not above its
      `specs/archive/state.json` `completed_projects` max, with `archived_projects` holding a
      strictly lower number -> nonzero exit and the named refusal. The suite already fixtures an
      archive file for its `--state-file` cases; extend it rather than adding a second one.
- [ ] Case 13: the counter-advance assertion -- a filter that consumes `$NAME` but leaves
      `next_project_number` unchanged -> nonzero exit, the named assertion failure, target
      byte-identical. Repeat under `--dry-run` and assert the same refusal is reported.
- [ ] Case 14: usage refusals -- `--allocate-into` with `--init`, an invalid NAME, a NAME in the
      reserved `__alloc_` namespace, and a NAME colliding with an existing `--argjson` binding.
      Each exits 1 with its own named message and leaves the target untouched. Follow cases 8 and 9's
      refusal-case shape.
- [ ] Update the header comment (which currently says "nine cases" and enumerates cases 1-9) and
      the final summary line to the new count.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production surface, covered
by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-state-write-concurrency.sh`.

**Scope Hypothesis**: Five new cases (10-14) are expected to cover the primitive's behavior and
both refusals; confirm at implementation time that the existing fixture's archive file can carry
case 12's shape without disturbing cases 5 and 6, which also read it.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` - add cases 10-14; update the header comment and case count

**Verification**:
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0 with all cases PASS and cases 1-9 unregressed.
- Temporarily removing the staleness refusal from `state-write.sh` makes cases 11 and 12 FAIL, and removing the counter-advance assertion makes case 13 FAIL -- confirming each case tests what it claims.

---

### Phase 6: Base-mode consumer audit, redeploy, and full gate [NOT STARTED]

**Goal**: Every base-mode `validate-state.sh` consumer's posture toward the new FAIL is recorded,
the source store is redeployed, and the complete gate set is clean.

**Tasks**:
- [ ] Enumerate every base-mode caller of `validate-state.sh` and record, per caller, whether it
      treats a nonzero base-mode exit as fatal or advisory: `scripts/skill-base.sh`,
      `scripts/update-task-status.sh`, `scripts/orchestrate-batch-admit.sh`,
      `scripts/orchestrate-predispatch-review.sh`, `scripts/lib/common.sh`,
      `scripts/lib/file-scope-overlap.sh`, `scripts/migrate-state-legacy-fields.sh`,
      `scripts/verify-deploy.sh` gate 10, `scripts/tests/test-init-specs.sh`, and
      `commands/task.md` Step 6.5 (which greps only `file_scope` lines and states a nonzero exit
      must not stop its later steps). Where a caller would newly block, state whether that is the
      intended tightening or needs a follow-up; this is a report in the summary, not an edit.
- [ ] Confirm `init-specs.sh`'s fresh-state template (`next_project_number: 1`, empty
      `active_projects`) passes Check 12, and that `test-init-specs.sh` is green.
- [ ] Redeploy the source store: `bash agent-system/extensions/core/scripts/deploy-headless.sh`
      (or the repository's standard invocation) and confirm `RESULT=landed_verify_clean`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Record gate 10's observed
      wall time against its 30s budget, given the pre-existing timeout-proneness noted in
      `scripts/tests/known-failures.txt`.
- [ ] Confirm the live `specs/state.json` passes both base and `--deep` modes after redeploy.
- [ ] Record any new `known-failures.txt` interaction observed during the gate run in the issue log
      rather than editing that file (it is claimed by a concurrent sibling this cycle).

**Timing**: 1.25 hours

**Depends on**: 3, 5

**Verification Tier**: full

**Scope Hypothesis**: The ten base-mode `validate-state.sh` consumers enumerated in the first task
are the complete set as of this plan's writing (derived from a `grep -rln validate-state.sh` over
`agent-system/extensions/core/scripts/` and `hooks/`); re-run that grep at implementation time and
audit whatever it returns rather than trusting this list.

**Files to modify**:
- none planned (audit, redeploy and gate run only; any edit this phase turns up is reported, not absorbed)

**Verification**:
- `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` passes with no FAIL-level finding, gate 10 included.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` reports no NEW failure.
- The consumer audit table is recorded in the task summary.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0, with the
      Check 12 positive, incident-shape, archive-array, archive-bound-passing, non-numeric-counter,
      base-mode-uniqueness and layer-agreement fixtures all PASS.
- [ ] `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0, with the
      concurrent-allocation, stale-counter, archive-bound, counter-advance and usage-refusal cases
      all PASS and cases 1-9 unregressed.
- [ ] Negative-control checks: reverting the archive union to a single array breaks the
      archive-array fixture; removing either `state-write.sh` refusal breaks its matching case.
- [ ] `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` and
      `--deep specs/state.json` both exit 0 against the live tree.
- [ ] `bash .claude/scripts/verify-deploy.sh` is clean, gate 10 included.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` reports no NEW failure.
- [ ] `deploy-headless.sh` reports `RESULT=landed_verify_clean`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-state.sh` - base-mode Check 12 (archive-aware
  counter-staleness) and the uniqueness check promoted from `--deep` to base mode.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - seven new fixtures.
- `agent-system/extensions/core/scripts/state-write.sh` - `--allocate-into NAME`, its stale-counter
  and counter-advance refusals, and its documentation.
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` - five new cases.
- A redeployed `.claude/` tree at `RESULT=landed_verify_clean`.
- Named follow-up work this plan deliberately leaves out, for the summary to carry forward:
  migrating the per-caller allocation sites to `--allocate-into` (each file's claimants and the
  required dependency edges are recorded under Decisions), and documenting the
  allocation-under-mutex convention in `context/patterns/task-lock.md` (claimed by 419).

## Rollback/Contingency

Every phase's edits are confined to four files in the source store, and each phase commits only its
own hunks, so the ordinary contingency is a forward fix or a targeted revert of the single
committing commit.

If a rollback that would discard uncommitted work becomes necessary -- the case
`guard-destructive-git.sh` blocks on a dirty tree -- follow `context/contracts/recovery.md`'s
rollback rung for the snapshot-then-rollback invocation shape, including its out-of-scope override
flag. Do not emit a bare reverting snapshot as a routine start-of-phase checkpoint; for a
defensive checkpoint before the Phase 4 edits, use
`bash .claude/scripts/git-snapshot.sh 400 --no-revert`, which is durable without touching the
working tree.

Two phase-specific contingencies:

- If Phase 1's Check 12 turns out to FAIL against the live tree (it passes as measured: counter
  444, combined max 443), do not weaken the check -- the counter is genuinely stale and the repair
  is the one-line `state-write.sh` invocation the FAIL message names. Repair the counter, then
  re-run.
- If Phase 4's refusals prove to break an existing caller despite the flag being opt-in, the flag
  can be reverted independently of Phases 1-3, which deliver requirements 2-4 on their own and do
  not depend on it.
