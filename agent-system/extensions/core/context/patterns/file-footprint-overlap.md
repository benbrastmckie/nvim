# File Footprint Overlap Detection

Canonical, single-source definition of the directory-prefix overlap algorithm used to decide
whether two tasks (or two phases within a task) touch the same files and should therefore be
serialized rather than dispatched concurrently.

This document defines the algorithm exactly once. Every consumer references this file by path
and never restates or re-derives the rule.

## Path Normalization

Before comparison, normalize every path string:
- Strip any trailing slash (`"foo/bar/"` becomes `"foo/bar"`).
- Treat paths as repo-relative strings; no filesystem resolution, symlink following, or
  existence check is performed (paths declared in `file_scope` need not exist yet).

## Overlap Rule

Two normalized path entries `pathA` and `pathB` **overlap** if any of the following holds:

1. **Exact match**: `pathA == pathB`.
2. **`pathA` is a directory-prefix ancestor of `pathB`**: `pathB` starts with `pathA + "/"`.
3. **`pathB` is a directory-prefix ancestor of `pathA`**: `pathA` starts with `pathB + "/"`.

This is **directory-prefix matching only** — there is no glob or regex matching. A path entry
that names a directory (with or without a trailing slash, after normalization) is treated as
covering every path beneath it.

### Directory-vs-file example

`.claude/skills/skill-orchestrate/` (a directory entry) overlaps with
`.claude/skills/skill-orchestrate/SKILL.md` (a file entry) under rule 2: the file path starts
with the directory path plus `/`. This is the typical case a file-scope entry is meant to catch —
one task declaring the whole skill directory as its scope, another declaring just the one file
inside it.

## Pairwise-Over-a-Set Pseudocode

To detect overlap across a set of tasks (or phases), each carrying a `file_scope` (or
`files_touched`) array, compare every unordered pair:

```
function normalize(path):
  return path.rstrip("/")

function overlaps(pathA, pathB):
  a = normalize(pathA)
  b = normalize(pathB)
  if a == b: return true
  if b.startswith(a + "/"): return true
  if a.startswith(b + "/"): return true
  return false

function has_overlap(scopeA: list[str], scopeB: list[str]) -> bool:
  for pathA in scopeA:
    for pathB in scopeB:
      if overlaps(pathA, pathB):
        return true
  return false

function find_overlapping_pairs(items: list[{id, file_scope}]) -> list[(id, id)]:
  pairs = []
  for i in range(len(items)):
    for j in range(i + 1, len(items)):
      if has_overlap(items[i].file_scope, items[j].file_scope):
        pairs.append((items[i].id, items[j].id))
  return pairs
```

This is an O(n^2) pairwise scan over the items in a single batch (task-creation batch, or the
phase list of a single task) — it is deliberately not a repo-wide scan and does not attempt to
compare across unrelated batches.

## Consumers

This algorithm has three active callers, at the task, lock-acquisition, and batch-admission
levels (a fourth, phase-level, caller is retired — see below). As of the shared-library
convergence, the lock-acquisition-level and batch-admission-level
callers no longer carry two independent transcriptions of the algorithm — they SPLICE the ONE
physical implementation at `.claude/scripts/lib/file-scope-overlap.sh`
(`FILE_SCOPE_OVERLAP_JQ_DEFS`'s `norm`/`scopes_overlap_first` defs, and the bash
`scopes_overlap()` wrapper around them). Neither caller restates or forks the predicate locally;
both source or splice the same file.

- **Task-level**: Multi-Task Creation Standard Component **4a** (File Footprint Capture and
  Overlap Detection) — see
  `.claude/docs/reference/standards/multi-task-creation-standard.md` — runs this algorithm
  pairwise across a batch of proposed tasks' `file_scope` entries and auto-adds a serializing
  `dependencies[]` edge on overlap.
- **Phase-level (retired)**: this level's caller, `infer_from_file_overlap(phase, phases)`, lived
  only in the now-deleted per-mode team-implement skill's own Stage 5, and had no other caller.
  No successor application of this algorithm exists at the phase level; a plan's declared
  dependencies are the sole mechanism deciding which phases may run in parallel.
- **Lock-acquisition-level**: `.claude/scripts/task-lock.sh`'s `cmd_acquire`, via the shared
  `scopes_overlap()` function sourced from `lib/file-scope-overlap.sh` (lazily, on first use —
  see `task-lock.md` for why this sourcing is deferred rather than unconditional), checks the
  acquiring task's `file_scope` against every OTHER currently-held lock's `file_scope` repo-wide
  (see `task-lock.md`'s "Cross-Task `file_scope` Overlap Check"). Unlike the two callers above,
  this is a live, repo-wide scan at acquire time rather than a one-shot pairwise pass over a fixed
  batch — see the Non-Goals note below on scan scope.
- **Batch-admission-level**: `.claude/scripts/orchestrate-batch-admit.sh` checks each candidate
  task's `file_scope` against every non-terminal task in `specs/state.json` — one read, no
  filesystem scan — closing the gap the task-level and phase-level callers leave open for tasks
  created in *separate* batches with no `dependencies[]` edge between them, and that the
  lock-acquisition-level caller leaves open for a non-terminal, unlocked, out-of-batch task (it
  only sees currently-held locks). Splices `FILE_SCOPE_OVERLAP_JQ_DEFS` directly into its
  `jq -n --slurpfile` program — the SAME shared defs `scopes_overlap()` wraps above, not an
  independent copy. Consumer: `scripts/orchestrate-cycle-plan.sh` step 4.5 (per-cycle
  eligibility gate). See
  `docs/architecture/batch-admit-schema.md` for the verdict schema this caller emits. **As of
  `orchestrate-batch-admit-v5`**: the comparison SET this caller scans against is unchanged (still
  every non-terminal task in `specs/state.json`, and this document's `overlaps(pathA, pathB)`
  predicate is applied identically to every pair); what changed is a downstream disposition filter
  over an already-detected `cross_batch` overlap (block only when the colliding task carries
  execution evidence, else admit with an advisory) — a comparison-set/disposition change entirely
  outside this document's overlap-predicate and scan-scope scope. See
  `context/patterns/batch-orchestration-guardrails.md`'s Classification Table for the disposition
  rule and `docs/architecture/batch-admit-schema.md`'s Version History for the full rationale.
- **Self-modification-hazard application** (same caller as above, a further application of this
  same predicate rather than a new matching rule): before the cross-batch comparison above runs,
  `orchestrate-batch-admit.sh` also tests a candidate's own `file_scope` against a fixed, declared
  list of orchestrator-critical paths (`context/reference/orchestrator-critical-paths.json`),
  using this document's identical `overlaps(pathA, pathB)` predicate — exact match or either-side
  directory-prefix containment. The only difference from the callers above is what the candidate
  is compared AGAINST (a static declared list rather than other tasks' `file_scope`); the
  matching rule itself is unchanged. See
  `context/patterns/batch-orchestration-guardrails.md`'s "Self-Modification Hazard" section for
  the rationale behind the declared list, and `docs/architecture/batch-admit-schema.md` for the
  `self_modifying` verdict field this application produces.
- **Session-registry application** (a further application of this same predicate, not a new
  matching rule — same shape as the self-modification bullet above, but consumed by BOTH the
  lock-acquisition-level and batch-admission-level callers rather than by
  `orchestrate-batch-admit.sh` alone): `task-lock.sh`'s `cmd_acquire` and
  `orchestrate-batch-admit.sh` both test a candidate's `file_scope` against the LIVE registered
  sessions' own precomputed, unioned `file_scope` (via `task-lock.sh session-list` and the shared
  `session_contention()`/`edge_connected_nums()` jq defs, also spliced from
  `lib/file-scope-overlap.sh`). The only difference from the callers above is what the candidate
  is compared AGAINST (a session's own unioned scope, filtered by D4's three liveness/self/edge
  exclusions, rather than another task's declared `file_scope` or a static critical-path list);
  the directory-prefix matching rule itself is unchanged. See "Three Contention Inputs" below for
  the full three-input asymmetry statement, `task-lock.md`'s Session-Registry Reader Contract for
  the reader-side detail, and `docs/architecture/batch-admit-schema.md` for the `session_active`
  verdict field this application produces on the batch-admission side.

All four callers reference this document by path; none restates the normalization or overlap
rule inline. Two of the four (lock-acquisition-level, batch-admission-level) additionally share
ONE physical predicate implementation rather than independently transcribing it, and both apply
the predicate a second and third time — via the self-modification and session-registry
bullets above — against inputs other than another task's declared `file_scope`.

## Three Contention Inputs

The lock-acquisition-level and batch-admission-level callers together consult THREE bounded
contention inputs, which are NOT three interchangeable instances of the same thing — each has
distinct semantics, and a reader should not assume symmetry between them:

1. **Held locks** (`task-lock.sh`'s currently-held `.lock/holder.json` entries, consumed ONLY by
   `cmd_acquire`): a liveness/confidence signal that supplies NO scope data of its own —
   `holder.json` carries no `file_scope` field. The other side's scope is always re-fetched from
   `specs/state.json` via `get_file_scope`, meaning a held lock can only ever CORROBORATE a
   collision `specs/state.json` could already reveal; it never independently discovers one.
2. **The session registry** (`specs/.sessions/*.json`, consumed by BOTH `cmd_acquire` and
   `orchestrate-batch-admit.sh` via `task-lock.sh session-list`): the ONLY input carrying its own
   precomputed, unioned `file_scope`, independent of any single task's `state.json` entry — a
   session's `file_scope` is the UNION across every task number it covers, not one task's
   declared scope. This is what lets it detect contention `state.json` alone cannot: a session
   actively working multiple tasks whose combined footprint overlaps a candidate, even when no
   single covered task's OWN declared `file_scope` would.
3. **Non-terminal `state.json` tasks** (consumed by both callers — `cmd_acquire`'s held-lock
   comparison re-fetches from here, and `orchestrate-batch-admit.sh`'s collision scan reads it
   directly): the BROADEST input (every non-terminal task, not just ones currently locked or
   covered by a live session) but also the LEAST live — a task can be non-terminal in
   `state.json` with no lock held and no session covering it (nothing actively working on it
   right now), which is exactly the residual invisibility gap
   `context/patterns/batch-orchestration-guardrails.md` names and the session-registry input
   above only partially closes (see that document's own statement of what remains open).

**D5 — no held-lock scan added to `orchestrate-batch-admit.sh`**: input 1 (held locks) is
consumed only by `cmd_acquire`, which already consumes it. Adding a held-lock scan to
`orchestrate-batch-admit.sh` would require a repo-wide filesystem walk of every `.lock/`
directory — directly contradicting that script's own "no repo-wide filesystem walk of any kind"
invariant — for ZERO new detections, since input 1 supplies no scope data `specs/state.json`
(input 3) does not already supply. The convergence for input 1 is therefore definitional (this
document now names all three inputs and their asymmetric semantics in one place), not a new
scan.

## Non-Goals

- No glob or regex matching (e.g. `*.lua`, `**/test_*`) — only literal directory-prefix
  containment.
- No filesystem validation of declared paths.
- No opinion on scan scope: this document defines the overlap PREDICATE only
  (`overlaps(pathA, pathB)` and its pairwise-set application), not how widely a caller applies
  it. The task-level and phase-level callers apply it within a small, already-collected batch (a
  creation batch, or a task's phase list); the lock-acquisition-level caller applies
  it repo-wide, scanning every currently-held lock in `specs/` at acquire time; the
  batch-admission-level caller applies it repo-wide via a single `specs/state.json` read,
  comparing against every non-terminal task regardless of lock or batch membership; the
  session-registry application (both callers) applies it via one bounded,
  dedicated-directory glob of `specs/.sessions/*.json` — bounded by the number of currently
  registered sessions, never a repo-wide filesystem walk. All four scan-scope shapes are in scope
  for this algorithm — each caller chooses its own scan scope, and this document is not extended
  or forked to accommodate the difference.
