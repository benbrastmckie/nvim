# Implementation Plan: Task #430

- **Task**: 430 - Feed observed-but-undeclared implement paths back into a task's declared
  `file_scope` instead of silently dropping them from phase commits
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None (362, 394, 395, 425, 428, 494 all confirmed `[COMPLETED]`/archived by the
  research round)
- **Research Inputs**: specs/430_feed_undeclared_implement_paths_into_file_scope/reports/01_feedback-mechanism-design.md
- **Artifacts**: plans/01_implement-phase-scope-feedback.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-commit-phase.sh` drops a `files_touched` path from a phase commit whenever that path is not
contained in the task's hand-authored, creation-time `file_scope` — correct as a fail-safe, but
nothing feeds the dropped path back into the declaration, so the same genuine work is dropped
again on every later phase (twenty firings in one measured invocation). This plan closes the loop
by making `git-commit-phase.sh` itself deposit each dropped path into the task's own
`.return-meta.json` `proposed_file_scope` array at drop time, and by extending that existing
additions-only channel's consumer chain (`update-task-status.sh --file-scope-add`,
`skill-base.sh`'s `skill_postflight_update()`) from `{research, plan}` to `{research, plan,
implement}`. Done means: a path dropped in phase N is in the task's declared `file_scope` by the
time phase N+1 commits; a genuine out-of-territory excursion is still dropped, still warned, and
still recorded; and every fail-open posture is byte-for-byte unchanged.

**SOURCE STORE IS THE EDIT TARGET.** Every path below is under
`agent-system/extensions/core/` (resolved from `<project-root>/.claude-extensions.json`'s
`source_dir`). Never hand-author under `.claude/**` — that tree is a gitignored, disposable
deploy artifact. Phase 6 redeploys. No task-number references and no record-versioning language
in any file landing under `agent-system/**`.

### Research Integration

The research report's four Decisions are adopted as written and are the spine of this plan:

1. **Channel and source** — extend the existing `proposed_file_scope` channel rather than
   inventing a parallel one, and source the proposal from `git-commit-phase.sh`'s own drop-time
   loop variable rather than from agent self-report. The report's decisive argument is the
   "mechanize over instructing" precedent recorded in `git-commit-phase.sh`'s own header (a prose
   "remember to do X" instruction fired 0/8 in one measured run; the same step moved inside a
   script every caller must already invoke fired 16/16). Asking the implementing agent to notice
   a stderr warning and self-report the path reproduces the exact failure this task exists to
   close.
2. **Auto-merge, no operator confirmation gate** — see Goals and the Decisions subsection below.
3. **Visibility unchanged** — the `WARNING:` and the `issue-record.sh --class "scope excursion"`
   call both still fire unconditionally on every drop. The proposal is additive to the warning,
   never a replacement for it.
4. **No reconciliation hazard with the containment chokepoint** — the report confirmed task 394
   landed `git-commit-scoped.sh`'s V10 gate as a second *drop-and-warn* layer (exit 7 means
   "commit succeeded with drops"), not a refusal. The dispatch's territory-edge warning that a
   refusal might race this work does not apply.

The report also flagged a **latent spec inconsistency** this plan must resolve in the same edit,
not merely add a case alongside: `return-metadata-file.md`'s "Multiple Sequential Writers" section
already lists `proposed_file_scope` as "producer-owned by the implementation agent," while the
field's own subsection says it is "Unused and absent for ... `implement` operations." Neither
passage anticipates a *script* producer. Phase 1 reconciles both passages.

Three plan-time re-derivations extend the report (line numbers in the report have moved; the
figures below were re-read in the source store during this planning round):

- **The drop loop is at `scripts/git-commit-phase.sh:319-334`**, not 270-290. The loop variable
  `f` at the `warn` + `issue-record.sh` call is the authoritative dropped-path value.
- **`test-update-task-status.sh` Case 11h actively PINS the rejection** of `--file-scope-add` on
  `postflight/implement`, and asserts on the literal error text `target_status in {research,
  plan}`. Widening the gate requires *inverting* an existing passing case, not only adding one.
  The report did not name this.
- **`.return-meta.json` must never be minted by the script.** `scripts/validate-return-meta.sh`
  requires `status` and a correctly shaped `artifacts` field; a bare
  `{"proposed_file_scope":[...]}` written by `git-commit-phase.sh` into a task directory that has
  no `.return-meta.json` yet would be a schema-invalid file. The report's "defaulting to `[]` on
  missing/malformed/absent" is therefore read as *skip-if-absent*, not create-if-absent (see
  Decisions below).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no ROADMAP.md consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- `git-commit-phase.sh` deposits every containment-dropped `files_touched` path into
  `${task_dir}/.return-meta.json`'s `proposed_file_scope` array at drop time, under `flock`,
  additively and idempotently, failing open and silently to the commit's own exit code on every
  error.
- `update-task-status.sh --file-scope-add` accepts `operation == postflight && target_status ==
  implement` alongside the existing `research` and `plan`.
- `skill-base.sh`'s `skill_postflight_update()` gains an `implement` arm that reads
  `proposed_file_scope` off the task's `.return-meta.json` and forwards it as `--file-scope-add`,
  exactly mirroring the existing `research` arm.
- `return-metadata-file.md` states the per-operation producer explicitly, naming
  `git-commit-phase.sh` as the `implement`-path producer, and reconciles the two previously
  unreconciled passages.
- `general-implementation-agent.md`'s Stage 7 carries an explicit obligation to read-modify-write
  any `proposed_file_scope` already present (deposited mid-dispatch by the script) rather than
  blind-overwriting it from a freshly built object.
- Every one of the dispatch's five VERIFY fixtures is pinned by a test.

**Non-Goals**:

- An operator confirmation gate for the merge. Auto-merge matches research's existing precedent;
  see Decisions below for the full ruling and justification.
- Weakening the containment predicate for a genuine excursion. Drop-and-warn survives intact,
  pinned by Phase 2's paired negative fixture.
- Making the check fatal. Fail-open on missing/empty/unreadable/malformed `file_scope` stays, and
  the new write path inherits the same posture.
- Any change to `orchestrator-postflight.sh`. Its `implement` gap is deliberately left as-is: the
  script has no live caller (its own header comment says so), so an edit there would be
  cosmetic-only. Phase 1 records this omission in prose so a future reader does not read it as an
  oversight.
- Any second state.json writer. The merge rides inside `update-task-status.sh`'s existing single
  mutex-guarded `state-write.sh` call, unchanged.
- Reading back `issues.jsonl` to recover dropped paths. That log is capture-only by contract, and
  the script already holds the path synchronously at drop time.

## Decisions

**Auto-merge, with no operator confirmation gate (the dispatch's SCOPE item 2, ruled
explicitly).** The proposal merges silently via the existing additive union, announced only by
`update-task-status.sh`'s existing non-blocking `[file-scope]` stderr notice
(`emit_file_scope_notice`, which already names the post-merge delta count and the new paths).
Justification, in order of weight:

1. The evidence standard on the implement path is *stronger* than on the research path that
   already auto-merges. A path reaches this proposal only because it was actually, already
   committed as real work in this task's own dispatch — not predicted as possibly needed later.
2. The admission-gate overlap-masking risk the dispatch raises is real but is **not a new risk
   class**. `research`'s own `proposed_file_scope` already carries the identical
   blind-union-merge-with-no-cross-task-check exposure today. Extending it to one more phase
   changes the risk's frequency, not its kind.
3. There is a genuine net *benefit*, not merely a managed cost:
   `batch-orchestration-guardrails.md` documents that lock-acquisition conflict detection compares
   a task's live `file_scope` against every other currently-held lock's `file_scope` on every
   acquire throughout the task's lifecycle, not only at creation. A path this task is demonstrably
   touching but has never declared is therefore *today* an undetected blind spot for a future
   colliding task's admission check. Widening the declaration to match reality closes that blind
   spot rather than opening one.
4. No confirmation-gated variant of this merge path exists to reuse. Building one would be a
   materially larger, unrequested scope increase, and the dispatch's hard constraints direct
   preserving `proposed_file_scope`'s existing semantics where that channel is the one extended.

**Skip-if-absent, never create: `git-commit-phase.sh` must not mint `.return-meta.json`.** When
the file is absent, the script warns non-fatally and skips the deposit; it does not create the
file. `validate-return-meta.sh` requires `status` and a shaped `artifacts` field, so a minted
`{"proposed_file_scope":[...]}` would be schema-invalid and would surface as a validator failure
far from its cause. In practice the file is present: `general-implementation-agent.md` Stage 0
mandates creating it with `"status": "in_progress"` before any substantive work, which is
necessarily before any phase commit. The report's "defaulting to `[]` on missing/malformed/absent"
is read accordingly as a default for the *array*, not a licence to create the *file*.

**Both drop sites are covered by one edit.** The deposit is placed inside the existing `else`
branch of the single `for f in "${files_touched[@]}"` containment loop, which serves both the
per-objective green-substep call site and the per-phase closing-commit call site. There is no
second drop site to patch.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `git-commit-phase.sh` becomes the first script in this source store to write `.return-meta.json` — a genuinely new pattern | M | H (by construction) | `flock -x` on a per-task lock file, mirroring `issue-record.sh`'s own `(flock -x 200; ...) 200> "$LOCK_FILE"` precedent; strictly additive and idempotent (skip if already present); every failure mode fails open, warns non-fatally, and never touches the commit's exit code. Phase 2 fixtures pin all three. |
| A genuine scope excursion is also proposed forward — the script cannot semantically distinguish "legitimate but undeclared" from "a real mistake" at drop time | M | M | Accepted, not eliminable without semantic input the script does not have. Bounded by: the path must already be `files_touched`-reported by this same dispatch in this task's own phase; the `WARNING:` and the `scope excursion` issue row still fire on every drop, so the conclusion-stage reviewer still sees every event; and `emit_file_scope_notice` names exactly what was absorbed. |
| The agent's own Stage 7 `.return-meta.json` write blind-overwrites the script's mid-dispatch deposit, silently losing it | H | M | Phase 1 states the producer reversal explicitly in the field's own spec; Phase 5 adds the read-modify-write obligation at `general-implementation-agent.md`'s Stage 7, the exact place the overwrite would happen. |
| Inverting `test-update-task-status.sh` Case 11h removes a guard-axis assertion rather than retargeting it | M | M | Phase 3 retargets rather than deletes: the case becomes an accepted-and-merges assertion for `implement`, and a NEW negative case pins a still-rejected target status so the `target_status` guard axis keeps its coverage. |
| A non-final phase's cheaper verification tier misses breakage in a consumer this plan did not enumerate | M | L | Each non-final tier is justified by a suite list produced by running `suite_selection_select` over that phase's own `Files to modify` paths, never asserted; Phase 6 runs the complete gate set over the redeployed tree. |
| Sibling tasks 420 and 435 are dispatched this same cycle on this shared tree; 435's declared `file_scope` includes `agent-system/extensions/core/scripts/` and `.../context/` at directory granularity, overlapping every path in this plan | H | M | Re-read every file immediately before editing it; stage and commit only this task's own hunks with an explicit file list, never a directory or glob add; never run `git-snapshot.sh` in its reverting default mode; treat an unexpected failure outside this plan's own file list as possibly a sibling's in-flight edit; STOP and report a foreign commit or foreign uncommitted modification after checking `git log`. See `context/contracts/territory.md`'s Cross-Task Territory section. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 3 (for 4); 2 (for 5) |
| 4 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Reconcile the `proposed_file_scope` spec and record the producer reversal [COMPLETED]

**Goal**: Make `context/formats/return-metadata-file.md` the authoritative, self-consistent spec
for the widened channel *before* any consumer is edited, so each later phase implements a written
contract rather than inventing one.

**Tasks**:
- [x] Re-read `context/formats/return-metadata-file.md`'s `### proposed_file_scope (optional)`
      subsection and its `### Multiple Sequential Writers` section immediately before editing
      (sibling task 435 declares this directory at coarse granularity). *(completed)*
- [x] Rewrite the subsection's **Include if** sentence so it permits `implement` alongside
      `research`, stating for each permitted operation what triggers the field: `research` — a
      report discovered concrete file targets not already declared; `implement` —
      `git-commit-phase.sh` dropped a `files_touched` path for containment during a phase commit. *(completed)*
- [x] Add a **Producer, per operation** paragraph replacing the current single-producer
      **Producer ownership** paragraph: `research` is produced by the research agent;
      `implement` is produced by `scripts/git-commit-phase.sh` itself, **not** by the
      implementing agent. State plainly that this reverses the producer direction for that one
      operation, and that the implementing agent is consequently a *later* writer that must carry
      the field through untouched, not its originator. *(completed)*
- [x] Extend the **Consumer** paragraph to name the `implement` consumer point
      (`operation == postflight && target_status == implement`, via `skill-base.sh`'s
      `skill_postflight_update()`), keeping the existing single-mutex-guarded-write statement
      intact. *(completed)*
- [x] Correct the `### Multiple Sequential Writers` list so `proposed_file_scope` is described by
      its actual per-operation producer rather than a blanket "the implementation agent" — the
      inconsistency the research report flagged. Leave the other fields in that list unchanged. *(completed)*
- [x] Add one short paragraph recording that `scripts/orchestrator-postflight.sh` deliberately
      gains no `implement` arm because it has no live caller, so a future reader does not read the
      omission as an oversight. *(completed)*
- [x] Add one sentence stating that the `implement`-path producer skips the deposit when
      `.return-meta.json` is absent and never creates it, because the file's own required fields
      cannot be synthesized by a commit wrapper. *(completed)*
- [x] Preserve the field's additions-only, never-remove semantics verbatim; this phase adds an
      operation and names producers, and changes no merge semantics. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-validate-return-meta.sh` is the complete covering check — `suite_selection_select` over this phase's single `Files to modify` path returns exactly those two suites.

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - permit `implement` in the `proposed_file_scope` subsection; replace single-producer ownership with per-operation producers naming `git-commit-phase.sh`; extend the consumer paragraph; reconcile the Multiple Sequential Writers list; record the `orchestrator-postflight.sh` non-edit and the skip-if-absent rule

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-validate-return-meta.sh` is green.
- `grep -n "implement" ` over the `proposed_file_scope` subsection shows the operation permitted, and no sentence anywhere in the file still asserts the field is "unused and absent for ... `implement`".
- The `Multiple Sequential Writers` list no longer attributes `proposed_file_scope` to a single blanket producer.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence for this file (no task-number references under `agent-system/**`).

---

### Phase 2: Deposit the dropped path at drop time in `git-commit-phase.sh`, with fixtures [COMPLETED]

**Goal**: Make the drop loop write each dropped path into the task's own `.return-meta.json`
`proposed_file_scope`, under `flock`, additively, idempotently, and fail-open — and pin all five
of the dispatch's VERIFY fixtures that live in this suite.

**Tasks**:
- [x] Re-read `scripts/git-commit-phase.sh`'s containment block (currently ~lines 234-336) and
      `scripts/tests/test-git-commit-phase.sh` immediately before editing; re-derive the drop
      loop's line numbers rather than trusting the figures in this plan. *(completed)*
- [x] Add a `propose_file_scope_addition <path>` helper function near `warn()`, before the
      containment block. Contract: resolve `${task_dir}/.return-meta.json`; if the file does not
      exist, `warn` once and return 0 (skip-if-absent — never create, see Decisions); if `jq
      empty` fails on it, `warn` and return 0; otherwise, inside `(flock -x 200; ...) 200>
      "${task_dir}/.return-meta.lock"`, read `.proposed_file_scope`, default a missing/`null`/
      non-array value to `[]`, append the path only if not already present, write the result to a
      temp file and `mv` it into place atomically. Every failure path — lock failure, `jq`
      failure, unwritable file, unwritable temp — `warn`s non-fatally and returns 0. The function
      never returns non-zero and never writes to stdout. *(completed)*
- [x] Add the `.return-meta.lock` filename to the fixture `.gitignore` consideration and confirm
      it is not picked up as a committed path (the lock file lives in the task directory, which
      the fixed `stage_paths` seed stages as a directory; verify in the Case 18 fixture that no
      `.return-meta.lock` is committed, and add the lock to the repo's existing lock ignore
      pattern if it is). *(completed)*
- [x] Call `propose_file_scope_addition "$f"` inside the existing containment loop's `else`
      branch, placed **after** the existing `warn` and `issue-record.sh` calls and **before** the
      loop continues, so the warning and the issue row remain unconditional and the deposit is
      strictly additive to them (research Decision 3). *(completed)*
- [x] Extend the script header: add a short paragraph under the PHASE-COMMIT CONTAINMENT
      SELF-CHECK section recording that a dropped path is additionally proposed back into the
      task's `file_scope` via `.return-meta.json`'s `proposed_file_scope`, that this is additive
      to and never a substitute for the warning and the issue row, and that the deposit fails open
      exactly as the check itself does. Cross-reference
      `context/formats/return-metadata-file.md`. *(completed)*
- [x] Extend `scripts/tests/test-git-commit-phase.sh` with new cases numbered from 18, following
      the file's existing house convention (`build_repo`/`write_progress`/`run_phase_commit`
      helpers, `pass`/`fail`/`info`, assertions reading file content rather than exit code alone).
      `build_repo` must be extended to seed a minimal valid `.return-meta.json` in
      `specs/999_probe/` — reuse the existing fixture task identifier and its `task-ref-ok`
      block, adding no new synthetic task number. *(completed)*
- [x] Case 18 (VERIFY 1 — genuine work is no longer dropped-and-forgotten): a `files_touched`
      path outside the declared `file_scope` is dropped from the commit AND appears in
      `specs/999_probe/.return-meta.json`'s `proposed_file_scope`. Assert both halves. *(completed)*
- [x] Case 19 (VERIFY 2 — the excursion guard survives intact): in the same fixture run, assert
      the `WARNING: ... dropping out-of-scope path` line is still emitted for that path and that
      the `issue-record.sh` call still wrote a `scope excursion` row to
      `specs/999_probe/issues.jsonl`. This is the paired-negative guard the dispatch's hard
      constraint requires: the predicate is not weakened, only supplemented. *(completed)*
- [x] Case 20 (idempotence): running the same phase commit twice leaves exactly one occurrence of
      the path in `proposed_file_scope` — no duplicate append. *(completed)*
- [x] Case 21 (VERIFY 3 — fixed-scope carve-out unchanged): `specs/999_probe/`, `specs/TODO.md`,
      and `specs/state.json` are still staged unconditionally and are never themselves proposed
      into `proposed_file_scope`. *(completed)*
- [x] Case 22 (VERIFY 4 — fail-open unchanged, three shapes): with `file_scope` absent, `[]`, and
      malformed (a bare string), the whole check is still skipped, nothing is dropped, nothing is
      proposed, and the commit's exit code is unchanged. Mirror Case 17a/b/c's existing shape. *(completed)*
- [x] Case 23 (deposit-path fail-open): with `.return-meta.json` absent, and separately with it
      present but malformed JSON, a drop still warns, still records the issue, still commits, and
      the script's exit code is identical to the same fixture run with a valid
      `.return-meta.json` — the deposit never affects the commit or its exit code, and no
      `.return-meta.json` is created in the absent case. *(completed)*
- [x] Case 24 (VERIFY 5 — post-commit completeness check reports accurately): a containment-
      dropped path is still excluded from the completeness check's surviving set, so the check
      reports on exactly the paths that were committed and does not newly report the dropped path
      as un-landed. Assert the check's output names the surviving paths and not the dropped one. *(completed)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh,test-task-reference-patterns-lib.sh` is the complete covering check — `suite_selection_select` over both of this phase's `Files to modify` paths returns exactly that union.

**Scope Hypothesis**: Seven new fixture cases (18-24) are expected to cover all five of the dispatch's VERIFY items plus idempotence and deposit-path fail-open. Confirm at implementation time by mapping each VERIFY item to a landed case number in the phase's progress-file notes; if one item needs two cases or two items collapse into one, adjust the count and record the actual mapping rather than forcing seven.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - add `propose_file_scope_addition()`; call it in the containment loop's `else` branch after the existing warn and issue-record calls; extend the header's SELF-CHECK section
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - seed `.return-meta.json` in `build_repo`; add Cases 18-24

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh,test-task-reference-patterns-lib.sh` is green, with Cases 1-17 still passing unchanged.
- `bash -n agent-system/extensions/core/scripts/git-commit-phase.sh` and `shellcheck` on the same file report no new findings.
- Case 19's assertions prove the `WARNING:` and the `scope excursion` row both still fire — the hard constraint that drop-and-warn survives intact.
- Case 23 proves the deposit path never changes the commit's exit code and never creates `.return-meta.json`.

---

### Phase 3: Widen `update-task-status.sh --file-scope-add` to `implement`, and retarget its tests [COMPLETED]

**Goal**: Let the consumer accept the implement-postflight call, with the `target_status` guard
axis keeping its test coverage rather than losing it.

**Tasks**:
- [x] Re-read `scripts/update-task-status.sh`'s `--file-scope-add` validation gate (currently
      ~lines 333-349) and its header documentation block (currently ~lines 55-85), and
      `scripts/tests/test-update-task-status.sh` Case 11, immediately before editing. *(completed)*
- [x] Widen the validation condition so the permitted set is `{research, plan, implement}`, and
      update the error message to name all three permitted target statuses. *(completed)*
- [x] Update the header block's `RESTRICTED to ...` sentence to name all three, and add one
      sentence identifying the implement consumer point: `skill-base.sh`'s
      `skill_postflight_update()` forwards `proposed_file_scope` deposited by
      `git-commit-phase.sh` at drop time. Cross-reference
      `context/formats/return-metadata-file.md`. *(completed)*
- [x] Confirm by reading — not by assumption — that the merge logic itself (the jq union on
      `active_projects[].file_scope` riding inside the single `state-write.sh` invocation) is
      status-agnostic and needs no change; record the confirmation in the phase's progress notes.
      Do not add a second writer. *(completed)*
- [x] Confirm `emit_file_scope_notice()` fires on the implement path with no edit, since it is
      driven by the post-merge delta rather than by target status. *(completed)*
- [x] Retarget `test-update-task-status.sh` Case 11h: it becomes an **accepted-and-merges**
      assertion for `postflight 1 implement ... --file-scope-add`, mirroring Case 11g's shape
      (exit 0, `file_scope` additively widened, state actually written). *(completed)*
- [x] Add a NEW negative case (11i) preserving the `target_status` guard axis Case 11h used to
      cover: a target status outside the permitted three (for example `postflight 1 completed
      ... --file-scope-add`) is still rejected, state is unchanged, and the error names all
      three permitted target statuses. Keep Case 11f's `operation`-axis negative untouched. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-backfill-file-scope.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-gate-out-self-attribution.sh,test-handoff-dispatch-identity.sh,test-lint-agent-contracts.sh,test-lint-lifecycle-status-var.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-suggest-next-batch.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-reconcile-handoff-status.sh,test-redeploy-checkpoint-promotion.sh,test-resume-scan-nonconformance.sh,test-skill-base-lifecycle.sh,test-update-task-status.sh` is the complete covering check — `suite_selection_select` over this phase's two `Files to modify` paths returns exactly that 20-suite union.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - widen the `--file-scope-add` permitted target-status set to `{research, plan, implement}`; update the error message and the header documentation block
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - retarget Case 11h to an implement-accepted assertion; add Case 11i preserving the `target_status`-axis negative

**Verification**:
- The 20-suite `--only` invocation above is green, with Cases 11a-11g still passing unchanged.
- `bash .claude/scripts/update-task-status.sh postflight <n> implement <sid> --file-scope-add='["x"]' --dry-run` no longer exits 1 with the restriction error (exercised through the test fixture, not against live `specs/state.json`).
- Case 11i proves an out-of-set target status is still rejected with an error naming all three permitted statuses.
- `git diff` on `update-task-status.sh` shows no new `state-write.sh` invocation.

---

### Phase 4: Add the `implement` forwarding arm in `skill-base.sh`, with coverage [COMPLETED]

**Goal**: Close the last link in the chain — the live implement-postflight path reads
`proposed_file_scope` and forwards it, mirroring the existing `research` arm exactly.

**Tasks**:
- [x] Re-read `scripts/skill-base.sh`'s `skill_postflight_update()` `--file-scope-add` write-back
      block (currently ~lines 1044-1077) and `scripts/tests/test-skill-base-lifecycle.sh`
      Group 4a immediately before editing. *(completed)*
- [x] Add a third arm to the existing `if "$operation" == "research" ... elif "$operation" ==
      "plan"` chain: `elif [[ "$operation" == "implement" && -n "${_task_dir}" && -f
      "${_task_dir}/.return-meta.json" ]]`, reading `.proposed_file_scope` with the same `jq -c
      '... // [] | if (type == "array") then . else [] end'` guard and the same
      empty/`null`/`[]`-passes-no-flag behaviour as the `research` arm. Do not restructure the
      existing arms. *(completed)*
- [x] Extend the block's leading comment to name the third source and its producer
      (`git-commit-phase.sh`, mid-dispatch, at containment-drop time), distinguishing it from
      `research`'s agent-authored proposal and `plan`'s harvested one. *(completed)*
- [x] Confirm by reading that this arm sits inside the existing `case "$status" in
      researched|planned|implemented)` block that already runs for `implemented`, and that
      `"$operation"` is what is forwarded as `target_status` to `update-task-status.sh` — so
      Phase 3's widened gate is the one this arm depends on. *(completed)*
- [x] Add a Group 4b to `test-skill-base-lifecycle.sh`, modelled on Group 4a's fixture shape: a
      fixture task with a `.return-meta.json` carrying a non-empty `proposed_file_scope`, driven
      through `skill_postflight_update <n> implement <sid> implemented "" <task_dir> ""`, asserting
      (a) `active_projects[0].file_scope` is additively widened with those paths, and (b) a
      `[file-scope]` notice naming the correct new-path count surfaces on stderr. *(completed:
      named "Group 4c", not "Group 4b" -- that label is already taken by an unrelated existing
      per-dispatch deploy-freshness group in this suite; also source-store-first resolution was
      required for both skill-base.sh and update-task-status.sh, mirroring this suite's own
      Group 5/6 pattern, since both subject files are pre-redeploy source-store edits)*
- [x] Add a degenerate sub-case: a `.return-meta.json` with no `proposed_file_scope` (and,
      separately, no `.return-meta.json` at all) passes no flag, leaves `file_scope` byte-for-byte
      unchanged, and emits no `[file-scope]` notice — mirroring Group 4a's own "no plans/ dir"
      degenerate case. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-corroborate-phase-counts.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-gate-out-self-attribution.sh,test-handoff-dispatch-identity.sh,test-lint-task-lookup-adoption.sh,test-manage-topics-create-order.sh,test-mint-dispatch-seq.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-marker-schema.sh,test-skill-base-lifecycle.sh,test-task-type-detect.sh,test-update-task-status.sh,test-validate-return-meta.sh` is the complete covering check — `suite_selection_select` over this phase's two `Files to modify` paths returns exactly that 21-suite union.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - add the `elif operation == "implement"` arm to `skill_postflight_update()`'s `--file-scope-add` write-back block; extend that block's leading comment
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - add Group 4b: implement-arm forwarding coverage plus the two degenerate no-op sub-cases

**Verification**:
- The 21-suite `--only` invocation above is green, with Group 4a still passing unchanged.
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` and `shellcheck` report no new findings.
- Group 4b proves end-to-end that a `proposed_file_scope` deposited into `.return-meta.json`
  reaches `active_projects[].file_scope` through the live implement-postflight path.
- The degenerate sub-cases prove an absent or empty field is a byte-for-byte no-op.

---

### Phase 5: Sync the prose sources the mechanism is ported from [NOT STARTED]

**Goal**: Keep the agent-facing and standards-facing descriptions matching the code, and give the
implementing agent the explicit read-modify-write obligation that protects the script's
mid-dispatch deposit from being overwritten at Stage 7.

**Tasks**:
- [ ] Re-read `agents/general-implementation-agent.md` (its `#### Phase-Commit Containment
      Self-Check` section and its `### Stage 7: Write Metadata File` section) and
      `context/standards/git-staging-scope.md` immediately before editing. Both files are inside
      sibling task 435's coarse declared scope.
- [ ] In `general-implementation-agent.md`'s Self-Check step 4, add one clause recording that the
      wrapper additionally proposes the dropped path back into the task's `file_scope` via
      `.return-meta.json`'s `proposed_file_scope`, that this is additive to and never a
      substitute for the warning and the issue row, and that the agent applies nothing by hand
      here. Leave steps 1-3 and 5 unchanged — in particular, leave step 5's fail-open sentence
      exactly as it stands.
- [ ] In `general-implementation-agent.md`'s Stage 7, add the preservation obligation: before the
      final `.return-meta.json` `Write`, read any `proposed_file_scope` already present — it may
      have been deposited mid-dispatch by `git-commit-phase.sh` — and carry it through untouched
      rather than blind-overwriting it from a freshly built object. Cross-reference
      `return-metadata-file.md`'s "Multiple Sequential Writers" section. State plainly that on
      this path the agent is a later writer, not the producer.
- [ ] In `git-staging-scope.md`, extend the existing "Why a task reported as carrying no
      `file_scope` can still see a drop at a later phase commit" paragraph — which already names
      the research report's `proposed_file_scope` and `plan-file-scope-harvest.sh` as the two
      `--file-scope-add` sources — with the third source: `git-commit-phase.sh`'s own drop-time
      deposit, consumed at implement postflight. Keep the paragraph's existing conclusion (that
      both readings of the same task at two different lifecycle points are correct, and that the
      fail-open posture is unchanged) intact.
- [ ] In `git-staging-scope.md`'s "Three Containment sites, not one" discussion of site 2, add one
      sentence noting that site 2 is now also the feedback source that keeps a declaration from
      staying stale, and that this changes nothing about the predicate or the drop-and-warn
      posture at any of the three sites.
- [ ] Verify no sentence in either file still implies `proposed_file_scope` is research-only.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-orchestrate-cycle-postflight.sh,test-todo-move-pair-staging.sh` is the complete covering check — `suite_selection_select` over this phase's two `Files to modify` paths returns exactly that union.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - add the proposal clause to Self-Check step 4; add the `proposed_file_scope` read-modify-write preservation obligation to Stage 7
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - name the drop-time deposit as the third `--file-scope-add` source; note site 2's new feedback role without changing any posture statement

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-orchestrate-cycle-postflight.sh,test-todo-move-pair-staging.sh` is green.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence for either file.
- A diff read-through confirms every changed hunk in both files is prose, with no posture
  statement (fail-open, drop-and-warn, never-refuse) altered.
- `grep -n "research" ` around each edited passage shows no surviving research-only claim about
  `proposed_file_scope`.

---

### Phase 6: Redeploy and run the complete gate set [NOT STARTED]

**Goal**: Regenerate the deployed `.claude/` tree from the source store and prove the whole change
set green under the repository's full gate set, end to end.

**Tasks**:
- [ ] Confirm the working tree holds this task's own committed work and no foreign uncommitted
      modification (`git status --short`, `git log --oneline -5`). If a sibling's in-flight edit
      is present, STOP and report rather than redeploying over it.
- [ ] Redeploy with the bounded-wait idiom required by
      `context/patterns/external-process-wait.md` Rule 1: `timeout 540 bash
      .claude/scripts/deploy-headless.sh`, with the Bash tool's `timeout` parameter raised to
      600000 (not its 120000ms default).
- [ ] Confirm the deploy-freshness warning for the `core` extension clears, and that the three
      stale extensions named in this dispatch (`core`, `lean`, `nvim`) are no longer reported
      stale — or, if `lean`/`nvim` staleness predates this task, record that it does and is out of
      this task's scope rather than silently absorbing it.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Run an end-to-end sanity check of the closed loop against a throwaway fixture (not live
      `specs/state.json`): a phase commit drops an undeclared path, the path lands in
      `.return-meta.json`'s `proposed_file_scope`, the implement postflight merges it into
      `file_scope`, and a second phase commit for the same path is NOT dropped. This is the one
      assertion no single-suite test makes, because it spans three scripts.
- [ ] Record in the phase's progress notes which VERIFY item each landed test case discharges, so
      the summary can report the mapping rather than reconstruct it.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the source store; declared with the reserved sentinel per `plan-format.md`'s whole-tree-claim declaration rule
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - any fixture adjustment the end-to-end check reveals

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` exits 0 and the `core` extension is no
  longer reported stale.
- `bash .claude/scripts/verify-deploy.sh` is green across the complete gate set (gates 0-9,
  including Gate 8's full shell-suite battery) — no `--skip-slow`, no `--only-gate` subset.
- The end-to-end fixture check demonstrates the drop-propose-merge-no-longer-dropped loop.
- `bash .claude/scripts/check-task-references.sh` and the record-version lint report no new
  occurrence anywhere under `agent-system/**`.

---

## Testing & Validation

- [ ] VERIFY 1: a genuine-work-but-undeclared path is handled by the new rule (proposed forward),
      not silently dropped-and-forgotten — `test-git-commit-phase.sh` Case 18.
- [ ] VERIFY 2: a deliberately out-of-territory path is STILL dropped, with its `WARNING:` and its
      `issue-record.sh --class "scope excursion"` call — Case 19, the hard constraint's guard.
- [ ] VERIFY 3: the fixed-scope carve-out paths are still staged unconditionally and are never
      proposed — Case 21.
- [ ] VERIFY 4: fail-open on absent/empty/malformed `file_scope` is unchanged — Case 22; plus
      fail-open on absent/malformed `.return-meta.json` — Case 23.
- [ ] VERIFY 5: the post-commit completeness check reports accurately under the new rule — Case
      24.
- [ ] Parallel consumer coverage where the research path's own coverage lives:
      `test-update-task-status.sh` Case 11h (retargeted) and 11i (new);
      `test-skill-base-lifecycle.sh` Group 4b beside Group 4a.
- [ ] Idempotence: a repeated drop of the same path appends once — Case 20.
- [ ] Full gate set green on the redeployed tree: `bash .claude/scripts/verify-deploy.sh`.
- [ ] End-to-end loop closure: drop, propose, merge, and no re-drop on the next phase commit.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — widened, reconciled
  `proposed_file_scope` spec with per-operation producers.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — drop-time `proposed_file_scope`
  deposit, flock-guarded and fail-open.
- `agent-system/extensions/core/scripts/update-task-status.sh` — `--file-scope-add` accepted for
  `implement`.
- `agent-system/extensions/core/scripts/skill-base.sh` — implement forwarding arm.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Self-Check clause and
  Stage 7 preservation obligation.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — third
  `--file-scope-add` source recorded.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — Cases 18-24.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — Case 11h retargeted,
  11i added.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — Group 4b.
- Regenerated deployed `.claude/` tree (Phase 6).
- `specs/430_feed_undeclared_implement_paths_into_file_scope/summaries/01_*-summary.md` at
  completion.

## Rollback/Contingency

Each phase commits independently, so the cheapest rollback is a scoped revert of the offending
phase's own commit, leaving the earlier phases in place. Phase order is chosen so that the only
phase that changes live behaviour on its own is Phase 2 — Phases 3 and 4 widen a gate and add a
forwarding arm that do nothing until a `proposed_file_scope` exists to forward, and Phases 1 and 5
are prose.

Per-phase contingency:

- **Phase 2** is the single revert point that restores today's behaviour completely: removing the
  `propose_file_scope_addition` call from the containment loop leaves the drop, the warning, and
  the issue row exactly as they are now, with no consumer-side change needed. If the new write
  path proves troublesome in practice, revert this one call before touching anything else.
- **Phase 3** can be narrowed instead of reverted: restoring the `{research, plan}` set closes the
  merge while leaving the deposit in place, so the dropped paths accumulate in `.return-meta.json`
  visibly without widening any declaration — a usable degraded mode, not a broken one.
- **Phase 4** reverts by deleting the `elif` arm; the gate widening in Phase 3 is then inert.
- **Phase 6** is re-runnable rather than revertible: a failed deploy is re-deployed, never
  hand-patched under `.claude/**`.

If a rollback must discard uncommitted work rather than revert a commit, take the snapshot first
per `context/contracts/recovery.md`'s rollback rung — including its out-of-scope override flag for
the deliberate whole-tree case — and only then run the destructive command. Do not emit a bare
`git-snapshot.sh 430` as a routine start-of-phase checkpoint; a defensive checkpoint before risky
work uses `--no-revert`, which is durable without reverting the working tree. Sibling tasks are
live on this same tree this cycle, so the reverting default mode is specifically prohibited here.
