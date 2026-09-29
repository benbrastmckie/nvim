# Research Report: Task #199

**Task**: 199 - Concurrent dispatch isolation posture
**Started**: 2026-09-28
**Completed**: 2026-09-28
**Effort**: research (decision + design; implementation deferred to plan/implement phases)
**Dependencies**: task 191 (git-snapshot revert fix, landed), task 192 (over-staging guard, landed),
task 193 (cross-task territory briefs, landed) — coordinated with, not re-decided
**Sources/Inputs**: codebase exploration (agent-system/extensions/{core,lean,cslib}), live
measurement against `~/Projects/BimodalLogic`, harness Agent-tool schema inspection
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Decision: a split verdict**, exactly as the dispatch invited. Per-dispatch git-worktree
  isolation (Option 2) for lean4/cslib **implement**-phase dispatches; keep the shared tree plus a
  new narrow per-file contention lock (Option 3(ii)) for general/meta/markdown dispatches. Option
  3(i) (hunk-level attribution) is **ruled out**: no hunk/line-to-task attribution mechanism
  exists anywhere in the codebase today, and building one is not cheaper than worktree isolation.
- **The disk-cost objection to worktree isolation is real but was overstated as a blocker.**
  `~/Projects/BimodalLogic`'s `.lake` is 16 GiB against only 27 GiB free — a naive
  independent-`.lake`-per-worktree design is close to prohibitive. But a hardlink clone
  (`cp -al .lake`) reproduces the full 15 GiB tree in **0.83 s with zero measured disk growth**
  (confirmed via `df` before/after). This changes the cost calculus from "expensive" to "cheap,
  conditional on Lake writing build outputs via atomic temp+rename" — an assumption this report
  flags for verification, not one it confirms.
- **The harness already exposes the exact primitive the dispatch asked to check for reuse**: the
  `Agent` tool's `isolation: "worktree"` parameter creates and tears down a git worktree
  automatically. `skill-orchestrate`'s Move 2 dispatch loop (`SKILL.md` lines ~130-156) calls
  `Agent` with no `isolation` parameter at all — confirmed by grep, and confirmed live: the
  present orchestrate cycle that dispatched this very research task placed it, and five siblings
  (tasks 139, 162, 163, 244, 43), on the **same shared working tree** with no isolation. Adopting
  the parameter is a dispatch-site change, not new worktree-lifecycle machinery.
- **"Merge-back is new machinery" is also overstated.** `git worktree add` shares one object
  database with the main tree (confirmed: `git worktree add` completed in 0.089 s with no
  network or object-copy cost). If the isolated agent commits inside its own worktree/branch as it
  already does today, landing it is an ordinary `git merge <branch>` from the main tree — not a
  new cross-repo merge system. A genuine same-line collision becomes an explicit, tooled git
  conflict instead of mode 1b's silent bleed — strictly better, not merely different.
- **`specs/state.json`/`TODO.md` do not need to be touched inside a worktree at all.** The
  existing Postflight Boundary contract already keeps `orchestrate-cycle-postflight.sh` as the
  sole writer of those two repo-wide singleton files, running in the main tree, after the agent
  returns. Worktree isolation of an implement dispatch's task-directory-and-source-file writes
  composes cleanly with that existing boundary; it introduces no new merge surface on the two
  files every task touches.
- **Mode 2's mutex is not missing — it is opt-in, and the opt-in gap is the actual defect.**
  `lake-build-guard.sh` already implements a correct flock-based mutex with lock-wait, abandoned-
  lock recovery, and result sharing. Any bare `lake build` bypasses it. The one bypass observed
  (`check-module-invariants.sh`) is a BimodalLogic-local script, out of scope to edit. This report
  recommends documenting the opt-in nature loudly (required WORK item) and flags — as a
  follow-up, not built here — a transparent PATH-shim `lake` wrapper as the system-level answer to
  "how do unguarded callers participate without editing every consumer repo's scripts."

## Context & Scope

Task 199 charters a single decision: should concurrent same-repo `/orchestrate` implement
dispatches share one working tree and one `.lake`, or should each get an isolated one? The
dispatch names three failure modes observed on 2026-09-09 in `~/Projects/BimodalLogic` (working-
tree revert, cross-task commit bleed, build contention) plus a fourth incident on 2026-09-17
(silent cross-task commit misattribution in a four-task base-mode batch). This is `phase=research`
of task 199 (dispatch_seq 6): the deliverable is the evidence-backed recommendation and design
guidance for the plan/implement phases, not the implementation itself. `file_scope` for this task
(from `specs/state.json`) already names exactly the files the recommendation below expects a
later plan to touch: `orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`,
`lake-build-guard.sh`, `git-commit-scoped.sh`, `batch-orchestration-guardrails.md`, `lean4.md`.

## Findings

### Codebase Patterns

- **`lake-build-guard.sh`** (`agent-system/extensions/core/scripts/`) already implements a
  correct `flock`-based mutex on `<root>/.lake/build-guard.lock`, with `status`/`preflight`/
  `build`/`result` subcommands, lock-wait timeout (exit 75), a hardcoded Lake-subcommand allowlist
  validated before dispatch, and REPLAY result-sharing keyed on a `scope_key` covering the tree
  fingerprint plus the argument vector. Its header states plainly: "any other consumer must opt in
  explicitly by invoking `lake-build-guard.sh build ...`" — confirming the dispatch's correction
  that the mutex exists and the defect is bypass, not absence.
- **`git-commit-scoped.sh` + `specs/.commit-lock/`** (`task-lock.sh`'s `commit-acquire`/
  `commit-release`) already solve the *race* on git's index for two concurrent scoped commits —
  serializing the add+commit pair and requiring every commit to name its pathspec. This is a
  different hazard than mode 1b: it prevents two commits from corrupting `.git/index.lock`
  concurrently; it does **not** prevent one commit's staged version of a shared file from already
  containing a sibling's uncommitted edits, because both dispatches edit the **same working-tree
  file** before either one stages anything. Explicit-path staging operates at file granularity and
  cannot subdivide a file's content by which dispatch wrote which line — confirmed by grep: no
  hunk/line/diff-based per-task attribution mechanism exists anywhere in
  `agent-system/extensions/core` (searched for `hunk`, `patch -p`, per-task diff tracking — the
  only hits were unrelated dispatch-file/plan-format prose, not an attribution mechanism).
- **`context/contracts/territory.md`'s Cross-Task Territory (Base Mode) section** (landed by task
  193) already gives every dispatch a `concurrent_siblings[]` list with each sibling's declared
  `file_scope`, granularity, and a `concurrency_note` obligating re-read-before-edit,
  never-run-git-snapshot-in-reverting-mode, and STOP-and-report on foreign work. It explicitly
  disclaims covering "working-tree or build isolation between concurrent dispatches... a distinct,
  unimplemented remedy owned elsewhere" — i.e., task 193 knowingly left this task's exact question
  open rather than silently assuming it was covered.
- **`git-staging-scope.md`** already documents the Postflight Boundary discipline that keeps
  `specs/state.json`/`TODO.md` writes to a single main-tree writer (`orchestrator-postflight.sh` /
  `orchestrate-cycle-postflight.sh`) inside a dedicated `specs/.scope-lock/` mutex, separate from
  the commit mutex. This is favorable groundwork for worktree isolation: nothing about isolating
  an implement dispatch's *source-file* writes requires touching how the two shared index files
  are written, because they are already never written from inside dispatched-agent territory in
  the first place (the "MUST NOT (Postflight Boundary)" rule in `skill-orchestrate/SKILL.md`
  already forbids the orchestrator from editing source — the boundary runs the other direction
  too, cleanly).
- **Prior art — `lean-comparator-run.sh`** (`agent-system/extensions/lean/`) already uses
  `git worktree add` at an exact commit, populated via `lake exe cache get` before an untrusted
  build, specifically because a worktree gives "an independent working directory and an
  independent `.lake/`" more cheaply than `git clone --depth 1` (its own documented rejection of
  the clone alternative). This is a *security* clean-room use, not concurrency isolation, but it
  establishes that worktree-plus-independent-`.lake` is already a proven, working pattern in this
  codebase, not a novel one.
- **Prior art — `cslib/context/project/cslib/patterns/lint-fix-wave-assignment.md`** already
  recommends worktree isolation for task pairs with >50% file overlap, with an explicit **NOT
  appropriate** carve-out: ">100 edit sites" or "tasks edit identical lines" (merge conflicts occur
  regardless). This independently corroborates that worktree isolation does not eliminate
  same-line conflicts — it converts them into a merge conflict instead of leaving them silent,
  which is the correct framing for scoring option 2 against mode 1b below (worktrees do not need
  to make same-line conflicts *vanish* to be a net improvement over mode 1b's silent bleed).
- **The harness's own `Agent` tool exposes `isolation: "worktree"`** (this session's own tool
  schema): "creates a temporary git worktree so the agent works on an isolated copy of the repo,"
  auto-cleaned up if the agent makes no changes, otherwise returning the path/branch. `grep`
  across `skill-orchestrate/SKILL.md`, `orchestrate-cycle-plan.sh`, and
  `orchestrate-build-dispatch.sh` for `isolation`/`worktree` returns **zero hits** — this
  parameter is wired nowhere in the dispatch pipeline today. Live confirmation: this very research
  dispatch (task 199) is running in `/home/benjamin/.config/nvim` alongside five sibling dispatches
  (tasks 139, 162, 163, 244, 43) on the identical shared working tree, addressable as session
  teammates — the exact "concurrent same-repo dispatch onto one shared tree" posture this task is
  chartered to evaluate, currently in effect with no isolation.

### Measurements (BimodalLogic — the repo where all incidents were observed)

| Measurement | Value | Method |
|---|---|---|
| `.lake` total size | 16 GiB (`.lake/packages` 9.2 GiB + `.lake/build` 6.1 GiB) | `du -sh` |
| Free disk | 27 GiB (of 457 GiB, 94% used) | `df -h` |
| `git worktree add HEAD` (no `.lake`) | 0.089 s | `time git worktree add` |
| Hardlink clone of `.lake` (`cp -al`) | 0.827 s, **0 GiB measured disk growth** | `time cp -al`; `df` before/after unchanged |
| Hunk/per-task attribution mechanism | **none found** | grep across `agent-system/extensions/core` for hunk/patch/attribution patterns |
| `isolation`/`worktree` wiring in dispatch pipeline | **none found** | grep `SKILL.md`, `orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh` |

**Reading the disk numbers together**: a naive "independent `.lake` per worktree, built fresh or
via `lake exe cache get`" design costs ~16 GiB per concurrent worktree against 27 GiB free — at
most one full extra worktree before exhaustion, which would badly cap concurrency for exactly the
task type (lean4/cslib) this option is meant to serve. The hardlink-clone alternative reduces the
*creation* cost to near-zero in both time and space, **provided** Lake's own build process writes
outputs via a temp-file-then-rename pattern (the common idiom that makes hardlink sharing safe: a
rename breaks the hardlink for the file being rewritten, so a rebuild in one worktree does not
silently corrupt the still-shared inode in a sibling worktree). This report did **not** verify
Lake's write pattern directly — that is a concrete, cheap verification step for the plan/implement
phase (grep Lake's own source or empirically test: hardlink-clone a `.lake`, touch one `.lean`
file in the clone, `lake build` it, then diff the corresponding `.olean`'s inode number against the
original to confirm they diverged rather than both changing). If the assumption fails, fall back
to a `lake exe cache get`-populated worktree (proven pattern, `lean-comparator-run.sh`) at the
full ~16 GiB cost, with an explicit concurrency cap sized to free disk.

## Decisions

### Scoring Table (every option against all three failure modes)

| Option | Mode 1a (revert) | Mode 1b (bleed) | Mode 2 (build contention) | Cost / concurrency effect |
|---|---|---|---|---|
| **1 — shared tree, patch per mechanism** | Fixed (task 191, landed) | **Not addressed at all** — explicit-path staging cannot subdivide a file's content by author | Mutex exists but opt-in; unaddressed bypass | Cheapest per-patch, but is the 4th+ patch on one root cause; task 192's own record shows enumerated patches teach agents the enumeration |
| **2 — per-dispatch worktree isolation** | Solved structurally (no shared tree to snapshot) | Solved structurally (no shared working copy to bleed from) | Solved structurally (independent `.lake`, no lock contention) | Disk cost real but mitigable (hardlink clone, measured); merge-back is an ordinary git merge (shared object store), not new machinery; preserves full concurrency, bounded by disk headroom |
| **3(i) — hunk-level staging** | Not addressed | Targets it directly, in principle | Not addressed | **Infeasible as scoped**: no per-task hunk/line attribution mechanism exists; building one is new, hard machinery (effectively a 3-way-merge/attribution subsystem), not "cheaper than worktrees" once honestly costed |
| **3(ii) — refuse on contended shared file** | Not addressed | Targets it directly, at low cost, using data task 193 already provides (`concurrent_siblings` file_scope) | Not addressed | Cheap; forces sequencing only on the one contended file, not the whole task — preserves concurrency everywhere else |

### The Split Verdict

**A. Lean4/cslib implement-phase dispatches → Option 2 (per-dispatch git worktree isolation).**
These are exactly the dispatches with (i) expensive builds that justify the isolation cost, and
(ii) frequent, by-construction shared-file collisions (`docs/theorem-index.md`, `README.md`,
`check-module-invariants.sh`). Design guidance for the plan/implement phases:
1. Wire the harness's `Agent(isolation: "worktree")` parameter (or an equivalent explicit
   `git worktree add -b task-{N}-{phase} <path> HEAD` if the harness parameter proves unsuitable
   for this call site — verify at implement time) into `orchestrate-cycle-plan.sh`'s dispatch row
   construction / `orchestrate-build-dispatch.sh`, gated to `phase == "implement"` for lean4/cslib
   task types (not research/plan, which do not commit source and do not need build isolation).
2. Populate the new worktree's `.lake` via hardlink clone (`cp -al` from the main tree's `.lake`)
   rather than a cold rebuild, after verifying the atomic-rename assumption above; fall back to
   `lake exe cache get` (the `lean-comparator-run.sh` precedent) if that assumption fails.
3. The dispatched agent commits inside its own worktree/branch exactly as it does today — no
   change to `git-workflow.md`, `git-commit-scoped.sh`'s internals, or the commit-mutex.
4. Postflight, running in the main tree exactly as the existing Postflight Boundary contract
   already requires, lands the work via `git merge <task-branch>` — an ordinary merge against a
   shared object database, not a new cross-repo merge system. A genuine same-line collision
   surfaces as an explicit git conflict for the orchestrator/user to resolve, which is a strict
   improvement over mode 1b's silent, permanent bleed.
5. `specs/state.json`/`TODO.md` are never written inside the worktree; the existing single-writer
   Postflight Boundary already keeps them main-tree-only, so no new merge surface is created there.
6. Cap concurrent worktree-isolated dispatches by available disk headroom (this repo's 27 GiB free
   against a 16 GiB baseline caps a naive design at ~1 extra full-divergence worktree; the
   hardlink-clone mitigation raises this ceiling substantially but a hard cap or a preflight
   free-space check is still warranted as a safety net, since the mitigation's benefit degrades if
   a worktree's build fully diverges from the shared baseline).

**B. General/meta/markdown dispatches → keep the shared tree, add Option 3(ii).** No `.lake`, no
expensive builds — worktree overhead buys nothing here. Instead:
1. Add a narrow per-file "in-edit" lock (e.g. `specs/.file-locks/<hash-of-repo-relative-path>`)
   created when a dispatch begins editing a file that also appears in a live sibling's declared
   `file_scope` (the `concurrent_siblings[]` list task 193 already renders into every dispatch),
   released at that file's own commit.
2. `git-commit-scoped.sh` (this task's own declared file_scope already names it) checks for a
   foreign-held lock on each positive pathspec entry before staging; on contention, refuse and
   direct the agent to defer/re-sequence rather than silently proceeding — Option 3(ii) exactly as
   scoped in the dispatch.
3. **Do not** attempt Option 3(i) — ruled out above as infeasible without new attribution
   machinery that costs as much as worktree isolation while solving less.
4. Mode 1a and mode 2 remain covered by their existing, separate fixes (task 191;
   `lake-build-guard.sh`'s mutex) — option 3 was never scored against those and this split verdict
   does not change that.

**C. Mode 2, cross-cutting under both branches.** Document, as WORK item (d)(i) requires: the
mutex in `lake-build-guard.sh` already exists and is correct; it is opt-in; the one observed
bypass (`check-module-invariants.sh`) is a BimodalLogic-local script, correctly out of scope to
edit here. Record this plainly in `lean4.md`'s build section and the guard's own header (if the
participation contract changes). As a **follow-up, not built in this pass**: a transparent
PATH-shim `lake` wrapper that silently routes bare `lake build`/`lake test` invocations through
the guard for any process that inherits the dispatch's `PATH` — this is the system-level answer
to "how does the agent system get unguarded callers to participate without editing every consumer
repo's scripts," but needs a feasibility check (how/whether the dispatch environment's `PATH` can
be safely pre-pended for a lean4/cslib session) that this research pass did not attempt.

**D. Mode-1b rules qualification (WORK item (d)(ii)).** Explicit-path staging remains the
sanctioned, correct form (task 192's predicate is not re-decided here) — but it is necessary, not
sufficient, under concurrency: it cannot subdivide a file's content by author. This qualification
should land as a cross-reference addition in `context/standards/git-staging-scope.md`'s existing
"Per-Operation Scope" section (a file this task's declared `file_scope` does not list, but which
is the natural home for a staging-layer caveat and is not owned by task 191's `git-workflow.md`/
`git-snapshot.sh`/plan-format ownership) — coordinate with task 191 rather than editing
`git-workflow.md` directly, per this dispatch's own MUST NOT.

## Risks & Mitigations

- **Risk**: the atomic-rename assumption behind hardlink-clone `.lake` sharing is unverified.
  **Mitigation**: cheap empirical test named above (hardlink-clone, rebuild one module, diff
  inode numbers) before committing to this approach in the implement phase; documented fallback
  (`lake exe cache get`) exists and is already proven in this codebase.
- **Risk**: worktree-isolated builds still exhaust disk if many lean4/cslib dispatches are batched
  concurrently and several diverge fully from the shared baseline. **Mitigation**: an explicit
  concurrency cap or preflight free-space check, sized conservatively against measured free space.
- **Risk**: the per-file lock in Option 3(ii) could deadlock or starve if a sibling holds a lock
  and never releases it (crash, hang). **Mitigation**: reuse the same lease/staleness pattern
  already proven by `specs/.commit-lock/`/`task-lock.sh` (age-based staleness override) rather than
  inventing a new lock primitive.
- **Risk**: PATH-shim `lake` interception (mode 2 follow-up) could mask legitimate direct `lake`
  invocations a user or script relies on running unguarded. **Mitigation**: scope any such shim to
  agent-dispatch sessions only, never a user's interactive shell; treat as a separate, later
  decision as stated above, not built in this task.

## Context Extension Recommendations

- **Topic**: whether Lake writes build artifacts via atomic temp+rename (load-bearing for the
  hardlink-clone `.lake` sharing strategy). **Gap**: no existing context file documents Lake's
  write semantics. **Recommendation**: once verified at implement time, record the finding in
  `agent-system/extensions/lean/context/project/lean4/domain/` alongside the existing
  comparator-integration design record, since both rely on the same worktree-plus-`.lake`
  pattern for different purposes.

## Appendix

### Search queries / commands used

- `jq -r '.extensions.core.source_dir, .extensions.lean.source_dir' .claude-extensions.json`
- `find . -iname "*worktree*" -o -iname "*territory*"` (core extension)
- `find . -iname "*worktree*" -o -iname "*comparator*" -o -iname "*lint-fix*" -o -iname "*wave*"` (lean extension)
- `du -sh .lake .lake/packages .lake/build` (BimodalLogic)
- `df -h .` (before/after hardlink clone)
- `time git worktree add /tmp/bimodal-worktree-test HEAD`
- `time cp -al .lake /tmp/bimodal-lake-hardlink-test`
- `grep -rln "hunk\|patch -p\|git diff.*hunk" scripts/*.sh context/**/*.md` (core extension)
- `grep -n "Task(\|Agent(\|subagent_type\|isolation" skills/skill-orchestrate/SKILL.md`
- `grep -n "isolation\|worktree" scripts/orchestrate-cycle-plan.sh scripts/orchestrate-build-dispatch.sh docs/architecture/orchestrate-state-machine.md`
- `ToolSearch("select:EnterWorktree,ExitWorktree")` and inspection of the `Agent` tool's own
  `isolation` parameter schema

### References

- `agent-system/extensions/core/scripts/lake-build-guard.sh` (header, mutex design)
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- `agent-system/extensions/core/context/contracts/territory.md` (Cross-Task Territory section)
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md`
- `agent-system/extensions/cslib/context/project/cslib/patterns/lint-fix-wave-assignment.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 2/Move 3, Postflight
  Boundary)
- `specs/archive/191_stop_git_snapshot_reverting_unrelated_work/`,
  `specs/archive/192_close_git_add_directory_pathspec_overstage_hole/`,
  `specs/archive/193_carry_territory_in_base_mode_dispatch_briefs/` (prior, coordinated work)
