# Implementation Plan: Task #557

- **Task**: 557 - Half-line test context note
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None (no research report was produced for this round; the plan is grounded
  directly in the cited probe file and the originating probe's own report, both read at plan time
  — see "Grounding Instead of a Research Report" below)
- **Artifacts**: plans/01_half-line-test-context-note.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The deliverable is one new durable context note in the lean extension's source store —
`agent-system/extensions/lean/context/project/lean4/patterns/half-line-test.md` — recording the
half-line test: given a proposed transport or index condition, name the half-line the COUNTER is
read from and the half-line the FORMULA is read from; if both answers are "forward", the proposal
is already decided by the recorded refutation mechanisms and needs no fresh probe. The note is
the reusable product of the one-sided open-modal probe, and its job is to let an agent apply the
test in a single reading rather than rediscovering the pincer. Beyond authoring the note, the
plan wires it into the four surfaces that make a lean4 context file actually reachable (the
context index, the extension's `EXTENSION.md` pointer list, the lean4 context `README.md` key-file
list, and a cross-pointer from the sibling note a reader would already be standing in), then
redeploys and verifies. Definition of done: an agent considering a transport or index condition
reaches the test through an index keyword search or through either pointer surface, applies it in
one reading, and the deployed tree is green.

### Grounding Instead of a Research Report

No `research_artifact` was supplied for this round, and none is needed: the substance of the note
already exists in compiled, readable form, and plan-time reads established every fact the note
must carry. Confirmed live at plan time:

- The cited probe exists and is readable at
  `/home/benjamin/Projects/BimodalLogic/specs/evidence/seam-gluing-ray-product/one-sided-count-move-refutation.lean`
  (414 lines). Its header docstring contains a section literally titled "The half-line test,
  which is the reusable product", stating the two questions and the decision rule, plus the
  one-sentence pincer, the two killing mechanisms, and an explicit "What this probe does NOT
  settle" paragraph.
- The two load-bearing declarations are `Probe855O.cntAt_eq_of_pend_eq_fwd` (frozen-future
  direction) and `Probe761S.splice_type_invariance_refuted` (freed-future direction, carried by
  `specs/evidence/seam-gluing-ray-product/ladder-splice-type-refutation.lean`). The probe's
  namespace is `Probe855O`; the headline with no hypotheses left standing is
  `Probe855O.futAtomPreservingCountMove_refutedO`.
- **The dispatch description mis-locates one input.** It says the "six-mechanism survival
  analysis lives in" the `.lean` probe. It does not: the probe file contains no
  mechanism-by-mechanism table and the word "six" appears nowhere in it. That table is the
  "Mechanism-by-mechanism measurement" section of the originating probe's own research report in
  the source repository's archive. The consequence for this plan is a citation decision, recorded
  under "Decisions Taken at Plan Time" below — not a research gap.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and `roadmap_flag` is not set, so no roadmap
consultation was performed and no roadmap phases are added.

### Decisions Taken at Plan Time

Three choices a reader of the finished note might otherwise wonder about, decided here so the
implementer does not re-litigate them mid-phase:

1. **Cite the probe files, not the archived report directory.** The six-mechanism survival table
   lives in an archived task directory in the source repository, whose name embeds a task number
   that renumbers under vault operations and that a future reader cannot verify — exactly the
   class of anchor `rules/no-task-references-in-deliverables.md` exists to keep out of a
   deliverable. The note therefore states the survival result in its own words and cites the
   durable anchors: the probe `.lean` files under
   `specs/evidence/seam-gluing-ray-product/`, which is already the citation convention of the
   sibling note `context/project/lean4/domain/ladder-counter-observables.md`. The note does not
   transcribe the table.
2. **Namespace-qualified declaration names are allowed.** `Probe855O.cntAt_eq_of_pend_eq_fwd` and
   `Probe761S.splice_type_invariance_refuted` are Lean namespaces in the probe corpus, not task
   references. Precedent is live and already passes the repo-wide lint: `Probe476.fmp_false` is
   cited in the deployed `context/project/lean4/domain/decidability-provenance.md`. Phase 4 still
   confirms this mechanically rather than on precedent alone.
3. **`patterns/`, as a new file, not an extension of the sibling note.** The dispatch names the
   mirrored `context/project/lean4/patterns/` path explicitly. The sibling
   `domain/ladder-counter-observables.md` is a different artifact with a different job (it
   enumerates the mechanisms defeating a clipped-coordinate index and the gate each implies);
   the half-line test is a one-reading triage test applied BEFORE that enumeration is consulted.
   They cross-reference rather than merge.

## Goals & Non-Goals

**Goals**:

- A single source-store context note stating the half-line test so an agent can apply it in one
  reading: the two questions, the decision rule for the both-forward answer, the two mechanisms
  that decide it, and the boundary of what the test decides.
- The note registered in the lean extension's `index-entries.json` with `load_when` and
  `keywords` that the terms an agent would actually search resolve against.
- The note reachable from the two human-facing pointer surfaces (`EXTENSION.md`, the lean4
  context `README.md`) and from the sibling note a reader considering an index condition is
  already in.
- A clean redeploy with the note present in the deployed tree, indexed, and line-count accurate.

**Non-Goals**:

- No Lean source is written, edited, or compiled, and no probe is added, re-signed, or re-run.
  Nothing in the source repository is touched.
- No transcription of the six-mechanism survival table, and no re-derivation of any refutation.
- No claim about decidability in either direction, and no weakening of any recorded Challenge
  statement — the note states the probe's own "does NOT settle" boundary rather than widening it.
- No new skill, agent, command, rule, hook, or script.
- No change to `provides.context` in the lean manifest: it declares the directory
  `project/lean4`, so a new file inside it needs no manifest edit (confirmed at plan time).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The two "six" sets get conflated: the originating report's six recorded refutation mechanisms are NOT the six mechanisms of `domain/ladder-counter-observables.md` (that note's six defeat a clipped-coordinate index; three of its probe citations overlap, the sets do not coincide) | M | H | The note asserts no identity between them. The cross-pointer in Phase 3 states the distinction in one clause. Phase 1 confirms the two probe-citation sets differ before any prose is written. |
| The note overreaches into a decidability claim the probe explicitly disclaims | H | M | Phase 2 carries a dedicated "what this does not decide" section lifted from the probe's own "What this probe does NOT settle" paragraph: no finite-fibre and no finite-width assumption, `not_finite_width_fmp` untouched, and the tight (doubling) chain gap in `LadderChain.lean` is explicitly NOT a one-sidedness gap. |
| The note is written as a blanket refusal rather than a test, making it useless for a genuinely past-looking proposal | M | M | The decision rule is stated with its boundary: a `snce`-bearing formula or a genuinely past-read counter falls OUTSIDE the decided region (the past-looking twin is paper-level, not machine-checked), where the test returns "not decided here" rather than "refuted". |
| `generate-context-line-counts.sh` refuses to run from the source store, so a plan naming the source-store copy cannot execute | M | H (if the path is copied from precedent) | Every invocation in this plan names the DEPLOYED entry point `bash .claude/scripts/generate-context-line-counts.sh`, which is the copy that rewrites the source `index-entries.json` files. Measured at plan time: the source-store copy exits with an explicit refusal. |
| `verify-deploy.sh --only-gate` silently SKIPs, or exits 2, when its `TARGET` is wrong | M | M | Every invocation passes the repository root `/home/benjamin/.config/nvim` explicitly as `TARGET` — the one directory that is simultaneously a deployed `.claude/` tree and the `agent-system/extensions` source store. Authority: `plan-format.md`'s `__FULL_SWEEP__` sub-case (b) and `context/project/lean4/patterns/plan-authoring-gate-collisions.md` Condition 2. |
| `agent-system/extensions/lean/index-entries.json` is also claimed by a concurrent sibling in this same cycle (a `research`-phase task declares it in `file_scope`) | M | M | Phase 3 re-reads the file immediately before editing, stages only this task's own hunks with an explicit file list (never a directory or glob pathspec), and treats a foreign modification as a STOP-and-report condition per `context/contracts/territory.md`. |
| `EXTENSION.md` has a 60-line ceiling enforced by the extension-docs lint; a pointer line pushes it up | L | L | Measured at plan time: 41 lines, so 18 lines of headroom remain after the one line this plan adds. Phase 3 re-measures with `wc -l` after editing rather than assuming. |
| A new deployed `.claude/context/**/*.md` with no index entry is a lint finding | M | H (if phases are reordered) | The index entry is authored in Phase 3, strictly before the Phase 4 redeploy. The phase order is load-bearing, not cosmetic, and Phase 4's dependency on Phase 3 encodes it. |
| `__WHOLE_TREE__` in Phase 4 exact-matches another task's identical claim and serializes this task behind it | L | M | This is the designed behaviour of the whole-tree-claim admission dimension, not a defect. The claim is declared honestly with the reserved sentinel; no real wide path is substituted to evade serialization. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict chain: the note's
prose must be grounded before it is written, the pointer text must describe a note that exists,
the index entry's `line_count` must be taken from final content, and the redeploy must observe
all of it.

---

### Phase 1: Ground the Claims and Capture the Pre-Edit Baseline [COMPLETED]

**Goal**: Fix every declaration name, probe path, and disclaimer the note will carry against the
files that actually carry them, and capture the pre-edit gate state so Phase 4's comparison is
against a measured baseline rather than an assumption.

**Tasks**:
- [x] Read the half-line-test section, the pincer sentence, and the "What this probe does NOT
      settle" paragraph of
      `/home/benjamin/Projects/BimodalLogic/specs/evidence/seam-gluing-ray-product/one-sided-count-move-refutation.lean`.
      Record verbatim: the two questions, the decision rule, and the two declarations named as
      killing each direction. *(completed: verbatim text captured in
      baselines/phase1-grounding-findings.md)*
- [x] Confirm each declaration the note will cite exists in the file that is cited for it:
      `cntAt_eq_of_pend_eq_fwd`, `cntAt_eq_of_lab_eq_fwd_of_pendFactorsLab`,
      `futAtomPreservingCountMove_refuted`, `atomPreservingCountMove_refuted_via_fwd`,
      `futAtomPreservingCountMove_refutedO`, `PastAtomPreservingCountMove`,
      `FutAtomPreservingCountMove`, and the namespace `Probe855O`; and
      `splice_type_invariance_refuted` in
      `specs/evidence/seam-gluing-ray-product/ladder-splice-type-refutation.lean`. Any name that
      does not resolve is dropped from the note rather than cited on faith. *(completed: all
      names resolved via grep, none dropped)*
- [x] Confirm the enabling biconditional's name as the probe states it
      (`PlusLanguage.PlusRayFibre.plusStab_iff_rays`, for `⊡φ ↔ ▷◁φ ↔ ◁▷φ`) and the landed
      `▷`-shaped count move it attributes (`exists_spliced_ladderPath_of_pend_past`).
      *(completed: both confirmed as stated verbatim in the probe's own docstring)*
- [x] Confirm the two "six" sets differ: list the probe files cited by
      `agent-system/extensions/lean/context/project/lean4/domain/ladder-counter-observables.md`
      and compare against the probe files named in the originating report's
      mechanism-by-mechanism table. Record the overlap and the difference; this is what the
      Phase 3 cross-pointer clause must be accurate about. *(completed: 4-file overlap, 2
      different each side, recorded in baselines/phase1-grounding-findings.md; see issue-log for
      the "three" vs. four discrepancy against the plan's Risk table)*
- [x] Confirm the sibling note does not already state the half-line test (grep it for
      `half-line`, `half line`, `one-sided`), so Phase 2 is authoring, not duplicating.
      *(completed: zero hits)*
- [x] Capture the baseline, each to its own file under this task's directory, with the exit
      status recorded alongside the output:
      `bash .claude/scripts/generate-context-line-counts.sh --check`;
      `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.
      *(completed: both exit 0, captured under baselines/)*
- [x] Record `wc -l` for `agent-system/extensions/lean/EXTENSION.md`,
      `.../context/project/lean4/README.md`, and
      `.../context/project/lean4/domain/ladder-counter-observables.md`, so Phase 3's line-count
      refresh can be checked against a known before-state. *(completed: 41/32/330)*
- [x] Record issue-log entries as they arise, per this dispatch's Issue Log section.
      *(completed: one minor issue recorded for the overlap-count discrepancy)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The phase modifies no tracked file at all, so the `prose` row's diff
read-through is the covering check and is satisfied by `git status --short` showing no
modification attributable to this phase beyond the captured baseline files under
`specs/557_half_line_test_context_note/`.

**Scope Hypothesis**: This phase asserts that every declaration name listed above resolves in the
file cited for it, and that the probe file contains no six-mechanism table. Confirm by `grep -n`
per name and by `grep -i -c "six"` over the probe file (expected: zero); a name that does not
resolve is reported in the phase's notes and dropped from Phase 2's citation list rather than
carried forward.

**Files to modify**:
- No source file is modified in this phase; its outputs are baseline captures under
  `specs/557_half_line_test_context_note/`.

**Verification**:
- Each cited declaration name has a recorded `grep` hit naming its file and line, or is recorded
  as dropped.
- `bash .claude/scripts/generate-context-line-counts.sh --check` exits 0 and reports zero
  mismatch (the recorded pre-edit baseline).
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0, with both gates observed RUNNING rather than SKIPPED, and its output saved as the
  baseline for Phase 4.
- The two "six" sets' overlap and difference are written down, with the probe filenames on each
  side.

---

### Phase 2: Author the Half-Line Test Note [COMPLETED]

**Goal**: Write the note so that an agent holding a proposed transport or index condition can
read it once, answer two questions, and know whether the proposal is already decided.

**Tasks**:
- [x] Create
      `agent-system/extensions/lean/context/project/lean4/patterns/half-line-test.md`. Author in
      the source store only; never hand-author the deployed `.claude/**` mirror
      (`rules/source-store-deploy-boundary.md`). *(completed)*
- [x] Open with one short paragraph stating what the note is for and when to reach for it: before
      attempting a proof or commissioning a probe for a proposed transport or index condition.
      *(completed)*
- [x] State **the test** as its own section: the two questions — which half-line is the COUNTER
      read from, and which half-line is the FORMULA read from — followed by the decision rule:
      both answers "forward" means the proposal is already decided and needs no fresh probe.
      *(completed)*
- [x] State **why both-forward is decided**, naming one mechanism per direction and nothing more:
      the frozen-future (`◁`) direction dies to `Probe855O.cntAt_eq_of_pend_eq_fwd` (the countdown
      at a position is determined by the pend profile at or above it, so freeing the entire past
      buys nothing — the headline `Probe855O.futAtomPreservingCountMove_refutedO` carries no
      hypotheses); the freed-future (`▷`) direction dies to
      `Probe761S.splice_type_invariance_refuted` (the `▷`-shaped count move already exists as the
      landed splice, and it does not preserve the realized stab-free type, because a nested
      counting formula counts occurrences at unbounded forward distance). *(completed)*
- [x] State, in one sentence, why there is no third option: the two projections are the only two,
      and `⊡φ ↔ ▷◁φ ↔ ◁▷φ` composes them without introducing anything else. *(completed)*
- [x] Carry the pincer in the probe's own one-sentence form: the counter and the closure's
      eventualities are read from the same forward half-line, so freezing the future leaves
      nothing to transport and freeing it loses the type. *(completed)*
- [x] State **how to answer the two questions** as a short procedure an agent can execute: name
      the quantity the condition's freedom is read over; decide whether the counter is
      forward-determined; decide whether the formula's eventuality reach is forward and unbounded.
      Include the strengthening fact that makes the test sharp: the one-sided forms are genuine
      RELAXATIONS of the refuted two-sided schema, so refuting a one-sided form is strictly
      stronger than the recorded two-sided refutation. *(completed)*
- [x] State **the boundary** explicitly, so the note is a test and not a blanket refusal: a
      genuinely past-read counter or a `snce`-bearing formula falls outside the decided region,
      where the honest answer is "not decided here" rather than "refuted" — the past-looking twin
      is paper-level and not machine-checked. *(completed)*
- [x] State **what the test does not decide**, from the probe's own disclaimer: no decidability
      consequence in either direction, no finite-fibre and no finite-width assumption,
      `not_finite_width_fmp` untouched, no recorded Challenge statement weakened, and the tight
      (doubling) chain gap in the ladder-chain route is NOT a one-sidedness gap. *(completed)*
- [x] Close with a short pointer section: the probe paths that carry the evidence, and the
      sibling note, with the one clause distinguishing the two "six" sets as established in
      Phase 1. *(completed)*
- [x] Keep the note one-reading short: target 70-110 lines. Prefer a flat section list over
      nesting, and state each mechanism once. *(completed: 84 lines, flat section list)*
- [x] Carry no task-number reference of any kind, and no record-versioning language (no "v2", no
      "previously", no "supersedes") — the note states the current test only
      (`rules/no-task-references-in-deliverables.md`,
      `rules/no-record-versioning-in-deliverables.md`). *(completed: verified via grep, zero
      hits)*
- [x] Record issue-log entries as they arise. *(completed: nothing further to record this
      phase)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The phase adds one pure-guidance markdown file with no executable
surface, and the selector's ENTIRE output over that single path is the `__FULL_SWEEP__` sentinel
(run at plan time, so no suite covers it); the covering check is therefore the `prose` row's diff
read-through together with
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
per `plan-format.md`'s `__FULL_SWEEP__` sub-case (b).

**Scope Hypothesis**: This phase asserts the note lands at 70-110 lines and cites no declaration
beyond the set Phase 1 confirmed. Confirm with `wc -l` on the finished file and by checking every
backticked identifier in it against Phase 1's recorded resolution list; a citation with no
recorded resolution is removed, not footnoted.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/patterns/half-line-test.md` - new: the
  half-line test, its decision rule, the one mechanism per direction that decides it, the
  procedure for answering the two questions, the boundary of the decided region, and the
  disclaimer

**Verification**:
- The file exists, is non-empty, and `wc -l` falls in the 70-110 band.
- A reader given only this file can answer both questions for a stated candidate condition and
  reach the decision rule without opening another file.
- Every backticked identifier in the note appears in Phase 1's recorded resolution list.
- `grep` over the note finds no task-number reference and no record-versioning phrasing.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with both gates RUNNING, and its output matches the Phase 1 baseline apart from the new
  file's own presence.

---

### Phase 3: Register the Note and Cross-Link It [COMPLETED]

**Goal**: Make the note reachable by the terms an agent would search and from the surfaces a
reader is already standing on, and keep every generated `line_count` exact in the same phase that
moves it.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/index-entries.json` immediately before editing: a
      concurrent sibling in this same cycle declares it in its own `file_scope`, so a foreign
      append is possible. A foreign modification is a STOP-and-report condition, checked against
      `git log` first, not something to work around. *(completed: `git log` showed no concurrent
      modification by another task)*
- [x] Add one entry for `project/lean4/patterns/half-line-test.md` to the `entries` array, with:
      `path`, `domain` `project`, `subdomain` `lean`, a `summary` naming what the note decides
      (the two questions, the both-forward verdict, the one mechanism per direction, and the
      boundary), and `line_count`. *(completed)*
- [x] Set that entry's `load_when` to `agents: ["lean-research-agent",
      "lean-implementation-agent"]` and `task_types: ["lean4"]`, matching every sibling pattern
      entry. **Do not add `planner-agent`** (or any other cross-domain shared agent) to
      `load_when.agents`: the adaptive query ORs its dimensions, so a shared agent named in a
      domain entry loads that domain's content into every other domain's dispatch — see
      `context/patterns/context-discovery.md`'s cross-domain-shared-agent hazard. *(completed,
      verified via jq)*
- [x] Set `keywords` to the terms an agent holding a candidate condition would actually search,
      at minimum: `lean4`, `half-line`, `transport-condition`, `index-condition`, `one-sided`,
      `open-modal`, `forward-determined`, `refutation-mechanism`. *(completed)*
- [x] Add no `description` and no `tags` key (both schema-forbidden), keep `load_when` keys drawn
      only from `agents`/`commands`/`task_types`/`always`, and keep `path`, `domain`,
      `subdomain`, `summary`, `line_count` all present. *(completed, verified via jq)*
- [x] Add one pointer line to `agent-system/extensions/lean/EXTENSION.md`'s `### Context
      Pointers` list, in the deployed-path form the neighbouring lines already use, with a
      one-clause description. Re-measure with `wc -l` afterwards and confirm the file stays under
      the 60-line ceiling (41 lines before the edit, measured at plan time). *(completed: 42
      lines after edit)*
- [x] Add one line to the `## Key Files` list of
      `agent-system/extensions/lean/context/project/lean4/README.md`, in that list's existing
      `path - description` form. *(completed)*
- [x] Add one cross-pointer to
      `agent-system/extensions/lean/context/project/lean4/domain/ladder-counter-observables.md`,
      placed where a reader about to work through its mechanisms will see it, saying that a
      candidate should be run through the half-line test first and naming the new note's path.
      Include the one clause distinguishing the two "six" sets, exactly as grounded in Phase 1 —
      assert no identity between them. *(completed: placed immediately before "## The six
      mechanisms")*
- [x] Refresh every affected generated `line_count` IN THIS PHASE, because the edits above move
      the quantity the extension-docs lint checks: run
      `bash .claude/scripts/generate-context-line-counts.sh --write` (the DEPLOYED entry point —
      the source-store copy refuses to run and exits with a diagnostic, measured at plan time),
      then `--check` to confirm zero drift. This touches `line_count` and nothing else.
      *(completed: --write touched exactly 3 entries, --check then reports zero mismatch)*
- [x] Stage only this task's own hunks, with an explicit file list; never `git add -A`, `git add
      .`, a directory pathspec, or a glob. *(will be done at phase-commit time via
      git-commit-phase.sh's derived file list)*
- [x] Record issue-log entries as they arise. *(completed: one minor issue recorded for
      test-gate-cache-equivalence.sh's pre-registered load-sensitive timeout)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edits are confined to one JSON data file and three markdown pointer
surfaces with no executable surface, and the covering check is
`bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/index-entries.json agent-system/extensions/lean/EXTENSION.md agent-system/extensions/lean/context/project/lean4/README.md agent-system/extensions/lean/context/project/lean4/domain/ladder-counter-observables.md`,
whose selector output over that whole set (run once as a single multi-path call at plan time) is
the mixed set `test-check-record-versioning.sh`, `test-check-task-references.sh`,
`test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-gate3-parallel-equivalence.sh`,
`test-gate3-strict-equivalence.sh`, `test-gate-cache-equivalence.sh`,
`test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`, `test-lean-src-roots.sh`,
`test-lint-agent-contracts.sh`, `test-lint-dead-command-recommendations.sh`,
`test-lint-extension-readme-table.sh`, `test-manifest-scripts-sync.sh`,
`test-milestone-ref-land.sh`, `test-milestone-review-handoff.sh`,
`test-orchestrate-batch-admit.sh`, `test-plan-file-scope-harvest.sh`,
`test-record-version-patterns.sh`, `test-roadmap-command-registration.sh`,
`test-sapience-capture.sh`, `test-script-inventory.sh` and `test-validate-state.sh` — no
sentinel is claimed.

**Scope Hypothesis**: This phase asserts exactly three index entries need a `line_count` value
written — the new `patterns/half-line-test.md` entry plus the two existing entries whose files
this phase edits (`project/lean4/README.md`, currently 32, and
`project/lean4/domain/ladder-counter-observables.md`, currently 330) — and that
`EXTENSION.md` is not itself indexed. Confirm with
`bash .claude/scripts/generate-context-line-counts.sh --check` before and after: the before-run
should name exactly the two edited indexed files, and the after-run should name none.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` - new entry for the half-line test note,
  carrying load_when, keywords, summary and line_count; refreshed line_count for the two
  existing entries whose files this phase edits
- `agent-system/extensions/lean/EXTENSION.md` - one `### Context Pointers` line for the new note
- `agent-system/extensions/lean/context/project/lean4/README.md` - one `## Key Files` line for
  the new note
- `agent-system/extensions/lean/context/project/lean4/domain/ladder-counter-observables.md` - one
  cross-pointer to the half-line test, with the clause distinguishing the two six-mechanism sets

**Verification**:
- `bash .claude/scripts/generate-context-line-counts.sh --check` exits 0 and reports zero
  mismatch across all entries.
- `jq` confirms the new entry carries `path`, `domain`, `subdomain`, `summary`, `line_count`;
  carries no `description` and no `tags`; has a `load_when` whose keys are drawn only from
  `agents`/`commands`/`task_types`/`always`; and has a `load_when.agents` that does NOT contain
  `planner-agent`.
- `jq` confirms the `entries` array grew by exactly one and that no entry other than the two
  whose files this phase edited changed any field besides `line_count`.
- `wc -l agent-system/extensions/lean/EXTENSION.md` is under 60.
- `bash .claude/scripts/verify-touched.sh` over this phase's four paths exits 0.
- `git diff --staged` shows only this task's own hunks in exactly these four files.

---

### Phase 4: Redeploy, Scoped Verification, and Deferral to the Orchestration Close [NOT STARTED]

**Goal**: Prove the note is present, indexed, and reachable in the deployed tree, that the gates
this task's own paths touch are green, and hand the complete gate set to the orchestration close.

**Tasks**:
- [ ] Redeploy the tree with the bounded-wait idiom the deploy path requires:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool's
      `timeout` parameter raised to 600000 rather than its 120000ms default (see
      `context/patterns/external-process-wait.md` Rule 1). Confirm exit 0. This is whole-tree
      regeneration, which is why `__WHOLE_TREE__` is declared below.
- [ ] Confirm the note landed in the deployed tree at
      `.claude/context/project/lean4/patterns/half-line-test.md`, and that its content is
      byte-identical to the source-store copy.
- [ ] Confirm the deployed merged index carries the entry: `jq` the entry out of
      `.claude/context/index.json` by `path`, and confirm that `path` resolves to an existing
      file in both the source store and the deployed tree (no ghost row, no unindexed deployed
      context file).
- [ ] Confirm discoverability concretely rather than by assertion: for each of the new entry's
      keywords, search the deployed index and confirm the entry comes back; and walk each pointer
      surface once as a reader would — from `EXTENSION.md`'s `### Context Pointers`, from the
      lean4 context `README.md`'s `## Key Files`, and from the sibling note's cross-pointer — each
      landing on the note.
- [ ] Run `bash .claude/scripts/validate-context-index.sh` and confirm it exits 0 with no error
      against the new entry.
- [ ] Run the scoped touched-path check that discharges this phase's own in-dispatch obligation:
      `bash .claude/scripts/verify-touched.sh` over this task's five touched paths (the new note
      plus the four Phase 3 files). Require exit 0, checked as an exit status in its own right
      rather than inferred from quiet output.
- [ ] Re-run `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
      with both gates RUNNING, and `diff` it against the Phase 1 baseline. A new finding, a
      removed finding, or a changed count means scope was exceeded and is resolved before
      proceeding, not explained away.
- [ ] Confirm the lint classes this task is most exposed to are clean on the final diff: no
      task-number reference anywhere in the new or edited deliverable files, and no
      record-versioning phrasing.
- [ ] **Defer the complete gate set to the orchestration close.** Under `/orchestrate`, the
      complete set is discharged once per invocation at the batch gate stage
      (`context/contracts/batch-gate-stage.md`), not independently inside this dispatch; this
      phase does not run an independent full battery. State that deferral explicitly in the
      phase's closing notes and in the handoff. Only on a standalone, non-orchestrated run, with
      no orchestration close to defer to, does this phase instead run
      `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` directly.
- [ ] Treat a failure in a file outside this task's own `Files to modify` lists as possibly a
      concurrent sibling's in-flight edit: check `git log` and the working tree before
      attributing it to this task.
- [ ] Record issue-log entries as they arise, including a `win` entry if any plan-time grounding
      saved rework, and attest explicitly in the handoff if there is genuinely nothing to record.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - whole-tree regeneration via `deploy-headless.sh`; no tracked source file is
  edited in this phase

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` exits 0 and the deploy-freshness check
  reports no stale extension.
- `.claude/context/project/lean4/patterns/half-line-test.md` exists and is byte-identical to its
  source-store counterpart.
- `jq` returns the new entry from `.claude/context/index.json`, and its `path` resolves in both
  trees.
- `bash .claude/scripts/validate-context-index.sh` exits 0 with no error naming the new entry.
- `bash .claude/scripts/verify-touched.sh` over this task's five touched paths exits 0.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0, both gates RUNNING, and `diff`s clean against the Phase 1 baseline apart from timing
  or path-prefix noise.
- Every keyword search returns the entry, and all three pointer surfaces are walked and each
  lands on the note.
- The complete gate set is explicitly deferred to the orchestration close, and the deferral is
  stated in the handoff — or, on a standalone run, `bash .claude/scripts/verify-deploy.sh
  /home/benjamin/.config/nvim` runs in full and is green.

---

## Testing & Validation

- [ ] An agent given only the deployed note can state, for a candidate transport or index
      condition, which half-line the counter is read from and which the formula is read from, and
      reach the correct verdict — decided, or outside the decided region — in one reading.
- [ ] The note names exactly one mechanism per direction and cites each by a declaration name
      that resolves in the probe file cited for it.
- [ ] The note asserts no decidability consequence and no identity between the two
      six-mechanism sets.
- [ ] The new index entry is schema-conformant, `line_count`-exact, and reachable by every
      keyword it declares; `load_when.agents` contains no cross-domain shared agent.
- [ ] All three pointer surfaces resolve to the note in the deployed tree.
- [ ] `generate-context-line-counts.sh --check` reports zero drift across all entries.
- [ ] Gates 3 and 4 produce a finding set matching the Phase 1 baseline.
- [ ] No task-number reference and no record-versioning phrasing in any deliverable file.

## Artifacts & Outputs

- `agent-system/extensions/lean/context/project/lean4/patterns/half-line-test.md` (new)
- `agent-system/extensions/lean/index-entries.json` (one new entry; two refreshed `line_count`
  values)
- `agent-system/extensions/lean/EXTENSION.md` (one pointer line)
- `agent-system/extensions/lean/context/project/lean4/README.md` (one key-file line)
- `agent-system/extensions/lean/context/project/lean4/domain/ladder-counter-observables.md` (one
  cross-pointer)
- The regenerated deployed mirror under `.claude/` (a disposable deploy artifact, not a tracked
  deliverable)
- Baseline captures and issue-log entries under `specs/557_half_line_test_context_note/`

## Rollback/Contingency

Every change is additive markdown plus one additive JSON entry; nothing is deleted and no
behaviour is altered, so rollback is per-file and cheap.

- **Before any risky step in a dirty tree**: take a durable, non-reverting checkpoint with
  `bash .claude/scripts/git-snapshot.sh 557 --no-revert`. Do not use the default reverting form
  as a routine checkpoint — it belongs only to a genuine rollback.
- **Note is wrong or overreaches**: the note is a single new file; correct it in place, or delete
  it together with its index entry and the three pointer lines, then redeploy. The deployed tree
  returns to its pre-task state because `.claude/` is regenerated, not hand-edited.
- **Index entry breaks schema conformance or line-count exactness**: revert the
  `index-entries.json` hunk alone and re-run
  `bash .claude/scripts/generate-context-line-counts.sh --write` followed by `--check`.
- **`EXTENSION.md` crosses the 60-line ceiling**: drop the pointer line; the index entry and the
  two remaining pointer surfaces still make the note reachable, and the shortfall is recorded
  rather than worked around.
- **A concurrent sibling has modified `index-entries.json`**: stop, confirm against `git log`
  that the change is not this task's own, and report it rather than merging blind or reverting
  another writer's work.
- **Deploy fails**: the source store is the truth; the failed deploy leaves no tracked file
  wrong. Re-run the bounded deploy once, and if it fails again report it with its output rather
  than hand-editing `.claude/**` to compensate.
