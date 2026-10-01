# Decision Record: Per-Dispatch Working-Tree Isolation — Removal Verdict

**Reaffirmed 2026-10-01.** Task 301 re-opened this verdict under new evidence (a live production
observation of the layer still running in a stale deploy, plus targeted external research into
CoW/reflink alternatives) and formally CONFIRMED it. See
`specs/decisions/worktree-isolation-removal-reaffirmation.md` for the reaffirmation record and
`specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md` for the
full evidentiary basis. This record's content below is unchanged and remains authoritative.

This record closes the split verdict recorded in
`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s
`## Working-Tree and Build Isolation Posture` section and replaces it with a blanket shared-tree
posture. It complements, and does not duplicate, that section: the three-failure-mode taxonomy,
the scoring table, and the measurements all remain valid as written and are cited here rather
than restated. What changes is the verdict those inputs were used to reach.

## The Verdict

**Per-dispatch `git worktree` isolation is removed, not narrowed.** Every dispatch — every phase,
every `task_type` — runs in the repository's single working tree. `dispatch-worktree.sh`, the
`task_selected_for_worktree_isolation()` selection predicate, and all provisioning, landing,
releasing and pruning wiring are deleted rather than left dormant behind a predicate that returns
false.

Concurrency safety rests entirely on declared `file_scope`, `dependencies[]` edges, and the five
contention inputs already built and in service. Two orchestrations in different sessions of the
same repository may run concurrently in that one working tree when no `file_scope` collision and
no dependency edge relates them; when a conflict exists, the orchestrator refuses and names the
task sets that could run instead.

## Cost Was Not the Reason

Recorded explicitly so that nobody revisiting this decision cites the disk-and-latency objection
as its basis, because that objection was measured and found to be small:

- `git worktree add`: 0.09–0.2 s, measured twice in two repositories independently.
- Hardlink-clone of a 16 GiB `.lake/`: ~0.8 s for 157,000+ files, with disk-usage movement on the
  order of `df`'s own 1 GiB rounding granularity rather than the ~16 GiB a real copy would cost.
- Every file's link count verified greater than 1 — genuinely hardlinked, none silently falling
  back to a real copy.

Those measurements stand. Isolation was cheap to provision. **It is removed for reliability and
complexity reasons, not cost ones**, and an argument from cost against it is an argument against
this repository's own evidence.

## The Reason: Three Defects, Every One Induced by the Layer

| Defect | Mechanism | Consequence |
|---|---|---|
| Destructive release on `nothing_to_land` | `dispatch-worktree.sh land` derives `nothing_to_land` from a pure branch-ancestry test (`merge-base --is-ancestor`) and never inspects the working tree; `orchestrate-cycle-postflight.sh` folds that verdict into the same success branch as `landed` and immediately releases | Silent destruction of uncommitted work. Nearly destroyed 456 verified, sorry-free, build-green Lean lines; caught only because an operator inspected the worktree by hand. Nothing in the system would have reported the loss |
| `git-commit-scoped.sh` cannot commit in a worktree | `PROJECT_ROOT` is derived from `BASH_SOURCE[0]`, with no `--repo-root` or `--worktree` flag; every pathspec falls through the WARN-and-drop branch, nothing stages, and the script returns success | False negative that reads as success to its caller. Produced a commit lacking its `Co-Authored-By` and `Claude-Session` trailers via an agent's manual fallback |
| `lake-build-guard.sh` false green | `cp -al` of `.lake/` shares inodes for the guard's five `build-guard.*` state files; `finalize_record()` truncates in place, so a worktree build overwrote the main tree's record | Reported "Build completed successfully (1200 jobs)" while writing no `.olean` for the requested module. A false green is the dangerous direction of wrong for a build gate |

No defect of any other origin is recorded against this dispatch path. Every known failure in it
was created by it.

## The Decisive Finding: the Layer Defeated One of Its Own Justifications

Build contention (mode 2) was one of the three failure modes worktree isolation was adopted to
close. The isolation mechanism broke mode 2's existing mitigation. `dispatch-worktree.sh`'s own
header states it:

> the same shared inode also made `build-guard.lock` serialize builds ACROSS trees, defeating the
> very build-contention isolation per-dispatch worktrees exist to provide (mode 2 above).

This is the system's own admission, not an inference drawn against it.

The same header carries a generalization that matters more than the single instance:

> The "independently rebindable via atomic rename" property stated two paragraphs up holds ONLY
> for a writer that actually renames into place — a truncate-in-place writer (like
> `finalize_record()`) never gets it, hardlink or not.

Atomic-rename rebindability was the load-bearing empirical assumption behind hardlink-cloning a
build directory at all. It is a **per-writer** property, not a property of the clone. Every
script that keeps mutable per-invocation state inside a directory this layer clones is therefore a
fresh instance of the same hazard, and the exclusion list is a manually maintained enumeration of
named files. A layer whose correctness depends on the continuing discipline of unrelated scripts
that do not know it exists cannot be audited once and then trusted. That is the structural reason
the layer goes, distinct from any one of the three defects.

## The Three Failure Modes, Re-Scored Under a Shared Tree

- **Mode 1a — working-tree revert.** Dormant. `git-snapshot.sh` offers a `--no-revert` mode, and
  its reverting modes already fail closed: they refuse when the task declares no `file_scope`, and
  refuse when any dirty tracked path falls outside the declared scope. The script also has no
  callers anywhere in `scripts/` or `skills/`. No worktree is required to hold this closed.
- **Mode 1b — cross-task commit bleed.** Covered by `file_scope` serialization plus the
  contended-path lease already implemented (the manifest producer in `orchestrate-cycle-plan.sh`,
  consumed at commit time by `git-commit-scoped.sh`). Residual: an absent or coarse `file_scope`,
  addressed under "What This Makes Load-Bearing" below.
- **Mode 2 — build contention.** **Not** covered by `file_scope`: no task declares `.lake/`, so
  two build-heavy tasks with provably disjoint source scopes still collide in the build directory.
  This is the one capability the shared tree does not inherit for free, and it is ruled next.

## Mode 2 Ruling: an Admission Rule, Not a PATH Shim

**RULED.** Mode 2 is closed by an admission rule: **never dispatch two build-heavy implement tasks
in the same cycle.** This is implemented in the cycle-split layer that already exists, and it
reuses the `task_type` family the deleted predicate named — that list (`lean4`, `cslib`) survives
its predicate, repurposed from "isolate this" to "do not co-schedule this." Within an
orchestration, mode 2 then becomes structurally impossible rather than merely guarded, with no new
subsystem introduced. This is a **blocking prerequisite**: the admission rule lands *before* the
removal, never after.

**CONSIDERED AND DECLINED, for now.** The PATH-shim wrapper that
`batch-orchestration-guardrails.md` names as the system-level answer and explicitly defers
("named, not built here") is not adopted. Its residual is stated rather than hidden: a bare
invocation of the build tool from outside an orchestration — an operator's own shell, or a script
this system does not own — remains unguarded. That is a different threat model from
in-orchestration contention, and it is the same exposure the opt-in guard carried before worktrees
existed; removal does not worsen it. If it ever produces an observed harm, the shim is the answer
and this paragraph is the record that it was weighed.

## What This Makes Load-Bearing

Neither item below is created by this verdict. Both are promoted by it, from a known gap to the
thing that stands in the place isolation used to occupy.

1. **An absent `file_scope` buys no protection at all.** `task-lock.md` states it plainly for the
   cross-task overlap check: `file_scope` empty or absent on either side yields "no protection, no
   scan effect, in either" direction. Two live harms are already documented: a two-task dispatch
   that bypassed a correctly-working collision guard purely because neither task declared a scope,
   and an eight-task batch whose dry-run reported Dispatch 8 / Deferred 0 / Blocked 0 while the
   plans themselves showed one script in three tasks' footprints, one doc in four, and one task
   deleting a CI job another was editing. The guard did not fail; it was never consulted. Under
   this verdict that is the only remaining silent path to mode 1b, so the stronger posture (a
   genuine defer gated on a coverage precondition) is preferred over the narrowest one (blocking
   only in the presence of a concurrently-held broad scope).
2. **Lock heartbeats must actually fire.** A stale lock warns and proceeds rather than refusing.
   Measured evidence records zero heartbeat trace lines for either in-flight task of a live
   session, with that session's `acquired_at` equal to its `heartbeat_at` exactly. With isolation
   gone, the repo-wide held-lock scan is the pessimistic enforcement layer, and a lock that goes
   stale while its holder is alive silently downgrades refusal to a warning.

## What This Does Not Change

The five contention inputs stay exactly as they are: creation-time auto-dependency edges, the
runtime wave/cycle-split check, the repo-wide held-lock scan at `task-lock.sh acquire`, the
`specs/state.json` collision scan, and the session registry at `specs/.sessions/*.json` carrying
each live session's unioned `file_scope`. The last of these, consumed by both `task-lock.sh` and
`orchestrate-batch-admit.sh`, is already the cross-session mechanism this posture depends on; it
is not new work.

The queue, liveness and conclusion-stage work already filed is unaffected and unchanged by this
verdict — it is the same direction, arrived at independently, and remains the correct sequence.

## Removal Footprint

| Surface | Size |
|---|---|
| `scripts/dispatch-worktree.sh` | 670 lines, deleted |
| `scripts/tests/test-dispatch-worktree.sh` | 661 lines, deleted |
| `scripts/tests/test-dispatch-isolation-fixture.sh` | 471 lines, deleted |
| Wiring references | ~228 across 20 non-test files. Heaviest: `orchestrate-cycle-plan.sh` (36), `orchestrate-cycle-postflight.sh` (24), `orchestrate-build-dispatch.sh` (14), `batch-orchestration-guardrails.md` (18), `lake-build-guard.sh` (5), `skill-orchestrate/SKILL.md` (4), `assess-repo-health.sh` (3), `orchestrator-runtime-files.md` (3), `mcp-server-ownership.md` (3), plus `manifest.json`, `commands/todo.md`, `state-schema.json`, `territory.md` and six others at 1–2 each |

Two byte budgets currently reported as failing gain headroom from this removal: `SKILL.md` at
1,317 B over its ceiling, and eager context load at 2,030 B over baseline.

The removal also deletes an entire **derived** hazard class rather than merely its symptoms: a
provisioned worktree holds a HEAD-stale tracked copy of `specs/`, which is why task artifacts had
to be written to the main tree by absolute path and why any merge-back had to refuse a branch that
touched `specs/**`. None of that reasoning needs to exist under a shared tree.

## Task Disposition

| Task | Disposition |
|---|---|
| Isolation-posture decision record revision | NEW. Rewrite the guardrails section to this verdict. Keep the measurements and the failure-mode taxonomy; record that cost was not the reason. Keystone for the rest |
| Build-heavy co-scheduling admission rule | NEW. The mode 2 ruling above. Blocking prerequisite for removal |
| Worktree layer removal | NEW. The footprint table above. Depends on both tasks above |
| Destructive-release fix (276) | **ABANDON**, rationale recorded here. Its subject — the `nothing_to_land` to `release` path — ceases to exist under this verdict. The evidence remains readable in `specs/` and is cited in the defect table above |
| `git-commit-scoped.sh` worktree targeting (277) | **REVISE, narrowed.** Part (a), worktree targeting, is moot. Part (b) — an unresolvable pathspec becoming a hard error instead of a silent WARN-and-drop — is a genuine shared-tree defect and is kept: the drop-and-continue posture is what converts any wrong-path invocation into a false success, independent of which tree it ran in. The dependency edge on the Move 2 isolation-forwarding task is dropped with part (a) |
| `lake-build-guard` false green (268) | **LEAVE ALONE.** Phases 1 through 4 are complete; only phase 5 (redeploy and final gate) remains, and finishing costs less than re-scoping. Its durable value — the guard's own header conventions, the recorded dead ends, and the cases added to `test-lake-build-guard.sh` — survives removal. Its phase 2 deliverable, the `build-guard.*` exclusion from the `cp -al` clone, lives inside the file being deleted and goes with it; that is expected, not a loss |
| Absent-`file_scope` admission posture (165) | **PROMOTE.** All three of its dependencies are archived, so it is unblocked and dispatchable now. Prefer the stronger posture, per the load-bearing note above |
| Session liveness, orchestration queue, next-batch suggestion (272, 275, 274) | **KEEP UNCHANGED**, in that order. They are this direction and were already filed as such |
| State-schema reconciliation (279) | **UNAFFECTED.** Unrelated to isolation; it stays as scoped |

Sequence: decision-record revision, then the admission rule, then removal — with the absent-scope
posture running in parallel on a disjoint footprint, and the liveness/queue/suggestion chain after.

## Scope Boundary Honored

This record decides the isolation posture and the mode 2 replacement mechanism. It does **not**
decide: where exactly the co-scheduling predicate lives within the cycle-split layer; whether the
PATH-shim wrapper is ever built (declined for now, with its residual named above); the
`MAX_TASKS` cap; the state-schema field rulings; or any consumer-repository data migration. Each
belongs to its own task, and none is silently folded into this one.
