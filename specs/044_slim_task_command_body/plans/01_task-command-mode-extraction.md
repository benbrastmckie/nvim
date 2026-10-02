# Implementation Plan: Task #44

- **Task**: 44 - slim_task_command_body
- **Status**: [IMPLEMENTING]
- **Effort**: 6.0 hours
- **Dependencies**: None
- **Research Inputs**: `specs/044_slim_task_command_body/reports/01_command-body-extraction-approach.md`
- **Artifacts**: plans/01_task-command-mode-extraction.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/commands/task.md` is a dispatcher over six mutually exclusive
modes; every `/task` invocation loads all six mode bodies but executes at most one. The five
non-default modes total 25,883 B (65.7% of the 39,403 B file). This plan extracts each of those
five modes verbatim into its own `context/patterns/task-{mode}-mode.md` file, plus the Create
Task Mode worked-examples/edge-case sub-region, replacing each with an imperative `READ ... now
and follow it exactly` pointer sited at the Mode Detection dispatch table. The mechanism is the
one already established in this repo for `todo.md`/`orchestrate.md` (commits `588cab9c5`,
`398bc8cbd`); the divergence is granularity — whole modes rather than reference appendices —
which is why the risk treatment and the mode-executability audit phase are stronger here than
the precedent needed.

### Research Integration

Findings carried into the plan without re-litigation:

- The per-mode byte breakdown and line ranges from the report's measurement table (independently
  re-measured during planning: recover 4,409 / expand 3,196 / sync 5,082 / review 10,085 /
  abandon 3,111 / examples 1,707 — all confirmed).
- `manifest.json` needs no edit: `.provides.context` already lists `patterns` wholesale
  (verified during planning).
- No cross-mode repointing is required *given* Create Task Mode stays inline. The two
  `Create Task jq pattern` references live at lines 428 (Expand Mode) and 809 (Review Mode) —
  both inside regions being extracted, so both get the wording micro-fix in Phase 6.
- Pointer wording must pass the passive/imperative test established by the precedent
  (`READ ... now and follow it exactly`, never "see also").

### Prior Plan Reference

No prior plan for this task. The sibling task archived at
`specs/archive/056_slim_todo_and_orchestrate_command_bodies/` supplies the mechanism and the
measurement-table convention this plan reuses; its explicit *rejection* of slimming `task.md`
was scoped to the "does it have a Notes-shaped appendix" question and does not bind the
mode-granularity approach taken here (see the research report's "Why the sibling task's
rejection doesn't transfer").

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap consultation was
performed.

## Goals & Non-Goals

**Goals**:
- Reduce `commands/task.md`'s per-invocation body by ~65-70% (target: 39,403 B -> ~12,300-13,400 B).
- Every mode remains **fully executable**, either inline or through a pointer whose imperative
  framing makes following it non-optional.
- Zero behavior change. Every relocated byte is relocated verbatim; the one content
  reconciliation (Action Verb Categories) is decided explicitly below and widens nothing that is
  not already effectively in force today.
- All six new context files registered in `index-entries.json` with accurate `line_count`.
- Before/after bytes measured and recorded in a measurement table, per the task's own constraint
  and the precedent's convention.

**Non-Goals**:
- Extracting Create Task Mode's core body (steps 1-2, 3.1-3.3, 4-4e, 4.5, 5-8). It is the
  default no-flag mode and the most frequent invocation shape; pointer-izing it would penalize
  the common case and would dangle the two `Create Task jq pattern` cross-references.
- Extracting Mode Detection, the CRITICAL `$ARGUMENTS` warning, or Constraints — all three apply
  to every invocation regardless of dispatched mode.
- Editing `.claude/**`. That tree is a disposable deploy artifact
  (`.claude/rules/source-store-deploy-boundary.md`).
- Redeploying. Regenerating `.claude/` from the source store is a separate operation, out of
  scope here.
- `manifest.json` changes.

## Decision: Action Verb Categories keyword discrepancy — MERGE-AND-DROP

The research flagged this and deliberately left it open. **Decision: option (a), merge the fuller
category table into step 3.2's inline bullets and delete the standalone `Action Verb Categories`
table.** Reasoning:

1. **This is the behavior-preserving option, not the behavior-changing one.** Today both the 3.2
   bullets and the standalone table sit inline in the same always-loaded region. An agent
   executing `/task` today sees both, so today's *effective* keyword set at decision time is
   already the union. Merging the union into 3.2 preserves exactly that; it does not widen
   anything.
2. **Option (b) is the one that narrows.** Keeping 3.2's four short bullets inline and relocating
   only the extra keywords would make 7 of today's ~19 keywords conditional on a READ that may
   not happen — converting an unconditional decision input into a conditional one. That is
   precisely the silent narrowing the task's "do not change command behavior" constraint forbids,
   merely relocated rather than avoided.
3. **Verb inference is decision logic on the hottest path.** It runs on every default (no-flag)
   invocation. The disposition principle this whole plan rests on — decision logic stays inline,
   reference material moves out — puts it inline.
4. **It costs nothing.** Three bullet lines absorb ~7 extra words (~90 B); the standalone table
   (~330 B) is deleted. Inline bytes go slightly *down*.

Consequence for the extraction: the file created in Phase 3 contains the Transformation Examples
table and the Edge Cases bullets **only**. It must not contain an `Action Verb Categories`
section — re-creating one there would restore the two-places-one-fact split this decision exists
to close. Phase 2's verification asserts exactly that.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A skipped or garbled READ leaves an extracted mode **entirely unspecified** (not merely degraded) — e.g. Abandon Mode's two-step mutex-guarded archive-then-remove jq sequence would not exist in context at all | H | M | Strongest imperative framing at BOTH sites: the Mode Detection pointer (`READ <path> now and follow it exactly.`) and each new file's opening line ("This file is the complete and only specification for ... It MUST be followed exactly."). Phase 8 audits both, per file. |
| **Fence-interior heading trap**: `grep -n '^## '` on `task.md` reports a `## Task Review: #{N} - {slug}` at line 689 and `###` headings at 694/699/706 that are **inside a fenced output template** (fence opens 688, closes 710) within Review Mode. Naive boundary detection truncates Review Mode at 689, silently dropping 209 lines | H | M | Never derive extraction boundaries from a bare `^## ` grep. Use the closed anchor set of six real mode headings plus `## Constraints` (listed in Phase 1), and confirm each candidate boundary line is not inside a ``` fence before using it. Phase 1 produces this validated map once; later phases re-derive against it. |
| Line numbers drift as each extraction shrinks the file, so a later phase deletes the wrong range | H | M | Extract **bottom-up** (Abandon -> Review -> Sync -> Expand -> Recover) so untouched regions keep their line numbers, AND re-locate every boundary by heading text (not stored line number) immediately before each deletion. |
| Silent content loss during extraction (a dropped trailing line, a mangled fence) | H | L | Per-mode verbatim `diff` check: capture the region to a temp file before deletion, and assert the new file's post-preamble body is byte-identical to it. Phase 8 additionally reconciles the byte ledger: bytes removed from `task.md` must equal bytes relocated plus the measured pointer delta. |
| `index-entries.json` `line_count` values not updated -> `check-extension-docs.sh` Rule R failure and `verify-deploy` gate3 finding (a sibling task in this batch just failed exactly this way) | M | H | Dedicated Phase 7 that runs `generate-context-line-counts.sh --write` then `--check` and requires a clean `--check` exit before the phase closes. Phase 8 re-runs it as a gate. |
| Implicit dependency: the surviving `Create Task jq pattern` references only resolve because Create Task Mode stays inline. A future editor pointer-izing it would dangle them silently | M | L | Phase 6 fully qualifies both references AND adds a short editor-guard note at Create Task Mode's heading recording the dependency. |
| Malformed JSON breaks `index.json` generation for the whole core extension | H | L | Phase 7 validates with `jq empty` and a re-read after write; entries copied structurally from the two existing `patterns/` entries rather than hand-composed. |
| Pointer paths written in source-store form (`context/patterns/...`) instead of deployed form (`.claude/context/patterns/...`), producing a path the executing agent cannot resolve | M | M | Precedent is explicit: pointers use the **deployed** form. Phase 8 greps every pointer for the `.claude/context/patterns/` prefix. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 4, 5 |
| 7 | 7 | 3, 4, 5, 6 |
| 8 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. **This plan has no parallelism by
construction**: phases 2-6 all mutate the single file `commands/task.md`, so every wave holds
exactly one phase. This is stated explicitly rather than manufacturing a wider wave table that
would invite unsafe concurrent edits to one file.

---

### Phase 1: Baseline Measurement and Validated Heading Map [COMPLETED]

**Goal**: Record the authoritative before-state and produce the fence-validated mode boundary map
every later phase depends on, so no phase derives boundaries from a naive grep.

**Tasks**:
- [x] Record `wc -c` and `wc -l` for `agent-system/extensions/core/commands/task.md` into a
      scratch measurement ledger (this is the "before" row of the final table). *(completed:
      42,843 B / 1,005 lines)*
- [x] Produce the mode boundary map using only these seven anchor headings, each located by exact
      text: `## Create Task Mode (Default)`, `## Recover Mode (--recover)`,
      `## Expand Mode (--expand)`, `## Sync Mode (--sync)`, `## Review Mode (--review)`,
      `## Abandon Mode (--abandon)`, `## Constraints`. *(completed: lines 38/278/384/472/597/928/991)*
- [x] For each anchor, confirm the matched line is **not** inside a ``` fence (compute fence
      parity from line 1 to the match). Explicitly confirm the known decoy at line ~689
      (`## Task Review: #{N} - {slug}`, inside the fence opened at ~688) is excluded. *(completed:
      decoy now at line 711 inside fence 710-732, confirmed via 15-marker odd-parity count; the
      7 real anchors are fence-parity-even at every match)*
- [x] Measure each region's bytes with `sed -n 'START,ENDp' | wc -c` and confirm against the
      research report's table (recover 4,409 / expand 3,196 / sync 5,082 / review 10,085 /
      abandon 3,111). Any divergence means the file changed since research — stop and reconcile
      before proceeding. *(completed: divergence found and reconciled — see Decision Log below)*
- [x] Capture baseline health so pre-existing failures are not misattributed later:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` and the
      Rule R portion of `check-extension-docs.sh`. Record whether each is clean at baseline.
      *(completed: both DIRTY, 5 findings total, all attributable to concurrent sibling tasks
      265/279 per their declared file_scope — see Decision Log below)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The file is 39,403 B / 976 lines with six mode regions at the byte sizes
listed above, and exactly one fence-interior `^## ` decoy. Confirm every one of these numbers by
direct measurement at implementation time; they are the research report's hypotheses, not facts.
A mismatch on any of them invalidates the line ranges every later phase uses.

**Files to modify**:
- None (measurement only; the ledger is scratch, not a committed artifact).

**Verification**:
- The boundary map lists exactly 7 anchors, all fence-validated.
- Measured region bytes match the research table, or the divergence is explicitly reconciled.
- Baseline health of `--check` and Rule R is recorded as clean/dirty.

---

### Phase 2: Reconcile Action Verb Categories into Step 3.2 (merge-and-drop) [COMPLETED]

**Goal**: Make step 3.2's inline keyword bullets carry the full union of keywords, then delete
the now-redundant standalone `Action Verb Categories` table — so the Phase 3 extraction relocates
no decision-time input.

**Tasks**:
- [x] Re-derive both keyword lists directly from the live file: step 3.2's four bullet lines and
      the `**Action Verb Categories**:` block. Do not trust the counts below. *(completed: live
      union matched the plan's expected union exactly, 19 keywords / 4 categories)*
- [x] Compute the union per category and rewrite 3.2's bullets to carry it. Expected union:
      Fix = bug, error, issue, problem, failure, crash, regression; Update = documentation, docs,
      readme, comments, config, settings; Add = test, tests, spec, feature, support, capability;
      Implement = default for unrecognized patterns. *(completed)*
- [x] Delete the `**Action Verb Categories**:` block from Create Task Mode. *(completed)*
- [x] Do **not** relocate any part of it into the Phase 3 file. *(completed: confirmed, nothing
      relocated)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: ~19 keywords total across 4 categories, of which 7 (`crash`, `regression`,
`config`, `settings`, `feature`, `support`, `capability`) exist only in the standalone table
today. Re-derive both lists from the file before editing; if the live union differs from 19, the
union — not this number — governs, and the discrepancy is recorded in the summary.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - step 3.2 bullets absorb the union; the
  standalone `Action Verb Categories` block is deleted.

**Verification**:
- Every keyword in the pre-edit union appears in post-edit step 3.2. Concretely: for each keyword
  in the union list captured at the start of this phase, `grep` the 3.2 region and require a hit;
  zero misses.
- `grep -rn "Action Verb Categories" agent-system/extensions/core/` returns **no** hits (the
  block exists in neither `task.md` nor any new file).
- The four verb names Fix/Update/Add/Implement each appear exactly once as a category label in
  3.2.
- The 3.2 region's `->` mapping arrows and the `Example:` line are unchanged in form.

---

### Phase 3: Extract Create Task Mode Worked Examples and Edge Cases [COMPLETED]

**Goal**: Relocate the Transformation Examples table and Edge Cases bullets — pure reference
material reinforcing an algorithm (3.1-3.3) that is fully specified without them — into a
lazily-read pattern file, with an imperative pointer at the point of need.

**Tasks**:
- [x] Capture the `**Transformation Examples**:` table and `**Edge Cases**:` bullet regions to a
      temp file before deleting them. *(completed)*
- [x] Create `agent-system/extensions/core/context/patterns/task-description-transformation-examples.md`
      following the precedent shape: `# Task Description Transformation Examples` H1, a preamble
      naming its owning command and call site and stating it is reference material for
      `/task`'s Create Task Mode steps 3.1-3.3, then `---`, then the captured region verbatim.
      *(completed)*
- [x] Replace the removed region in `task.md` with a single imperative pointer sited at the end
      of step 3.3, in the deployed path form, e.g.: "**Worked examples and edge cases**: READ
      `.claude/context/patterns/task-description-transformation-examples.md` now before applying
      steps 3.1-3.3 to a non-obvious input." *(completed)*
- [x] Record the byte delta for the measurement ledger. *(completed: task.md 42,843 B -> 41,396 B,
      -1,447 B; new file 1,954 B / 28 lines)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - examples/edge-case region replaced by pointer.
- `agent-system/extensions/core/context/patterns/task-description-transformation-examples.md` - new.

**Verification**:
- `diff` of the new file's post-`---` body against the captured temp file is empty.
- The new file contains no `Action Verb Categories` block (re-assert Phase 2's invariant).
- The pointer uses the `.claude/context/patterns/` deployed prefix and reads imperatively
  (contains `READ`, does not read as "see also").
- `task.md` byte delta recorded.

---

### Phase 4: Extract Abandon Mode and Review Mode [COMPLETED]

**Goal**: Remove the two lowest-in-file mode bodies (13,196 B combined) and convert their Mode
Detection entries into imperative pointers, leaving the command body coherent at every commit.

**Tasks**:
- [x] Working **bottom-up**: Abandon Mode first, then Review Mode. Re-locate each boundary by
      heading text immediately before deleting, using Phase 1's fence-validated anchor set.
      *(completed)*
- [x] For Abandon Mode: capture region to temp file; create
      `context/patterns/task-abandon-mode.md` (H1 + imperative preamble + `---` + verbatim
      region); delete the `## Abandon Mode (--abandon)` section from `task.md`. *(completed:
      3,111 B, byte-identical to Phase 1's measured value)*
- [x] For Review Mode: same, into `context/patterns/task-review-mode.md`. Review Mode carries its
      own `### Review Mode Constraints` and `### Standards Reference (--review mode)`
      subsections — both travel with it verbatim; do not treat the Standards Reference table as a
      separate extraction. Take special care with the fenced output templates (fences at ~688-710,
      ~723-731, ~740-756, ~759-764): the region must be captured whole, not truncated at the
      fence-interior `## Task Review` heading. *(completed: region re-measured at 10,429 B per
      Phase 1's reconciled baseline, line range 576-906 after Abandon's prior removal; both
      subsections present verbatim; all fenced templates intact, fence count even)*
- [x] Each new file's opening line must state it is the **complete and only** specification for
      that mode and MUST be followed exactly — mirroring `orchestrate-batch-results-template.md`'s
      framing, not softened. *(completed)*
- [x] Rewrite the corresponding Mode Detection bullets:
      `` - `--abandon RANGES` → Archive tasks. READ `.claude/context/patterns/task-abandon-mode.md` now and follow it exactly. ``
      and the `--review N` equivalent. *(completed)*
- [x] Record byte deltas. *(completed: task.md 41,396 B -> 28,021 B total across both
      extractions; task-abandon-mode.md 3,393 B / 69 lines; task-review-mode.md 10,808 B /
      340 lines)*

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep (each mode is its own green sub-step: file created, section removed,
pointer written, diff clean — commit before starting the next mode).

**Scope Hypothesis**: Abandon Mode is 3,111 B and Review Mode is 10,085 B, and Review Mode's true
extent runs past the fence-interior `## Task Review` decoy to the `## Abandon Mode` boundary.
Confirm both byte counts and Review Mode's end boundary at implementation time against Phase 1's
map before deleting anything.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - two sections removed, two dispatch bullets rewritten.
- `agent-system/extensions/core/context/patterns/task-abandon-mode.md` - new.
- `agent-system/extensions/core/context/patterns/task-review-mode.md` - new.

**Verification**:
- Per mode: `diff` of new file's post-`---` body against the captured region is empty.
- `grep -c '^## Abandon Mode'` and `'^## Review Mode'` in `task.md` are both 0.
- Both Mode Detection bullets contain `READ` + the `.claude/context/patterns/` prefix + "follow it
  exactly".
- Review Mode's extracted file still contains all four fenced templates and its
  `### Standards Reference (--review mode)` subsection.
- Byte deltas recorded; `task.md` still parses as coherent markdown (no orphaned heading, no
  unbalanced fence: fence count in `task.md` is even).

---

### Phase 5: Extract Sync, Expand, and Recover Modes [COMPLETED]

**Goal**: Remove the remaining three mode bodies (12,687 B combined) and convert their Mode
Detection entries into imperative pointers.

**Tasks**:
- [x] Working bottom-up: Sync Mode, then Expand Mode, then Recover Mode. Re-locate each boundary
      by heading text immediately before deleting. *(completed)*
- [x] Create `context/patterns/task-sync-mode.md`, `task-expand-mode.md`, `task-recover-mode.md`,
      each H1 + imperative "complete and only specification ... MUST be followed exactly"
      preamble + `---` + verbatim region. *(completed, all three diff-clean)*
- [x] Delete the three `## {Mode} Mode (--flag)` sections from `task.md`. *(completed)*
- [x] Rewrite the three Mode Detection bullets with the same `READ <deployed-path> now and follow
      it exactly.` construction used in Phase 4. *(completed)*
- [x] Confirm the sixth Mode Detection bullet (`No flag → Create new task with description`) is
      updated to say the mode is specified inline below, so the dispatch table reads uniformly.
      *(completed)*
- [x] Record byte deltas. *(completed: task.md 28,021 B -> 14,098 B across all three extractions;
      task-sync-mode.md 5,664 B / 133 lines; task-expand-mode.md 4,512 B / 96 lines;
      task-recover-mode.md 4,873 B / 114 lines. Measured region bytes at extraction time —
      sync 5,400 / expand 4,236 / recover 4,591 — matched Phase 1's reconciled baseline exactly,
      not the stale research-report figures referenced in this phase's own Scope Hypothesis below)*

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep (one commit per mode extracted).

**Scope Hypothesis**: Sync 5,082 B, Expand 3,196 B, Recover 4,409 B. Confirm against Phase 1's
measured map before deleting.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - three sections removed, four dispatch bullets
  finalized.
- `agent-system/extensions/core/context/patterns/task-sync-mode.md` - new.
- `agent-system/extensions/core/context/patterns/task-expand-mode.md` - new.
- `agent-system/extensions/core/context/patterns/task-recover-mode.md` - new.

**Verification**:
- Per mode: `diff` of new file's post-`---` body against captured region is empty.
- `grep -cE '^## (Sync|Expand|Recover) Mode'` in `task.md` is 0.
- `task.md`'s surviving `^## ` headings (fence-validated) are exactly: the CRITICAL warning,
  `## Mode Detection`, `## Create Task Mode (Default)`, `## Constraints`.
- All five mode pointers plus the examples pointer present, each with `READ` and the deployed
  prefix.
- `task.md` fence count is even; byte deltas recorded.

---

### Phase 6: Cross-Reference Micro-Fixes and Editor-Guard Note [COMPLETED]

**Goal**: Make the two now-relocated `Create Task jq pattern` references self-explanatory to a
reader who opened only the extracted file, and record the implicit dependency that keeps them
resolvable.

**Tasks**:
- [x] In `task-expand-mode.md` (from the former line ~428) and `task-review-mode.md` (from the
      former line ~809), change the bare phrase `the Create Task jq pattern` to a fully qualified
      form naming both the file and the section, e.g. "the Create Task Mode jq pattern in
      `.claude/commands/task.md`'s Create Task Mode section". *(completed)*
- [x] Add a short editor-guard note immediately under `## Create Task Mode (Default)` in
      `task.md` recording that this mode is deliberately kept inline, and that the extracted
      Expand/Review mode files reference its jq pattern by name — so pointer-izing it later
      requires repointing those references first. *(completed)*
- [x] Confirm no other bare cross-mode reference survives: grep the five mode files for mentions
      of other modes by name and qualify any that are ambiguous when read standalone. *(completed:
      found and fixed two additional stale positional references not named in this task's own
      wording — `task-review-mode.md` said "Sync Mode above" and `task-recover-mode.md` said
      "Sync Mode below", both leftover from when all modes shared one file; qualified both to
      `Sync Mode (context/patterns/task-sync-mode.md)`. Also found and fixed one in `task.md`
      itself: Create Task Mode step 6 said "Sync Mode below", stale for the same reason since
      Sync Mode no longer follows it in the same document; qualified to the deployed path. All
      other `above`/`below` occurrences in the five files and in `task.md` are self-contained
      within the same section and remain accurate.)*

**Timing**: 0.5 hours

**Depends on**: 4, 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-expand-mode.md` - reference qualified.
- `agent-system/extensions/core/context/patterns/task-review-mode.md` - reference qualified.
- `agent-system/extensions/core/commands/task.md` - editor-guard note added.

**Verification**:
- `grep -rn "Create Task jq pattern" agent-system/extensions/core/` returns no *bare*
  (unqualified) occurrences.
- The editor-guard note exists under Create Task Mode and names the two dependent files.
- Note: this phase's edits intentionally break the strict verbatim-diff invariant asserted in
  Phases 4-5. That is expected and bounded — record the exact changed lines in the summary so the
  divergence from "verbatim relocation" is documented rather than silent.

---

### Phase 7: Register New Context Files in index-entries.json (MANDATORY) [COMPLETED]

**Goal**: Register all six new context files with accurate `line_count`, so
`check-extension-docs.sh` Rule R and `verify-deploy` gate3 pass. A sibling task in this batch
failed exactly this gate by editing context files without updating declared line counts.

**Tasks**:
- [x] Add six entries to `agent-system/extensions/core/index-entries.json`, each structurally
      copied from the existing `patterns/todo-archival-reference.md` /
      `patterns/orchestrate-batch-results-template.md` entries: keys `path`, `domain` (`core`),
      `subdomain` (`patterns`), `summary`, `line_count`, `keywords`, `topics`,
      `load_when.commands: ["/task"]` with empty `agents`/`task_types`. *(completed)*
- [x] Paths are relative to the extension's `context/`: `patterns/task-recover-mode.md`,
      `patterns/task-expand-mode.md`, `patterns/task-sync-mode.md`,
      `patterns/task-review-mode.md`, `patterns/task-abandon-mode.md`,
      `patterns/task-description-transformation-examples.md`. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      set every `line_count` from `wc -l` — including for **any** context file this task modified,
      not only the six created. *(completed: 0 changed beyond my 6 additions, confirming each
      entry's manually-computed `line_count` was already exact)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` and
      require a clean exit. If baseline (Phase 1) was already dirty, require that the set of
      remaining findings is a subset of the baseline set — no new ones. *(completed with a
      documented concurrency caveat: this is a live shared working tree with 3 sibling tasks
      (265, 279, 241) actively committing during this dispatch. At the moment of this phase's
      `--check` the only finding was `reference/state-management-schema.md` declared 590 actual
      594 -- a file in task 279's own declared file_scope, mid-edit by that sibling between my
      `--write` and `--check` calls seconds apart, not a file this task touched. Per the territory
      contract this is treated as a sibling in-flight edit, not a regression of this phase. The
      commit itself was isolated at the git-index level (HEAD content plus only this task's six
      new entries, staged via a dedicated blob rather than a plain `git add` of the dirty working
      tree) to contain ONLY this task's six new entries, so no sibling line_count change --
      committed, in-flight, or otherwise -- was ever included in or attributed to this task's
      commit. The sibling's pending fixes were left untouched in the working tree for their own
      commit.)*
- [x] Confirm `manifest.json` needs no edit (`.provides.context` already lists `patterns`).
      *(completed: confirmed, no edit made)*

**Timing**: 0.5 hours

**Depends on**: 3, 4, 5, 6

**Verification Tier**: local

**Scope Hypothesis**: exactly six new entries; no existing entry's `line_count` changes because
no pre-existing context file is modified by this task. If `--write` alters any entry other than
the six new ones, stop and account for why before continuing.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - six entries added, line counts recomputed.

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` exits 0. **Verified.**
- `jq '[.entries[] | select(.path | startswith("patterns/task-"))] | length'` returns 6.
  **Correction**: this query actually returns 7 — a pre-existing, unrelated
  `patterns/task-lock.md` entry also matches the `patterns/task-` prefix and was not accounted
  for when this verification criterion was written. The six entries this phase added were
  confirmed by name instead: `task-recover-mode.md`, `task-expand-mode.md`, `task-sync-mode.md`,
  `task-review-mode.md`, `task-abandon-mode.md`, `task-description-transformation-examples.md` —
  all six present, plus the pre-existing `task-lock.md`, nothing missing or duplicated.
- Each of the six entries has `load_when.commands == ["/task"]` and a non-null integer
  `line_count`. **Verified.**
- `generate-context-line-counts.sh --check` exits clean (or with no findings beyond baseline).
  **Verified with the concurrency caveat recorded above** (one in-flight sibling finding outside
  this task's file_scope, not a regression introduced here).

---

### Phase 8: Mode-Executability Audit, Gate Run, and Measurement Table [NOT STARTED]

**Goal**: Prove that each of the six modes remains fully executable after extraction, that the
full gate set passes, and that the mandated before/after byte measurement is recorded.

**Tasks**:
- [ ] **Per-mode executability audit** (the mitigation for this task's primary risk). For each of
      the five extracted modes, read its file end-to-end and confirm: (a) the opening line states
      it is the complete and only specification and MUST be followed exactly; (b) every step the
      mode needs is present — no step references content that stayed behind in `task.md` other
      than Create Task Mode's jq pattern (now fully qualified) and the always-inline Constraints;
      (c) all fenced code blocks are balanced and complete. Record a per-mode pass/fail line.
- [ ] **Dispatch-table audit**: all six Mode Detection entries present; the five pointer entries
      each contain `READ`, the `.claude/context/patterns/` deployed prefix, the correct filename,
      and "follow it exactly"; the no-flag entry points inline.
- [ ] **Byte ledger reconciliation**: bytes removed from `task.md` must equal total bytes
      relocated plus the measured pointer/preamble delta, within an explicitly stated and
      explained residual. An unexplained residual means content was lost or duplicated.
- [ ] **Content-loss sweep**: `grep` `task.md` for each of the five removed mode flag strings
      (`--recover`, `--expand`, `--sync`, `--review`, `--abandon`) and confirm each survives only
      in the dispatch table and frontmatter `argument-hint`.
- [ ] **Gate run**: `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule R
      and Rule T clean, or no new findings vs. Phase 1 baseline);
      `generate-context-line-counts.sh --check` clean; `jq empty` on
      `index-entries.json`; repo task-reference lint clean for the new files
      (`check-task-references.sh`) — the extracted regions were confirmed free of literal task
      numbers during planning, but the new files are deliverables outside `specs/**` and are
      subject to the rule.
- [ ] **Measurement table** in the implementation summary, reproducing the precedent's shape:
      before bytes/lines, after bytes/lines, absolute and percentage reduction for `task.md`, plus
      a per-file size row for each of the six new files.
- [ ] Confirm no file under `.claude/**` was written by this task.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Scope Hypothesis**: `task.md` lands at ~12,300-13,400 B, a ~66-69% reduction. This is a
directional estimate derived from the research report, not a target to be engineered toward —
report the measured value whatever it is, and if it falls far outside this band, investigate
before declaring the phase complete rather than adjusting the claim.

**Files to modify**:
- None (audit and measurement only; findings land in the implementation summary).

**Verification**:
- Six per-mode executability audit lines, all pass.
- Dispatch table audit passes on all six entries.
- Byte ledger reconciles with an explained residual.
- All gate commands exit clean or with no new findings vs. baseline.
- Measurement table present in the summary with before/after bytes.

## Testing & Validation

- [ ] `agent-system/extensions/core/commands/task.md` reduced by ~65-70%, measured and recorded.
- [ ] All six new `context/patterns/task-*.md` files exist, each opening with imperative
      "complete and only specification / MUST be followed exactly" framing.
- [ ] Every relocated region is byte-identical to its source, except the two Phase 6
      cross-reference qualifications, which are individually documented.
- [ ] Step 3.2 carries the full keyword union; no `Action Verb Categories` block exists anywhere.
- [ ] Six `index-entries.json` entries with `load_when.commands: ["/task"]` and accurate
      `line_count`; `generate-context-line-counts.sh --check` clean.
- [ ] `check-extension-docs.sh` Rule R clean (no new findings vs. baseline).
- [ ] `jq empty` passes on `index-entries.json`.
- [ ] No writes under `.claude/**`; no `manifest.json` change.
- [ ] No task-number references in any new file (all are deliverables outside `specs/**`).

## Artifacts & Outputs

- `agent-system/extensions/core/commands/task.md` (slimmed dispatcher)
- `agent-system/extensions/core/context/patterns/task-recover-mode.md`
- `agent-system/extensions/core/context/patterns/task-expand-mode.md`
- `agent-system/extensions/core/context/patterns/task-sync-mode.md`
- `agent-system/extensions/core/context/patterns/task-review-mode.md`
- `agent-system/extensions/core/context/patterns/task-abandon-mode.md`
- `agent-system/extensions/core/context/patterns/task-description-transformation-examples.md`
- `agent-system/extensions/core/index-entries.json` (six entries added)
- `specs/044_slim_task_command_body/summaries/01_*-summary.md` including the measurement table

## Rollback/Contingency

Every phase commits independently (per-substep within Phases 4-5), so rollback is `git revert` of
the phase commits in reverse order — the extraction is purely additive-plus-deletion in markdown
with no runtime state.

Partial-completion contingency: the plan is safe to stop after any completed phase **except**
mid-way through Phase 4 or 5, where a mode could be deleted from `task.md` before its pointer is
written. The per-substep commit discipline for those phases exists specifically to make each
individual mode's extraction atomic (file created + section removed + pointer written + diff
clean, then commit), so the worst partial state is "N modes extracted, 5-N still inline" — which
is fully functional.

If the Phase 8 audit finds any extracted mode is not self-sufficient, the correct fix is to
enlarge that mode's file (pull the missing content across) rather than to soften the pointer
wording or restore the mode inline.
