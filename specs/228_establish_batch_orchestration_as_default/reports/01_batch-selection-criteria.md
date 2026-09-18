# Research Report

**Task**: 228 - Establish batch orchestration as the documented default, with batch-selection
criteria and an explicit conflict rule
**Started**: 2026-09-18T15:58:00Z
**Completed**: 2026-09-18T16:30:00Z
**Effort**: medium (documentation-only, no script/predicate changes)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/context/patterns/multi-task-operations.md`,
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`,
  `agent-system/extensions/core/commands/orchestrate.md`,
  `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/core/index-entries.json`, `specs/state.json` (task 228's own metadata)
**Artifacts**:
- This report: `specs/228_establish_batch_orchestration_as_default/reports/01_batch-selection-criteria.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- A grep across the three candidate files for batch-selection guidance confirms zero hits, as the
  task description reports; the gap is real, not already covered elsewhere.
- **Recommendation: the canonical home is a new section in
  `batch-orchestration-guardrails.md`**, not a new file and not a new section in
  `multi-task-operations.md`. Reasoning is below (Findings > Canonical Home Decision).
- **Recommendation: dominance order for the three selection criteria is Shared File Territory >
  Topic Cohesion > Graph Shape (width)**, with an explicit, ready-to-use rule for each of the
  three pairwise conflicts. Full drafted section text is included below, ready for the plan to
  drop in with minimal editing.
- Two pointer edits are needed (`merge-sources/claudemd.md`'s "Multi-task syntax" paragraph and
  `commands/orchestrate.md`'s Constraints bullet) plus one wording fix in
  `multi-task-operations.md`'s Overview ("common case" framing).
- No script, predicate, or dispatch-path change is implicated anywhere in this research; the task
  is documentation-only, matching its own scope statement.

## Context & Scope

Task 228 asks for a single canonical statement establishing that batching related open tasks into
one `/orchestrate N[,N-N]` invocation is the *normal* way to work this system — not a
throughput-only power feature — together with an explicit, conflict-resolving rule for choosing
which tasks belong in one batch. The task explicitly declines to pre-commit to a canonical home
among three candidates (a new file, a new section in `multi-task-operations.md`, or a new section
in `batch-orchestration-guardrails.md`) and requires the decision, plus the actual selection-rule
content, to come out of this work.

Task 228's own declared `file_scope` (read from `specs/state.json`) is:
```
agent-system/extensions/core/context/patterns/multi-task-operations.md
agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md
agent-system/extensions/core/merge-sources/claudemd.md
agent-system/extensions/core/commands/orchestrate.md
```
Notably, this list contains **no new file** — only the two candidate pattern files and the two
pointer-carrying files named in the task description. This is a signal (not a proof) that the
task's own author anticipated the "new section in an existing file" outcome over "new file";
Findings below independently arrive at the same conclusion from register/audience analysis.

Explicitly out of scope (per the task description, respected throughout this research): the
shared-tree-vs-isolated-worktree decision, dispatch-brief content for informing concurrent
agents, and any machine derivation of "shared file territory" (owned by the separate
file-scope-lifecycle topic, which has open sibling tasks in `specs/state.json` addressing
declaration granularity, backfill, and absent-scope admission posture). This research does not
touch any of those.

## Findings

### Confirmed: the guidance gap is real

`grep -i` for "which tasks to batch", "choose", "batch together", "group related" across
`multi-task-operations.md`, `batch-orchestration-guardrails.md`, and `commands/orchestrate.md`
returns no selection-criteria content. Both pattern files are rich in *admission* and
*mechanism* guidance (what happens once a batch is proposed) but say nothing about *composition*
(which tasks a human or an `/orchestrate` invocation should name together in the first place).

### `commands/orchestrate.md` already states the mechanism is uniform

Line 24 (Constraints section): "The loop uses dependency-aware wave dispatch, uniformly for a
batch of one task or many." This is the load-bearing sentence the task description cites, and it
confirms the *capability* is not in question — only the framing. This is the natural anchor point
for a one-line pointer to the new canonical section (see Recommended Edits below).

### `multi-task-operations.md`'s Overview frames single-task as "the common case"

The file's own Design Principles bullet reads: "Single-task input falls through to existing flow
unchanged (zero overhead for common case)" — literally naming single-task the common case in the
document that defines the multi-task mechanism. This directly contradicts a batch-as-default
posture and is named explicitly in the task's Acceptance criteria as needing to change.

Additional observation, **out of the strict acceptance requirement but worth flagging for
planning**: the file's own Overview paragraph is now stale in a second way — it describes
`/research`, `/plan`, and `/implement` as the commands this pattern extends, but Section 6's own
"Superseded note" states those three commands (and the skill layer they dispatched to) have since
been deleted, leaving `/orchestrate` as the sole multi-task-capable entry point. The task's
Acceptance criteria only requires fixing the "common case" phrase, not a full Overview rewrite, so
this is recorded as an optional adjacent cleanup rather than something this task's plan must do.

### Canonical Home Decision: `batch-orchestration-guardrails.md`, not a new file, not `multi-task-operations.md`

Three considerations converge on the same answer:

1. **Register/audience match.** `multi-task-operations.md` states its own audience in its header:
   "Command developers implementing multi-task support." Its content is procedural —
   `parse_task_args()` pseudocode, batch-validation bash, git-commit-format templates,
   consolidated-output table layouts. Selection *criteria* for humans deciding what to type into
   one `/orchestrate` invocation is a different register entirely: normative guidance for an
   operator, not an implementation spec for a command author.
   `batch-orchestration-guardrails.md`, by contrast, already states in its own opening paragraph
   that it documents "principles... not mechanisms" and its own "Related Documents" closing
   section says explicitly: "This document states principles only. The mechanisms are defined,
   exactly once each, elsewhere." Selection guidance is exactly this kind of principle statement,
   not a mechanism.
2. **Existing normative-rule style already present.** `batch-orchestration-guardrails.md` already
   contains sections written in the same voice a selection-criteria section needs: "## Blocking
   vs. Advisory: The Criterion", "## Non-Negotiables", "the normative principle this repository
   holds every admission gate to." A new "how to choose a batch" section slots into this existing
   style without introducing a new voice to the corpus.
3. **Thematic adjacency, not just formal similarity.** The task description's own strongest
   argument for batch-as-default — the collision-visibility argument (admission gates can only
   compare tasks they can see together) — is a direct extension of
   `batch-orchestration-guardrails.md`'s existing "Three Existing Admission Layers" analysis,
   which already explains exactly this scan-scope limitation for the *admission* side. Selection
   criteria is the natural human-facing counterpart one abstraction level up: admission decides
   whether a *proposed* batch is safe; selection guidance decides which tasks to *propose*
   together in the first place so that admission has something worth checking.

A new standalone file (`context/patterns/batch-selection.md`) was considered and rejected: it
would duplicate `batch-orchestration-guardrails.md`'s own stated purpose (principles governing
batch composition) under a new name, fragmenting one topic across two files with an unclear
boundary between them — exactly the "second copy" outcome the task's Acceptance criteria warns
against ("merge-sources/claudemd.md and commands/orchestrate.md carry pointers, never second
copies" implies the same anti-fragmentation intent applies between the two pattern files too).

### Register check for `index-entries.json`

Both `multi-task-operations.md` and `batch-orchestration-guardrails.md` are already indexed with
`topics: ["orchestration"]` and `load_when.commands: ["/orchestrate"]`. Adding a section to
`batch-orchestration-guardrails.md` requires only a `line_count` and (optionally) `keywords`
update to its existing index entry (adding e.g. `"selection"`, `"batch-composition"`) — no new
index entry, no new topic, no new load_when wiring. This is a smaller, lower-risk footprint than
introducing a new file, which would need its own full index entry.

## Drafted Content: Ready-to-Use Section for `batch-orchestration-guardrails.md`

The text below is drafted to the file's existing voice and heading conventions and is intended to
be inserted as a new top-level `##` section — placement recommendation: immediately after the
file's opening paragraph and before "## The Three Existing Admission Layers", since selection
(which tasks to propose together) logically precedes admission (whether the proposed batch is
safe to dispatch).

---

> ## Batching Is the Default: Selection Criteria and Conflict Resolution
>
> `/orchestrate N[,N-N]` performs dependency-aware wave dispatch uniformly for a batch of one task
> or many (see `commands/orchestrate.md`'s Constraints section). Because the mechanism is already
> uniform, batching related open tasks into ONE `/orchestrate` invocation is the normal way to
> work this system, not a specialized throughput optimization reserved for large backlogs. A
> single-task invocation remains fully correct and unpenalized — it is simply the batch-of-one
> case of the same mechanism, not a separate default posture.
>
> ### Why batch-as-default, not batch-as-optimization
>
> The strongest argument for batching is not throughput — it is collision visibility. The three
> admission layers documented above (creation-time overlap, runtime wave/cycle-split, lock
> acquisition) can only compare tasks they can see together, within one invocation's candidate set
> or the currently-held-lock set. Two related tasks dispatched from two separate `/orchestrate`
> invocations are mutually invisible to every in-batch check — nothing retroactively notices they
> should have been serialized. Batching is therefore the mechanism by which a real collision
> becomes checkable at all; running related tasks apart does not avoid the collision, it only
> removes the machinery's ability to see it.
>
> ### The three selection criteria
>
> Three criteria inform which open tasks belong in one batch, and they do not always agree:
>
> - **Shared file territory** — tasks whose declared `file_scope` (or otherwise known intent)
>   overlaps in the files they touch.
> - **Topic cohesion** — tasks sharing a `topic` field in `specs/state.json`, so one agent's
>   research or implementation context warms the next.
> - **Graph shape** — the shape of the batch's intra-batch dependency graph: a single connected
>   component drains cleanly wave-by-wave, while a set of mutually independent tasks maximizes
>   wave-1 width and therefore concurrency.
>
> ### The dominance rule
>
> **Shared file territory > topic cohesion > graph shape (width).** Apply in this order:
>
> 1. **Shared file territory is mandatory, never optional.** If two open, non-terminal candidate
>    tasks touch overlapping files, batch them together whenever both are realistic candidates for
>    this invocation — even when doing so collapses the batch to width 1 (full serialization) and
>    gains nothing from parallel dispatch except collision visibility. That visibility is a
>    correctness property, not a throughput optimization, so it outranks width every time the two
>    disagree.
> 2. **Topic cohesion is the tie-breaker for filling out a batch, never a reason to exclude a
>    territory-mandatory task.** Once every territory-mandatory member is included, prefer adding
>    same-topic idle candidates over unrelated ones when choosing which additional tasks to
>    include (subject to the batch-size cap) — shared topic context reduces re-discovery cost for
>    the dispatched agent with no downside, since topic-mates with no territory overlap and no
>    dependency edge dispatch in the same wave regardless. Topic cohesion never forces
>    serialization on its own; it only shapes which independent tasks get proposed together.
> 3. **Graph shape / width is the residual objective**, applied within whatever candidate set
>    rules 1-2 already produced. Prefer a batch whose intra-batch dependency graph is either fully
>    connected (drains cleanly across waves) or fully independent (maximizes wave-1 concurrency).
>    Avoid a batch that is neither — a handful of chained tasks alongside a handful of unrelated
>    singletons gets neither benefit: the chain still serializes across waves while the singletons
>    gain nothing from being batched alongside it.
>
> **Worked resolution of the three pairwise conflicts:**
>
> | Conflict | Winner | Why |
> |---|---|---|
> | Shared file territory vs. graph shape (width) | Territory | A collision left unbatched is invisible to every admission layer; width is a throughput preference, territory-driven serialization is a correctness requirement. |
> | Shared file territory vs. topic cohesion | Territory (rarely actually conflicts) | Topic-cohesive tasks that also share territory were already going to be forced together by territory alone (or by the creation-time auto-`dependencies[]` edge — see `docs/reference/standards/multi-task-creation-standard.md` Component 4a); topic cohesion never has a reason to exclude a territory-mandatory task, since excluding it would only lose the visibility gain for no benefit. |
> | Topic cohesion vs. graph shape (width) | Situational, bounded by the batch-size cap | Same-topic tasks with no territory overlap and no dependency edge cost nothing to batch together — they dispatch in the same wave either way. The real trade-off arises only at the batch-size cap: when choosing which idle candidates fill the remaining slots, prefer completing a topic group over padding width with unrelated singletons, but yield immediately if a topic-mate is not actually dispatch-safe (blocked, terminal, or would itself trip an admission gate). |
>
> ### Territory is a human judgment, not a machine derivation (scope note)
>
> This document's admission layers derive collisions mechanically from `file_scope` (see "The
> Three Existing Admission Layers" above); the selection criterion above is different — it asks a
> human proposing a batch to recognize likely shared territory *before* creation-time auto-edges
> or runtime admission ever run, since neither mechanism exists to choose which tasks a human
> types into one `/orchestrate` invocation in the first place. This section does not specify or
> depend on any machine derivation of "shared territory" as a selection input — `file_scope`
> declaration granularity, backfill, and absent-scope admission posture are owned by the
> file-scope-lifecycle topic and are out of scope here. Where `file_scope` is undeclared or
> coarse, apply this criterion as ordinary human judgment about which tasks are likely to touch
> the same code, not as a lookup against a machine-computed set.
>
> ### Worked example
>
> Five open tasks share `topic: "x"`. Two of them (`A`, `B`) declare overlapping `file_scope`; a
> third (`C`) depends on `A`; `D` and `E` are unrelated to any of the other four and to each
> other. Applying the rule above: `A` and `B` are mandatory together (territory). `C` joins
> because it is topic-cohesive and its dependency edge to `A` means it cannot dispatch usefully
> apart from the same invocation that resolves `A`. `D` and `E` are optional adds —
> topic-cohesive and territory-clean, so batching them costs nothing and both widen wave 1. The
> resulting batch, `/orchestrate A,B,C,D,E`, is a single invocation whose intra-batch graph is
> `{A: [], B: [], C: [A], D: [], E: []}` — clean, wave-1-wide except for `C`'s one-wave wait on
> `A` — and every territory-sharing pair is visible to the admission layers.

---

## Recommended Edits (pointer sites and wording fix)

These are the three surgical edits the plan/implementation should make; none touches a script,
predicate, or dispatch path, matching the task's explicit "framing and guidance only" scope.

1. **`multi-task-operations.md`, Overview, Design Principles bullet** — reword to remove the
   "common case" framing while preserving the true technical claim:
   - Current: `Single-task input falls through to existing flow unchanged (zero overhead for common case)`
   - Suggested: `Single-task input falls through to existing flow unchanged (no special-casing overhead for a batch of one)`

2. **`commands/orchestrate.md`, Constraints section, line 24** — append a pointer after the
   existing sentence:
   - Current: `The loop uses dependency-aware wave dispatch, uniformly for a batch of one task or many.`
   - Suggested addition (same bullet or a following one): `See context/patterns/batch-orchestration-guardrails.md's "Batching Is the Default" section for which tasks to batch together.`

3. **`merge-sources/claudemd.md`, "Multi-task syntax" paragraph** — append a pointer after the
   existing `multi-task-operations.md` pointer:
   - Current ends with: `...for the rest of that run. See \`.claude/context/patterns/multi-task-operations.md\` for the full specification.`
   - Suggested addition: `For which tasks to batch together, see \`.claude/context/patterns/batch-orchestration-guardrails.md\`'s "Batching Is the Default" section.`

4. **`index-entries.json`** — update `batch-orchestration-guardrails.md`'s existing entry:
   bump `line_count` to reflect the new section's added lines, and optionally add
   `"selection"`/`"batch-composition"` to its `keywords` array. No new entry is needed (see
   Findings > Register check above).

## Decisions

- Canonical home: new section in `batch-orchestration-guardrails.md` (not a new file, not
  `multi-task-operations.md`). See Findings > Canonical Home Decision for the three converging
  reasons.
- Dominance order for the three selection criteria: Shared File Territory > Topic Cohesion >
  Graph Shape (width), with the three pairwise conflict resolutions spelled out in the drafted
  section's table above.
- The territory criterion is documented explicitly as human judgment, not a machine derivation,
  with an explicit forward-pointer to the file-scope-lifecycle topic — this keeps the new section
  from overstepping into that topic's ownership while still satisfying the task's requirement to
  cite shared file territory as a selection criterion.

## Risks & Mitigations

- **Risk**: a future reader might read the new section's "mandatory" territory language as
  implying a *machine* check exists to enforce co-batching. **Mitigation**: the drafted section's
  "Territory is a human judgment" subsection explicitly disclaims this and names the owning topic.
- **Risk**: `multi-task-operations.md`'s Overview is stale in a second way (references deleted
  `/research`/`/plan`/`/implement` commands) beyond the one phrase the Acceptance criteria names.
  **Mitigation**: flagged above as an optional adjacent cleanup, explicitly out of this task's
  required scope — the plan should decide whether to fold it in or leave it for a separate task,
  rather than silently expanding scope.
- **Risk**: placement of the new section (immediately after the opening paragraph, before "The
  Three Existing Admission Layers") could be judged to disrupt the existing document's flow.
  **Mitigation**: this is a placement judgment call for the implementer; the content itself does
  not depend on exact placement, and an alternative (appending near the end, cross-referenced from
  the top) would satisfy the same Acceptance criteria equally well.

## Context Extension Recommendations

None — this is a meta task whose own deliverable directly extends
`agent-system/extensions/core/context/patterns/`; there is no separate context-documentation gap
outside this task's own scope to flag.

## Appendix

### Search queries used

- `grep -i "which tasks to batch\|choose\|batch together\|group related" context/patterns/multi-task-operations.md context/patterns/batch-orchestration-guardrails.md commands/orchestrate.md` (0 hits on the selection-guidance phrases specifically; general prose hits on "choose"/"group" unrelated to batch selection)
- `grep -n "batch-orchestration-guardrails\|multi-task-operations" index-entries.json`
- `grep -n "granularity" context/contracts/territory.md docs/architecture/orchestrate-state-machine.md`
- `grep -rn "file-scope-lifecycle" specs/state.json`

### References

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (1098 lines;
  read in full)
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` (667 lines; read in
  full)
- `agent-system/extensions/core/commands/orchestrate.md` (309 lines; read in full)
- `agent-system/extensions/core/merge-sources/claudemd.md` (lines 95-120 read for the
  `/orchestrate` table row and "Multi-task syntax" paragraph)
- `agent-system/extensions/core/index-entries.json` (entries for both candidate pattern files)
- `specs/state.json` (task 228's own metadata: `file_scope`, `topic`, `title`; sibling
  file-scope-lifecycle-topic task descriptions for the granularity-under-revision context)
