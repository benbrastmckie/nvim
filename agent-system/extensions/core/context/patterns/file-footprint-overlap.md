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

### Reserved sentinels

A `file_scope` entry need not name a real path at all. A **reserved sentinel** is a fixed,
slashless literal token (e.g. `` `__WHOLE_TREE__` ``, declared once as a named constant in
`scripts/lib/file-scope-overlap.sh`'s `whole_tree_claim_sentinel` def) that a producer declares
to make an otherwise-undeclarable scope claim honest and greppable, without inventing a new
field or a new matching rule.

A slashless token is structurally **inert against any real path** under both predicates on this
page, as a direct consequence of the rules already stated above, not a special case carved out
for it:

- **Overlap** (the three-clause rule above): a reserved token can never satisfy clause 1 (no
  real path is spelled identically to it), clause 2 (it contains no `/`, so no real path can
  start with `token + "/"`), or clause 3 (the reverse of clause 2). It is exactly as inert
  against a real path as any other ordinary, non-prefix-related string would be.
- **Containment** (the one-directional predicate below): nothing is ever "under"
  `` `__WHOLE_TREE__`/ `` by construction, for the identical reason clause 2 above fails — a
  slashless entry has no `"/"`-suffixed prefix any real path could start with.

Two DIFFERENT tasks each declaring the SAME reserved token DO produce an ordinary Overlap exact
match against EACH OTHER (clause 1: the two literal strings are identical) — this is not a false
positive carved out of the rule; it is the rule applying normally to two equal strings, and it is
exactly the detection signal the sentinel's consumer (`orchestrate-batch-admit.sh`'s
`whole_tree_claim` admission dimension — see `docs/architecture/batch-admit-schema.md` and
`context/patterns/batch-orchestration-guardrails.md`'s "Whole-Tree Regeneration Hazard" section)
reads to recognize a same-claim pair.

**This inertness is what makes the convention adoptable before its gate ships.** Because a
reserved sentinel is provably inert against every real path under both predicates, declaring it
in a plan's `Files to modify` block today has ZERO behavioral effect on any consumer that does
not specifically look for it — no false collision, no false containment, no change to any
existing verdict. A plan may therefore adopt the convention before the admission dimension that
reads it exists at all, and a plan written before the convention existed simply declares
nothing, with no migration or backfill required either way.

## Containment vs. Overlap

**Containment** is a distinct, one-directional predicate, siblings to (never a replacement for)
the symmetric Overlap Rule above: a concrete path `P` is **covered by** a single declared scope
entry `S` when, after this document's own normalization, any of the following holds:

1. **Exact match**: `P == S`.
2. **`S` is a directory-prefix ancestor of `P`**: `P` starts with `S + "/"`.
3. **(extension) `S` is a glob pattern that matches `P`**: `S` contains a glob metacharacter
   (`*`, `?`, or `[`), and `P` matches `S` under ordinary bash pattern matching (`[[ "$P" ==
   $S ]]`, unquoted right-hand side).

Containment answers "is this one concrete path inside that one declared scope?" — the question a
consumer with a single dirty file path and a single task's `file_scope` array needs answered.
Overlap answers a different, symmetric question — "do these two scopes, as sets of paths, share
any territory?" — which is what serializing two tasks' declared scopes against each other needs.
Neither subsumes the other: containment is deliberately one-directional (clause 2 only tests `S`
as an ancestor of `P`, never the reverse — an entry nested *inside* the concrete path does not
make the path "covered"), and only containment carries the glob-matching extension in clause 3.

**The glob clause is containment-only.** It is an additive extension bolted onto the
one-directional predicate above and does **not** apply to the symmetric Overlap Rule, which
remains glob-free exactly as stated in the Non-Goals section below. A small minority of live
`file_scope` entries (observed: 3 of 249) use a glob shape such as
`agent-system/extensions/*/agents/**`; without this clause, containment would silently fail to
recognize a concrete path as covered by such an entry.

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

- **Whole-tree-claim application** (same caller as the cross-batch comparison above, a further
  application of this document's Overlap predicate against a RESERVED SENTINEL rather than a
  real path — see "Reserved sentinels" above): `orchestrate-batch-admit.sh`'s
  `whole_tree_claim` admission dimension is reached by inspecting WHICH path the cross-batch
  collision scan's own `$hit` already matched on — when it is the reserved
  `` `__WHOLE_TREE__` `` token rather than a real declared path, the verdict is shaped
  differently (its own `defer_reason`, fields, and `--phase-map` exemption), but the matching
  rule that PRODUCED `$hit` is the identical Overlap predicate, unchanged. See
  `context/patterns/batch-orchestration-guardrails.md`'s "Whole-Tree Regeneration Hazard: The
  Sixth Admission Dimension" section for the full rationale and the rejected zero-code
  alternative, and `docs/architecture/batch-admit-schema.md` for the `whole_tree_claim` verdict
  shape this application produces.

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

- No glob or regex matching in the symmetric **Overlap Rule** (e.g. `*.lua`, `**/test_*`) — only
  literal directory-prefix containment between two scopes. The one-directional **Containment**
  predicate (see that section above) is the sole, deliberate exception: its clause 3 glob
  extension exists because a caller comparing one concrete dirty path against one declared scope
  has no symmetric-overlap use case to protect, and the ~1% of live `file_scope` entries that are
  glob-shaped would otherwise never be recognized as covering anything.
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
- No cross-repository scope: when two repositories' task spaces file work against one shared
  source store (see `rules/source-store-deploy-boundary.md`), this predicate and every consumer
  wired to it see only the invoking repository's own `specs/state.json` — a correctly-sited
  actor in each repository can claim the same source-store file with no `dependencies[]` edge and
  no overlap finding anywhere. Accepted risk, detected manually; see the
  `### Cross-Repository Scope -- Adjudicated Limitation` subsection below for the adjudication.

### Cross-Repository Scope -- Adjudicated Limitation

**The counterexample.** Commit `f49576632` ("lean: record four Lean 4 measurement and syntax
gotchas", five files, +105 lines) landed from an orchestrate conclusion-stage channel (a)
dispatch running in a second repository whose deployed `.claude/` tree is produced from this
source store. Two records in this repository had been filed roughly an hour earlier from the
identical four issue-log entries (`iss_1791886589088_do8mDR`, `iss_1791914943297_AoBxvm`,
`iss_1791928136829_T0iDVg`, `iss_1791921588196_IcZKne`) and were still unstarted when the
dispatch ran, with declared `file_scope` entries covering
`context/project/lean4/domain/lean4-syntax.md` and
`context/project/lean4/patterns/dependency-tracing.md` — both among the five files `f49576632`
edited. Commit `4311617a2` subsequently annotated both records with what had landed. Neither
this repository's overlap gate nor its `dependencies[]` graph produced any finding: both are
scoped to this repository's own `specs/state.json`, and the colliding dispatch belonged to the
other repository's task space.

**The ruling.** A now-archived record ruled the orchestration queue's scope, verbatim:

> SCOPE -- RULED: PER-REPO. One queue per repository, living beside the existing session
> registry. No cross-repo global queue and no global-ready schema requirement: file_scope
> conflicts are inherently per-repo, so a global queue would carry no information the per-repo
> one lacks.

**The adjudication.** Examined against the counterexample above and upheld on 2026-11-06: no
cross-repo gate, global queue, or global-ready schema is built. The cross-repository entry in
`## Non-Goals` above states the resulting limitation as an accepted, manually-detected risk, not
a design gap awaiting a future mechanism — the next paragraph states why a mechanism would not
have closed it regardless of scope.

**What no mechanism reaches.** An orchestrate conclusion-stage channel (a) dispatch carries no
task record of its own in either repository's terms — it implements directly from issue-log
entries. A gate or graph keyed on task records or on `dependencies[]` cannot see such a dispatch
by construction, cross-repo or not. This is independently corroborated by measured occurrences
against the same declared territory: the four-note landing itself (`f49576632`), which included
the `dependency-tracing.md` section named in one of the two colliding records' own appendix, and
a second, same-repository channel (a) dispatch (commit `9a43026d2`) that later repaired index
metadata inside the identical declared territory while both records still sat unstarted, with no
task record of its own either — confirming the record-less shape recurs independent of the
cross-repo element. Any future proposal in this space must state explicitly what it does about
the record-less case, or state explicitly that it does not cover it.
