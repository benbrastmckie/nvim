# Implementation Plan: Task #549

- **Task**: 549 - Give the Lean `unusedArguments` remedy a narrow route instead of the wholesale
  `runLinter --update` rewrite
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None (`state.json` `dependencies: []`; the BimodalLogic-numbering edge on 785
  was dropped at migration — `migrated_from.dropped_dependencies: [785]`, re-verified at plan time)
- **Research Inputs**: specs/549_lean_unusedarguments_narrow_remedy_route/reports/01_unusedarguments-narrow-remedy.md
- **Artifacts**: plans/01_unusedarguments-narrow-remedy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The deliverable is one new Condition appended to the lean extension's existing plan-authoring
gate-collision checklist, recording that `lake exe runLinter --update <lib>` is a wholesale lint-ledger
reserialization rather than an additive insert, naming the narrow hand-insert route a plan should
pre-authorize instead, and deciding ledger-row versus in-source `set_option` for the
`unusedArguments` category. Appending to that file moves a quantity its `index-entries.json` entry
derives (`line_count`), and the check that detects the drift is commit-blocking, so the metadata
reconciliation is scheduled in the same phase as the append rather than deferred. A final phase
redeploys the tree so the two source-store edits reach the deployed `.claude/**` mirror, and
discharges the orchestration's gate obligation.

### Research Integration

The research report's core findings were re-verified against live state at plan time and hold: the
target file exists (228 lines, nine Conditions, wired into both `EXTENSION.md` and
`index-entries.json`), the dispatch's "task 785 creates it" framing is stale for this repository,
and neither named relation task (539, 544) has any written artifact to collide with. The report's
drafted Condition text is carried forward as the Phase 1 draft, refined with four facts measured
at plan time (ledger shape, row count, serialization granularity, sort order) and with one
correction.

**One research finding is corrected by plan-time measurement.** Report Finding 6 states that
`index-entries.json`'s `line_count` drift is advisory-only, on the evidence that
`validate-context-index.sh` calls `log_warning` rather than `log_error`. That is true of
`validate-context-index.sh` but is not the whole enforcement surface:
`check-extension-docs.sh`'s Rule R (`check_line_count_accuracy`, source line ~793) compares
`declared` against `wc -l` with **exact string equality and no tolerance** and reports through
`index_truth_report`, i.e. FAIL — and `verify-deploy.sh` gate 3 runs
`check-extension-docs.sh --quiet`. The `line_count` update is therefore **commit-blocking**, which
is why this plan folds it into Phase 1 instead of following the report's "cheap to do in the same
phase, but advisory" framing or leaving it for a later consumer.

Report Recommendation 1 (add `index-entries.json` to `proposed_file_scope`) is already satisfied:
`state.json`'s `file_scope` for this task already names both the pattern file and
`index-entries.json`. No scope change is needed.

### Prior Plan Reference

No prior plan. `plans/` did not exist before this dispatch.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and `roadmap_flag` is not
set, so no roadmap consultation was performed and no roadmap phases are added.

### Domain Plan-Authoring Gotchas Queried

The deployed context index was queried for a `project/**` entry whose
`load_when.task_types[]` contains this dispatch's own `task_type` (`meta`) and whose
`keywords[]`/`topics[]` name `plan-authoring`. **Zero hits** — the two entries carrying a
`plan-authoring` keyword (`project/lean4/patterns/dependency-tracing.md` and the target file
itself) are both scoped to `task_types: ["lean4"]`, not `meta`. Zero hits is the expected case for
`meta`; no additional checklist items were imported from that layer. The target file's own nine
Conditions were nonetheless read in full, because they are this task's edit target.

## Carried-Figure Re-Validation

The dispatch's Premise Re-Validation block extracted two lines. Both were checked, and the result
is stated explicitly here even where it only confirms the description unchanged.

| Carried figure | Verification result |
|---|---|
| "1,119 lines changed, rather than adding the single row" (dispatch line 33) | **Carried as cited, not re-measured.** This figure records the diff size of one `lake exe runLinter --update FormalSystem` run in the source repository. Re-measuring it would require re-running that command, which this dispatch forbids outright ("Do NOT run `lake exe runLinter --update` as part of this record"). Corroborating live measurement at `/home/benjamin/Projects/BimodalLogic/scripts/nolints.json`: the ledger is **914 lines** holding **228 rows**, every row of category `unusedArguments`, in a flat `[[linter, declName], …]` array serialized one element per line (a 4-line block per row: `[`, the linter string, the declaration string, `]`; 228 × 4 + 2 bracket lines = 914 exactly). A wholesale reserialization of a 914-line file plausibly yields a four-figure changed-line count, so the cited figure is consistent with the file's measured size; it is not independently confirmed. |
| "dropped edge(s) on source-repository task(s) 785" (dispatch line 80) | **Confirmed unchanged.** `specs/state.json`'s entry for project 549 carries `"dependencies": []` and `"migrated_from": {"dropped_dependencies": [785], …}`. There is no outstanding blocker, and no local task creates the target file as a first-time act — it already exists, authored by unrelated completed local work. |

Two further dispatch assertions were measured at plan time because this plan's own text depends on
them:

- **"its four exemption rows are intended"** (dispatch line 80) — **does not describe the file as
  it now stands.** The ledger holds 228 rows, not four. The figure is best read as the rows the
  originating incident itself touched, not as a census of the file. This plan does not rely on the
  figure either way: the dispatch's standing instruction is that the ledger is correct as-is and
  must not be re-edited, which this plan honors (no phase touches it, and it is deliberately
  absent from every `Files to modify` block).
- **"next to `Bof`'s identical exemption"** (dispatch line 52) — **confirmed, and sharper than
  stated.** `FormalSystem.Metalogic.Decidability.RaySummary.Bof` sits at row index 221 (file line
  888) and `…RaySummary.tpOf_eq_spliceIdx_of_tpOf_eq` at index 222 (line 892) — literally
  adjacent. Three further `RaySummary` rows follow, consistent with the dispatch's note that the
  same remedy was needed again for a second Goal. Measured additionally: the ledger is **not
  sorted** (`[.[][1]] == sort` is `false`); rows sit in append order. This matters for the
  guidance text — "place the row next to an existing exemption of the same shape" is not an
  aesthetic preference but the only format-faithful option, because the file carries no canonical
  sort for a hand-insert to respect, while `--update` imposes its own.

## Goals & Non-Goals

**Goals**:
- Record, in the lean extension's existing plan-authoring gate-collision checklist, that
  `lake exe runLinter --update <lib>` regenerates the whole lint ledger in its own serialization
  and is not an additive insert.
- Name the narrow route a plan should pre-authorize instead: a hand-inserted row in the ledger's
  own existing format, placed next to an existing exemption of the same shape.
- State why the finding is predictable rather than incidental: a Goal whose signature is pinned by
  a plan's Challenge Statements block trips `unusedArguments` whenever the pinned hypothesis is not
  read by the proof body.
- Decide and record ledger-row versus in-source `set_option` for this category, with the condition
  under which each is correct, stating the rejected option on its own merits.
- Keep `index-entries.json`'s derived metadata for that file truthful in the same phase that moves
  it, so the commit-blocking Rule R check stays green.
- Land both edits in the deployed tree by regeneration, never by hand-authoring under `.claude/**`.

**Non-Goals**:
- No edit to `/home/benjamin/Projects/BimodalLogic/scripts/nolints.json`, to any Goal, or to any
  in-source `set_option` line. The dispatch states the ledger is correct as it stands; this is not
  a data-repair record.
- No invocation of `lake exe runLinter --update` in any form, including to re-measure the cited
  1,119-line figure.
- No new pattern file. The deliverable is the next Condition appended to the existing checklist,
  not a competing home for the same material.
- No new pinning rule. Tasks 539 and 544 own the Challenge-Statements-pinning mechanism; this
  record adds only the linter-remedy consequence of pinning.
- No `EXTENSION.md` change. It already references the file by path with a description
  ("Gate collisions for plan authoring") that does not turn on the condition count.
- No correction of the one pre-existing, sibling-owned `line_count` drift (see Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The baseline for gate 3 is already RED, so a naive "gate 3 exits 0" criterion is unmeetable as written | M | H (measured, already true) | Measured at plan time: `verify-deploy.sh --skip-slow --only-gate 3,4` exits 1 with **exactly one** finding — `lean` entry `project/lean4/tools/mcp-tools-guide.md` `line_count` declared 198, actual 207. That path is outside this plan's `Files to modify` union. Every gate-3 criterion below is written as a baseline delta: a pass requires that every finding name a file outside this plan's union. |
| `generate-context-line-counts.sh --write` corrects the sibling-owned drift in the same shared file, pulling a foreign change into this task's commit | M | H | The mismatched entry belongs to concurrent sibling task 463, whose Phase 1 edits `mcp-tools-guide.md` and is `[IN PROGRESS]`. Phase 1 therefore **hand-edits only this task's own entry's `line_count`** rather than running `--write` — the narrow route, exactly parallel to the guidance this record is authoring. Phase 2's deploy runs `--write` automatically; the handling for the hunk it produces is specified in Phase 2's tasks. |
| Another dispatch appends a Condition before this one lands, making a hard-coded "Condition 10" heading wrong or duplicated | L | L | No sibling in this cycle's Territory JSON claims the pattern file, but task 576 depends on 549 and claims it for later work. Phase 1's first task re-reads the file immediately before editing and numbers the addition as the next free slot. The Scope Hypothesis makes the "10" a hypothesis to confirm, not a fact. |
| The declared `line_count` is off by one because the appended block's trailing newline is miscounted | M | M | Rule R compares against `wc -l` with exact equality and no tolerance. Phase 1's verification reads the declared value back and asserts byte equality with `wc -l` output, and runs `generate-context-line-counts.sh --check` to confirm this task's own entry is absent from its mismatch census. |
| The new Condition restates content tasks 539/544 own, or leaks task-management metadata into a deliverable | M | L | Both relation tasks were confirmed `not_started` with empty `artifacts` at research and plan time — nothing written to restate. The Condition text states the linter-remedy consequence only, with no pinning rule of its own. Phase 1 verification greps the new hunk for task references, `iss_*` ids, and record-versioning language. |
| The redeploy collides with the sibling's own whole-tree regeneration | M | M | Phase 2 declares the reserved `__WHOLE_TREE__` sentinel so `orchestrate-batch-admit.sh`'s `whole_tree_claim` dimension serializes it against sibling 463's Phase 4, which declares the same sentinel. |
| `deploy-headless.sh` fails and leaves the deployed tree stale | M | L | The source store is the authoritative record and is already correct at that point. Phase 2's contingency records the failure via `issue-record.sh` and leaves the deployed tree stale rather than hand-editing `.claude/**`, which `source-store-deploy-boundary.md` forbids outright. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Append the `unusedArguments` Ledger-Row Condition and Reconcile Its Index Entry [COMPLETED]

**Goal**: The lean extension's plan-authoring gate-collision checklist carries a new Condition
stating that `lake exe runLinter --update <lib>` is a wholesale ledger reserialization, naming the
narrow hand-insert route, explaining why a pinned Challenge hypothesis makes the finding
predictable, and deciding ledger-row versus in-source `set_option` with the condition under which
each is correct — and `index-entries.json`'s derived metadata for that file is truthful in the same
commit.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
      in full immediately before editing (per this dispatch's Territory concurrency note), and
      record the highest existing Condition number. At plan time it is 9, so the new heading is
      `## Condition 10`; if the file has gained Conditions in the interim, use the next free number
      instead of hard-coding 10. *(completed: re-read confirmed 9 was still the highest at
      implementation time, so the new heading is Condition 10)*
- [x] Append the new Condition at end-of-file, after Condition 9's trailing companion checklist
      (the C15 / C33 / `FAIL INV` bullets). That checklist is scoped under Condition 9's heading, so
      a new `## Condition` heading closes it cleanly; do not insert ahead of it, which would split
      Condition 9's own body. *(completed)*
- [x] Author the Condition in the file's established style: a descriptive `## Condition N — …`
      heading, the mechanism in prose, bolded lead-ins for the sub-points, and a closing
      `**Plan-authoring consequence**:` bullet. The drafted text below is ready to lift; adjust
      only the heading number and any wording needed to match surrounding voice.

  > ## Condition 10 — `unusedArguments` From the Batch Env-Linter Is a Ledger-Row Remedy, Not an In-Source `set_option`
  >
  > `lake exe runLinter --update <lib>` regenerates the whole project lint ledger
  > (`scripts/nolints.json`) in its own serialization; it is **not** an additive insert. A phase
  > that names it as the remedy for a single `unusedArguments` finding is authorizing a
  > repository-wide file rewrite in the middle of that phase — one measured run rewrote 1,119 lines
  > to record one intended exemption.
  >
  > **The narrow route**: hand-insert the one exemption row directly, in the ledger's own existing
  > format, placed next to an existing exemption of the same shape. The ledger is a flat
  > `[[linterName, declName], …]` array serialized one element per line, so a row is a four-line
  > block, and the file carries no canonical sort for an insert to respect — rows sit in append
  > order. Adjacency to a sibling exemption is therefore the format-faithful placement, not a
  > stylistic preference, and `--update`'s own serialization is what makes it a wholesale rewrite.
  > Carry the reason in the in-source `set_option` suppressions already attached to the declaration
  > for its other linter categories, not in the ledger row, which has no comment field.
  >
  > **Why this finding is predictable, not incidental**: a Goal whose signature is PINNED by a
  > plan's Lean Challenge Statements block trips `unusedArguments` whenever the pinned hypothesis
  > is not read by the proof body — the hypothesis is in the signature because the Challenge pins
  > it, not because the proof needs it. Each pinned-but-unread hypothesis produces one finding, and
  > a plan pinning several such Goals meets the same collision once per Goal.
  >
  > **Ledger row vs. in-source `set_option` — match the surface to the linter's category.**
  > `unusedArguments` is raised by the batch/environment-linter pass (`lake exe runLinter`, the
  > `#lint` family), which walks the declared environment after elaboration and is suppressed by a
  > ledger row — or by an in-source nolint *attribute* (`@[nolint unusedArguments]`) where the
  > harness is confirmed to support it — never by a `set_option`. A locally scoped
  > `set_option linter.<name> false in` immediately above one declaration is the correct mechanism
  > only for genuinely elaboration-time linter categories, `unusedVariables` and
  > `unusedFintypeInType` among them, which is why those two can sit as `set_option` lines on the
  > same Goal while `unusedArguments` cannot. The appeal of the uniform in-source option is real —
  > it keeps every exemption beside the declaration that needs it, self-documents, touches no
  > shared file, and gives the Goal one suppression style instead of two — but the batch pass does
  > not read an option named after a linter it owns, so adopting it risks a silent no-op: the gate
  > still reports the finding when it next runs, discovered only at that point. Under `--wfail`
  > (Condition 8) that is a hard failure, not a note.
  >
  > **Plan-authoring consequence**: a plan whose Challenge Statements block pins a hypothesis a
  > Goal's proof will not read pre-authorizes the narrow ledger-row remedy at authoring time —
  > naming the ledger file, the hand-insert technique, and the adjacent existing row — and carries
  > the ledger file in its own file scope. It does not name `runLinter --update` as a remedy, and
  > does not reach for a `set_option` for this category.

- [x] Verify the authored hunk carries no task-management metadata and no record-history framing:
      no `task N` / `tasks N-M` reference, no `iss_*` identifier, and none of
      `previously|no longer|formerly|used to|superseded|withdrawn|carried forward`. The three
      permitted durable version axes are unaffected — the text pins no toolchain or schema version.
      *(completed: grep over the new hunk returned no matches for either pattern class)*
- [x] Recompute the file's line count: `wc -l agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`.
      *(completed: 272 lines, up from 228)*
- [x] Hand-edit `agent-system/extensions/lean/index-entries.json`'s entry for
      `project/lean4/patterns/plan-authoring-gate-collisions.md`: set `line_count` to that exact
      measured value (228 at plan time, plus whatever the appended block adds), and broaden
      `summary` from "Nine gate surfaces a Lean plan author must enumerate…" to state the new count
      and name the added surface (for example "…plus the batch env-linter's ledger-row remedy").
      Do **not** run `generate-context-line-counts.sh --write`: it rewrites every mismatched entry
      in the file, and one pre-existing mismatch in this same file belongs to a concurrent sibling
      (see this phase's Scope Hypothesis and the Risks table).
- [x] Add retrieval keywords to that entry's `keywords` array so the new Condition is findable:
      `nolints`, `runLinter`, `unusedArguments`. A plan-time `grep -rln` over `agent-system` for
      `runLinter|nolints|unusedArguments` found no existing guidance at all, so these keywords
      carry the only route to this material. *(completed)*
- [x] Confirm the hand-edit changed only this task's own entry:
      `git diff -- agent-system/extensions/lean/index-entries.json` shows hunks confined to the
      `plan-authoring-gate-collisions.md` entry, with no change to the `mcp-tools-guide.md` entry's
      `line_count`. *(completed: diff confined to one entry, three-hunk, no mcp-tools-guide.md change)*
- [x] Commit, staging the two files by explicit path (never a directory or glob pathspec).
- [x] Record any issue or win via `issue-record.sh` as it arises; if there is genuinely nothing to
      record for this phase, attest that explicitly in the handoff prose.
      *(completed: win recorded — gate 3,4 and generate-context-line-counts.sh --check both came
      back fully green rather than the plan-time-measured baseline RED, i.e. the sibling-owned
      mcp-tools-guide.md mismatch was resolved by another dispatch in the interim)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --quiet --only
test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh,test-roadmap-command-registration.sh`
is the covering check for the `index-entries.json` edit — `suite_selection_select` returned exactly
this six-suite set for that path at authoring time, and the justification names all six rather
than the schema/reachability pair alone, so the tier does not under-verify its own selection. The
markdown path maps to `__FULL_SWEEP__` (no suite covers it), so
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
supplies plan-format.md's sub-case (b) gate subset for a source-store non-`specs/**` markdown edit,
with the repository root (the directory holding `.claude-extensions.json`) passed as `TARGET`
rather than the resolved `source_dir`.

**Scope Hypothesis**: exactly two files change, the markdown edit is a single append-at-EOF hunk
touching no existing line, and the JSON edit touches only the
`plan-authoring-gate-collisions.md` entry. The new Condition's number is 10. Confirm with
`git diff --stat` showing exactly those two paths; with `git diff --
…/plan-authoring-gate-collisions.md` showing one hunk whose every line is an addition at
end-of-file; with `git diff -- …/index-entries.json` showing no `mcp-tools-guide.md` hunk; and with
`grep -c '^## Condition ' …/plan-authoring-gate-collisions.md` returning one more than the
pre-edit count. A separately measured fact this hypothesis does **not** assert: the file already
carries one unrelated `line_count` mismatch for `project/lean4/tools/mcp-tools-guide.md` (declared
198, actual 207) owned by concurrent sibling task 463 — it is expected to remain uncorrected by
this phase, and correcting it is out of scope.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md` -
  append the new Condition at end-of-file: the wholesale-reserialization mechanism, the narrow
  hand-insert route with the ledger's measured format, the predictability of the finding under a
  pinned Challenge hypothesis, the ledger-row-vs-`set_option` decision with the rejected option on
  its own merits, and the closing plan-authoring consequence
- `agent-system/extensions/lean/index-entries.json` - the coupled generated surface for the edit
  above: set this entry's `line_count` to the post-append `wc -l` value, broaden its `summary` to
  state the new condition count and the added surface, and add the `nolints` / `runLinter` /
  `unusedArguments` retrieval keywords

**Verification**:
- `grep -n '^## Condition ' …/plan-authoring-gate-collisions.md` shows the new heading as the
  last `## Condition` in the file, and the C15 / C33 / `FAIL INV` companion checklist still sits
  above it, under Condition 9.
- `grep -nE 'runLinter --update|nolints\.json|@\[nolint|set_option linter' …/plan-authoring-gate-collisions.md`
  shows all four mechanisms present in the new hunk.
- `grep -nE '\btasks? [0-9]+\b|iss_[0-9]+' <the new hunk>` returns nothing.
- `grep -nEi 'previously|no longer|formerly|used to|superseded|withdrawn|carried forward' <the new hunk>`
  returns nothing.
- `jq -r '.entries[] | select(.path=="project/lean4/patterns/plan-authoring-gate-collisions.md") | .line_count' agent-system/extensions/lean/index-entries.json`
  equals `wc -l < …/plan-authoring-gate-collisions.md` byte for byte — Rule R compares with exact
  equality and no tolerance.
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no mismatch naming
  `plan-authoring-gate-collisions.md`. It still exits 1 on the pre-existing
  `mcp-tools-guide.md` mismatch (`declared 198, actual 207`, measured at plan time); that single
  out-of-scope finding is the expected baseline, not a regression. If a mismatch naming this
  plan's own files appears, that is a real failure.
- `jq -e '.entries[] | select(.path=="project/lean4/patterns/plan-authoring-gate-collisions.md") | (.keywords | index("nolints")) and (.keywords | index("unusedArguments"))' agent-system/extensions/lean/index-entries.json`
  exits 0, and `jq empty agent-system/extensions/lean/index-entries.json` exits 0.
- `bash .claude/scripts/tests/run-all.sh --quiet --only test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh,test-roadmap-command-registration.sh`
  exits 0. Measured green at authoring time (`6 passed, 0 failed (0 expected, 0 NEW), 0 skipped,
  6 total`), so this is an absolute criterion, not a delta.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  — measured RED at authoring time with exactly one finding, the `mcp-tools-guide.md`
  `line_count` mismatch owned by sibling task 463. A pass for this phase requires that every
  finding name a file outside this plan's `Files to modify` union, enumerated in the handoff. A
  finding naming either of this plan's own two files is a blocker; the sibling-owned finding is
  not, and is not grounds to edit an out-of-scope file.
- No file under any deployed `.claude/` tree was hand-edited.
- One commit, scoped to these two files by explicit path.

---

### Phase 2: Redeploy and Discharge the Gate Obligation [NOT STARTED]

**Goal**: Phase 1's two source-store edits reach the deployed `.claude/**` mirror by regeneration,
and this orchestration's complete gate obligation is discharged or explicitly deferred to the
orchestration close.

**Tasks**:
- [ ] Confirm the source store is the only place Phase 1 edited:
      `git status --short` shows no hand-authored modification under `.claude/`.
- [ ] Run the redeploy with the bounded-wait idiom required by
      `context/patterns/external-process-wait.md` Rule 1:
      `timeout 540 bash .claude/scripts/deploy-headless.sh /home/benjamin/.config/nvim`, with the
      Bash tool `timeout` parameter raised to 600000 (not its 120000 ms default).
- [ ] Confirm both edits reached the deployed tree: the new Condition heading appears in
      `.claude/context/project/lean4/patterns/plan-authoring-gate-collisions.md`, and the deployed
      `.claude/context/index.json` entry for that path carries the new `line_count` and the new
      keywords.
- [ ] Inspect `git diff -- agent-system/extensions/lean/index-entries.json` after the deploy.
      `deploy-headless.sh` runs `generate-context-line-counts.sh --write` automatically before
      every deploy, so it may have additionally corrected the sibling-owned `mcp-tools-guide.md`
      `line_count` (198 -> 207) in that same file. If that hunk is present, leave it **unstaged**
      and name it in the handoff: it is a regenerable value belonging to concurrent sibling task
      463's in-flight edit, not this task's to commit. Stage only this task's own hunks, if any
      remain.
- [ ] If a foreign commit, a foreign uncommitted modification outside the one characterized above,
      or a running build this dispatch did not start is observed, STOP and report it — after
      checking `git log` to confirm the work is not this task's own — rather than proceeding.
- [ ] Commit the regenerated deploy-tree paths this task owns, staging by explicit path.
- [ ] Record any issue or win via `issue-record.sh` as it arises; if there is genuinely nothing to
      record for this phase, attest that explicitly in the handoff prose.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: this phase authors no source edit of its own — it regenerates the deployed
tree, so every path it changes under `.claude/**` is a generated copy, and the deployed copies of
the pattern file and of `index.json` are covered by the `__WHOLE_TREE__` sentinel rather than
enumerated. Confirm with `git status --short` showing no modification under
`agent-system/extensions/lean/` attributable to this phase other than the characterized
`generate-context-line-counts.sh --write` effect on `index-entries.json`.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree, so this phase is
  declared as a whole-tree claimant. The deployed copies of
  `.claude/context/project/lean4/patterns/plan-authoring-gate-collisions.md` and
  `.claude/context/index.json` are covered by this sentinel and are not enumerated separately.

**Verification**:
- `deploy-headless.sh` reported `RESULT=landed_verify_clean` or `RESULT=landed_verify_red`; a
  `RESULT=not_landed` is a failure handled by the contingency below.
- `grep -c '^## Condition ' .claude/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
  equals the same count in the source-store copy.
- `jq -r '.entries[] | select(.path=="project/lean4/patterns/plan-authoring-gate-collisions.md") | .line_count' .claude/context/index.json`
  equals the source-store value and equals `wc -l` of the deployed markdown file.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  — read as a baseline delta against the authoring-time measurement (one finding, the
  sibling-owned `mcp-tools-guide.md` mismatch). Note that this phase's own deploy may have
  corrected that very finding as a side effect, in which case the gate goes green; either outcome
  is a pass, and a finding naming this task's own files is not.
- **Scoped touched-path check, then explicit deferral.** This is the plan's final phase, so it
  declares tier `full`; under `/orchestrate` its own in-dispatch obligation is the scoped
  touched-path check —
  `bash .claude/scripts/verify-touched.sh` over this task's touched paths, plus the gate-3,4
  subset above — and an explicit deferral of the complete gate battery to the orchestration
  close (Move 4), never an independent full-battery invocation as this phase's own criterion. The
  complete gate set is still owed once per orchestration invocation and is discharged there. Run
  as a standalone, non-orchestrated phase with no Move 4 to defer to, this criterion becomes
  `bash .claude/scripts/tests/run-all.sh` plus
  `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` directly.
- No file under any deployed `.claude/` tree was hand-edited; the deployed copies differ from the
  prior state only by regeneration.

---

## Testing & Validation

- [ ] The new Condition is the last `## Condition` in the pattern file, and Condition 9's companion
      checklist still sits under Condition 9.
- [ ] The Condition states all four required facts: the wholesale-reserialization mechanism of
      `runLinter --update`; the narrow hand-insert route in the ledger's own format next to a
      same-shape row; the predictability of the finding under a pinned Challenge hypothesis; and
      the ledger-row-vs-`set_option` decision with its condition and the rejected option on its own
      merits.
- [ ] `index-entries.json` is valid JSON, its entry's `line_count` equals `wc -l` exactly, its
      `summary` states the new count, and its `keywords` carry the three new retrieval terms.
- [ ] `generate-context-line-counts.sh --check` reports no mismatch naming this plan's own files.
- [ ] The six-suite `run-all.sh --only` set selected for `index-entries.json` exits 0.
- [ ] `verify-deploy.sh --skip-slow --only-gate 3,4` reports no finding naming this plan's own
      files.
- [ ] No deliverable file carries a task-number reference, an `iss_*` identifier, or
      record-versioning language.
- [ ] Nothing under `/home/benjamin/Projects/BimodalLogic/` was modified; `scripts/nolints.json`
      there is untouched and `lake exe runLinter --update` was never run.
- [ ] No file under any deployed `.claude/` tree was hand-authored.

## Artifacts & Outputs

- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
  — one new Condition appended.
- `agent-system/extensions/lean/index-entries.json` — the reconciled entry for that file
  (`line_count`, `summary`, `keywords`).
- Regenerated deployed copies under `.claude/context/project/lean4/patterns/` and
  `.claude/context/index.json` (generated, not hand-authored).
- `specs/549_lean_unusedarguments_narrow_remedy_route/summaries/01_unusedarguments-narrow-remedy-summary.md`
  at completion.

## Rollback/Contingency

- **If Phase 1's verification fails**: the two edits are confined to one append-at-EOF hunk and one
  JSON entry. Revert with `git checkout HEAD --` on the two named paths (the working tree must be
  clean for that path, or take a defensive checkpoint first with
  `bash .claude/scripts/git-snapshot.sh 549 --no-revert` — `--no-revert`, never the default
  reverting form, since this is a checkpoint rather than a rollback), then re-apply.
- **If the declared `line_count` cannot be made to match**: the remedy is the exact `wc -l` value,
  not a tolerance — Rule R has none. Re-measure after every subsequent edit to the markdown file;
  do not reach for `generate-context-line-counts.sh --write`, which would pull the sibling-owned
  entry into this task's commit.
- **If `deploy-headless.sh` reports `not_landed`**: the source store is already correct and is the
  authoritative record. Record the deploy failure via `issue-record.sh` and leave the deployed tree
  stale rather than hand-editing `.claude/**` to simulate the deploy —
  `source-store-deploy-boundary.md` forbids that remedy outright. The task completes with the
  source-store edit landed and the deploy deferred.
- **If a rollback of Phase 1 is needed after Phase 2 has deployed**: revert the two source-store
  paths first, then re-run `deploy-headless.sh` to bring the deployed tree back in line with the
  reverted source store. Never hand-edit the deployed tree to undo a deploy.
