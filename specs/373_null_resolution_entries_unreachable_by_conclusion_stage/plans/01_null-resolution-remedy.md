# Implementation Plan: Task #373

- **Task**: 373 - Null `resolution` entries unreachable by the conclusion stage
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/373_null_resolution_entries_unreachable_by_conclusion_stage/reports/01_null-resolution-filter-remedy.md
- **Artifacts**: plans/01_null-resolution-remedy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A `kind: "issue"` entry written without `--resolution` lands in `issues.jsonl` as an explicit
JSON `null`, which the conclusion stage's filter (`.resolution // ""`) coerces to `""` and drops
— making the entry permanently unreachable by the only consumer built to act on it, with no
write-time warning, no read-time tally, and no mention in the report. This plan implements the
remedy the research phase selected: **widen the reader** (coalesce null to `"open"` instead of
`""`), composed with a **lightweight tally** (`implicit_open_count`) that preserves the
provenance signal the merge would otherwise discard. Both `issue-log.md`'s `resolution` row and
`conclusion-stage.md`'s "The Filter Predicate" section are updated to state explicitly what a
null means, which the task description requires regardless of which remedy is chosen. Done when
the real 739/740 fixture entries yield three cited proposals instead of zero, the new null case
is covered by the aggregator's own regression suite, and the full gate set passes on a
redeployed tree.

### Research Integration

- **Remedy choice is settled, not re-litigated here.** Option 1 (tighten the writer) is ruled
  out as the sole remedy because the six already-written fixture entries are append-only and
  this task is barred from retroactive edits — a writer-side change leaves the mandated
  regression fixture still returning zero proposals. Option 2 is the one remedy that satisfies
  it; the "surface the gap" half of Option 3 composes on top.
- **Blast radius confirmed minimal.** The conclusion stage is the sole consumer of the
  `resolution` field. Re-verified at plan time: a grep for `unknown_classes|no_contribution_tasks`
  across the source store returns hits only in `orchestrate-conclusion-aggregate.sh`,
  `conclusion-stage.md`, `orchestrate-batch-results-template.md`, and the aggregator's own test
  suite. The research phase's one correction to the task description stands: `books-observe.sh`
  is a second *reader of the file* but never reads or branches on `.resolution`, so it needs no
  change and is deliberately excluded from file scope.
- **Empirical basis for merging null into `open`.** No entry in either fixture file uses the
  literal `"open"` or `"worked_around"` at all — every non-`fixed_inline` entry is null. The
  closed enum has no value meaning "deliberately not worth acting on" today, so reading null as
  `open` removes no expressive capability the schema currently offers.
- **Writer is deliberately untouched.** `--resolution` stays optional for every `--kind`; no new
  validation, no required-field refusal. The `git-commit-phase.sh` "scope excursion" call site
  (the one engine site omitting the flag) needs no change — its null now correctly enters
  classification as `open`, which is the more accurate reading of a dropped out-of-scope path.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; no roadmap
consultation performed.

## Goals & Non-Goals

**Goals**:
- Make a null `resolution` on a `kind: "issue"` entry reachable by the conclusion stage, by
  coalescing null to `"open"` in the aggregator's filter predicate.
- Add an informational `implicit_open_count` field to the `--aggregate` JSON output and render it
  in the conclusion report block, so the provenance of a null-sourced candidate stays visible.
- State explicitly, in both `issue-log.md`'s `resolution` row and `conclusion-stage.md`'s "The
  Filter Predicate" section, that a null/omitted value is treated identically to `"open"`.
- Close the test-coverage gap that let this defect reach a live run: add a null-`resolution` case
  to the aggregator's regression suite.
- Prove the fix against the real 739/740 entries: three cited proposals where there were zero.

**Non-Goals**:
- No change to `issue-record.sh` — `--resolution` stays optional for every `--kind`.
- No change to the three-channel derivation contract, the per-channel approval gates, or the
  approval ledger.
- No change to the `kind: "win"` exemption.
- No retroactive edit to any already-written `issues.jsonl` entry in any repo, including the
  BimodalLogic fixture (which is read-only input here, copied not mutated).
- No deploy into `~/Projects/BimodalLogic` — the fixture is exercised through an isolated scratch
  root instead (see Phase 4).
- No change to `books-observe.sh` or the books extension.
- No fix for the class-string drift the research phase observed incidentally (`gate-collision`
  vs. seed `gate collision`, etc.) — a separate concern, explicitly out of scope.
- No change to `signal-tagging.md`'s two `--resolution`-omitting examples — under this remedy
  they are no longer defective.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The aggregator's regression suite resolves the DEPLOYED script copy first (`$REPO_ROOT/.claude/scripts/...` precedes the source-store fallback), so running it after a source-store edit but before deploy silently tests the stale code and reports a false green | H | H | Phase 4 deploys BEFORE running the suite. Phases 1 and 3 explicitly do NOT claim suite coverage; their declared tiers rest on lint and a `jq` parse only. |
| A doc edit to `conclusion-stage.md` disturbs the `### Step 4a`/`4b`/`4c` block boundaries that the suite's case (k) parses with `awk`, breaking a passing test | M | L | All Phase 2 edits land in "The Filter Predicate", "The Unknown-Class Tally", Step 1, and Step 2 — all outside the Step 4a-4c span. Case (k) reads the source store directly, so it is runnable pre-deploy as the phase's own check. |
| Merging null into `"open"` surfaces more proposals than an author intended | L | L | Every proposal still passes the existing per-channel `AskUserQuestion` gate; visibility, not unilateral action, is the only change. The fixture-wide check found zero instances of a null meaning anything other than "unresolved". |
| `implicit_open_count` is misread as implying an obligation to act | L | M | Document it as informational-only, parallel to `unknown_classes[]`'s existing "never a decision this stage makes unilaterally" framing. |
| Adding a new top-level key to the `--aggregate` JSON breaks a strict consumer | M | L | Verified at plan time: no schema validation exists for this output, and the only consumers are the four files named in Research Integration. Addition is strictly additive. |
| A sibling task (#371, #372) edits a shared conclusion-stage file concurrently | M | M | Both siblings dispatch this same cycle with undeclared `file_scope`. Re-read every target file immediately before editing; stage only this task's own hunks with an explicit file list, never a directory or glob; treat an out-of-scope failure as possibly a sibling's in-flight edit and report rather than "fix" it. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files (one
script vs. four docs) and may be run in either order or together.

**Source-store discipline (applies to every phase)**: every edit target below is under
`agent-system/extensions/core/**`. Never hand-author under `.claude/**` — that tree is a
disposable deploy artifact regenerated by Phase 4's `deploy-headless.sh` run. No file landing
under `agent-system/**` may contain a task-number reference.

---

### Phase 1: Widen the filter predicate and add the implicit-open tally [COMPLETED]

**Goal**: A null `resolution` on a non-win entry enters classification as `open`, and the
`--aggregate` output reports how many candidates arrived that way.

**Tasks**:
- [x] Re-read `scripts/orchestrate-conclusion-aggregate.sh` immediately before editing (sibling
      tasks are live on this tree this cycle). *(completed)*
- [x] At the `$candidates` binding (currently line ~253), change the coalesce default from
      `(.resolution // "")` to `(.resolution // "open")`. This single token is the entire
      functional fix; leave the rest of the predicate — including the `.kind != "win"` arm —
      byte-identical. *(completed)*
- [x] Add an `implicit_open_count` binding computed as
      `($candidates | map(select(.resolution == null)) | length)`, and emit it as a new top-level
      key in the final `jq` object, placed between `unknown_classes` and
      `no_contribution_tasks` (currently lines ~274-275). *(completed)*
- [x] Update the script's own header-comment usage block (the `--aggregate` paragraph, lines
      ~14-17) to name the new output field and state that a null/omitted `resolution` is read as
      `open`. The header is what `usage()` prints via `sed -n '2,46p'`; keep the edit inside that
      line range so `--help` still shows it.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose`
plus a standalone `jq -n` parse of the edited filter program is the complete covering check for
this phase — the edit is confined to one jq program inside one script with no signature, flag,
or exit-code change, and the suite that would otherwise cover it resolves the stale deployed copy
until Phase 4 deploys.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - filter coalesce default `""` -> `"open"`; new `implicit_open_count` binding and output key; header usage block updated

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0
  (no findings at -S warning).
- The edited jq program parses: extract it and run `jq -n` over it (or pipe a one-line synthetic
  entry through the extracted filter) and confirm exit 0.
- `grep -n 'resolution // "open"' agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`
  returns exactly one hit; `grep -c 'resolution // ""'` returns zero.
- `grep -n 'implicit_open_count' ...` returns both the binding and the output-key line.

---

### Phase 2: State what a null means, in both contracts and the report block [COMPLETED]

**Goal**: No reader of the schema or the stage contract can come away without knowing what a
null `resolution` means, and the new tally has a documented render line.

**Tasks**:
- [x] Re-read each target file immediately before editing it. *(completed)*
- [x] `context/formats/issue-log.md`: fill the `resolution` row's currently-empty Notes column
      (line ~94) to state that a null/omitted value is treated identically to `"open"` by the
      conclusion stage's filter, and that there is therefore no way to write a schema-legal
      `kind: "issue"` entry that is permanently unreachable. Keep the closed three-value set
      unchanged. *(completed)*
- [x] `context/contracts/conclusion-stage.md`, "The Filter Predicate" section (lines ~50-59):
      add the null-equals-open statement to the admission rule, so the section covers all four
      possible field states (`open`, `worked_around`, `fixed_inline`, null/omitted) rather than
      three. Do not restate the `kind: "win"` exemption — it is already correct. *(completed)*
- [x] `context/contracts/conclusion-stage.md`, Step 1 (line ~205): add `implicit_open_count` to
      the enumerated list of keys the lead parses out of `$aggregate_json`. *(completed)*
- [x] `context/contracts/conclusion-stage.md`, Step 2 (line ~216): extend the carry-as-is
      instruction to include `implicit_open_count` alongside `unknown_classes[]` and
      `no_contribution_tasks[]`. *(completed)*
- [x] `context/contracts/conclusion-stage.md`, "The Unknown-Class Tally" section (line ~96): add
      a short adjacent paragraph (or a sibling section immediately after it) documenting
      `implicit_open_count` as informational-only, explicitly mirroring that section's existing
      "never a decision this stage makes unilaterally" framing. *(completed: added as a new
      sibling section "The Implicit-Open Tally" immediately after)*
- [x] `context/patterns/orchestrate-batch-results-template.md`: add one rendered line to the
      `### Conclusion` block, immediately after the existing `**Unknown-class tally**:` line
      (~line 182), for the implicit-open count. *(completed)*
- [x] `docs/reference/utility-scripts-inventory.md`: in the `issue-record.sh` entry (line ~34),
      add one clause noting that an omitted `--resolution` writes an explicit null which the
      conclusion stage reads as `open`. Do NOT add a new row for
      `orchestrate-conclusion-aggregate.sh` — see Scope Hypothesis. *(completed: Scope Hypothesis
      re-confirmed, grep for "conclusion-aggregate" still returns no hit)*
- [x] Confirm no edit introduced a task-number reference or record-versioning language ("no
      longer", "previously", "supersedes") into any `agent-system/**` file. *(completed: verified
      via git diff grep and check-task-references.sh, 0 occurrences)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and
task-reference lint) together with a diff read-through confirming every hunk is prose inside a
markdown table cell or paragraph is the complete covering check — these four files have no
compile or elaboration surface, and the one mechanical consumer of their content
(`test-orchestrate-conclusion-aggregate.sh` case (k), which `awk`-parses `conclusion-stage.md`'s
Step 4a-4c blocks from the source store) is exercised directly by the phase check below.

**Scope Hypothesis**: `docs/reference/utility-scripts-inventory.md` is hypothesized to need only
the `issue-record.sh` row touched, not a new aggregator row — a plan-time
`grep -n "conclusion-aggregate" docs/reference/utility-scripts-inventory.md` returned no hit, and
the inventory's own stated inclusion criterion is "standalone scripts not invoked as part of the
normal research/plan/implement/postflight lifecycle", which the aggregator (Move 5 of
`/orchestrate`) is not. Confirm at implementation time by re-running that grep and re-reading the
inventory's inclusion criterion; if the criterion actually admits lifecycle scripts, add the row
rather than silently skipping it. This supersedes the research report's recommendation 5, which
assumed an aggregator row already existed.

**Files to modify**:
- `agent-system/extensions/core/context/formats/issue-log.md` - `resolution` row Notes column: null means `open`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Filter Predicate covers null; Step 1 parse list; Step 2 carry list; `implicit_open_count` documented beside the unknown-class tally
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - one new rendered line in the `### Conclusion` block
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - `issue-record.sh` row notes null's downstream meaning

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` passes (doc-lint, task-reference lint).
- Diff read-through: every changed hunk is markdown prose or a table cell; no code fence altered.
- `awk '/^### Step 4a/{f=1} /^### Step 4b/{f=0} f' agent-system/extensions/core/context/contracts/conclusion-stage.md`
  (and the 4b/4c equivalents) each still contain `--check-approval` with their own channel letter
  and no other's — i.e. case (k)'s invariant holds on the edited file.
- `grep -n "open" agent-system/extensions/core/context/formats/issue-log.md` shows the
  `resolution` row's Notes column is no longer empty.
- `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` (or gate 4 above)
  reports no new occurrence.

---

### Phase 3: Cover the null case in the aggregator's regression suite [COMPLETED]

**Goal**: The exact value that caused the live defect is asserted by the suite that should have
caught it.

**Tasks**:
- [x] Re-read `scripts/tests/test-orchestrate-conclusion-aggregate.sh` immediately before
      editing. *(completed)*
- [x] Extend Case (a) (lines ~196-212) — or add an adjacent Case (l) immediately before the
      final results block, matching the existing case-block style — with a
      `kind: "issue"`, `resolution: null` entry. The existing `write_entry` helper already
      accepts the literal string `null` for its resolution argument and writes a JSON null
      (line ~187), so no helper change is needed. *(completed: added Case (l) immediately before
      the final results block, not an extension of Case (a))*
- [x] Assert the null entry now appears in `proposals[]`'s `citations[]` for its class.
      *(completed)*
- [x] Assert `implicit_open_count` equals the number of null-resolution non-win entries in that
      scratch fixture. *(completed)*
- [x] Assert a `kind: "win"`, `resolution: null` entry is still excluded from `proposals[]` and
      still appears in `wins[]` — the win exemption must not regress as collateral of widening
      the filter. *(completed)*
- [x] Keep the suite's case lettering, `pass`/`fail` message style, and `PASSED`/`FAILED`
      counter convention identical to the surrounding cases.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose`
plus `bash -n scripts/tests/test-orchestrate-conclusion-aggregate.sh` is the covering check for
this phase — the edit adds a self-contained case block to one test file with no change to any
shared helper, and the suite's own green run is deferred to Phase 4 because it resolves the
stale deployed aggregator copy until the deploy happens.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - null-resolution admission case, `implicit_open_count` assertion, win-exemption non-regression assertion

**Verification**:
- `bash -n agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh`
  exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0
  (no findings at -S warning).
- The new case block's `pass`/`fail` strings follow the existing `(letter) name: detail` shape.

---

### Phase 4: Deploy, run the suites, and prove the fix on the real fixture [NOT STARTED]

**Goal**: The deployed tree carries the fix, the aggregator's suite is green including the new
case, and the real 739/740 entries produce three cited proposals where they previously produced
zero.

**Tasks**:
- [ ] **Capture the pre-fix baseline first, before deploying.** Build an isolated scratch root
      mirroring the suite's own `build_scratch` shape (`scripts/tests/test-orchestrate-conclusion-aggregate.sh`
      lines ~139-165): `mktemp -d`; create `<scratch>/.claude/scripts/lib/`; copy the CURRENT
      (pre-deploy) `.claude/scripts/orchestrate-conclusion-aggregate.sh`,
      `.claude/scripts/deploy-root-guard.sh`, `.claude/scripts/lib/common.sh`, and
      `.claude/scripts/lib/task-lookup-lib.sh` into it; create
      `<scratch>/specs/739_e2_depth_two_stratification_shared_stratum_falsifier/` and
      `<scratch>/specs/740_ktype_summary_finite_preds_restatement/`; write a
      `<scratch>/specs/state.json` whose `active_projects` carries those two
      `project_number`/`project_name` pairs; and COPY (never move, never edit) the two real
      `issues.jsonl` files from
      `~/Projects/BimodalLogic/specs/archive/{739_...,740_...}/issues.jsonl` into them.
- [ ] Run the scratch copy pre-deploy:
      `bash <scratch>/.claude/scripts/orchestrate-conclusion-aggregate.sh --aggregate --session sess_fixture_373 --tasks "739 740"`.
      Record that `proposals` is empty — this is the defect, reproduced, and the before-half of
      the acceptance criterion.
- [ ] Deploy the source-store changes: `bash .claude/scripts/deploy-headless.sh`.
- [ ] Rebuild the scratch root the same way, this time copying the POST-deploy
      `.claude/scripts/orchestrate-conclusion-aggregate.sh`, and re-run the same command.
- [ ] Assert the post-fix output: exactly 3 proposals — `tooling` with 3 citations (all task
      739), `proof-repair` with 1 citation (739), `gate-collision` with 2 citations (740) — 6
      citations total, `implicit_open_count` = 6, and `wins` length 9. Every one of the 4
      `fixed_inline` non-win entries must remain excluded.
- [ ] Run the targeted suites:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-build-dispatch.sh`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. All gates, not a subset
      — this is the final phase and the whole task's cross-cutting surface (a changed aggregator
      output shape, four changed contract/schema documents, and a redeployed tree) is in scope.
- [ ] Remove the scratch root. Confirm `~/Projects/BimodalLogic` is byte-unchanged
      (`git -C ~/Projects/BimodalLogic status --porcelain` shows nothing new under `specs/archive/`).

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: the expected post-fix figures asserted above (3 proposals; 6 citations;
`tooling`=3, `proof-repair`=1, `gate-collision`=2; `implicit_open_count`=6; `wins`=9; 4
`fixed_inline` non-win entries excluded) were derived at plan-authoring time by reading
`kind`/`class`/`resolution` off all 18 entries in the two live
`~/Projects/BimodalLogic/specs/archive/{739_...,740_...}/issues.jsonl` files — they are a
prediction about a future run, not a fact. Confirm by re-deriving the same tally from those two
files immediately before the post-deploy run (`jq -r '"\(.kind)\t\(.class)\t\(.resolution)"'`
over each file) and comparing against the aggregator's actual output; if the fixture has drifted
since, update the expected figures from the re-derivation rather than treating the mismatch as a
fix failure.

**Files to modify**:
- none planned - this phase deploys and verifies; `.claude/**` is regenerated by `deploy-headless.sh`, never hand-edited

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set (gates 1-22, including
  gate 8's full `tests/run-all.sh` battery, gate 3 doc-lint, gate 4 task-reference lint, gate 5
  manifest parity/content-hash equality, and gate 22 shellcheck), observed green in this
  dispatch, never trusted on sight.
- Pre-deploy fixture run: `proposals | length` == 0.
- Post-deploy fixture run: `proposals | length` == 3; `[.proposals[].citations[]] | length` == 6;
  `implicit_open_count` == 6; `wins | length` == 9; and the per-class citation counts match
  `tooling`=3, `proof-repair`=1, `gate-collision`=2.
- `run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-build-dispatch.sh`
  reports all cases passing, including the new null-resolution case and the unchanged case (a),
  (b), and (k).
- `git -C ~/Projects/BimodalLogic status --porcelain` shows no modification under
  `specs/archive/`.

## Testing & Validation

- [ ] The aggregator's regression suite passes, including a new case asserting a null-resolution
      `kind: "issue"` entry reaches `proposals[]`.
- [ ] The `kind: "win"` exemption is asserted intact with a null resolution — not regressed as
      collateral of widening the filter.
- [ ] `fixed_inline` entries remain excluded (existing case (a) still green).
- [ ] `implicit_open_count` is present in the `--aggregate` output and equals the null-sourced
      candidate count.
- [ ] The real 739/740 fixture yields 3 proposals / 6 citations post-fix and 0 proposals pre-fix.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 on the redeployed tree.
- [ ] No file under `agent-system/**` contains a task-number reference (gate 4).
- [ ] Both `issue-log.md` and `conclusion-stage.md` state what a null `resolution` means — the
      task description's unconditional requirement, independent of the remedy chosen.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - widened filter, new `implicit_open_count` output field, updated usage header
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - null-resolution regression case
- `agent-system/extensions/core/context/formats/issue-log.md` - `resolution` row states null's meaning
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Filter Predicate covers null; `implicit_open_count` documented; Step 1/Step 2 lists extended
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - implicit-open render line in the `### Conclusion` block
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - `issue-record.sh` row notes null's downstream meaning
- Regenerated `.claude/**` deploy artifact (from `deploy-headless.sh`, not hand-authored)
- `specs/373_null_resolution_entries_unreachable_by_conclusion_stage/summaries/01_*-summary.md` (implementation phase)

## Rollback/Contingency

Each phase commits independently with an explicit file list, so reverting is a per-phase
`git revert` of the relevant commit followed by `bash .claude/scripts/deploy-headless.sh` to
bring the deployed tree back in line with the source store. The functional fix is one token
(`""` -> `"open"`) plus one strictly additive output key, so a partial revert is coherent: the
doc edits stand on their own (they describe the stage's behavior, and a reverted filter would
make them wrong — revert both together, or neither).

Nothing in this plan edits uncommitted work belonging to another writer, and no phase needs a
reverting working-tree rollback. If a defensive checkpoint is wanted before Phase 4's deploy
(the only step that rewrites a tree wholesale), take a durable, non-reverting one:
`bash .claude/scripts/git-snapshot.sh 373 --no-revert`. A genuine rollback — one that discards
working-tree state — follows `context/contracts/recovery.md`'s rollback rung for the exact
invocation shape, including its out-of-scope override flag; never emit the bare reverting form as
a routine precaution.

The BimodalLogic fixture is read-only input: it is copied into a scratch root, never mutated, so
no rollback there is ever owed.
