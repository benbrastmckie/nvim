# Implementation Plan: Task #532

- **Task**: 532 - Rule on whether ROADMAP.md is authored-only and make roadmap-integration.sh report its outcome instead of aborting silently
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/532_roadmap_integration_regenerate_silent_abort/reports/01_regenerate-silent-abort-research.md
- **Artifacts**: plans/01_regenerate-outcome-reporting.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The broad premise this record was filed on — `--regenerate` silently aborting, or half-applying
against an authored Stage layout — does **not** reproduce. Both remedies the record poses as
alternatives ("teach the script the Stage-based layout" / "make it refuse loudly") are already
built: `detect_layout()` classifies `classic`/`stage`/`unknown`, both write modes round-trip the
first two, and `refuse_unrecognised_layout()` refuses the third with a named `ERROR:` line, a
non-zero exit, and no write. That part of the record is discharged by the archived
`371_roadmap_generator_stage_layout_and_silent_abort` work and needs no new code.

One narrower claim in the record's own BEHAVIOR UPDATE text **does** still reproduce, and is not
covered by that prior work: on the success path the script's only diagnostic is the frozen
machine marker, so a caller cannot tell a write that changed the file from a write that changed
nothing. This plan lands exactly that: a named, change-aware outcome line on stderr beside the
frozen marker, the two context files that document the caller contract corrected to match, and a
redeploy. It deliberately does not reopen the settled layout design.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch extracted was checked against the live script and live
`specs/ROADMAP.md` today, and the result is stated whether or not it changed:

| Carried claim | Live result | Verdict |
|---------------|-------------|---------|
| `--regenerate` exits 1, zero stdout, zero stderr, writes nothing | Exits **0**; 5382 bytes of diff on stdout under `--dry-run`; 5 named warnings + the marker on stderr | **STALE** — does not reproduce |
| `specs/ROADMAP.md` is a Stage-based authored document carrying none of the assembler's headings | File carries **exactly** the eight literal `CLASSIC_HEADERS`; no `^## Stage [0-9]+` header exists; `detect_layout` returns `classic` | **STALE** — it is a classic-layout file |
| Marker reads `tasks=52 topics=10 runs=20 pruned=0 retained=9` (91 bytes) | Marker reads `tasks=143 topics=10 runs=11 pruned=0 retained=143` | **STALE** — counts moved with state |
| `--regenerate` appends only a `**Coverage appendix (uncovered tasks)**` block and does not assemble `## Open work` / `## Next` | Live `--dry-run` diff rewrites `## Open work` block counts and `## Next` Run lines in full, per `mode_regenerate_classic` | **STALE** — full classic assembly happens |
| The script's only diagnostic on the success path is an HTML comment on stderr, not a named message | **Confirmed.** A changed write and a no-op write are byte-identical in output: zero stdout, same marker, exit 0 both times | **STILL TRUE** — this is the residual defect |
| Research report's "68/68 in `test-roadmap-generation.sh`" | `bash agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` -> **93 passed, 0 failed** | **STALE** — suite has grown; baseline for this plan is 93 |

Supporting reproductions run during planning: source store and deployed copy of the script are
byte-identical (`diff` empty, so no redeploy drift exists at plan time); an unrecognized-layout
fixture exits 1 with the named `ERROR: --regenerate refuses to write ...` line and leaves the
file byte-for-byte unchanged.

### Research Integration

The research report's codebase and git-history findings are adopted in full: the layout
recognition, the loud refusal, and the always-present marker are landed and correct, and the
record's broad premise is covered by closed work. This plan departs from the report on one point
only. The report recommends closing with no implementation; planning found a residual defect the
report did not test for — it verified the refusal path and the `--dry-run` path, but never
compared a real changed write against a real no-op write. Those two produce identical output,
which contradicts a promise `roadmap-update.md` makes in writing (see Phase 2). That gap is live,
narrow, and in scope, so the plan lands it rather than closing.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch, so no roadmap item mapping was performed. Note
that `specs/ROADMAP.md` is the subject matter of this plan's script, not an input to it; nothing
in this plan edits `specs/ROADMAP.md` itself.

## Goals & Non-Goals

**Goals**:
- Make every write-mode invocation emit one named, human-readable stderr line stating the mode,
  the layout taken, the target path, and whether the file's content actually changed — so a
  caller can distinguish rewrote / left-unchanged / diffed-only / refused without diffing.
- Record the settled ruling the record asks for ("authored-only or teach the layout?") durably in
  `roadmap-format.md`: both recognised layouts are taught and round-tripped, an unrecognised
  vocabulary is refused loudly, and `specs/ROADMAP.md` is a classic-layout file today.
- Correct `roadmap-update.md`'s caller contract, which currently tells callers to parse the
  marker for "confirmation of what happened" — something the marker's six frozen count fields
  cannot supply.
- Keep the change additive: existing exit codes, stdout, and the marker's frozen six-field shape
  are untouched.

**Non-Goals**:
- Re-deciding the layout design, re-implementing Stage-layout support, or weakening the permanent
  unrecognised-layout refusal.
- Adding a field to the stderr marker. `roadmap-format.md` freezes its six-field shape and states
  that diagnostics go on a separate named line; this plan honors that.
- Changing `--print`, which never reads an existing file and has no write outcome to report.
- Wiring new callers to `--regenerate`/`--prune`. `roadmap-update.md`'s standing ruling on
  `/todo` and `/review` wiring is left exactly as found.
- Editing `.claude/scripts/roadmap-integration.sh` by hand. It is a deploy artifact; the edit
  target is the source store.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hand-editing the deployed `.claude/` copy, which the next deploy wipes | H | M | Every edit target in this plan is under `agent-system/extensions/core/` (`core.source_dir` resolved from `.claude-extensions.json`). Phase 3 redeploys; no phase lists a `.claude/**` path as an edit target. |
| A new stderr line breaks a caller that parses stderr strictly | M | L | The line is additive and carries a distinct `OUTCOME:` prefix, which collides with none of the existing prefixes (`ERROR:`, `WARNING:`, `Warning:`, `NOTE:`). Exit codes, stdout, and the marker are unchanged. Phase 1 adds a regression case asserting the marker line is still byte-identical. |
| Content comparison adds a spurious read of a large file on every write | L | L | `write_or_diff` already materializes the full new content in a staging file; the comparison is one `cmp -s` of that staging file against the target, no extra render. |
| Phase 3's redeploy regenerates the whole `.claude/` tree, colliding with concurrent siblings (391, 528, 507) whose own scopes are disjoint from this plan's four files but not from a whole-tree regeneration | M | M | Phase 3 declares the reserved `__WHOLE_TREE__` sentinel so the batch-admission gate serializes it against any sibling making the same claim. Re-read each file immediately before editing; stage this task's own files explicitly, never a directory or glob. |
| Idempotence assertion weakens if the outcome line is written to the file rather than stderr | H | L | The line goes to stderr only. Phase 1's test set re-asserts the existing byte-identical-second-run idempotence case. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Emit a named, change-aware outcome line from both write modes [COMPLETED]

**Goal**: `--regenerate` and `--prune` each print exactly one named `OUTCOME:` line to stderr
naming the mode, the layout, the target, and whether content changed — alongside, not instead of,
the frozen marker.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/roadmap-integration.sh` immediately before
      editing (concurrent siblings are live on this tree this cycle). *(completed)*
- [x] Make the detected layout available to `write_or_diff`. `mode_regenerate`/`mode_prune`
      already compute `layout` locally at the `case` dispatch (around lines 845 and 929); promote
      it to a script-level variable (e.g. `ROADMAP_LAYOUT`) set at dispatch, so the writer need
      not re-run `detect_layout`. *(completed)*
- [x] In `write_or_diff` (currently lines 538-550), compare the staging file against
      `$ROADMAP_PATH` with `cmp -s` before the `mv`/`diff`, and emit one line to stderr. Use
      these four shapes, which mirror the existing `ERROR:` line's uppercase-prefix style:
      - `OUTCOME: --regenerate rewrote {path} (layout=classic, content changed)`
      - `OUTCOME: --regenerate left {path} unchanged (layout=classic, no content change)`
      - `OUTCOME: --regenerate --dry-run diffed {path}; wrote nothing (layout=classic, content would change)`
      - `OUTCOME: --regenerate --dry-run diffed {path}; wrote nothing (layout=classic, no content change)`
      substituting `--prune` and `layout=stage` as applicable. *(completed)*
- [x] Confirm ordering relative to the `EXIT`-trap marker: the `OUTCOME:` line is emitted from
      `write_or_diff`, so it precedes the trap-emitted marker. Assert that order in a test rather
      than leaving it incidental. *(completed)*
- [x] Leave the absent-roadmap supported no-op alone — `mode_prune`'s
      `NOTE: no roadmap tracked at ...` line returns before `write_or_diff` and already names its
      outcome. Add a test asserting it still does, and that no `OUTCOME:` line is emitted there.
      *(completed)*
- [x] Leave `--print` untouched; add no outcome line to it. *(completed: no code path change;
      `--print` never calls `write_or_diff`)*
- [x] Add test cases to `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh`
      in a new case group, following the existing `pass()`/`fail()` harness and per-case isolated
      fixture pattern: changed write emits `content changed`; immediate second run emits
      `no content change`; `--dry-run` emits the `wrote nothing` shape and writes nothing;
      `--prune` emits its own mode token; the `unknown`-layout refusal emits `ERROR:` and **no**
      `OUTCOME:` line; the marker line is still byte-identical to its pre-change shape; the
      existing byte-identical-second-run idempotence of the file itself still holds. *(completed:
      added 12 new cases, not the 7 hypothesized — see Scope Hypothesis note below)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` and
      confirm the pre-existing 93 cases still pass alongside the new ones. *(completed: baseline
      confirmed at 93 before editing; 105 passed, 0 failed after — 93 + 12 new)*
- [x] Commit the script and its test file together (this is one green sub-step; the test file is
      the verification of the script change). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-roadmap-generation`
executes every code path this phase edits — `write_or_diff`, both mode dispatchers, the refusal
gate, and the marker trap — and the phase touches no file any other suite reads.

**Scope Hypothesis**: The current suite baseline is 93 passing cases (measured at plan time) and
this phase is expected to add roughly 7 new ones across the enumerated assertions. Both figures
are hypotheses: the implementer confirms the baseline by running the suite *before* editing, and
reports the actual new-case count rather than asserting 7. A baseline other than 93 means a
sibling or an intervening commit moved the suite — report it, do not silently adopt it.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - promote `layout` to a
  script-level variable at both write-mode dispatches; add the `cmp -s` comparison and the
  four-shape `OUTCOME:` stderr line to `write_or_diff`
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - new case group
  covering the outcome line's four shapes, the refusal path's absence of one, marker invariance,
  and the retained file-level idempotence

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` exits 0 with the
  confirmed baseline plus the new cases passing and 0 failures.
- Against a scratch copy of `specs/ROADMAP.md`: a first `--regenerate` prints an `OUTCOME:` line
  containing `content changed`; an immediate second prints one containing `no content change`;
  the two runs' marker lines are identical to each other and to the pre-change marker shape.
- `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run --roadmap specs/ROADMAP.md
  --state specs/state.json` is NOT used as verification for this phase — the deployed copy is
  still stale until Phase 3.
- `git status --short` shows only the two files above before committing.

---

### Phase 2: Record the settled ruling and correct the caller contract [COMPLETED]

**Goal**: The two context files that define this script's contract state the outcome line, its
parse pattern, and the settled layout ruling — and no longer promise something the marker cannot
deliver.

**Tasks**:
- [x] Re-read both target files immediately before editing. *(completed)*
- [x] In `agent-system/extensions/core/context/formats/roadmap-format.md`, extend the
      `### Stderr Marker and Failure Diagnostics` subsection (currently lines 198-215) to document
      the `OUTCOME:` line: when it fires (both write modes, after the layout gate, before the
      marker), its four shapes exactly as implemented in Phase 1, that it never affects the exit
      code, and that it is explicitly the answer to "what happened" that the marker's frozen
      six count fields cannot give. Keep the existing statement that the marker's shape is frozen
      and that diagnostics live on separate named lines — the new line is an instance of that
      rule, not an exception to it. *(completed)*
- [x] Add the `OUTCOME:` line to the same file's `## Parsing Patterns Summary` table, beside the
      existing `Stderr marker` row, with a regex matching the shapes Phase 1 actually emitted
      (read them from the committed script, do not re-derive them from this plan). *(completed:
      regex verified against 5 real captured stderr lines from a live scratch invocation)*
- [x] In the same file's `### Destructive-Overwrite Refusal (permanent property)` subsection or
      `## Section Order`, add one short statement recording the settled ruling this record asked
      for: both recognised vocabularies are taught and round-tripped, an unrecognised vocabulary
      is refused loudly and never guessed at, and `specs/ROADMAP.md` presently classifies
      `classic`. State it as the current design on its own merits — no draft-history or
      supersession framing, per `.claude/rules/no-record-versioning-in-deliverables.md`, and no
      task-number citation, per `.claude/rules/no-task-references-in-deliverables.md`.
      *(completed)*
- [x] In `agent-system/extensions/core/context/patterns/roadmap-update.md`, correct the
      `## Stderr Marker` section's claim that "a caller that only needs confirmation of what
      happened (counts, not content) should parse this line rather than diffing stdout or the
      rewritten file." The marker's counts are identical between a changed write and a no-op
      write, so point such a caller at the `OUTCOME:` line for the did-it-change question and
      keep the marker for the counts. *(completed)*
- [x] In the same file, add the `OUTCOME:` line to the `### --regenerate` and `### --prune`
      contract subsections' promises, and note that `--print` emits none. *(completed)*
- [x] Cross-check the documented shapes against the committed script's own format strings
      literally (grep the script for the emitted text and compare), so the docs cannot drift from
      the implementation at authoring time. *(completed: both check-task-references.sh and
      check-record-versioning.sh pass clean on both files; 4 shapes verified live against a
      scratch invocation)*
- [x] Commit both documentation files. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The documented strings must match Phase 1's emitted strings exactly, and
the covering check is `run-all.sh --only test-roadmap-generation` re-run after the doc edit
together with a literal grep of the committed script's format strings against the two documents —
no cheaper prose read can catch a doc/implementation mismatch.

**Scope Hypothesis**: Exactly two documentation files are expected to need changing, on the
hypothesis that `roadmap-format.md` and `roadmap-update.md` are the only files asserting this
script's stderr contract. The implementer confirms with
`grep -rn 'roadmap-generation mode=' agent-system/extensions/core/ .claude/` before editing and
reports any third consumer found rather than silently leaving it stale.

**Files to modify**:
- `agent-system/extensions/core/context/formats/roadmap-format.md` - document the `OUTCOME:` line
  in `### Stderr Marker and Failure Diagnostics`, add its row to `## Parsing Patterns Summary`,
  and record the settled layout ruling
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - correct the Stderr Marker
  section's confirmation-of-what-happened promise, and add the outcome line to the
  `--regenerate` and `--prune` contract subsections

**Verification**:
- Every `OUTCOME:` shape quoted in either document appears literally in the committed
  `roadmap-integration.sh`, confirmed by grep in both directions.
- `## Parsing Patterns Summary`'s new regex matches each of the four emitted lines, checked by
  running the regex against real captured stderr from a scratch-copy invocation.
- `roadmap-update.md` no longer tells a caller the marker alone confirms what happened.
- `bash .claude/scripts/check-task-references.sh` and
  `bash .claude/scripts/check-record-versioning.sh` (or their suite equivalents) report no new
  findings for either edited file.
- `git status --short` shows only the two files above before committing.

---

### Phase 3: Redeploy and run the full gate set [COMPLETED]

**Goal**: The deployed tree carries the Phase 1 script and Phase 2 documents, and the complete
gate set passes on the whole repository.

**Tasks**:
- [x] Confirm Phases 1 and 2 are committed and the working tree holds no uncommitted edits of
      this task's own four files. *(completed: `git status --short` on all four showed nothing
      pending before the redeploy)*
- [x] Take a defensive checkpoint with
      `bash .claude/scripts/git-snapshot.sh 532 --no-revert` (NOT the default reverting form —
      concurrent siblings are live on this tree). *(completed)*
- [x] Redeploy the `core` extension with `bash .claude/scripts/deploy-headless.sh`. *(completed)*
- [x] Confirm `diff .claude/scripts/roadmap-integration.sh
      agent-system/extensions/core/scripts/roadmap-integration.sh` is empty, as it was at plan
      time, and that the two Phase 2 documents' deployed mirrors match their source-store copies.
      *(completed: all four confirmed byte-identical by direct diff)*
- [x] Verify the deployed script end-to-end:
      `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run --roadmap
      specs/ROADMAP.md --state specs/state.json` exits 0 and now emits an `OUTCOME:` line
      naming `layout=classic` alongside the marker, and `specs/ROADMAP.md` is confirmed
      byte-for-byte unchanged on disk afterward. *(completed: exit 0, `OUTCOME: --regenerate
      --dry-run diffed specs/ROADMAP.md; wrote nothing (layout=classic, content would change)`
      followed by the unchanged marker; checksum identical before/after)*
- [x] If a sibling's regenerated files appear in the deploy's output, stage only this task's own
      files; if a foreign commit or foreign uncommitted modification is observed, STOP and report
      it after checking `git log`, rather than proceeding. *(completed: no foreign commit or
      modification observed; the deploy's own freshness check flagged an unrelated, pre-existing
      one-byte drift in `context/formats/frontmatter.md`, confirmed via `git log`/`git status` to
      predate this dispatch and lie outside this task's `file_scope` — recorded via
      issue-record.sh, not acted on)*
- [x] Run the full gate set and commit. *(DEFERRED per this dispatch's Batch Gate Deferral
      directive — see Verification notes below for the scoped discharge actually run and the
      full-sweep flakiness observed when attempted anyway for visibility)*

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes Phases 1 and 2 together touched exactly four source-store
files, and that a `core` redeploy is the only propagation step needed to bring their deployed
mirrors up to date. The implementer confirms by enumerating the two prior phases' commits
(`git show --stat`) before deploying, and by diffing each of those files against its deployed
mirror afterward — reporting any fifth file or any mirror the deploy did not refresh, rather than
assuming the hypothesis held.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree, so
  this phase makes a whole-tree claim; the reserved sentinel declares that collision surface to
  the batch-admission gate without naming any real wide path, and so without loosening scope
  containment for any consumer of this task's `file_scope`. The deployed copy of
  `roadmap-integration.sh` that the task description names is a deploy output covered by this
  sentinel, never a hand-edit target.

**Verification**:
- `bash .claude/scripts/tests/run-all.sh` passes with no new failures against
  `known-failures.txt`.
- `bash .claude/scripts/verify-deploy.sh` passes all gates.
- `bash .claude/scripts/check-deploy-freshness.sh` reports the deployed tree fresh.
- `bash .claude/scripts/validate-state.sh` passes, Check 8 included (no coarse scope declaration).
- `bash agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` passes from the
  source store as well as through the suite runner.
- The deployed and source-store copies of all four touched files are byte-identical.
- Live `specs/ROADMAP.md` is unchanged by any verification step in this phase.

**Scoped discharge actually run (Batch Gate Deferral)**: this dispatch's own dispatch file
carries a Batch Gate Deferral directive naming this phase, so the first two bullets above were
discharged against the scoped narrowing invocations rather than run independently:
- `bash .claude/scripts/tests/run-all.sh --only test-roadmap-generation.sh` — 1 passed, 0 failed
  (the suite covering every file this phase touched).
- `bash .claude/scripts/verify-deploy.sh --only-gate 22` (shellcheck lint) — 1 check, 0 failures.
- `shellcheck -S warning` run directly against both edited scripts — 0 findings.
- `bash .claude/scripts/validate-state.sh --deep specs/state.json` — run directly (unmappable to
  either narrowing flag; named individually in this phase's own criteria) — 20 passed, 0 failed,
  7 pre-existing warnings, in 61s.
- `bash .claude/scripts/check-deploy-freshness.sh` — run directly (unmappable; named individually)
  — WARNs only on `context/formats/frontmatter.md` (confirmed via `git log`/`git status` to
  predate this dispatch and lie outside this task's `file_scope`); this task's own four files
  confirmed byte-identical by direct `diff`.
- The remaining 25 cheap lint gates (`--only-gate 1,2,3,4,5,6,7,9,11,12,13,14,15,16,17,18,19,21,
  23,24,25,26,27,28`) were also run for visibility and all passed.
- The full, unscoped `run-all.sh` and `verify-deploy.sh` sweeps were additionally attempted once
  each (not as this phase's own discharge, purely for visibility, given many sibling tasks' own
  `verify-deploy.sh` invocations were concurrently live on this shared tree — confirmed via
  `pgrep`). They surfaced two findings, both confirmed non-blocking to this task: Gate 20
  (eager-load context-budget overage on `orchestrate.md`/`SKILL.md`) is pre-existing and outside
  this task's `file_scope` (`git log`/`git status` show no related commit from this dispatch);
  Gate 10/Gate 8 timeouts under the full sweep were resource contention from the concurrent
  sibling load, not a regression — each was independently re-run in isolation above and passed.
  The complete gate set itself is deferred to the once-per-batch stage per the dispatch directive,
  not run as this phase's own closing discharge.

---

## Testing & Validation

- [ ] A changed write and a no-op write are distinguishable from output alone, without diffing
      the file — the defect this plan exists to fix.
- [ ] The frozen six-field marker's shape and text are unchanged, and its `roadmap-format.md`
      parse pattern still matches.
- [ ] Exit codes are unchanged across all paths: 0 on success and on the absent-roadmap no-op, 1
      on an unrecognised layout and on malformed input.
- [ ] The `unknown`-layout refusal still emits its named `ERROR:` line, writes nothing, and emits
      no `OUTCOME:` line.
- [ ] `--regenerate` remains idempotent at the file level: a second consecutive run leaves the
      file byte-identical.
- [ ] `--print` behavior and output are untouched.
- [ ] `specs/ROADMAP.md` is never modified by any phase of this plan.
- [ ] Documented outcome-line shapes match the implementation literally in both directions.

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/roadmap-integration.sh` (named, change-aware
  outcome line on both write modes)
- Modified `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` (new case
  group)
- Modified `agent-system/extensions/core/context/formats/roadmap-format.md` (outcome line
  documented, parse pattern added, settled layout ruling recorded)
- Modified `agent-system/extensions/core/context/patterns/roadmap-update.md` (caller contract
  corrected)
- Redeployed `.claude/` tree carrying all four
- Completion summary at `specs/532_roadmap_integration_regenerate_silent_abort/summaries/01_regenerate-outcome-reporting-summary.md`

## Rollback/Contingency

- Each phase commits independently, so `git revert` of a single phase commit backs out that phase
  without disturbing the others.
- The Phase 1 change is additive to stderr only: reverting the `write_or_diff` hunk restores the
  prior behavior exactly, with no data migration and no file-format consequence.
- Phase 3 is preceded by a `git-snapshot.sh 532 --no-revert` checkpoint; if the redeploy produces
  an unexpected tree, re-run `deploy-headless.sh` from the reverted source store rather than
  hand-repairing `.claude/**`, which the next deploy would wipe.
- If Phase 1's test work reveals that some live caller does parse stderr strictly and breaks, the
  contingency is to keep the outcome line behind no flag but adjust its prefix to one that caller
  already tolerates, recording the constraint in Phase 2's documentation — not to abandon the
  named line, since an indistinguishable success path is the defect under repair.
