# Implementation Plan: Task #336

- **Task**: 336 - Rule on the in-dispatch phase-commit staging surface: fifteen implementation
  agents commit with no file_scope check and no contended-path lease
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None (declared explicitly; see Goals & Non-Goals)
- **Research Inputs**: specs/336_phase_commit_staging_has_no_scope_check/reports/01_phase-commit-scope-check-ruling.md
- **Artifacts**: plans/01_phase-commit-containment-self-check.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The in-dispatch phase-commit surface shared by fifteen implementation-agent definitions invokes
`git-commit-scoped.sh` with no `--task` flag and no containment check, so nothing compares the
staged path list against the task's own declared `file_scope`. Research ruled the mechanism
question definitively: `--task` alone is **structurally incapable** of catching the observed
defect (a path declared by zero tasks never enters the contention manifest), so the ruling is
**both mechanisms at two layers** — `--task` plus a documented pre-commit Containment self-check
inside the recipes (landed here), with the durable mechanical chokepoint inside
`git-commit-scoped.sh` recorded as a constrained follow-up (not landed here, that file is out of
`file_scope`). Done means: all fifteen definitions carry both halves uniformly, the pre-fix
behaviour is exercised as a live regression case, and the follow-up is recorded with its
coordination constraints.

### Research Integration

Four findings from `reports/01_phase-commit-scope-check-ruling.md` drive this plan's shape and are
not re-litigated during implementation:

1. **`--task` is an Overlap-family mechanism; the defect needs a Containment-family one.** Traced
   to `build_contended_manifest` in `scripts/lib/territory-contention-lib.sh`: a path enters the
   contention manifest only when `uniq_tasks >= 2`, i.e. two or more tasks' declared `file_scope`
   name it. A path declared by **zero** tasks is never written to `path_declarers` at all, so the
   V5 lease can never refuse it under any `--task` value. This is the explicit concession the
   Acceptance criterion demands: **`--task` does not address the observed undeclared-path case**;
   it closes a different, real hazard (two tasks both declaring one path, dispatched
   concurrently). Both are wanted; neither substitutes for the other.
2. **The mid-dispatch asymmetry is confirmed, not assumed.** `build_contended_manifest` runs
   exactly once per `/orchestrate` cycle from `orchestrate-cycle-plan.sh`, before the dispatch
   loop. A phase commit fires later, inside an already-running agent, with no cycle-plan or
   postflight step re-running and no guarantee the session's manifest file still exists or is
   current. Any postflight-sited or cycle-plan-sited gate therefore categorically cannot reach
   this surface. The check must live either in the recipe prose (reachable now) or inside
   `git-commit-scoped.sh` (the follow-up).
3. **Failure mode is drop-and-warn, never refuse-the-whole-commit** — reusing the already-settled
   "under-stage, never over-stage" fail-safe direction from `git-staging-scope.md` rather than
   inventing a posture. An agent legitimately touching an incidental out-of-scope file must still
   be able to land its in-scope work.
4. **Uniformity is justified, no subset.** The defect is byte-identical in shape across all
   fifteen (zero `--task` occurrences in every file, verified again at plan time).

### Prior Plan Reference

No prior plan. This is round 1 for this task.

### Roadmap Alignment

`roadmap_path` was not supplied in this dispatch's delegation context, so no roadmap phases are
added and `specs/ROADMAP.md` is not written by any phase of this plan. A read-only consultation
confirms this task sits in the roadmap's current priority set as a ready core-safety item with a
scope disjoint from its co-dispatched siblings; that placement needs nothing from this plan.

## Goals & Non-Goals

**Goals**:
- Land the ruled mechanism — `--task {N}` plus a documented pre-commit Containment self-check —
  uniformly at every `git-commit-scoped.sh` invocation site in all fifteen definitions.
- Record the reasons, including the explicit concession that `--task` alone does not reach the
  observed undeclared-path case, in a durable in-repo home (the canonical block) and in this
  task's own artifacts.
- Address the mid-dispatch asymmetry head-on: site the check where it can actually run, and say
  in-file why neither a postflight nor a cycle-manifest-dependent mechanism was chosen.
- Exercise the observed commit's shape as a live regression case demonstrating pre-fix behaviour.
- Record the `git-commit-scoped.sh` mechanical chokepoint as a constrained follow-up with its
  coordination constraints, without widening `file_scope` to reach it.

**Non-Goals**:
- Any edit to `scripts/git-commit-scoped.sh` (or its source-store original). Out of `file_scope`
  by ruling; recorded as a follow-up in Phase 5.
- The postflight excursion gate, and the own-task-directory filter false positive in the
  postflight advisory — the sibling task's surface, which cannot reach this one.
- The nine recipe sites owned by the `--task`-wiring task. Zero file overlap with this task.
- Any change to what `file_scope` means or how it is harvested.
- Adding a new `context/standards/*.md` file or amending an existing one: not in `file_scope`.
  The recommended "Phase Commit (mid-dispatch)" subsection for `git-staging-scope.md` rides along
  with the Phase 5 follow-up record, it is not authored here.
- Declaring any dependency edge. This task owns the surface with demonstrated harm and must not
  be serialized behind tasks that do not touch its files.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Scope creep into `git-commit-scoped.sh` ("just fix it properly in one place" while already in the recipes) | H | M | Named in the dispatch, the report, and the Non-Goals here. Phase 5 writes the follow-up record as the sanctioned outlet. Any phase that finds itself editing that script has gone out of scope and must stop. |
| Editing `.claude/**` instead of the source store — the edit appears to succeed and is wiped by the next deploy | H | M | Every path in every phase below is an `agent-system/extensions/**` path. `.claude-extensions.json` carries no `source_dir`, so the in-repo `agent-system/` tree **is** the source store; `.claude/` is the deploy artifact. Phase 6 re-greps `.claude/` only to confirm the deploy mirrors the source, never to edit it. |
| Prose duplication across fifteen files drifts, producing exactly the per-extension divergence item 4 warns against | M | H | One canonical block in `general-implementation-agent.md` (Phase 2); the other fourteen carry a short pointer plus the flag, following the cross-reference convention these files already use for the 4D-ii / 4D-iii protocols. Phase 5 audits uniformity mechanically. |
| Task-number leakage into `agent-system/**` deliverables | M | M | The canonical block and every pointer must cite **durable anchors only** (file names, section headings, `{N}` as a template placeholder). No "see task NNN" text in any `agent-system/**` file. Phase 5 runs `check-task-references.sh`. |
| A prose-only self-check gets skipped by a future dispatch under context pressure — the same failure class that let the original defect exist | M | H | Accepted, named residual risk, and the whole reason the mechanical chokepoint is the priority follow-up. The in-file text states explicitly that it is interim, not a claimed permanent fix. |
| Line/token budget validators reject the enlarged agent definitions | M | M | Keep the canonical block tight and the fourteen pointers to 2-4 lines. Phase 6 runs the full gate; a budget failure is resolved by trimming prose, never by dropping a definition from the set. |
| Live `git-commit-scoped.sh` execution in Phase 1 touching the project repo's real history | H | L | Phase 1 operates **exclusively** in a throwaway git repository created under the session scratchpad, with its own synthetic `specs/state.json`. Never `cd` into the project repo for the experiment; never run the script with the project root as `PROJECT_ROOT`. |
| Sibling task editing two of the fifteen files concurrently (plan-revision-detection declares `general-implementation-agent.md` and `lean-implementation-agent.md`) | M | M | Known serialization contender, recorded visibly, no edge declared. Regions do not touch — that task works on plan-revision detection, this one on the commit recipe. Pass `--task 336` on this task's own commits so the lease arbitrates if both land in one cycle. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 2, 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 3 and 4 edit disjoint file sets and
are safe to run concurrently.

---

### Phase 1: Exercise the pre-fix regression case [COMPLETED]

**Goal**: Produce live, dated evidence that the observed commit's shape passes through the
pre-fix surface uncaught **even with `--task` supplied** — the claim the Acceptance criterion
requires be exercised rather than asserted — plus a mechanical run of the Containment predicate
over the observed ten-path list.

**Tasks**:
- [x] Create a throwaway git repository under the session scratchpad (never the project repo):
  `init` it, add a `specs/` directory, and write a synthetic `specs/state.json` whose single
  active project declares exactly ONE path in `file_scope`, mirroring the observed shape.
  *(completed)*
- [x] Copy `agent-system/extensions/core/scripts/git-commit-scoped.sh` (and the one library it
  sources, if sourcing is required for standalone operation) into the throwaway repo so the real
  code under test is exercised, not a paraphrase. *(completed: also copied task-lock.sh,
  deploy-root-guard.sh, and task-lookup-lib.sh, the full dependency closure needed for standalone
  `--task` operation)*
- [x] Create ten files in the throwaway repo mirroring the observed commit's generated-file shape
  (one declared, nine undeclared), then invoke the copied script **with** `--task <synthetic-N>`
  and a message of the `task {N} phase {P}: {name}` shape, staging all ten. *(completed)*
- [x] Capture the full transcript plus `git show --stat` of the resulting commit. The expected
  result is that all ten land and exit status is 0 — no refusal, no warning about the nine.
  *(completed: exit 0, all ten landed, confirmed)*
- [x] Confirm the mechanism by inspecting the throwaway repo: `specs/.contention-manifest/` is
  absent or contains no entry for any of the ten paths, demonstrating the `uniq_tasks >= 2` gate
  is why the lease never fires. *(completed: manifest directory absent entirely)*
- [x] Hand-run the Containment predicate (exact match, or either side as directory/glob ancestor)
  over the observed ten-path list against the one-path declared scope, as a small shell loop.
  Expected: 1 contained, 9 uncontained — the exact decision the Phase 2 self-check will make.
  *(completed: 1 kept / 9 dropped, matching the hypothesis exactly)*
- [x] Write the transcripts, the `git show --stat` output, the manifest-absence observation, and
  the predicate run into
  `specs/336_phase_commit_staging_has_no_scope_check/evidence/01_pre-fix-regression.md`, dated,
  with the commands verbatim so a future reader can re-run them. *(completed)*
- [x] If the harness blocks live execution of the script for any reason, record that fact
  explicitly in the evidence file and fall back to the report's structural code trace, naming
  which branch was taken. Do **not** silently present a trace as a live run. *(completed: not
  blocked; live run executed, recorded as such in the evidence file's Harness note)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the ten observed paths comprise one path inside the declared scope and nine
outside it, and the predicate run is therefore expected to yield 1 kept / 9 dropped. Confirm by
reading the observed path list and the declared single path out of the evidence the task
description carries, rather than assuming the 1/9 split; if the actual split differs, record the
real numbers and carry them forward into Phase 2's wording.

**Files to modify**:
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/01_pre-fix-regression.md` - new
  evidence file holding the live transcripts, the manifest-absence observation, and the
  Containment predicate run

**Verification**:
- The evidence file exists, is non-empty, and contains a verbatim command transcript plus a
  `git show --stat` listing.
- The transcript shows exit status 0 and all ten paths committed with `--task` supplied, or an
  explicitly recorded reason why the live run could not be performed.
- The predicate run's kept/dropped counts are stated as numbers, not prose approximations.
- No commit was created in the project repository by this phase: `git log --oneline -1` in the
  project repo is unchanged from the phase's start (other than this task's own postflight work).

---

### Phase 2: Author the canonical self-check and the ruling in the core definition [COMPLETED]

**Goal**: Land the ruled mechanism in full, once, in
`agent-system/extensions/core/agents/general-implementation-agent.md`: `--task {N}` on both of its
invocation sites, a named canonical pre-commit Containment self-check step, and the recorded
reasons — including the explicit concession about `--task` and the explicit treatment of the
mid-dispatch asymmetry.

**Tasks**:
- [x] Re-grep the file for `git-commit-scoped.sh` and separate genuine invocation sites from prose
  mentions. Plan-time observation: two invocation sites (the per-objective green-substep commit
  and the per-phase commit), with four further prose mentions that must NOT be edited as if they
  were recipes. *(completed: confirmed exactly 2 invocation sites and 4 prose mentions, matching
  the Scope Hypothesis)*
- [x] Add `--task {N} \` to both invocation sites, placed on its own continuation line alongside
  `--message` / `--session`, preserving each site's existing flags. *(completed)*
- [x] Author one canonical, named block — give it a stable heading such as
  `#### Phase-Commit Containment Self-Check` so the other fourteen definitions can point at it by
  name — containing: (a) the step itself, run immediately before the `git-commit-scoped.sh`
  invocation; (b) read the task's own declared `file_scope`; (c) apply the Containment predicate
  (exact match, or either side as a directory/glob ancestor) to each positive entry of the
  about-to-stage list; (d) for any uncontained entry, drop it from `stage_paths` for this commit,
  emit a loud named warning following the existing WARNING wording convention, and record it
  non-fatally via `issue-record.sh` with a scope-excursion class; (e) never refuse the whole
  commit over this. *(completed, with an added fail-open clause (e2) for a missing/malformed
  file_scope)*
- [x] Carve the task's own task-directory, `specs/TODO.md`, `specs/state.json`, and the plan path
  out of the predicate explicitly. These are unconditionally staged by the recipe and are never
  task deliverables, so testing them for containment would produce a guaranteed false positive on
  every single commit. State this carve-out in the block, not as an unstated assumption.
  *(completed)*
- [x] Record the reasons in the block, compactly: that the lease covers only paths two or more
  tasks declare and therefore does nothing for a path declared by none (so the flag addresses the
  contended-path case and explicitly not the undeclared-path case); that a phase commit runs
  mid-dispatch with no postflight in scope and no cycle-manifest guarantee, which is why the check
  is sited in the recipe rather than at a postflight or cycle-plan layer; and that this prose step
  is interim, with the mechanical in-script chokepoint named as the durable fix. *(completed)*
- [x] Verify the authored text cites durable anchors only — file names, section headings, `{N}` as
  a template placeholder — and contains no task-number reference of any kind. *(completed:
  check-task-references.sh reports 0 occurrences)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: two genuine invocation sites in this file (plan-time grep shows
`git-commit-scoped.sh` on six lines, of which four are prose references). Confirm by reading each
of the six occurrences in context before editing; edit only the lines that are a `bash
.claude/scripts/git-commit-scoped.sh \` invocation head.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - add `--task {N}` to both
  invocation sites; add the canonical `Phase-Commit Containment Self-Check` block with its
  predicate, drop-and-warn semantics, carve-out list, and recorded reasons

**Verification**:
- `grep -c -- '--task' ` on the file returns at least 2, and every genuine invocation site carries
  the flag (confirmed by reading each site, not by the count alone).
- The canonical block exists under a stable heading, and names: the Containment predicate, the
  drop-and-warn failure mode, the carve-out list, and the `issue-record.sh` call.
- The block states both reasons explicitly: the undeclared-path concession and the mid-dispatch
  siting rationale.
- `bash .claude/scripts/check-task-references.sh` reports no new finding for this file.
- The four prose mentions are unchanged (diff review confirms only the intended hunks moved).

---

### Phase 3: Wire the four multi-site and domain-heavy definitions [NOT STARTED]

**Goal**: Bring the four definitions carrying more than one invocation site, or a domain-specific
recipe variant, into line with Phase 2's canonical block — uniformly, with no per-extension
divergence in the mechanism.

**Tasks**:
- [ ] For each file below: grep its `git-commit-scoped.sh` occurrences, separate invocations from
  prose, and add `--task {N} \` to every invocation, preserving existing flags.
- [ ] Add a 2-4 line pointer immediately before each invocation, directing the reader to the
  canonical self-check block by its heading name in the core definition — following the
  cross-reference convention these files already use for the core definition's other per-phase
  protocols, rather than restating the predicate.
- [ ] Where a file's recipe carries extra flags, keep them and place `--task {N}` consistently in
  the same position relative to `--message` / `--session` across all sites.
- [ ] Confirm no file in this phase gained any task-number reference.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: 9 invocation sites across these 4 files (plan-time grep: founder 5, lean
hard-mode 2, lean 1, cslib hard-mode 1). Confirm per file with a fresh grep before editing; if a
file's site count differs from this hypothesis, use the observed count and note the discrepancy in
the phase's progress notes.

**Files to modify**:
- `agent-system/extensions/founder/agents/founder-implement-agent.md` - `--task {N}` at each
  invocation site plus the canonical-block pointer
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - same
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - same
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - same

**Verification**:
- Every genuine invocation site in all four files carries `--task {N}`, confirmed by reading each
  site.
- Every invocation is preceded by a pointer naming the canonical block's heading.
- `bash .claude/scripts/check-task-references.sh` reports no new finding for these four files.
- Diff review shows only recipe-adjacent hunks changed; no domain content was disturbed.

---

### Phase 4: Wire the ten single-site definitions [NOT STARTED]

**Goal**: Apply the identical edit to the remaining ten definitions, completing uniform coverage
of all fifteen.

**Tasks**:
- [ ] For each file below: grep its `git-commit-scoped.sh` occurrence, confirm it is a genuine
  invocation, and add `--task {N} \` preserving existing flags. Note that at least one of these
  already carries `--honest-index-rows {N}` — keep it and add `--task {N}` alongside, do not
  replace it.
- [ ] Add the same 2-4 line pointer to the canonical block before each invocation, with wording
  identical across all ten so the set does not drift.
- [ ] Confirm no file in this phase gained any task-number reference.

**Timing**: 1.0 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: exactly one invocation site per file, 10 sites total across these 10 files
(plan-time grep). Confirm per file with a fresh grep; a file showing more than one occurrence must
be read in context before any edit, since the extra occurrence may be prose.

**Files to modify**:
- `agent-system/extensions/books/agents/books-implementation-agent.md` - `--task {N}` plus the
  canonical-block pointer
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - same
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` - same
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` - same
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` - same
- `agent-system/extensions/python/agents/python-implementation-agent.md` - same
- `agent-system/extensions/rust/agents/rust-implementation-agent.md` - same
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` - same
- `agent-system/extensions/web/agents/web-implementation-agent.md` - same
- `agent-system/extensions/z3/agents/z3-implementation-agent.md` - same (retain its existing
  `--honest-index-rows {N}`)

**Verification**:
- All ten files carry `--task {N}` at their invocation site, confirmed by reading each site.
- All ten pointers are textually identical; a diff of the ten pointer hunks against each other
  shows only the surrounding-context difference.
- The pre-existing `--honest-index-rows {N}` flag survives wherever it was present.
- `bash .claude/scripts/check-task-references.sh` reports no new finding for these ten files.

---

### Phase 5: Uniformity audit and follow-up record [NOT STARTED]

**Goal**: Prove mechanically that what landed is uniform across all fifteen definitions, and
record the `git-commit-scoped.sh` mechanical chokepoint as a constrained follow-up with its
coordination constraints — without touching that script.

**Tasks**:
- [ ] Run a single audit loop over all fifteen `file_scope` entries printing, per file: the count
  of `git-commit-scoped.sh` occurrences, the count of `--task` occurrences, and whether the
  canonical-block pointer (or, for the core definition, the block itself) is present. Capture the
  output verbatim.
- [ ] Assert the audit's invariant: for every file, `--task` count is at least its genuine
  invocation-site count, and the pointer-or-block check passes. Any file failing either is a
  defect to fix in this phase, not a subset to justify — the ruling is uniform.
- [ ] Record the per-file audit table in
  `specs/336_phase_commit_staging_has_no_scope_check/evidence/02_uniformity-audit.md`.
- [ ] Write the follow-up specification to
  `specs/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md`,
  stating: the mechanism (a Containment check inside `git-commit-scoped.sh`, reading the named
  task's own `file_scope` directly from `specs/state.json`, independent of the cycle contention
  manifest, either as new behavior on the existing `--task` flag or a distinct opt-in flag); why
  it is the durable fix (a chokepoint inside the one script every definition calls cannot be
  forgotten by the sixteenth definition someone adds, whereas recipe prose can); the required
  fail-open posture (a missing, malformed, or unreadable `file_scope`, or any internal error,
  proceeds exactly as today — a scope guard must never be the sole reason a commit cannot
  happen); the exit-code requirement (a new or deliberately reused code, distinct from the
  existing contended-path refusal code, since Containment is a different predicate from
  lease contention) and the hard constraint that this must be coordinated with the task that owns
  that script's exit-code contract, whose description is to be read before any code is proposed;
  and the rider that the "Phase Commit (mid-dispatch)" subsection recommended for
  `git-staging-scope.md` lands with that follow-up, not here.
- [ ] State in the follow-up record that it is a specification awaiting filing via `/task`, and
  that this task does not file it — so a future reader does not assume a task number exists.
- [ ] Re-read the Non-Goals list and confirm no phase of this plan modified
  `scripts/git-commit-scoped.sh`, its source-store original, any `context/standards/*.md` file, or
  anything under `.claude/**`: `git status --short` must show changes only under
  `agent-system/extensions/**` (the fifteen files) and `specs/336_*/`.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4

**Verification Tier**: interface

**Scope Hypothesis**: 21 genuine invocation sites across the fifteen files in total (2 + 9 + 10
from Phases 2-4). Confirm against the audit loop's own output rather than this estimate; the audit
output is authoritative and the number here is a hypothesis to be overwritten by it.

**Files to modify**:
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/02_uniformity-audit.md` - new, the
  per-file audit table and its invariant assertion
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md` -
  new, the constrained follow-up specification

**Verification**:
- The audit table covers exactly fifteen files, with no file missing and none added.
- The invariant holds for all fifteen, or the phase is not complete.
- The follow-up record names the mechanism, the fail-open posture, the exit-code requirement, and
  the coordination constraint, and states that filing is not done here.
- `git status --short` shows no modification to `git-commit-scoped.sh` (either copy), to any
  `context/standards/*.md` file, or to anything under `.claude/**`.

---

### Phase 6: Final verification gate [NOT STARTED]

**Goal**: Run the repository's complete gate set and confirm the fifteen enlarged definitions pass
wiring, index, and budget validation.

**Tasks**:
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and record the result. This is the full gate set
  for this repository; a hand-picked subset of validators does not satisfy this tier.
- [ ] If a context-budget validator rejects an enlarged definition, resolve it by trimming the
  added prose (shorten the pointer, tighten the canonical block) — never by dropping a definition
  from the set, which would reintroduce the per-extension divergence the ruling forbids.
- [ ] Run `bash .claude/scripts/check-task-references.sh` repository-wide and confirm zero new
  findings outside `specs/**`.
- [ ] Confirm the deploy boundary held: the fifteen edits exist in `agent-system/extensions/**`.
  Any divergence in the deployed `.claude/**` mirror is expected until the next deploy and must
  not be hand-patched.
- [ ] Record the gate output in the implementation summary.

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: fifteen source-store files are expected to show as modified by this task at
gate time. Confirm against `git status --short` filtered to `agent-system/extensions/**` rather
than asserting the count; a count below fifteen means Phase 3 or 4 is incomplete and the
partial-uniformity contingency applies.

**Files to modify**:
- none planned; this phase runs gates and records their output in the task's summary

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits clean, with its output recorded.
- `bash .claude/scripts/check-task-references.sh` reports zero new findings outside `specs/**`.
- All fifteen `file_scope` entries show as modified in the source store, and no file under
  `.claude/**` was hand-edited.

## Testing & Validation

- [ ] Pre-fix regression case is exercised live (or its blocked-execution fallback explicitly
  recorded), with transcripts and a `git show --stat` listing, in
  `evidence/01_pre-fix-regression.md`.
- [ ] The regression evidence demonstrates specifically that `--task` supplied does **not** refuse
  the undeclared paths — the Acceptance criterion's load-bearing claim.
- [ ] The Containment predicate run reports concrete kept/dropped counts over the observed path
  list.
- [ ] All fifteen definitions carry `--task {N}` at every genuine invocation site.
- [ ] All fifteen carry the canonical self-check block or a pointer to it, with identical pointer
  wording across the fourteen.
- [ ] The canonical block states the undeclared-path concession and the mid-dispatch siting
  rationale explicitly.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes.
- [ ] `bash .claude/scripts/check-task-references.sh` shows zero new findings outside `specs/**`.
- [ ] `git status --short` confirms no out-of-scope file was touched — in particular not
  `git-commit-scoped.sh`, not any `context/standards/*.md`, and nothing under `.claude/**`.

## Artifacts & Outputs

- `specs/336_phase_commit_staging_has_no_scope_check/plans/01_phase-commit-containment-self-check.md`
  (this plan)
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/01_pre-fix-regression.md`
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/02_uniformity-audit.md`
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md`
- `specs/336_phase_commit_staging_has_no_scope_check/summaries/01_*-summary.md` (written at
  implement postflight)
- Fifteen modified agent definitions under `agent-system/extensions/**`, enumerated in Phases 2-4

## Rollback/Contingency

All fifteen edits are additive, prose-level, and confined to markdown agent definitions with no
compile or elaboration surface — a per-file revert is always available and never leaves a
half-applied mechanism, because each file's edit is self-contained (flag plus pointer).

- **Per-phase**: each phase commits per green sub-step, so reverting a single phase means
  reverting its own commits. No cross-phase coupling requires a wider rollback.
- **Whole-task**: if the ruling itself must be withdrawn, revert the Phase 2-4 commits in reverse
  order. The evidence files under `specs/336_*/evidence/` are records, not mechanism, and should
  be kept even on a mechanism rollback — the pre-fix regression evidence remains valid.
- **Before any rollback that would discard uncommitted work**: take a durable checkpoint first per
  `context/contracts/recovery.md`'s rollback rung, using the invocation shape documented there
  (including its out-of-scope override flag for the deliberate whole-tree case). Do not improvise
  a destructive git command on a dirty tree.
- **Partial-uniformity contingency**: if Phase 3 or 4 cannot complete for some files, the task is
  `[PARTIAL]`, not complete-with-a-subset. A subset landing is the per-extension divergence the
  ruling explicitly forbids; either finish the set or revert to a uniform state (all fifteen
  unchanged) and record the blocker.
