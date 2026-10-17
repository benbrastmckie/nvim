# Implementation Plan: Task #396

- **Task**: 396 - Lean phase commit gated on full build, and plan-file section anchoring
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: 376
- **Research Inputs**: specs/396_lean_phase_commit_full_build_and_plan_anchor/reports/01_phase-commit-anchor-guidance.md
- **Artifacts**: plans/01_phase-commit-anchor-guidance.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two guidance items land in the lean extension's **source store**
(`agent-system/extensions/lean/`), both distilled from minor-severity implementation issues
logged on a prior task. ITEM 1 is a **revision, not an addition**: three passages currently
instruct the opposite of the new policy (prefer/accept a scoped `lake build Module.Name` as the
phase-end bar, reserve the full build for final verification), and all of them must change
together or the files will contradict each other. ITEM 2 adds a plan-file section-anchoring rule
that has no existing home anywhere in the source store. Definition of done: the full-build
phase-commit gate and the anchor-forward-from-heading rule are stated consistently across all
three files, every stale phrase is gone, the deployed tree is regenerated from the source store,
and the complete gate set is green.

### Research Integration

- All three dispatch-named edit sites were located and read; current text contradicts ITEM 1
  exactly as predicted, with minor (single-digit to ~15 line) line-number drift. Current text,
  not the dispatch's line estimates, is the planning basis.
- The orthogonal detach+guard contract in `context/project/lean4/operations/long-builds.md`
  already treats scoped and full builds identically ("Scoped builds are covered too"), so ITEM 1
  removes scoped builds as an *acceptable phase-commit gate* without touching that file's
  detach/guard mechanics. `file_scope` stays at the three named files.
- ITEM 2's failure mode has **no generic home**: a survey of all 35 files under
  `core/context/patterns/` plus `core/agents/reviser-agent.md` (the other plan-section splicer)
  found no anchor-forward-from-heading rule. Research recommends landing it narrowly in the three
  lean files, phrased generically so a future second incident can promote the same paragraph into
  a shared core pattern file by reference rather than by rewrite. This plan adopts that
  recommendation (see Decisions).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- A Lean phase commit is gated on a full `lake build` of the whole library, stated consistently
  in the standard agent, the hard-mode agent, and the shared flow file.
- The cost of that gate (every phase commit now pays a full-library build) is named explicitly at
  each gate site, as a recorded tradeoff rather than an accident.
- A scoped `lake build Module.Name` is explicitly retained as a legitimate **non-gating** interim
  check, so the change removes an unsound gate without removing a useful fast signal.
- A multi-line plan-file section edit anchors on heading-marker LINES searched forward from the
  target section's own start, stated in generic (non-lean-specific) language.
- No stale phrase survives anywhere in the three files that would contradict either new rule.

**Non-Goals**:

- Changing `context/project/lean4/operations/long-builds.md`'s detach/guard mechanics, its
  preference order, or its verdict-reading tiers. ITEM 1 consumes that contract; it does not
  amend it.
- Creating a new shared pattern file under `agent-system/extensions/core/context/patterns/` for
  ITEM 2, or editing `core/agents/reviser-agent.md` (see Decisions for the rationale and the
  conditions under which that becomes the right call).
- Any mechanical/script-level enforcement. `git-commit-scoped.sh` carries no build-status gate
  today and gains none here; both items are agent-instruction prose.
- Any edit under `.claude/**` by hand. The deployed tree is regenerated, never hand-authored.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| One of the three files is left stale relative to the other two — the exact failure class ITEM 1 is about, applied to documentation | H | M | Sequence the flow file first (it fixes the canonical wording), then the agent files; Phase 4 runs an explicit stale-phrase grep sweep over all three files with the phrase list enumerated in Phase 4's tasks |
| A stale-phrase grep misses an occurrence because the phrase wraps across a line break (confirmed: `acceptable for phase-end` currently matches **zero** lines because it wraps mid-phrase) | M | H | Phase 4's sweep greps on short, single-line-safe fragments (`Module.Name`, `final verification only`, `categorically safe`, `scoped phase-end bar`, `ModuleName`) and reviews every hit by eye, rather than trusting a long-phrase grep returning zero |
| The dispatch description's own "preserve the orthogonal constraint" paragraph names `Bash(run_in_background: true)` as the required detach mechanism; the files now **forbid** exactly that (a landed revision replaced it with a foreground-first preference order plus shell-level backgrounding) | H | M | Treat the files' current text as authoritative, never the dispatch paragraph. New guidance points at `long-builds.md`'s preference order instead of restating any detach mechanism. Phase 1-3 tasks state this explicitly |
| Adding the full-build gate makes multi-phase Lean tasks materially slower (a full build can exceed the foreground cap on its own) | M | H | This is the task's explicit intent — closing a real correctness gap. The cost is named in the guidance at each gate site, and no code change is needed because the detach+guard contract already handles arbitrarily long builds |
| ITEM 2's generic wording may not match verbatim whatever a future shared pattern file uses | L | M | Low cost either way: a later centralization is copy-then-point-at-it, not a rewrite, given the wording is generic from the start |
| A concurrent sibling dispatch edits a shared file this cycle | M | L | Sibling `file_scope` (task 350) is disjoint from this task's three files; still, re-read each file immediately before editing and stage only this task's own hunks, per the dispatch Territory block |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. Every wave here holds a single phase: all
four phases write to overlapping subsets of the same three files, so none may run concurrently.

### Phase 1: ITEM 1 in the shared flow file [COMPLETED]

**Goal**: `lean-implementation-flow.md` states the full-build phase-end gate as the canonical
policy, with the cost named, and no longer claims the final stage is the only full build.

**Tasks**:

- [x] Re-read `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
      immediately before editing (sibling-concurrency obligation from the dispatch Territory block). *(completed)*
- [x] Rewrite Stage 4C ("Verify Phase Completion", currently 2 bullets at ~L107-113) so a full
      `lake build` of the whole library is the only build that satisfies phase-end verification.
      Replace the bullet `Run \`lake build Module.Name\` to verify the module compiles (preferred;
      faster than full build)` and its `Fall back to \`lake build\` only if ...` companion. *(completed)*
- [x] State, in Stage 4C, why a scoped build cannot serve as the gate: it cannot observe
      cross-module name clashes or downstream breakage — a scoped build of one module can pass
      while the full library build fails because a newly introduced declaration collides with an
      identically named declaration in another module. Describe the failure class; do **not**
      cite a task number or a commit sha (`.claude/rules/no-task-references-in-deliverables.md`;
      the two shas quoted in the task description are also not present in local history). *(completed)*
- [x] State, in Stage 4C, that a scoped `lake build Module.Name` remains legitimate as a fast,
      explicitly **non-gating** interim check mid-phase. *(completed)*
- [x] Name the cost in Stage 4C in one sentence: this makes every phase-end pay a full-library
      build rather than a single module's, which is the accepted price of catching cross-module
      breakage in the phase that introduced it, and which makes the detached+guarded invocation
      contract MORE load-bearing, not less. Point at
      `context/project/lean4/operations/long-builds.md` for *how* to run the build (its preference
      order and its "Reading the build's verdict" tiers) rather than restating either. *(completed)*
- [x] Make Stage 4D ("Mark Phase Complete") conditional on Stage 4C's verdict: the phase is
      marked `[COMPLETED]` only on a green full build; a red or unread verdict yields
      `[PARTIAL]`/`[BLOCKED]`, never a closed phase. *(completed)*
- [x] Correct Stage 5 (~L119-128): remove or rewrite both false claims — the parenthetical
      `(mandatory -- this is the only required full build)` and the trailing note sentence
      `Phase-end uses \`lake build Module.Name\`. Only this final stage requires full \`lake
      build\`.` — so Stage 5 reads as the final re-run over the completed task rather than as the
      sole full build. *(completed)*
- [x] Confirm no remaining occurrence of `Module.Name` in this file sits in a gating context
      (baseline: 2 occurrences, both gating, both edited by this phase). *(completed: 2 occurrences
      remain, both explicitly non-gating — one in a "never ... Module.Name" clause, one labeling
      the scoped build as a non-gating interim check)*
- [x] Record any deviation inline on the checklist item, and log issues/wins via
      `.claude/scripts/issue-record.sh` as they arise. *(completed: deviation recorded below —
      ITEM 2's canonical block was briefly added to this file during drafting, then reverted
      since it is Phase 3's work)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly 2 gating occurrences of `Module.Name` in this
file (Stage 4C and the Stage 5 note) and exactly 1 file modified. Confirm at implementation time
with `grep -n "Module.Name" <file>` before and after, and with `git status --short` showing only
this one source-store file.

**Tier Justification**: a single markdown context file with no executable surface and no mapped
test suite (`suite_selection_select` returns `__FULL_SWEEP__` for it), covered by the
source-store markdown gate subset `bash agent-system/extensions/core/scripts/verify-deploy.sh
--skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` plus a diff read-through.

**Files to modify**:

- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` - Stage
  4C rewritten as a full-build gate with the cost named; Stage 4D made conditional on it; Stage
  5's "only required full build" / "Only this final stage requires full" claims corrected

**Verification**:

- `grep -n "faster than full build\|Only this final stage requires full" <file>` returns nothing.
- `grep -n "Module.Name" <file>` — every remaining hit (if any) is read by eye and confirmed to
  sit in a non-gating, explicitly-interim context.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` reports no failures.
- Diff read-through confirms every changed hunk is prose inside this one file.

---

### Phase 2: ITEM 1 in the standard implementation agent [COMPLETED]

**Goal**: `lean-implementation-agent.md`'s MUST DO / MUST NOT lists and its Phase Checkpoint
Protocol gate the phase commit on a full library build, consistently with Phase 1's wording.

**Tasks**:

- [x] Re-read `agent-system/extensions/lean/agents/lean-implementation-agent.md` immediately
      before editing. *(completed)*
- [x] Rewrite MUST DO item 7 (currently `Prefer \`lake build Module.Name\` for phase-end
      verification — scoped is less work, not categorically safe; ...`) so it mandates a full
      `lake build` of the whole library as the phase-end gate and demotes the scoped build to a
      non-gating interim check. *(completed)*
- [x] Rewrite MUST DO item 8's scoping parenthetical `(final verification only)` so the
      end-of-task full build is stated as being *in addition to*, never instead of, the per-phase
      full build. Leave item 8's tail — the build-guard preference-order pointer, the foreground
      `timeout N` form, the shell-level-background fallback, and the explicit prohibition on
      `Bash(run_in_background: true)` — byte-for-byte unchanged. *(completed)*
- [x] Rewrite MUST NOT item 3, whose current text (wrapping across lines as `scoped \`lake build
      Module.Name\` is acceptable for` / `phase-end; only full \`lake build\` is mandatory at the
      final stage`) states the policy this task reverses. New text forbids closing a phase or
      firing a phase commit on a scoped build alone, and still forbids skipping the final full
      build. *(completed)*
- [x] Insert the gate into the Phase Checkpoint Protocol (currently 6 numbered steps at
      ~L683-711) as a new step between the current step 2 ("Execute phase steps") and current
      step 3 ("Mark phase [COMPLETED]"): run a full `lake build` of the whole library through the
      build guard, read its verdict per `long-builds.md`'s "Reading the build's verdict", and do
      not proceed to marking the phase `[COMPLETED]` or to the git-commit step until that verdict
      is green. On a red verdict: fix forward per `.claude/context/contracts/recovery.md`, or mark
      `[PARTIAL]`/`[BLOCKED]` — never commit a phase on a red or unread full build. *(completed)*
- [x] Renumber the Phase Checkpoint Protocol's subsequent steps (old 3-6 become 4-7) and update
      any in-section cross-reference to a step number so none points at a renumbered step.
      *(completed)*
- [x] Add the cost sentence once in the Phase Checkpoint Protocol (not repeated per list item),
      and extend the "Why phase-granular commits" bullet list with one bullet recording that the
      gate's price is a full-library build per phase and its benefit is catching cross-module
      breakage in the phase that introduced it. *(completed)*
- [x] Verify the new text contains no task-number reference and no commit sha. *(completed)*
- [x] Record any deviation inline; log issues/wins as they arise. *(completed: none)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly 2 occurrences of `Module.Name` in this file (MUST
DO 7 and MUST NOT 3), 1 occurrence of `final verification only` (MUST DO 8), a 6-step Phase
Checkpoint Protocol becoming 7 steps, and exactly 1 file modified. Confirm with `grep -n` for
each string and `git status --short` before and after.

**Tier Justification**: a single agent-definition markdown file with no executable surface and no
mapped test suite, covered by the source-store gate subset `bash
agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
/home/benjamin/.config/nvim` (gate 6 is the agent-contracts lint, the one gate that reads agent
definitions) plus a diff read-through.

**Files to modify**:

- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - MUST DO 7 and 8 and MUST
  NOT 3 rewritten; a full-build gate step inserted into the Phase Checkpoint Protocol with
  subsequent steps renumbered; the cost recorded once in that section

**Verification**:

- `grep -n "final verification only\|categorically safe" <file>` returns nothing.
- `grep -n "Module.Name" <file>` — every remaining hit is read by eye and confirmed non-gating.
- The Phase Checkpoint Protocol's numbered steps read 1..7 with no duplicate or skipped number,
  and the build gate precedes both the `[COMPLETED]` marking and the git-commit step.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
  /home/benjamin/.config/nvim` reports no failures.
- `grep -nE "task [0-9]+|tasks [0-9]+" <file>` surfaces no new occurrence in the added text.

---

### Phase 3: ITEM 1 in the hard-mode agent, and ITEM 2 in all three files [COMPLETED]

**Goal**: the hard-mode agent carries the same full-build gate inline (it does not receive the
flow file as ambient context), and the plan-file section-anchoring rule is stated in all three
files in generic language.

**Tasks**:

- [x] Re-read all three files immediately before editing. *(completed)*
- [x] **ITEM 1, hard agent Stage 4D** (~L241-262): replace the inline comment `# Scoped build for
      current module -- less work, not categorically safe; ...` and change the guard invocation's
      target from `-- build ModuleName` to the full-library form, keeping the surrounding
      bounded-waiter idiom (`& pid=$!`, the `kill -0` liveness loop, the outer `timeout`, the
      un-piped `wait` capturing `GUARD_EXIT`) byte-for-byte intact, and keeping the explicit
      `Bash(run_in_background: true)`-is-forbidden paragraph that follows it intact. *(completed)*
- [x] **ITEM 1, hard agent Stage 4D prose**: correct `the scoped phase-end bar in ...` to name
      the phase-end bar without the `scoped` qualifier, leaving the verdict-tier sentence (guard
      exit code / `.olean`-newer-than-source) otherwise unchanged. Add the one-sentence cost
      note and the one-sentence reason a scoped build cannot gate (cross-module clashes and
      downstream breakage), inline — the flow file is **not** in this agent's context. *(completed)*
- [x] **ITEM 1, hard agent Stage 4H** ("Git Commit"): add a one-line precondition that Stage 4D's
      full build was observed green before the commit fires. *(completed)*
- [x] **ITEM 1, hard agent MUST DO 7**: extend so the full build is required at every phase end
      (Stage 4D) as well as before returning `implemented`, without disturbing the item's
      preference-order tail. **MUST DO 4** (`Commit at every green-build milestone`): qualify
      "green-build" as a green *full* library build per Stage 4D. *(completed)*
- [x] **ITEM 2, canonical text in the flow file**: add a short block immediately after Stage 4A's
      marker code fence stating the rule generically — when an edit replaces or splices a whole
      section of a markdown plan file, both anchors must be LINES that begin with heading markers
      (a line starting with two or three hash characters and a space), and the end anchor must be
      searched FORWARD from the target section's own start line; never anchor on a bare heading
      substring, because the same text commonly recurs in prose earlier in the file (in a Goals
      or Overview paragraph) and a whole-file match on it splices at the wrong place, duplicating
      the span between the two matches. Note that the single-line phase-marker swap shown above is
      already safe by construction (heading text plus bracketed status marker is unique) and that
      this rule governs edits spanning from one heading to the next. Describe the failure class
      without a task number or commit sha. Add the same forward-search note at Stage 4D's marker
      step as a one-line pointer back to the 4A block. *(completed)*
- [x] **ITEM 2, standard agent**: add a compact statement of the rule in the "Phase Status
      Updates (MANDATORY)" section after the "After Completing a Phase" block, pointing at the
      flow file for the full rationale (that file is auto-loaded for this agent per the lean
      extension's index entry). Extend the write-authority MUST NOT item (the one delimiting
      plan-file writes to phase headings and checklist items) with a clause requiring any
      multi-line plan-file edit to anchor on heading-marker lines searched forward from the
      section start, never on a bare substring. *(completed)*
- [x] **ITEM 2, hard agent**: add the same compact statement inline near Stage 4A's
      plan-file-write boundary paragraph — **self-contained, with no pointer to the flow file**
      and no `@`-reference to the standard agent (its MUST NOT 10) — and extend its own
      write-authority MUST NOT item with the same clause. *(completed)*
- [x] Verify none of the added ITEM 2 text contains a line that itself begins with a heading
      marker, so the new guidance does not create the very anchor-collision hazard it describes
      inside these files. *(completed)*
- [x] Record any deviation inline; log issues/wins as they arise. *(completed: none for Phase 3
      itself; a pre-existing, out-of-scope fourth location carrying the same stale contradiction —
      rules/lean4.md lines ~49/54 — was found and will be reported via proposed_file_scope rather
      than edited)*

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts 1 occurrence each of `less work, not categorically
safe`, `scoped phase-end bar`, and `build ModuleName` in the hard agent, two write-authority MUST
NOT items (one per agent file), and exactly 3 files modified. Confirm with `grep -n` for each
string and `git status --short`.

**Tier Justification**: `interface` rather than `local` because this phase changes wording that
all three files must agree on after Phases 1-2 already moved two of them, so the covering check
is the three-file consistency sweep plus `bash
agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
/home/benjamin/.config/nvim` over the enumerated dependent set (both agent files and the flow
file), which no single-file check covers.

**Files to modify**:

- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - Stage 4D build made
  full-library with the cost and reason inline; Stage 4H commit precondition; MUST DO 4 and 7
  qualified; ITEM 2 rule stated inline near Stage 4A and in the write-authority MUST NOT item
- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` -
  canonical ITEM 2 block after Stage 4A, with a one-line pointer at Stage 4D
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - compact ITEM 2 statement in
  the Phase Status Updates section plus the write-authority MUST NOT clause

**Verification**:

- `grep -n "categorically safe\|scoped phase-end bar\|build ModuleName" <hard-agent>` returns
  nothing.
- The hard agent's Stage 4D code fence still contains `pid=$!`, a `kill -0` liveness loop, an
  outer `timeout`, and an un-piped `wait` capturing `GUARD_EXIT`, and the
  `Bash(run_in_background: true)`-is-forbidden paragraph is intact.
- `grep -n "forward" <each of the three files>` shows the anchoring rule present in all three.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
  /home/benjamin/.config/nvim` reports no failures.
- `grep -nE "task [0-9]+|tasks [0-9]+" <each file>` surfaces no new occurrence in added text.

---

### Phase 4: Consistency sweep, deploy, and full gate [COMPLETED WITH EXCLUSIONS]

**Goal**: no stale phrase contradicts either new rule anywhere in the three files, the
source-store change reaches the deployed tree, and the complete gate set is green.

**Tasks**:

- [x] Run the stale-phrase sweep over all three files using short, single-line-safe fragments
      rather than long phrases (a long phrase can wrap across a line break and silently return
      zero — `acceptable for phase-end` currently matches nothing for exactly that reason):
      `Module.Name`, `ModuleName`, `categorically safe`, `final verification only`, `scoped
      phase-end bar`, `faster than full`, `only required full build`, `Only this final stage`.
      Read every surviving hit by eye and confirm it sits in an explicitly non-gating context.
      *(completed: 8 fragments swept; only `Module.Name` hit (7 occurrences across the 3
      files), each read by eye and confirmed in an explicitly non-gating context — e.g. "A
      scoped `lake build Module.Name` remains legitimate as a fast, explicitly non-gating
      interim check"; the other 7 fragments returned zero hits)*
- [x] Cross-read the three files against each other and confirm they agree on: what gates a phase
      commit (a full library build), what a scoped build is still good for (non-gating interim
      feedback), and how a plan-file section edit anchors. *(completed: all three state the
      full-library build as the sole phase-commit gate, the scoped build as explicitly
      non-gating interim feedback, and the same forward-search-from-heading anchoring rule for
      a multi-line plan-file edit)*
- [x] Read `context/project/lean4/operations/long-builds.md`'s "Scoped builds are covered too"
      section and confirm it carries no claim that contradicts the new gate. Expected outcome: it
      does not — its subject is detach/guard parity and lock granularity, not gating, and its
      "scoped invocation remains preferable ... it is simply doing less work" clause stays true
      for non-gating interim builds. If a genuine contradiction is found, do **not** edit it:
      it is outside `file_scope`. Propose it via `proposed_file_scope` in `.return-meta.json` and
      report it. *(completed: no contradiction found, matches the expected outcome exactly;
      `file_scope` widening not needed)*
- [x] Confirm every edit from Phases 1-3 landed under `agent-system/extensions/lean/` and nothing
      was hand-authored under `.claude/**` (`.claude/rules/source-store-deploy-boundary.md`).
      *(completed: `git status --porcelain` on the three edited agent/flow files shows clean —
      already committed in phases 1-3 under `agent-system/extensions/lean/`; no `.claude/**`
      hand-authoring)*
- [x] Run `timeout 540 bash .claude/scripts/deploy-headless.sh` and confirm it completes.
      *(completed: `RESULT=landed_verify_clean`, 36 checks / 0 failures)*
- [x] Diff each of the three deployed copies against its source-store original and confirm each
      pair is byte-identical (they were byte-identical before this task's edits, so a non-empty
      diff means a stale deploy):
      `.claude/agents/lean-implementation-agent.md`,
      `.claude/agents/lean-implementation-hard-agent.md`,
      `.claude/context/project/lean4/agents/lean-implementation-flow.md`.
      *(completed: all three `diff` invocations empty)*
- [x] Run the complete gate set and triage any failure attributable to this task's file scope.
      Treat a failure in a file outside that scope as possibly a sibling's in-flight edit, per
      the dispatch Territory block, and report it rather than silently fixing it. If the dispatch
      file carries a Batch Gate Deferral directive, discharge this item per that directive and
      record the narrowing as an enumerated, evidenced exclusion. *(completed: dispatch 18
      carries a Batch Gate Deferral directive; discharged against the scoped narrowing
      `verify-deploy.sh --only-gate 3,4,5,6` — gates 3/4/5/6 are the ones relevant to this
      task's markdown/agent-contract edits — 5 checks, 0 failures; gate 8 (full shell-suite
      battery) is deferred to the once-per-batch stage per the directive — see Reasoned
      Exclusions below)*
- [x] Record any deviation inline; log issues/wins as they arise. *(completed: no deviations;
      one win logged — see Issue Log)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 8 (full shell-suite battery, `tests/run-all.sh`) of the complete gate set | Dispatch 18 carries an explicit Batch Gate Deferral directive: this phase discharges against a scoped narrowing instead of independently running the complete gate set, and the full set runs once for the whole batch at the end of the `/orchestrate` invocation. | `.dispatch/18.md`'s `## Batch Gate Deferral` section; this task's `modified_files` (the 3 lean agent/flow files) attributes its share of the deferred full run back to this task per that section's own attribution rule. |

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase modifies no source file of its own; it regenerates the deployed
`.claude/` tree. Confirm with `git status --short` showing only `.claude/**` regeneration
(gitignored in a deployed tree) and no unexpected source-store modification attributable to this
phase.

**Files to modify**:

- none planned (deploy regenerates `.claude/**`; no hand-authored file is edited in this phase)

**Verification**:

- The stale-phrase sweep above leaves no hit in a gating context in any of the three files.
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully.
- `diff` is empty for each of the three source-store/deployed file pairs listed above.
- The complete gate set — `bash agent-system/extensions/core/scripts/verify-deploy.sh
  /home/benjamin/.config/nvim`, all gates including gate 3 (doc-lint), gate 4 (task-reference
  lint), gate 5 (manifest parity and content-hash equality), gate 6 (agent-contracts lint) and
  gate 8 (the full shell-suite battery) — reports no failures attributable to this task's file
  scope.

---

## Decisions

- **ITEM 2 lands narrowly in the three lean files, not in a new core pattern file.** Research
  confirmed no existing generic home and recommended against creating one on a single observed
  incident: every surveyed core pattern file is backed by multiple call sites or an existing
  cross-cutting mechanism, `file_scope` is currently exactly these three files, and generic
  wording now makes a future promotion a copy-then-point-at-it change rather than a rewrite. If a
  second incident of the same class appears elsewhere in the source store, the correct follow-up
  is a new shared pattern file plus a widened `file_scope` covering
  `core/agents/reviser-agent.md` (the other plan-section splicer) — not retroactive work here.
- **The flow file is auto-loaded only for the standard agent, not the hard-mode agent.** The lean
  extension's index entry for `project/lean4/agents/lean-implementation-flow.md` lists
  `load_when.agents: ["lean-implementation-agent"]`, and neither agent file references the flow
  file by path. The dispatch description's framing of it as "the shared flow both agents
  reference" is therefore inaccurate. Consequence, and the reason Phase 3 splits its treatment:
  the standard agent may point at the flow file for rationale, while the hard agent must carry
  both items **inline** and self-contained. Rejected alternative: adding
  `lean-implementation-hard-agent` to that index entry's `agents` array to make the file genuinely
  shared — it would push ~200 lines of standard-mode flow into every hard-mode dispatch's ambient
  context for no benefit, and it would widen `file_scope` to `index-entries.json`.
- **`long-builds.md` is not edited and `file_scope` is not widened.** Its scoped-build section
  concerns detach/guard parity and lock granularity, not phase-commit gating. Phase 4 verifies
  this by reading rather than assuming, and routes a genuine contradiction through
  `proposed_file_scope` instead of an out-of-scope write.
- **The dispatch's detach-mechanism paragraph is stale and is not followed.** It instructs
  preserving a requirement that every `lake build` run via `Bash(run_in_background: true)`; the
  current files **prohibit** that tool parameter outright and mandate a foreground-first
  preference order with shell-level backgrounding as the fallback. The orthogonal constraint this
  task must not weaken is preserved in its *current* form: new guidance points at
  `long-builds.md`'s preference order and never restates a detach mechanism.
- **The gate is placed before the `[COMPLETED]` marking, not merely before the commit.** A phase
  whose full build is red is not a completed phase, so the build verdict gates the marker and the
  commit together, rather than allowing a `[COMPLETED]` marker to stand above a red build.

## Testing & Validation

- [ ] All three files state the same phase-commit gate (a full library build) and the same
      non-gating role for a scoped build.
- [ ] All three files state the plan-file section-anchoring rule; the hard agent's copy is
      self-contained with no pointer to the flow file or the standard agent.
- [ ] The full-build cost is named at each gate site (flow file Stage 4C, standard agent's Phase
      Checkpoint Protocol, hard agent Stage 4D).
- [ ] No stale phrase survives: the Phase 4 fragment sweep leaves no hit in a gating context.
- [ ] The hard agent's Stage 4D bounded-waiter idiom and its
      `Bash(run_in_background: true)`-is-forbidden paragraph are intact and unweakened.
- [ ] No added text references a task number or a commit sha
      (`.claude/rules/no-task-references-in-deliverables.md`).
- [ ] Every edit is under `agent-system/extensions/lean/`; nothing hand-authored under
      `.claude/**`.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
      reports no failures attributable to this task's file scope.
- [ ] The three deployed copies are byte-identical to their source-store originals after the
      deploy.

## Artifacts & Outputs

- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
  (revised: ITEM 1 gate, ITEM 2 canonical block)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (revised: ITEM 1 MUST
  DO/MUST NOT and Phase Checkpoint Protocol gate, ITEM 2 statement and write-authority clause)
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` (revised: ITEM 1 Stage
  4D/4H and MUST DO items, ITEM 2 inline statement and write-authority clause)
- Regenerated deployed copies under `.claude/` (produced by `deploy-headless.sh`, not
  hand-authored)
- `specs/396_lean_phase_commit_full_build_and_plan_anchor/summaries/01_phase-commit-anchor-guidance-summary.md`
- Issue-log entries in `specs/396_lean_phase_commit_full_build_and_plan_anchor/issues.jsonl`

## Rollback/Contingency

All four phases are prose edits to three tracked markdown files, each committed separately per
phase, so reverting is `git revert` of the offending phase commit — no snapshot is needed and no
working-tree-discarding operation is warranted. If a phase's edits must be undone before they are
committed, re-apply the correct text with a targeted `Edit` rather than discarding the working
tree: per `.claude/rules/error-handling.md`'s write-gating constraint and
`.claude/context/contracts/recovery.md`'s ladder, fix forward first. Only a genuine rollback
scenario reaches that ladder's snapshot-then-rollback rung, and it uses the invocation shape
`recovery.md` specifies, never a bare precautionary `git-snapshot.sh`. The deployed `.claude/`
tree needs no rollback of its own: it is regenerated from the source store by
`deploy-headless.sh`, so reverting the source commit and redeploying restores it.
