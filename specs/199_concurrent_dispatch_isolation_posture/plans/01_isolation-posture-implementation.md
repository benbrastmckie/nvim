# Implementation Plan: Task #199

- **Task**: 199 - Decide and implement the working-tree and build isolation posture for concurrent same-repo dispatches
- **Status**: [NOT STARTED]
- **Effort**: 16.5 hours
- **Dependencies**: 191, 192, 193, 213, 242, 243, 259, 266 (all coordinated-with, none re-decided)
- **Research Inputs**: specs/199_concurrent_dispatch_isolation_posture/reports/01_isolation-posture-recommendation.md
- **Artifacts**: plans/01_isolation-posture-implementation.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/standards/shell-strict-mode.md
  - .claude/context/standards/shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase already returned the decision this task was chartered to make: a **split
verdict** — per-dispatch git-worktree isolation for lean4/cslib **implement** dispatches, and the
shared tree plus a narrow contended-path commit refusal (Option 3(ii)) for general/meta/markdown
dispatches, with hunk-level staging (Option 3(i)) ruled out as infeasible. This plan implements
that verdict and records it. The edit target is the **source store**
(`agent-system/extensions/core/`, `agent-system/extensions/lean/`) — never `.claude/**`, which is
a gitignored deploy artifact. Done means: the decision record exists with all three failure modes
scored; the worktree provisioning/merge-back machinery exists, is wired into the dispatch and
postflight sites, and is covered by its own test suite; the contended-path refusal exists in
`git-commit-scoped.sh`; the mutex's opt-in nature and the mode-1b staging qualification are
documented where an agent reads them; a fixture reproduces the observed two-dispatch batch shape
and demonstrates that cross-task commit bleed no longer occurs; and the change is redeployed and
confirmed live in a consumer repo.

### Research Integration

Findings from `reports/01_isolation-posture-recommendation.md` that shape this plan:

- **The decision is made, not re-opened.** The scoring table (every option against modes 1a/1b/2)
  and the split verdict are inputs here; Phase 2 transcribes them into the durable decision
  record rather than re-deriving them.
- **Cost measurements already taken**: `.lake` is 16 GiB against 27 GiB free in the reference
  consumer repo; `git worktree add` costs 0.089 s; a hardlink clone (`cp -al .lake`) reproduces
  the 15 GiB tree in 0.827 s with **zero measured disk growth**. The disk objection is therefore
  real but mitigable — conditional on one unverified assumption (below).
- **One load-bearing assumption remains unverified**: that Lake writes build outputs via atomic
  temp+rename, which is what makes hardlink sharing safe. Phase 1 gates the whole design on
  verifying it, with the already-proven `lake exe cache get` population path (precedent:
  `lean/scripts/lean-comparator-run.sh`) as the documented fallback.
- **Option 3(i) is ruled out**: no hunk/line-to-task attribution mechanism exists anywhere in the
  codebase; building one costs more than worktree isolation and solves less.
- **The build mutex is not missing** — `lake-build-guard.sh` already implements a correct
  flock-based mutex. The defect is that it is **opt-in** and any bare `lake` bypasses it. This
  plan documents that (WORK (d)(i)) and does not touch the mutex itself. The PATH-shim wrapper
  the research names as the system-level answer to unguarded callers is explicitly a **follow-up,
  not built here**.
- **Prior art to reuse, not reinvent**: `lean-comparator-run.sh`'s worktree lifecycle (add,
  populate `.lake` before any build, `worktree remove --force` on cleanup) and
  `specs/.commit-lock/` / `task-lock.sh`'s lease-with-staleness-override lock pattern.

Two design facts established during this planning pass, beyond the research report:

1. **`.claude/` is gitignored in both the reference consumer repo and this one**
   (`.gitignore:6` here, `.gitignore:106` there), so a fresh `git worktree add` produces a tree
   with **no `.claude/` at all** — no deployed scripts for the dispatched agent to call. The
   worktree must therefore have `.claude/` materialized into it. A **symlink will not work**:
   `deploy-root-guard.sh` and `common_repo_root` resolve `SCRIPT_DIR` with
   `cd "$(dirname ...)" && pwd`, which follows a symlink back to the main tree and makes
   `PROJECT_ROOT` the *main* tree — silently defeating the isolation. A hardlink clone
   (`cp -al .claude`) keeps the physical path inside the worktree and still passes the guard's
   `*/.claude | */.opencode` structural check.
2. **`specs/` IS tracked**, so a worktree carries a HEAD-stale copy of `specs/state.json`,
   `specs/TODO.md` and every task directory. Task artifacts must continue to be written to the
   **main tree** by the absolute paths the dispatch file already names (which composes cleanly
   with the existing Postflight Boundary single-writer contract), and the merge-back step must
   **refuse** a branch that touched `specs/**` rather than merging a stale snapshot over live
   state.

Consequence of (1) and (2) together: this plan provisions the worktree from a **script**
(`dispatch-worktree.sh`) named in the dispatch file, and deliberately does **not** depend on the
harness `Agent(isolation: "worktree")` parameter. That parameter would relocate the agent's whole
repo copy opaquely — including `specs/`, whose absolute main-tree paths the dispatch file and the
handoff contract both depend on — and wiring it would require editing
`skills/skill-orchestrate/SKILL.md`, which a sibling task holds this cycle. The script-provisioned
route is both safer for `specs/**` and free of that footprint collision. Record this as a
deliberate divergence from the research report's design guidance item A.1, not an oversight.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:

- Record the split verdict as a durable decision record scoring **every** option against **all
  three** failure modes (1a working-tree revert, 1b cross-task commit bleed, 2 build contention),
  including the cold-build/hardlink measurements and the hunk-attribution infeasibility finding
  that informed it.
- Provide `dispatch-worktree.sh`: provision, locate, merge back (land), and release a
  per-dispatch git worktree, with a free-space preflight, a `.claude/` hardlink materialization
  step, and a hard refusal to land a branch that touched `specs/**`.
- Select worktree isolation mechanically for `implement`-phase dispatches of lean4/cslib task
  types, and render the isolated working-tree contract into the dispatch file the agent reads.
- Land an isolated dispatch's branch from the main tree at postflight, surfacing a genuine
  same-line collision as an explicit git conflict instead of mode 1b's silent bleed.
- Give general/meta/markdown dispatches Option 3(ii): a machine-derived contended-path manifest
  and a first-claim lease that makes `git-commit-scoped.sh` refuse to stage a path a live sibling
  is concurrently contending for.
- Document the build mutex's opt-in nature and its bypass hazard where an agent will read it, and
  qualify the rules that currently present targeted staging as the concurrency remedy.
- Prove the fix with a fixture reproducing the observed batch shape: two concurrent lean4
  implement dispatches in one repo, both editing one shared markdown file, one of them invoking
  an unguarded `lake`.

**Non-Goals**:

- Option 3(i), hunk-level staging or per-hunk attribution — ruled out by research; not attempted.
- A PATH-shim `lake` wrapper to make unguarded callers participate in the mutex — named as the
  system-level answer, deferred as a follow-up with its own feasibility question.
- Any change to `core/scripts/git-snapshot.sh`, `core/rules/git-workflow.md`, the plan format, or
  `hooks/guard-destructive-git.sh`; any re-decision of the over-staging predicate.
- Blocking explicit multi-file path staging — it remains the sanctioned form, unchanged.
- Implementing the territory payload (already landed elsewhere) or serializing the batch
  (concurrency is the design; isolation removes the shared resource instead).
- Editing any project-local script in the reference consumer repo, and any retroactive repair of
  the commit that carries the bled rows.
- Removing, weakening, or rewiring the existing flock mutex in `lake-build-guard.sh` under any
  option.
- Declaration-granularity changes to `file_scope` (owned by the file-scope-lifecycle tasks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Lake does not write build outputs via atomic temp+rename, so a hardlink-shared `.lake` corrupts a sibling's inode | H | M | Phase 1 verifies empirically (inode divergence test) **before** any wiring; documented fallback is `lake exe cache get` population at full disk cost plus a concurrency cap |
| Disk exhaustion when several isolated worktrees diverge fully from the shared `.lake` baseline | H | M | Free-space preflight in `provision` with a conservative floor; hard cap on simultaneous isolated worktrees; refuse-and-defer (never silently proceed) when the floor is breached |
| A symlinked `.claude/` in the worktree makes `PROJECT_ROOT` resolve to the main tree, silently defeating isolation | H | M | Hardlink clone only (`cp -al`), never a symlink; Phase 1 verifies `PROJECT_ROOT` resolves inside the worktree; Phase 4 asserts it in the test suite |
| An agent writes `specs/**` inside the worktree; landing the branch overwrites live state with a HEAD-stale snapshot | H | M | `land` refuses outright on any `specs/**` path in the branch diff, naming every offending path; dispatch file states the artifact-paths-are-main-tree rule explicitly |
| Merge-back hits a genuine same-line conflict | M | H | By design: surface it as an explicit, named git conflict with the branch and worktree preserved for resolution. Never auto-resolve, never `-X ours/theirs`. This is the honest cost of the chosen option and is strictly better than silent bleed |
| The new contended-path refusal blocks legitimate commits and leaves agents with no compliant way to commit | H | M | Fail **open** on any unreadable/absent/malformed manifest; lease carries an age-based staleness override (the `specs/.commit-lock/` pattern); refusal names the contending task and the release condition; explicit multi-file path staging stays permitted |
| `orchestrate-cycle-plan.sh` footprint collides with sibling tasks editing the same file | M | H | Re-read the file immediately before each edit; keep both edits to this file in separate, serialized phases (6 then 8); the file-footprint admission gate serializes the overlapping tasks; whichever lands last reconciles the header contract |
| Worktree provisioning failure silently degrades to a shared-tree dispatch, reintroducing the hazard the task exists to remove | H | M | Provision failure **defers** the dispatch (existing `out_deferred_rows` convention) rather than falling through to the shared tree; the fallback is loud and recorded |
| Stale worktrees and branches accumulate across runs | M | M | `release` in postflight on every outcome; a `prune` verb reaping worktrees whose recorded session is no longer live, built on the same lease-staleness pattern |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1 |
| 3 | 5, 6 | 4 |
| 4 | 7, 8 | 5, 6 |
| 5 | 9 | 8 |
| 6 | 10 | 7, 9 |
| 7 | 11 | 10 |

Phases within the same wave can execute in parallel.

### Phase 1: Verify the load-bearing preconditions [NOT STARTED]

**Goal**: Settle the three unverified facts the rest of the design rests on, and pick the `.lake`
population strategy from evidence rather than assumption.

**Tasks**:
- [ ] Verify Lake's write pattern in the reference consumer repo (`~/Projects/BimodalLogic`):
      hardlink-clone `.lake` to a scratch path (`cp -al`), record the inode of one module's
      `.olean`, touch that module's `.lean` source in a worktree using the clone, run a guarded
      build of that module only (`lake-build-guard.sh build --timeout 1800 -- build <Module>`),
      then compare inode numbers. Divergence = atomic rename confirmed (hardlink strategy is
      safe); same inode with changed content = the assumption is FALSE.
- [ ] Record the verdict and choose: hardlink clone (`cp -al`) if confirmed, otherwise
      `lake exe cache get` population plus a disk-sized concurrency cap.
- [ ] Verify the `.claude/` fact: `git worktree add` a scratch worktree of this repo, confirm no
      `.claude/` is present, `cp -al` the main tree's `.claude/` into it, then confirm a deployed
      script run from inside the worktree resolves `PROJECT_ROOT` to the **worktree** root and
      passes `deploy-root-guard.sh`. Confirm a symlinked `.claude/` does the opposite.
- [ ] Verify the `specs/` fact: confirm the scratch worktree carries a tracked, HEAD-stale
      `specs/state.json`, and that `.claude/`-relative ephemeral runtime paths
      (`specs/.commit-lock/`, `specs/.scope-lock/`) are absent there.
- [ ] Measure free-space headroom and pick the concrete preflight floor and worktree cap values
      Phase 4 will encode.
- [ ] Remove every scratch worktree and clone (`git worktree remove --force`, `rm -rf` the
      clone) and confirm `git worktree list` is clean.
- [ ] Record all findings in this plan file under this phase (they are Phase 2's inputs and the
      summary's evidence).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Verification**:
- Every one of the four facts has a recorded yes/no verdict with the command output that produced
  it — no "assumed" entries.
- The chosen `.lake` population strategy and the two numeric values (free-space floor, worktree
  cap) are written down.
- `git worktree list` shows no leftover scratch worktrees in either repo.

---

### Phase 2: Record the decision [NOT STARTED]

**Goal**: WORK item (b) — the durable, evidence-backed decision record, scoring every option
against all three failure modes.

**Tasks**:
- [ ] Add a new `## Working-Tree and Build Isolation Posture` section to
      `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`,
      positioned with the other decision-bearing sections (near `## Open Design Fork — RESOLVED`).
- [ ] State the three failure modes by mechanism (working-tree revert; cross-task commit bleed;
      build contention) without citing task numbers — durable anchors only, per the deliverable
      rule.
- [ ] Transcribe the scoring table: each of Option 1, Option 2, Option 3(i), Option 3(ii) against
      modes 1a, 1b, 2, plus cost and concurrency effect. Score honestly: an option that fixes one
      mode and leaves two open says so.
- [ ] Record why explicit-path staging cannot address mode 1b (path granularity is the file;
      staging cannot subdivide a file by author) and that this does **not** overturn the
      over-staging predicate — the sanctioned explicit multi-file list remains permitted and
      remains sufficient against over-broad staging.
- [ ] Record the split verdict and its **selection predicate**: `phase == implement` AND task type
      in the lean4/cslib family selects worktree isolation; every other dispatch keeps the shared
      tree plus contended-path refusal.
- [ ] Record the measurements from Phase 1 and the research report (worktree-add cost, hardlink
      cost and zero disk growth, `.lake` size vs. free space, the Lake write-pattern verdict) and
      the hunk-attribution infeasibility finding.
- [ ] Record the two deliberate divergences: the script-provisioned worktree instead of the
      harness `isolation` parameter (with the `specs/**` and `.claude/` reasons), and the
      PATH-shim `lake` wrapper deferred as a follow-up.
- [ ] Cross-reference the new section from `## Related Documents`.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - new decision
  record section plus a `## Related Documents` cross-reference

**Verification**:
- `grep -n '1a\|1b\|mode 2' ` over the new section shows all three modes named explicitly in the
  scoring table.
- The scoring table has a row per option (4 rows) and a column per mode (3 columns).
- `bash .claude/scripts/check-task-references.sh` reports no new findings (no task numbers in a
  deliverable outside `specs/**`).
- The selection predicate is stated once, in one place, in terms a script can implement.

---

### Phase 3: Document the mutex opt-in and the staging qualification [NOT STARTED]

**Goal**: WORK items (d)(i) and (d)(ii) — put both hazards where an agent will actually read them.

**Tasks**:
- [ ] In `agent-system/extensions/lean/rules/lean4.md`'s `## Build Commands` section, add the
      opt-in statement: the guard implements a real flock mutex, but participation is **opt-in** —
      any process invoking bare `lake` (including a project-local script the agent system does not
      own and cannot edit) bypasses the lock entirely and can collide with a guarded build. State
      the consequence plainly (a lost build, not a corrupted one) and the agent-side obligation
      (route every `lake` invocation through the guard; treat an unexplained build failure during
      concurrent work as possible contention).
- [ ] Add the same fact to `lake-build-guard.sh`'s header as a short cross-reference under its
      existing "WHAT THIS DELIBERATELY DOES NOT DO" block — a pointer to the decision record and
      the bypass hazard only. Do **not** change the participation contract, the allowlist, or any
      mutex behavior.
- [ ] Add the mode-1b qualification to
      `agent-system/extensions/core/context/standards/git-staging-scope.md`'s per-operation scope
      section: targeted explicit-path staging is **necessary but not sufficient** under
      concurrency, because path granularity is the file and two dispatches editing one file bleed
      into each other's commits however carefully each stages. Point at the decision record for
      the posture that does address it. Do **not** write this into `rules/git-workflow.md`, which
      another task owns; note in the text that the two documents are cross-referenced.
- [ ] Sanity-check every claim against the guard's actual source before writing it (the mutex,
      lock-wait exit 75, abandoned-lock recovery, result sharing, audible degradation when `flock`
      is absent) so the documentation cannot overstate or understate what exists.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/rules/lean4.md` - opt-in/bypass note in the build section
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - header cross-reference only (no
  behavior change)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - mode-1b qualification
  (footprint addition beyond the declared `file_scope`; recorded deliberately — see
  Artifacts & Outputs)

**Scope Hypothesis**: this phase asserts exactly three files carry the two documentation
obligations. Confirm at implementation time by grepping for every place that presents targeted
staging as the concurrency remedy (`grep -rn 'concurrent' agent-system/extensions/core/context
agent-system/extensions/core/rules`) and every place that documents guarded builds
(`grep -rln 'lake-build-guard' agent-system/extensions`); if a fourth location presents either
claim, add it here rather than silently leaving it stale.

**Verification**:
- `shellcheck` clean on `lake-build-guard.sh` (comment-only change, so this must stay clean).
- `git diff` on `lake-build-guard.sh` shows comment lines only — zero executable-line changes.
- `bash .claude/scripts/tests/test-lake-build-guard.sh` still passes.
- `bash .claude/scripts/check-task-references.sh` reports no new findings.

---

### Phase 4: `dispatch-worktree.sh` — provision, path, release [NOT STARTED]

**Goal**: The worktree lifecycle's creation side, as a standalone, independently testable script.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/dispatch-worktree.sh` with `set -euo pipefail`,
      the standard `SCRIPT_DIR`/`common_repo_root`/`deploy-root-guard.sh` preamble, and a `--help`
      usage block documenting every verb, exit code, and the runtime paths it owns.
- [ ] `provision <task_number> --session <sid> --seq <n>`: free-space preflight against the floor
      chosen in Phase 1 (refuse, loudly, rather than proceed); `git worktree add -b
      orchestrate/task-<N>-<seq> <root>/.orchestrate-worktrees/<N>-<seq> HEAD`; hardlink-clone
      `.claude/` into the worktree (`cp -al`, never a symlink — record why in a comment);
      populate `.lake` by the Phase 1-chosen strategy when the main tree has one; write a
      provisioning record (task, session, seq, branch, path, created_at) for `prune`; emit the
      worktree path on stdout as JSON.
- [ ] `path <task_number>`: resolve an existing worktree path from the record; empty output and a
      distinct exit code when none exists.
- [ ] `release <task_number> [--force]`: `git worktree remove` (with `--force` only when asked),
      remove the record, leave the branch intact for later inspection.
- [ ] `prune --session <sid>`: reap worktrees whose recorded session is no longer live, using the
      age-based staleness pattern from `specs/.commit-lock/`/`task-lock.sh` rather than a new lock
      primitive.
- [ ] Assert, inside `provision`, that a script run from the new worktree's `.claude/scripts/`
      resolves `PROJECT_ROOT` to the worktree root; refuse the provision if it does not.
- [ ] Register `.orchestrate-worktrees/` and the provisioning-record path in
      `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`'s
      ephemeral/durable classification, and add them to `.gitignore` if not already covered.
- [ ] Write `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` covering: a
      clean provision; the free-space refusal; `.claude/` present and physically inside the
      worktree; `PROJECT_ROOT` resolution; `path` hit and miss; `release` leaving no worktree and
      no record; `prune` reaping a stale record and sparing a live one; idempotent re-provision.
- [ ] `chmod +x` both new scripts (the test runner reports a lost exec bit as a loud SKIP).

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/dispatch-worktree.sh` - new
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` - new
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - register the
  new ephemeral runtime paths
- `.gitignore` - ignore `.orchestrate-worktrees/` if not already covered

**Scope Hypothesis**: this phase asserts four files (two new, two edited) and roughly a
400-line script. Confirm at implementation time: check whether
`orchestrator-runtime-files.md` already has a class the new paths fall under (it may need no edit
at all), and whether `.gitignore` already covers the path by an existing rule.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` passes, every case.
- `shellcheck` clean on both new scripts per `context/standards/shell-strict-mode.md`.
- `bash .claude/scripts/dispatch-worktree.sh --help` prints every verb and exit code.
- After the suite runs, `git worktree list` shows no leftovers and no stray `orchestrate/task-*`
  branches from test fixtures.

---

### Phase 5: `dispatch-worktree.sh` — land (merge-back) [NOT STARTED]

**Goal**: Land an isolated dispatch's work into the main tree as an ordinary git merge, with the
`specs/**` refusal that keeps live state safe from a HEAD-stale snapshot.

**Tasks**:
- [ ] Add `land <task_number> --session <sid>`: run from the **main tree**; diff the dispatch
      branch against its merge base and **refuse** (distinct exit code, every offending path
      named) if any path is under `specs/**`; otherwise `git merge --no-ff` the branch.
- [ ] On a merge conflict: abort the merge, preserve both the branch and the worktree, emit a
      machine-readable conflict verdict naming every conflicted path, and exit with a distinct
      code. Never auto-resolve and never pass `-X ours`/`-X theirs`.
- [ ] Refuse to land when the main tree has uncommitted modifications to any path the branch
      touches — surface it rather than merging over in-flight work.
- [ ] Emit a JSON verdict on stdout for every outcome (`landed`, `nothing_to_land`,
      `refused_specs_paths`, `conflict`, `refused_dirty_overlap`, `unavailable`) so the postflight
      caller branches on data, not on parsed prose.
- [ ] Keep every diagnostic on stderr and the verdict alone on stdout, per the JSON-channel
      discipline the lint enforces.
- [ ] Extend `test-dispatch-worktree.sh`: a clean land; a `specs/**` refusal; an induced
      same-line conflict left unresolved with the branch intact; a dirty-overlap refusal; a
      nothing-to-land no-op; exit codes distinct for each.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/dispatch-worktree.sh` - the `land` verb
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` - land cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` passes.
- The induced-conflict case leaves the repo with no in-progress merge (`git merge --abort` ran),
  the branch present, and the worktree present.
- The `specs/**` refusal case leaves `specs/state.json` byte-identical to before the attempt.
- `shellcheck` clean; `bash .claude/scripts/tests/test-lint-json-channel-discipline.sh` passes.

---

### Phase 6: Dispatch-site wiring [NOT STARTED]

**Goal**: Select isolation mechanically at dispatch time and tell the agent, in its dispatch file,
exactly which tree it is working in and where its artifacts still go.

**Tasks**:
- [ ] **Re-read `orchestrate-cycle-plan.sh` immediately before editing** — sibling tasks are
      concurrently scoped to this same file.
- [ ] In `orchestrate-cycle-plan.sh`'s live dispatch-prep section, add the selection predicate:
      `phase == "implement"` AND the task's type is in the lean4/cslib family → isolated. Keep the
      predicate in one small helper so the decision record and the code state it once each.
- [ ] Call `dispatch-worktree.sh provision` for a selected task. On any failure, append to
      `out_deferred_rows` with a named reason — **never** fall through to a shared-tree dispatch.
- [ ] Extend the dispatch row from `{task, phase, agent, model, dispatch_file, force, focus}` with
      `isolation` (`"none"` or `"worktree"`) and `worktree_path` (`null` when not isolated), and
      update the row-shape documentation in the script header and in the `--dry-run` row builder
      so both renderings stay identical. `--dry-run` must provision nothing.
- [ ] Pass the worktree path to `orchestrate-build-dispatch.sh` via a new empty-value-skips-flag
      `--worktree <path>`, matching the convention every other flag there already uses.
- [ ] In `orchestrate-build-dispatch.sh`, render an `## Isolated Working Tree` section, gated on
      that flag, stating: every **source** edit and every `lake`/build invocation happens under
      the worktree path; task artifacts (`.return-meta.json`, the handoff, reports/plans/
      summaries) are written to the **absolute main-tree paths this same dispatch file already
      names**; nothing under the worktree's own `specs/` may be written or committed; commit
      source work on the dispatch branch inside the worktree as usual.
- [ ] Confirm the row change is additive for existing consumers: `skill-orchestrate/SKILL.md`'s
      Move 2 reads named fields only and needs no edit — verify by reading it, and record that
      conclusion in the script header rather than editing the skill.
- [ ] Extend `test-orchestrate-cycle-plan.sh` (predicate true/false, row fields, deferral on
      provision failure, `--dry-run` provisions nothing) and
      `test-orchestrate-build-dispatch.sh` (section present with the flag, absent without it,
      byte-identical output when the flag is omitted).

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - selection predicate,
  provision call, row fields, `--worktree` pass-through
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - `--worktree` flag and the
  `## Isolated Working Tree` section
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - predicate and row
  cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - section cases

**Scope Hypothesis**: this phase asserts that the dispatch row's consumers are exactly
`skill-orchestrate/SKILL.md`'s Move 2/Move 3 and `orchestrate-cycle-postflight.sh`, so adding two
fields breaks nothing. Confirm at implementation time with
`grep -rn 'dispatch\[\]\|\.dispatch_file\|jq -r .task' agent-system/extensions/core` and read every
hit before editing; if a third consumer parses the row positionally, adapt this phase rather than
assuming additivity.

**Verification**:
- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run ...` emits the two new row fields and
  creates no worktree (`git worktree list` unchanged).
- A live non-lean dispatch's dispatch file is **byte-identical** to one built before this phase.
- Both extended test suites pass; `shellcheck` clean on both scripts.
- `bash .claude/scripts/tests/test-lint-deploy-caller-wrap.sh` still passes (the self-overwrite
  wrap structure in `orchestrate-cycle-plan.sh` must be preserved — do not move logic to top level).

---

### Phase 7: Postflight land and release wiring [NOT STARTED]

**Goal**: Land and clean up an isolated dispatch from the main tree, at the one place the
Postflight Boundary already puts main-tree writes.

**Tasks**:
- [ ] In `orchestrate-cycle-postflight.sh`, for a `dispatch[]` row with `isolation == "worktree"`,
      call `dispatch-worktree.sh land` **after** the agent's return is read and **before** the
      task's status transition, and branch on the JSON verdict.
- [ ] Map each verdict to an outcome: `landed`/`nothing_to_land` → continue as today;
      `conflict`/`refused_specs_paths`/`refused_dirty_overlap` → record the task as needing human
      resolution with the offending paths verbatim in the reason, preserve branch and worktree,
      and do **not** claim the phase landed.
- [ ] Call `release` only on a clean land; preserve the worktree on any refusal or conflict so the
      work is recoverable.
- [ ] Call `prune` once per cycle for the current session so a crashed run's worktrees are reaped
      on the next invocation.
- [ ] Extend `test-orchestrate-cycle-postflight.sh`: clean-land path, conflict path (status not
      advanced, worktree preserved, reason carries the conflicted paths), `specs/**` refusal path,
      and a non-isolated row taking a byte-identical path to today.

**Timing**: 1 hour

**Depends on**: 5, 6

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - land/release/prune
  wiring (footprint addition beyond the declared `file_scope`; recorded deliberately)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - the four
  cases above

**Verification**:
- Extended suite passes; a non-isolated row's postflight behavior is unchanged.
- The conflict case leaves the task's status un-advanced and the worktree present.
- `bash .claude/scripts/tests/test-lint-postflight-boundary.sh` passes — postflight still writes
  no source and remains the sole writer of the shared state files.
- `shellcheck` clean.

---

### Phase 8: Contended-path manifest producer [NOT STARTED]

**Goal**: Derive, mechanically, the set of paths two or more concurrently dispatched tasks are
contending for — no agent cooperation, using data the dispatch pipeline already computes.

**Tasks**:
- [ ] **Re-read `orchestrate-cycle-plan.sh` immediately before editing** (same-file sibling
      hazard, and Phase 6 has already touched it).
- [ ] Reuse the sibling-territory computation already in the script: a path is *contended* for
      this cycle when it appears in the declared `file_scope` of two or more tasks dispatched this
      same cycle. A directory/glob entry contends with any path beneath it.
- [ ] Write a cycle-scoped manifest (`{session_id, cycle, generated_at, contended: [{path,
      tasks:[...], granularity}]}`) to an ephemeral runtime path under `specs/`, following the
      existing `specs/.commit-lock/`/`specs/.scope-lock/` naming convention; overwrite per cycle.
- [ ] Skip the manifest entirely for a single-task cycle and for `--dry-run` — byte-identical
      behavior to today in both cases.
- [ ] Exclude paths belonging to a task dispatched with `isolation == "worktree"`: it has no
      shared working copy to contend over, so listing it would produce a false refusal.
- [ ] Register the manifest path in `orchestrator-runtime-files.md` and `.gitignore`.
- [ ] Extend `test-orchestrate-cycle-plan.sh`: two tasks sharing a path (contended); directory
      entry covering a sibling's file (contended); disjoint scopes (no manifest entry);
      single-task cycle (no manifest); isolated task excluded; `--dry-run` writes nothing.

**Timing**: 1.5 hours

**Depends on**: 5, 6

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - manifest producer
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - manifest cases
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - register the
  manifest path
- `.gitignore` - ignore the manifest path if not already covered

**Scope Hypothesis**: this phase asserts the existing sibling-territory computation already
carries every input the manifest needs (per-task `file_scope`, granularity, and the set of tasks
dispatched this cycle). Confirm by reading `build_sibling_territory` and its
`_sibling_territory_classify_entry` helper before writing the producer; if granularity or the
dispatched-task set is not available at that point, place the producer where it is rather than
duplicating the derivation.

**Verification**:
- Extended suite passes.
- A single-task `--dry-run` produces no manifest file at all.
- The manifest's JSON validates with `jq` and lists every contended path exactly once.
- `shellcheck` clean; `test-lint-deploy-caller-wrap.sh` still passes.

---

### Phase 9: Contended-path refusal in `git-commit-scoped.sh` [NOT STARTED]

**Goal**: Option 3(ii) — make the shared-tree commit path refuse to stage a path a live sibling is
concurrently contending for, with a first-claim lease that keeps exactly one committer moving.

**Tasks**:
- [ ] Add a `--task <task_number>` input to `git-commit-scoped.sh` (empty-value-skips, so every
      existing call site is unaffected until it opts in) naming the committing task.
- [ ] Before staging, for each **positive** pathspec entry: consult the cycle manifest. Not
      listed → proceed exactly as today.
- [ ] Listed and unclaimed → claim it with a lease file (`{task, session, claimed_at}`) under a
      `specs/`-rooted ephemeral claims directory, then stage and commit, then release the claim.
- [ ] Listed and claimed by **this** task → proceed (re-entrant).
- [ ] Listed and claimed by another live task → **refuse before any `git add`**, with a distinct
      exit code and a message naming the path, the holding task, and the release condition
      (the holder's commit). Direct the agent to defer that path and re-sequence — never to widen
      the pathspec and never to force it.
- [ ] Honor an age-based staleness override on a claim, reusing the `task-lock.sh` lease pattern
      rather than inventing a new primitive.
- [ ] **Fail open**: a missing, unreadable, or malformed manifest, an absent `--task`, or any
      error inside the check proceeds with today's behavior and a stderr notice. A concurrency
      guard must never be the reason an agent cannot commit at all.
- [ ] Leave every existing gate (V2 unmatched-path classification, V3 exclude-only refusal, the
      commit mutex, the ephemeral-exclude injection) untouched, and keep explicit multi-file path
      staging permitted.
- [ ] Extend `test-git-commit-scoped.sh`: unlisted path proceeds; unclaimed listed path claims,
      commits, releases; re-entrant claim proceeds; foreign live claim refuses with nothing staged;
      stale claim overridden; missing/corrupt manifest fails open; no `--task` fails open; existing
      V2/V3 cases unchanged.

**Timing**: 2 hours

**Depends on**: 8

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - manifest check, claim lease,
  refusal path, `--task` input
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - the eight cases above
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - register the
  claims directory

**Scope Hypothesis**: this phase asserts that adding an optional input and a fail-open pre-staging
check leaves every existing caller of `git-commit-scoped.sh` behaviorally unchanged. Confirm at
implementation time by enumerating callers
(`grep -rn 'git-commit-scoped.sh' agent-system/extensions`) and verifying each either omits
`--task` (fail-open, unchanged) or is updated deliberately in this phase.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` passes, including
  every pre-existing case.
- The foreign-claim refusal case leaves `git diff --cached` empty — nothing staged before the
  refusal.
- `bash .claude/scripts/tests/run-all.sh` passes (this script sits on the shared commit path, so
  the full suite is the honest gate).
- `bash .claude/scripts/tests/test-lint-scoped-commit-boundary.sh` passes.
- `shellcheck` clean.

---

### Phase 10: Fixture — reproduce the batch shape and prove the bleed is gone [NOT STARTED]

**Goal**: The acceptance criterion: a fixture reproducing two concurrent lean4 implement dispatches
in one repo, both editing one shared markdown file, one invoking an unguarded `lake`, demonstrating
that cross-task bleed into a commit no longer occurs.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-dispatch-isolation-fixture.sh`
      building a throwaway git repo (no dependency on the reference consumer repo, no network, no
      real Lean toolchain — stub `lake` on `PATH`).
- [ ] Set up two tasks whose `file_scope` share one markdown file, both with a lean4-family task
      type and both at `implement` phase; run the real dispatch-prep path so each is selected for
      isolation and provisioned.
- [ ] In each worktree, edit the shared markdown file distinctly, then commit each with the real
      scoped-commit path.
- [ ] Assert **no bleed**: each task's commit contains only its own lines in the shared file;
      neither commit contains the sibling's lines. This is the direct negative of the observed
      incident.
- [ ] Land both branches; assert the first lands clean and the second surfaces an **explicit
      conflict verdict** with the branch preserved — asserting the honest outcome (conflict made
      visible), not a magical merge.
- [ ] Add the mode-2 leg: have one dispatch invoke the stub `lake` unguarded while the other holds
      the guard's lock; assert the isolated dispatches use **separate** `.lake` directories, so the
      unguarded call cannot collide with the sibling's guarded build.
- [ ] Add the shared-tree counterpart: two general/meta tasks sharing one file, both dispatched to
      the shared tree; assert the manifest lists the path and that the second committer is
      **refused** with nothing staged.
- [ ] Assert full teardown: no leftover worktrees, branches, locks, claims, or manifests.

**Timing**: 2 hours

**Depends on**: 7, 9

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-dispatch-isolation-fixture.sh` - new

**Verification**:
- The fixture passes and its no-bleed assertion fails when the isolation wiring is disabled
  (verify by temporarily forcing the predicate false) — a test that cannot fail proves nothing.
- The conflict leg asserts the conflict verdict and the preserved branch, not a silent success.
- The shared-tree leg asserts nothing was staged on refusal.
- Teardown assertions pass: `git worktree list` clean, no `orchestrate/task-*` branches left.
- `shellcheck` clean; the suite is executable.

---

### Phase 11: Full gates, redeploy, and consumer-repo confirmation [NOT STARTED]

**Goal**: Close the remaining acceptance criteria: repo-wide gates green, the change deployed, and
confirmed live where an agent will actually run it.

**Tasks**:
- [ ] `shellcheck` every shell file touched or added, per
      `context/standards/shell-strict-mode.md`.
- [ ] `bash .claude/scripts/tests/run-all.sh` — full suite, zero failures, zero unexpected SKIPs
      (a SKIP means a lost exec bit, not a pass).
- [ ] `bash .claude/scripts/check-task-references.sh` — no task numbers in any deliverable outside
      `specs/**`.
- [ ] `bash .claude/scripts/validate-wiring.sh` and `bash .claude/scripts/verify-deploy.sh` — the
      two new scripts and every documentation addition are wired and reachable, not orphaned.
- [ ] Redeploy: `bash .claude/scripts/deploy-headless.sh`, then confirm the new scripts and the
      documentation additions are present in this repo's deployed `.claude/` tree.
- [ ] Confirm live in a consumer repo: verify the deployed `dispatch-worktree.sh` is present and
      `--help`-responsive there, and that `lean4.md`'s build section carries the opt-in note.
- [ ] Reconcile the header contracts if a sibling task landed an overlapping edit to
      `orchestrate-cycle-plan.sh` in the meantime (the footprint note's "whichever lands last
      reconciles" obligation).
- [ ] Record in the summary: the decision, the Phase 1 measurements, the hunk-attribution
      finding, the two deliberate divergences, the deferred PATH-shim follow-up, and anything
      excluded with its reason.

**Timing**: 1.5 hours

**Depends on**: 10

**Verification Tier**: full

**Verification**:
- `run-all.sh` exits 0 with every suite reported PASS.
- `shellcheck` reports nothing on every touched shell file.
- `check-task-references.sh`, `validate-wiring.sh`, `verify-deploy.sh` report no new findings.
- The deployed `.claude/scripts/dispatch-worktree.sh` exists in a consumer repo and `--help`
  succeeds there.
- `git status --short` shows no unintended paths; every commit was scoped and path-explicit.

## Testing & Validation

- [ ] `bash .claude/scripts/tests/test-dispatch-worktree.sh` — full worktree lifecycle including
      the `specs/**` refusal and the preserved-conflict case
- [ ] `bash .claude/scripts/tests/test-dispatch-isolation-fixture.sh` — the acceptance fixture
      (two concurrent lean4 implement dispatches, one shared markdown file, one unguarded `lake`)
- [ ] `bash .claude/scripts/tests/test-orchestrate-cycle-plan.sh`
      — selection predicate, row fields, deferral on provision failure, contention manifest
- [ ] `bash .claude/scripts/tests/test-orchestrate-build-dispatch.sh` — the isolated-working-tree
      section, present with the flag and byte-identical output without it
- [ ] `bash .claude/scripts/tests/test-orchestrate-cycle-postflight.sh` — land/conflict/refusal
      branches and the unchanged non-isolated path
- [ ] `bash .claude/scripts/tests/test-git-commit-scoped.sh` — claim/refuse/fail-open plus every
      pre-existing V2/V3 case
- [ ] `bash .claude/scripts/tests/test-lake-build-guard.sh` — unchanged behavior after the
      comment-only header edit
- [ ] `bash .claude/scripts/tests/run-all.sh` — whole suite green
- [ ] `shellcheck` clean on every touched or added shell file
- [ ] `bash .claude/scripts/check-task-references.sh` — no task numbers outside `specs/**`
- [ ] `bash .claude/scripts/validate-wiring.sh`, `bash .claude/scripts/verify-deploy.sh`
- [ ] Redeploy and confirm the change is live in a consumer repo

## Artifacts & Outputs

New:
- `agent-system/extensions/core/scripts/dispatch-worktree.sh`
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh`
- `agent-system/extensions/core/scripts/tests/test-dispatch-isolation-fixture.sh`
- `specs/199_concurrent_dispatch_isolation_posture/summaries/01_*-summary.md` (implement phase)

Modified (declared `file_scope`):
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- `agent-system/extensions/core/scripts/git-commit-scoped.sh`
- `agent-system/extensions/core/scripts/lake-build-guard.sh` (header comment only)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/lean/rules/lean4.md`

Modified (**footprint additions beyond the declared `file_scope`** — recorded deliberately so the
admission gate and any sibling task can see them):
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (mode-1b qualification;
  the research report names this as the correct home, and it is not owned by the task that owns
  `rules/git-workflow.md`)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (land/release/prune
  wiring; the merge-back has to run in the main tree after the agent returns, which is exactly
  this script's boundary)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (register the new
  ephemeral runtime paths)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`,
  `test-orchestrate-build-dispatch.sh`, `test-orchestrate-cycle-postflight.sh`,
  `test-git-commit-scoped.sh` (test extensions for the above)
- `.gitignore` (ignore the new ephemeral runtime paths, if not already covered)

Not modified, deliberately: `core/scripts/git-snapshot.sh`, `core/rules/git-workflow.md`,
`context/formats/plan-format.md`, `hooks/guard-destructive-git.sh`, the territory payload,
`skills/skill-orchestrate/SKILL.md`, and every project-local script in any consumer repo.

## Rollback/Contingency

- **Per-phase**: every phase commits per green sub-step with explicit, path-named staging, so a
  bad phase is reverted with `git revert` of its own commits — no working-tree discard needed.
- **If a genuine working-tree rollback is required**: follow `context/contracts/recovery.md`'s
  rollback rung for the exact snapshot-then-rollback invocation, including its out-of-scope
  override flag for the deliberate whole-tree case. Do **not** emit a bare default-mode
  `git-snapshot.sh` as a routine checkpoint; an ordinary defensive checkpoint before risky work
  uses `--no-revert`, which is durable without reverting the tree.
- **If Phase 1 falsifies the Lake atomic-rename assumption**: keep the design and switch `.lake`
  population to `lake exe cache get` (the proven precedent) with a disk-sized concurrency cap.
  Phases 4-11 are unaffected in shape.
- **If worktree isolation proves unworkable in the consumer repo at Phase 10/11**: the two halves
  of the split verdict are independent. The contended-path refusal (Phases 8-9) stands alone and
  can ship without the worktree half; the selection predicate then evaluates false everywhere
  and every dispatch keeps the shared tree. Record the exclusion and its reason plainly rather
  than claiming full coverage.
- **If merge-back conflicts prove frequent enough to be a net regression**: `land`'s refusal path
  already preserves the branch and the worktree, so no work is lost; narrow the selection
  predicate (e.g. to dispatches whose declared scopes actually overlap) rather than reverting the
  machinery.
- **Ephemeral runtime state** (worktrees, branches, manifests, claims) is removed by
  `dispatch-worktree.sh release`/`prune` and by the claims' staleness override; a crashed run
  leaves nothing that blocks the next one.
