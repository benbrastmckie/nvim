# Implementation Plan: Email Safety Context-Loading Decision

- **Task**: 43 - Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: 194 (archived/completed), 257 (archived/completed) — none blocking
- **Research Inputs**: specs/043_email_safety_context_loading_decision/reports/01_email-safety-context-loading-decision.md
- **Artifacts**: plans/01_email-safety-context-loading-decision.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research settled the decision empirically: option (b) — the mechanical enforcement layers
(`mail-guard.sh` PreToolUse hook plus the nix-built wrapper binaries themselves) combined with
the safety content each email consumer already duplicates inline in its own body already carry
the enforcement, so none of the five email domain files needs to become eager-loaded. What is
actually missing is a written record of that reasoning: `EXTENSION.md` still says "Operating
rules are non-negotiable — see `domain/safety-invariants.md` before any `email` work", an
imperative no consumer performs, and `safety-invariants.md` itself carries no statement of its
real (reference, not runtime) role. This plan is documentation-only: it records the verified
decision in the email extension's source store so a future audit finds the reasoning instead of
re-litigating the question. Done means a reader of `EXTENSION.md` or `safety-invariants.md` can
see, without re-deriving it, which layer enforces what and why the five files are deliberately
not eager.

### Research Integration

Key findings carried into the phases below:

- Confirmed non-loading: the merged `## Email Extension` section in the deployed
  `.claude/CLAUDE.md` lists the five domain files as plain backticked paths, never `@`-imports.
  They resolve at no tier automatically.
- The loading-tier taxonomy the decision turns on: (1) session-start eager (`CLAUDE.md`'s own
  `@`-imports), (2) invocation-time eager (a `SKILL.md` / agent-definition body, read in full
  when the Skill/Agent tool invokes it — the tier that actually gates a mutation), (3) on-demand
  (a plain path in prose, read only if an agent decides it needs it). An `@`-prefixed path
  written *inside* a skill or agent body sits at tier 3, not tier 1 — it is stylistic, not
  harness-expanded.
- Two mechanical layers hold with zero markdown loaded: `hooks/mail-guard.sh` (deployed and
  registered in `.claude/settings.local.json`) and the nix-built binaries' own baked-in hash
  check, staleness gate, `MAX_BATCH_SIZE` cap, and confirm-manifest state machine.
- Cost of rejecting the decision: ~13k tokens/session for all five files, ~1.4k for
  `safety-invariants.md` alone (51,612 bytes across the five, measured).
- **Two corrections to the research report that shape Phase 1.** First, the report names
  *three* consumers; there are **four** — `skills/skill-email-implementation/SKILL.md` also
  inlines the load-bearing constants (`MAX_BATCH_SIZE=50`, `PLAN_EXPIRY_DAYS=7`, the `>= 0.90`
  delete confidence threshold) and its own `$PATH` precondition check. Second, the report treats
  `safety-invariants.md` as having five sections; it has **eleven** (`Wrapper-Only`,
  `Two-Layer Enforcement`, `Propose-Review-Confirm-Execute`, `Delete Is Himalaya-Level Only`,
  `` `$PATH` Precondition ``, `Index-Freshness Gate`, `Default-Mode Cursor`,
  `Sub-50 Transparent Drain`, `Mtime-Preserve / Expiry-Stop`, `Archive Extra Gates`,
  `Account Isolation, Folder-Scoped Only`). The coverage claim must therefore be confirmed over
  11 sections x 4 consumers, not 5 x 3 — this is Phase 1's Scope Hypothesis, and if a section
  turns out to have no inline counterpart anywhere, Phase 1's decision gate routes to its
  contingency branch rather than recording an unverified claim.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap consulted.

## Goals & Non-Goals

**Goals**:
- Record decision (b) as a documented, evidenced choice in the email extension source store
  (`agent-system/extensions/email/**`), including the enforcement-coverage evidence behind it.
- Replace `EXTENSION.md`'s misleading "see `domain/safety-invariants.md` before any `email`
  work" imperative with wording that states the actual loading model, while keeping the pointer
  list useful to a human auditor.
- Give `safety-invariants.md` an explicit role-and-loading-model statement so its non-loading
  reads as a deliberate decision, not a dead import.
- Name the drift hazard the decision accepts (rules duplicated in two places) at both ends, so a
  future editor of either copy knows to check the other.

**Non-Goals**:
- Making any of the five domain files eager-loaded (options (a) and (c) are rejected by research;
  this plan does not revisit that).
- Changing any operational behavior: no wrapper contract, gate, threshold, batch cap, or
  classification rule changes. Documentation only.
- Editing the inlined safety content in the four consumer bodies. Research verified it already
  carries the enforcement; Phase 1 only *confirms* that coverage, it does not rewrite it.
- Normalizing the `@`-prefixed context references inside consumer bodies. That form is a
  project-wide authoring convention (core agents, including the planning agent, use it too);
  changing it in the email extension alone would diverge from convention for no safety gain.
- Creating a core-extension `context/patterns/context-loading-tiers.md`. The research report
  raises it as a candidate follow-up; it is agent-system-wide scope, belongs to `extensions/core`
  rather than `extensions/email`, and is left for a separate task.
- Running a deploy / regeneration. Regeneration is manual-only (see
  `context/patterns/regeneration-is-manual-only.md`), and a full resync during this dispatch
  would sweep in seven sibling tasks' in-flight source-store edits.
- Adding a constants-drift lint across the duplicated locations (research flags it as an
  explicitly out-of-scope follow-up).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A `safety-invariants.md` section turns out to have no inline counterpart in any of the four consumers, meaning the decision's premise is incomplete for that invariant | H | M | Phase 1 is a decision gate: the coverage map is built before any decision wording is written. An uncovered invariant is recorded in the map as an explicit gap, and Phase 2 records the decision as conditional on that gap rather than asserting full coverage — the contingency branch, never a silent "verified" claim |
| Recording "the consumers duplicate the rules" invites the two copies to drift apart | M | H | Stated, not hidden: both the `safety-invariants.md` banner (Phase 1) and the `EXTENSION.md` rewrite (Phase 2) name the four consumer files explicitly and instruct a future editor of either side to update the other. Accepted, documented cost of the decision |
| This plan's file set extends past the task's anticipated `file_scope` (`EXTENSION.md`, `agents/`, `skills/`) into `context/project/email/domain/safety-invariants.md`, `README.md`, and `index-entries.json` | L | H (certain) | `file_scope` is descriptive/anticipated, not validated (see `rules/state-management.md`). All three added paths are inside `agent-system/extensions/email/**`, which the dispatch constraints permit, and none appears in any concurrent sibling's declared territory (verified against the dispatch's Territory block: siblings 139, 162, 163, 199, 207, 244, 167 claim only `extensions/core`, `extensions/literature`, `extensions/lean`, and `extensions/latex` paths) |
| A sibling task commits into the shared working tree mid-phase | M | H | Re-read every target file immediately before editing it; stage only this task's own file paths by explicit name (never a directory or glob pathspec); never run `git-snapshot.sh` in its reverting default mode |
| The deployed `.claude/CLAUDE.md` still shows the old `EXTENSION.md` wording after this task completes, and a reader mistakes that for the edit having failed | L | H | Phase 4 verifies the source-store text and states explicitly in the task summary that the deployed tree refreshes only on the next manual regeneration |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Build the enforcement-coverage map and record the role of safety-invariants.md [COMPLETED]

**Goal**: Establish, section by section, where each `safety-invariants.md` invariant is actually
enforced, and write that evidence plus the file's real role into the file itself as a banner
section. This is the decision gate for the whole plan: every later phase's wording depends on
what this map finds.

**Tasks**:
- [x] Re-read `context/project/email/domain/safety-invariants.md` in full and enumerate its
      section headings (expected 11 — confirm, do not assume). *(completed: confirmed exactly
      11 `## ` sections, matching the Scope Hypothesis)*
- [x] For each section, locate its inline counterpart in each of the four consumer bodies:
      `agents/email-implementation-agent.md`, `skills/skill-email-cleanup/SKILL.md`,
      `skills/skill-email-sync/SKILL.md`, `skills/skill-email-implementation/SKILL.md`.
      Record, per invariant: which consumer(s) carry it inline, and/or which mechanical layer
      (`hooks/mail-guard.sh` deny/allow list, or a wrapper binary's own baked-in check) enforces
      it independently of markdown. *(completed)*
- [x] Decision gate: if every invariant is covered by at least one inline consumer copy or one
      mechanical layer, proceed on the main branch (full coverage). If any invariant is covered
      by neither, do NOT widen scope to fix it here — record it as a named gap row in the map,
      and carry that gap forward into Phase 2's wording (conditional decision) and into the task
      summary as a follow-up candidate. *(completed: full coverage confirmed — every invariant
      has at least one inline consumer copy or one independent mechanical layer; main branch
      taken, no gap)*
- [x] Add a banner section immediately after the file's H1 (before `## Wrapper-Only`) stating:
      (a) this file is reference material, resolved on demand, deliberately not eager-loaded at
      any tier; (b) the operationally load-bearing rules are duplicated inline in the four
      consumer bodies named above, each of which is read in full at its own invocation time;
      (c) the two mechanical layers hold with zero markdown loaded; (d) the measured cost that
      makes eager promotion a bad trade (~1.4k tokens for this file, ~13k for all five);
      (e) an editor's instruction: changing a rule or constant here requires updating the
      consumer copies named in the map, and vice versa. *(completed)*
- [x] Embed the coverage map as a table in that banner section (columns: Invariant | Inline in
      consumer(s) | Mechanical layer | Notes). *(completed: 11-row table)*
- [x] Commit (source-store path staged by explicit name only). *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the map is asserted to cover **11 invariant sections across 4 consumer
files**, with every invariant covered by at least one inline copy or one mechanical layer.
Confirm at implementation time by (1) `grep -n '^## '` over `safety-invariants.md` for the
actual section count, and (2) a per-section grep across the four consumer bodies for its
operative rule text or constant. A different section count, a fifth consumer, or an uncovered
invariant supersedes this hypothesis and routes the decision gate above to its contingency
branch.

**Files to modify**:
- `agent-system/extensions/email/context/project/email/domain/safety-invariants.md` - add
  role-and-loading-model banner section plus the coverage map table after the H1; no change to
  any existing invariant's content

**Verification**:
- `grep -c '^## '` on the file shows exactly one more section than before the edit.
- Every consumer file named in the banner and in the map exists at the stated path
  (`test -f` each).
- Every invariant section heading in the file appears as a row in the coverage map (no invariant
  silently omitted).
- Diff read-through confirms every changed hunk is prose inside the new banner section; no
  existing invariant text is altered.
- `bash .claude/scripts/check-task-references.sh` reports no new hits for this path (no task
  numbers in a deliverable outside `specs/**`).

---

### Phase 2: Rewrite EXTENSION.md's safety framing and Context Pointers [COMPLETED]

**Goal**: Make the CLAUDE.md-merged fragment state the verified loading model instead of an
imperative ("see `domain/safety-invariants.md` before any `email` work") that no consumer
performs.

**Tasks**:
- [x] Re-read `EXTENSION.md` immediately before editing (sibling activity in the shared tree).
      *(completed)*
- [x] Replace the third sentence of the opening paragraph (the "Operating rules are
      non-negotiable — see `domain/safety-invariants.md` before any `email` work" imperative)
      with wording that: keeps the non-negotiable character of the rules; states that they are
      enforced mechanically by `hooks/mail-guard.sh` plus the wrapper binaries themselves, and
      carried inline in each email skill/agent body at invocation time; and states that the
      domain files are on-demand reference, not ambient context. *(completed)*
- [x] Retitle/reframe the `### Context Pointers` section so its list reads as
      read-on-demand reference material for a human or auditor, with one line stating the
      decision: these paths are deliberately plain (non-loading) and are not promoted to
      `@`-imports, because the enforcement lives in the layers named above — the full evidence
      is the coverage map in `safety-invariants.md`. *(completed)*
- [x] Add one line directed at a future new consumer (a hypothetical additional email skill or
      agent): it must inline or explicitly `Read` the safety content it depends on; that content
      is not ambient. *(completed)*
- [x] If Phase 1's decision gate took its contingency branch, phrase the decision as holding for
      the covered invariants and name the gap explicitly rather than claiming full coverage.
      *(completed: not applicable — Phase 1 found full coverage, no gap, so the decision is
      stated unconditionally)*
- [x] Keep the five listed paths unchanged in form (plain backticks, `.claude/`-prefixed as
      deployed) — do not convert any to `@`-imports. *(completed)*
- [x] Commit (`EXTENSION.md` staged by explicit name only). *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/email/EXTENSION.md` - opening-paragraph safety sentence and the
  `### Context Pointers` section

**Verification**:
- `grep -c '^@' EXTENSION.md` is 0 and `grep -n '@\.claude' EXTENSION.md` is empty: no path was
  promoted to an eager import (the constraint "no volatile files in any eager prefix" holds
  trivially because no eager prefix is added at all).
- All five domain paths still present in the file (`grep -c 'domain/.*\.md'` unchanged).
- The phrase "before any `email` work" no longer appears.
- The file's other sections (Task-Type Routing, Commands, skill tables) are byte-identical in
  the diff.
- `bash .claude/scripts/check-task-references.sh` reports no new hits for this path.

---

### Phase 3: Align README.md and index-entries.json with the recorded decision [COMPLETED]

**Goal**: Keep the extension's own two other descriptions of `safety-invariants.md` consistent
with its newly documented role, so the next audit does not find a third, contradicting account.

**Tasks**:
- [x] Re-read `README.md` and `index-entries.json` immediately before editing. *(completed)*
- [x] Update the `README.md` file-table row for
      `context/project/email/domain/safety-invariants.md` so its Purpose cell names the file's
      role (on-demand synthesis + coverage map) alongside its content, matching Phase 1's banner.
      *(completed)*
- [x] Add the missing `context/project/email/domain/staleness-detection.md` row to the same
      table — it is one of the five pointers named in `EXTENSION.md` but is absent from the
      README table, which would otherwise leave the decision's own subject list incomplete.
      *(completed)*
- [x] Update the `summary` field of the `project/email/domain/safety-invariants.md` entry in
      `index-entries.json` to mention the loading model, and confirm its `load_when` block is
      consistent with the decision (an advisory index hint, not an eager-load directive — do not
      change its semantics, only verify and note). *(completed: confirmed `load_when` is an
      advisory index hint only — consumed by check-extension-docs.sh/install-extension.sh
      metadata paths, never a harness auto-load mechanism — so no semantic change was needed.
      Also refreshed the stale `line_count` field 102 -> 156, see progress-file deviation 3.4)*
- [x] Commit (both paths staged by explicit name only). *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: asserted that `README.md`'s table is missing exactly one of the five
domain-file rows (`staleness-detection.md`). Confirm at implementation time by grepping the
README table for each of the five domain filenames; add rows for whichever are actually absent,
not for a count fixed at plan time.

**Files to modify**:
- `agent-system/extensions/email/README.md` - safety-invariants row purpose text; add missing
  domain-file row(s)
- `agent-system/extensions/email/index-entries.json` - `summary` for the
  `project/email/domain/safety-invariants.md` entry

**Verification**:
- `jq empty agent-system/extensions/email/index-entries.json` exits 0 (valid JSON).
- `jq '[.[]? // (.entries?[]?) | select(.path == "project/email/domain/safety-invariants.md")] | length'`
  (or the file's actual top-level shape) returns 1 — exactly one entry, not duplicated.
- All five domain filenames appear in `README.md`.
- `bash .claude/scripts/validate-context-index.sh` passes (or is unchanged in its findings versus
  a pre-edit run).
- `bash .claude/scripts/check-task-references.sh` reports no new hits for these paths.

---

### Phase 4: Cross-file consistency gate and close-out [NOT STARTED]

**Goal**: Confirm the four edited files tell one consistent story, that nothing operational
changed, and that the decision is discoverable from each entry point a future auditor would use.

**Tasks**:
- [ ] Read the final state of all four edited files and check the three accounts of the loading
      model (`EXTENSION.md`, `safety-invariants.md` banner, `README.md` row) agree with each
      other and with `index-entries.json`'s summary — no contradiction, no stale imperative left
      anywhere.
- [ ] Confirm zero behavioral drift: `git diff` over the task's commits touches only the four
      paths above, and contains no change to any constant, threshold, wrapper name, gate, or
      flag anywhere in the extension.
- [ ] Run the repo gates: `bash .claude/scripts/validate-wiring.sh`,
      `bash .claude/scripts/validate-context-index.sh`,
      `bash .claude/scripts/check-task-references.sh`.
- [ ] Confirm the four consumer bodies are untouched (`git diff --stat` shows no entry under
      `agent-system/extensions/email/agents/` or `.../skills/`).
- [ ] Record in the implementation summary: the decision taken, the coverage map's outcome
      (full coverage, or the named gap), that the deployed `.claude/` tree refreshes only on the
      next manual regeneration, and the two deferred follow-ups (a core
      `context-loading-tiers.md` pattern doc; a constants-drift lint across the duplicated
      locations).
- [ ] Final commit if any gate fix was needed; otherwise no commit.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None (verification phase; edits only if a gate fails)

**Verification**:
- All three gate scripts exit 0, or any non-zero exit is pre-existing and reproducible on a
  clean checkout of the same paths.
- `git diff --stat` across this task's commits lists exactly: `EXTENSION.md`, `README.md`,
  `index-entries.json`, `context/project/email/domain/safety-invariants.md`.
- No consumer body (`agents/**`, `skills/**`) appears in the diff.
- A reader starting from `EXTENSION.md` alone can reach the coverage map and the recorded
  decision in one hop.

## Testing & Validation

- [ ] `bash .claude/scripts/validate-wiring.sh` passes.
- [ ] `bash .claude/scripts/validate-context-index.sh` passes.
- [ ] `bash .claude/scripts/check-task-references.sh` reports no new hits outside `specs/**`.
- [ ] `jq empty agent-system/extensions/email/index-entries.json` exits 0.
- [ ] Every `safety-invariants.md` section heading has a row in the coverage map.
- [ ] `EXTENSION.md` contains no `@`-prefixed context path (nothing promoted to eager loading).
- [ ] The four consumer bodies are byte-identical to their pre-task state.
- [ ] Each of the five domain files is still referenced by plain backticked path, unchanged in
      form.

## Artifacts & Outputs

- `agent-system/extensions/email/context/project/email/domain/safety-invariants.md` — new
  role-and-loading-model banner section with the enforcement-coverage map table
- `agent-system/extensions/email/EXTENSION.md` — rewritten safety framing sentence and
  reframed Context Pointers section
- `agent-system/extensions/email/README.md` — updated safety-invariants row plus the missing
  domain-file row(s)
- `agent-system/extensions/email/index-entries.json` — updated `summary` for the
  safety-invariants entry
- `specs/043_email_safety_context_loading_decision/summaries/01_*-summary.md` — implementation
  summary recording the decision, the coverage outcome, and the two deferred follow-ups

## Rollback/Contingency

Every phase is documentation-only and independently committed, so rollback is a targeted
`git revert` of this task's commits — no snapshot-then-reset recipe is needed, and none should
be emitted: the working tree is shared with seven concurrent sibling tasks this cycle, so a
whole-tree revert is exactly the wrong instrument. If a gate in Phase 4 fails in a way that
implicates an earlier phase's wording, fix the wording forward in place rather than reverting.

If Phase 1's decision gate finds an invariant covered by neither an inline consumer copy nor a
mechanical layer, that is a genuine finding, not a plan failure: record the gap, phrase Phases 2
and 3 conditionally, and surface it as a follow-up candidate in the summary. Do not expand this
task into fixing the gap — the decision this task exists to record still stands for every
covered invariant, and an unrecorded decision is the defect being closed.
