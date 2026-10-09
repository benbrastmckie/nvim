# Research Report: Task #344

**Task**: 344 - Carry the batching-by-default doctrine to the point of use, and make a territory
overlap produce a serializing edge rather than a separation
**Started**: 2026-10-09T00:57:33Z
**Completed**: 2026-10-09T01:04:45Z
**Effort**: Large (7 doctrine items + 1 new CLI primitive + 1 spec re-point, all in the
agent-system source store)
**Dependencies**: 280 (completed), 311 (completed) — both satisfied; dogfood batch
`{280, 311, this}` is already down to `{this}` since both predecessors landed.
**Sources/Inputs**: Codebase (agent-system/extensions/core/ source store), live `specs/state.json`
in this repo and in `~/Projects/Logos/Verification`, hands-on execution of
`scripts/validate-state.sh --deep` against synthetic fixtures.
**Artifacts**: This report.
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-task-references-in-deliverables.md.

## Executive Summary

- The doctrine (dominance rule: territory > topic > width) already exists, correctly stated, in
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s "Batching
  Is the Default" section. This task's job is exclusively to carry it to seven specific points of
  use and close two narrow, measured gaps (no narrowness qualifier on Rule 1; no edge-backfill
  primitive) — never to re-derive the doctrine.
- Item 1's defect is confirmed exactly as described: `merge-sources/claudemd.md` line 121 already
  names the guardrails section, but the pointer sits as a trailing clause of a bold
  "**Multi-task syntax**:" label with no heading of its own, directly under the command table —
  verified by reading the file.
- Item 3's structural hazard is confirmed and **re-measured today** (2026-10-09, vs. the
  dispatch's 2026-10-06 measurement): `agent-system/extensions/core/manifest.json` appears in
  `file_scope` for 9 tasks in this repo's `specs/state.json`, of which **4 are still open**
  (281, 282, 313, 347) — down from the originally measured 5, because 3 of the original 9
  (273, 280, 306 or similar) completed in the interim. The mechanism is live and current, not a
  one-off artifact of a stale snapshot. In the consumer repo, task 170
  (`rename_root_books_tooling_dir_to_bookkit`) still declares 135 `file_scope` paths today,
  corroborating Item 3(ii)'s nine-task overlap claim's premise.
- For Item 6(b) (write-time cycle refusal), I built and ran a synthetic two-task mutual-dependency
  fixture against the real `scripts/validate-state.sh --deep`: it emits exactly
  `[FAIL] Dependency cycle detected among project_number(s): 2,1` on a cycle and
  `[PASS] No dependency cycles detected among active_projects` on a clean graph. This confirms the
  reuse path the dispatch demands (shell out to the existing script against a scratch copy of
  `state.json`, never transcribe a second Kahn implementation) is mechanically sound **without
  modifying `validate-state.sh` at all** — which matters because `validate-state.sh` is NOT in
  this task's declared `file_scope`.
- Item 6(a)'s direction rule cannot be a numeric default ("higher task number depends on lower").
  Live counter-evidence: task 274 (lower number, older) and task 312 (lower number, older) both
  carry `dependencies: [... 344]` — the *older* tasks depend on the *newer* one, because 344's
  work is their real prerequisite. The direction must be expressed by the call's own argument
  shape (the positional `task_number` is always the dependent; `--depends-on-add`'s array lists
  its new predecessors), never inferred from task numbering.
- Recommended approach for all seven items, the scope-note ruling, and the `--depends-on-add`
  design are in Findings/Recommendations below.

## Context & Scope

This is a doctrine-placement and primitive-building task, not a doctrine-authoring task. All
edits land in `agent-system/extensions/core/` (the source store) per
`rules/source-store-deploy-boundary.md`; `.claude/**` is never a target. The task's own declared
`file_scope` is:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/patterns/multi-task-operations.md`
- `agent-system/extensions/core/merge-sources/claudemd.md`
- `agent-system/extensions/core/scripts/update-task-status.sh`
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh`

Notably, `scripts/validate-state.sh` and `scripts/lib/*.sh` are **not** declared, which rules out
any solution for Item 6(b) that requires editing `validate-state.sh` (e.g. extracting its inline
Kahn loop into a new shared library file and refactoring `validate-state.sh` to call it) — see
Findings below for the subprocess-based alternative that respects this boundary.

Explicitly out of scope (declared boundaries in the dispatch, independently confirmed by reading
the named files/owners):
- The stale "Batching is not yet supported..." string in `commands/orchestrate.md` and
  `docs/architecture/orchestrate-state-machine.md` (owned elsewhere; not touched).
- `docs/reference/standards/multi-task-creation-standard.md` and Component 4a's cross-batch blind
  spot (owned elsewhere; this task only supplies the edge-writing primitive that owner's own
  "overlaps-N-add-edge" verdict will call).
- `scripts/orchestrate-batch-admit.sh` and its admission verdict schema (owned elsewhere; this
  task changes what gets batched and what the system teaches, never what the runtime admits).
- `context/formats/roadmap-format.md` and any batch-proposal lint (owned elsewhere; this task
  states the posture those authors render).

## Findings

### Item 1 — Always-loaded-layer placement (`merge-sources/claudemd.md`)

Confirmed by direct read: line 121 of `merge-sources/claudemd.md` reads

```
**Multi-task syntax**: `/orchestrate` accepts multiple task numbers using commas and ranges
(e.g., `/orchestrate 7, 22-24, 59`), processed via dependency-aware wave dispatch. See
`.claude/context/patterns/multi-task-operations.md` for the full specification and
`.claude/context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default"
section for which tasks to batch together.
```

This sits directly under the Command Reference table's `/orchestrate` row, with no heading
between it and the table, and the actionable clause ("for which tasks to batch together") is the
tail of a sentence about comma/range *syntax*, not about *posture*. A reader scanning for "when do
I batch" has no heading to stop at; the sentence reads, and is skimmed, as grammar documentation.

**What a fix must add, and why the token cost is justified**: one short, separately-readable
sentence stating the default posture and the overlap-to-edge move, placed so it is visually
distinct from the syntax sentence (its own line, ideally introduced by a bolded lead phrase the
way `**Multi-task syntax**:` itself already is). The consumer repo
(`~/Projects/Logos/Verification/specs/ROADMAP.md`, lines 13–18) already carries exactly this kind
of short, operative statement at its own always-read entry point:

```
- **Batching is the default; shared file territory is a reason to batch, not to separate.** Two
  tasks that touch the same file are not independent work items even if nothing in the DAG says
  so — ... wave dispatch sequences them. A batch that serializes to width 1 is a correct batch.
- **A dependency outside the batch blocks; it does not sequence.** ...
- **Eight tasks per batch** (`MAX_TASKS=8`); a longer list is silently trimmed. ...
```

This is real evidence that a 2–3 line operative restatement is sufficient to carry the posture at
an always-loaded layer, and that the pattern is already proven useful enough to have been
independently reinvented downstream once the doctrine document alone did not reach the point of
use. The token cost is one short paragraph (roughly 60–90 tokens) added once to a file that is
loaded every session regardless of task. That fixed, eager cost is paid back the moment it
prevents even one of the defect classes Item 3 documents below (a mandatory group silently
truncated by `MAX_TASKS`, or a batch composed without noticing an overlap) — each of which costs
an entire wasted orchestration cycle, far more expensive than the one-time read cost. A
pointer-only design has already been tried (it is what exists today) and has not reached the
point of use in practice, by the dispatch's own account; restating it is not redundant, it is the
only version of this content an agent composing an invocation will actually see before deciding
how many tasks to run together.

### Item 2 — Naming the overlap-to-edge operation as the default move

`multi-task-operations.md`'s "File Footprint Overlap as a Serialization Edge" section (§13)
already states the *mechanism*: Component 4a auto-adds a serializing edge for same-batch overlap,
and the runtime wave-split check in `orchestrate-cycle-plan.sh` (step 4.5) covers cross-batch
overlap for tasks already admitted together. What is missing is the *prescriptive* sentence for
the case this task exists to close: two already-existing, separately-created tasks whose
`file_scope` is found to overlap, with no edge yet. Today's doctrine says the overlap is
"mandatory together" but is silent on what the composer should *do* about an unordered pair.

Both the guardrails doc (next to the dominance rule) and `multi-task-operations.md` (next to §13)
need one explicit sentence of the shape: "When an overlap is found between two unordered
candidates, add a serializing `dependencies[]` edge (direction per the rule in Item 6/
`--depends-on-add`) and run them as a sequence in the same invocation — never record the overlap
as a bare exclusion." This is the connective tissue between Items 1, 3, 4, 5, and 6: it is the one
sentence that turns "territory is mandatory" into an actual next action.

### Item 3 — Rule 1's missing narrowness qualifier

Confirmed: `docs/reference/standards/multi-task-creation-standard.md`'s Component 0 carries an
explicit **Narrowness qualifier** —

> "the shared-edit-target signal means a shared *narrow* `file_scope` entry or one named
> acceptance gate/check — not a broad, widely-edited infrastructure file or a directory-root
> scope."

— but the guardrails doc's Rule 1 ("Shared file territory is mandatory, never optional...") has
no equivalent language anywhere in its text. Re-reading Rule 1 in full confirms this: it is
unconditional on the *kind* of file, only on the fact of overlap.

**Re-measured today (2026-10-09)**, both instances the dispatch names:

- *This repo*: tasks declaring `agent-system/extensions/core/manifest.json` in `file_scope`:
  9 total (273, 280, 281, 282, 306, 313, 347, 355, 366), of which **4 remain open**
  (281, 282, 313, 347) — status `not_started` for all four. The other five have completed since
  the dispatch's 2026-10-06 measurement, which is itself evidence the registration-file signal is
  live and churns naturally; a literal Rule 1 would make all currently-open manifest.json-touching
  tasks one mandatory group of 4 today (and was 5+ at measurement time), purely from a shared
  registration file, with no narrower overlap between any specific pair of them.
- This task's own `file_scope` deliberately omits `manifest.json` (per the dispatch's "HOST-SCRIPT
  RULING" for Item 6), which is itself the worked instance of applying a narrowness judgment by
  hand: including it would pull in every other open manifest.json-touching task as "mandatory,"
  inflating the group well past what the task's real edit footprint needs.
- *Consumer repo*: `~/Projects/Logos/Verification/specs/state.json` still shows task 170
  (`rename_root_books_tooling_dir_to_bookkit`, status `not_started`) with 135 `file_scope` entries
  today, corroborating the premise behind Item 3(ii)'s "one rename task ... overlaps nine open
  tasks" claim (a single broad-footprint task can trivially out-overlap the rest of an otherwise
  modest batch).

**The structural consequence is real and mechanically demonstrable**: `MAX_TASKS=8` is enforced in
`docs/architecture/orchestrate-state-machine.md`'s dispatch code as a flat `first N` slice
(`validated_tasks=("${validated_tasks[@]:0:$MAX_TASKS}")`) with no concept of a
"territory-mandatory group" at that layer — the guardrails doc's own "List territory-mandatory
members first" instruction is the *only* thing standing between a literal Rule 1 and a silent,
mid-group truncation. A Rule 1 that can mechanically demand a 9-task (or at measurement time,
5-6-task) mandatory group, with the cap then silently trimming it, is exactly the failure mode
the dispatch describes.

**What Rule 1 needs (both, not either/or)**:
1. A **narrowness test**, mirrored (not duplicated prose — cross-referenced) from Component 0's
   own qualifier: a shared broad/coarse file (a repository-root gate script, a registration
   manifest, a shared README, a CHANGELOG, or any entry that would independently trip
   `validate-state.sh` Check 8's coarse-`file_scope` WARN) does not, by itself, make two tasks
   territory-mandatory under Rule 1. Rule 1 should name this test explicitly rather than leave the
   reader to infer it only applies to "real" overlaps.
2. An explicit **pointer from Rule 1 to the existing cap-aware fallback**: the guardrails doc
   already has the right fallback ("Keep a proposed batch at 8 or fewer... If a single
   territory-mandatory group alone exceeds 8 tasks, it cannot be admitted as one invocation. Run
   it as consecutive batches in dependency order instead...") in its "batch-size cap" subsection,
   but Rule 1 itself does not point to it. Making that connection explicit — rather than leaving
   Rule 1 to read as absolute and the cap subsection as an unrelated footnote — is what keeps the
   two consistent, and satisfies "consistent with the existing truncation-precedence rule" without
   inventing a second fallback mechanism.

### Item 4 — Owner-blocked carve-out

Confirmed as a genuine gap: nothing in the dominance rule or Items 1-3's proposed fixes states
what happens when the would-be predecessor cannot progress (blocked, held, or `[PARTIAL]` behind
something outside any task's control). Applying Rule 1 unconditionally in that case parks a
trivial, ready task behind a permanently-stalled one, for zero visibility gain — the stalled
predecessor is not going to run in this invocation regardless of whether the edge exists.

The dispatch's own cited live instance (two consumer-repo tasks overlapping on five
`components/framed_channel/certificate/*.txt` files, deliberately left unwired) is a worked
example of exactly this carve-out already being applied by hand, without it being written down
anywhere as a rule. The fix: add an explicit carve-out clause immediately after Rule 1 (or as a
numbered exception to it) stating that Rule 1's mandate is suspended when the predecessor is
blocked/held/stuck-`[PARTIAL]` with no resolving task in this system, and that the batch
proposal/rendering (Item 5) must then **state the reason**, not emit a bare exclusion. This is the
one case where separation is the correct, reasoned outcome, and it must look different in the
rendered output from an unreasoned "never with."

### Item 5 — Batch-plan rendering rule

The current convention (bare "never with" notes for unordered overlaps) is not merely weak, it is
measurably wrong in the consumer repo per the dispatch's own account: of observed "never with"
notes checked against `scripts/lib/file-scope-overlap.sh`'s actual overlap predicate, three are
genuinely territory-backed and a fourth is not backed by `file_scope` at all — i.e. the convention
both under-renders genuine overlaps (a bare note instead of an edge+sequence) and over-renders
false ones (excluding a pair that is provably disjoint). I independently confirmed the overlap
predicate lives in exactly one place
(`agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`'s `FILE_SCOPE_OVERLAP_JQ_DEFS`
/ `scopes_overlap_first`), which both `scripts/task-lock.sh` and
`scripts/orchestrate-batch-admit.sh` already consume — so "check against the real predicate" is a
real, reusable, already-centralized check, not a new one this task must build.

**Rendering rule to state**: for an unordered territory overlap, a batch plan or roadmap entry
picks an order and records the serializing edge (Item 6's primitive is how), rendering the pair as
a sequence — never as a bare "never with" note. Where Item 4's carve-out genuinely applies, the
render is a reasoned exclusion (predecessor blocked/held, named), never an unreasoned one. A bare
"never with" note with no stated reason is not an acceptable terminal rendering in either case.

**Boundary respected**: this item states the posture the ROADMAP batch-block grammar and the
batch-proposal lint must render; it does not touch `context/formats/roadmap-format.md` and does
not author that lint — both are out of this task's `file_scope` and are owned by other,
undeclared tasks per the dispatch's explicit boundary.

### Item 6 — The edge-backfill operation (`--depends-on-add`)

**Host-script fit confirmed.** `update-task-status.sh` already has three flags with an identical
validation shape: `--file-scope-add=<json-array>` (restricted to
`operation=postflight && target_status in {research, plan}`), `--research-questions=<json-array>`
(restricted to `operation=postflight && target_status=needs_research`), and
`--hold-reason=<string>` (restricted to `operation=preflight && target_status=hold`). Each
validates eagerly (malformed value is a hard error, not a silent no-op) and each has documented
"no-op status replay" behavior: when the call's `target_status` equals the task's *current*
status (a status no-op), the flag's side effect still fires — e.g. a `--file-scope-add` on an
already-`"researched"` task still unions in the new paths even though no status transition
happens. This is the load-bearing precedent for `--depends-on-add`'s own design, because adding a
dependency edge between two *already-existing* tasks is inherently phase-independent — there is no
natural `operation:target_status` pair that means "just add this edge."

**Recommendation**: restrict `--depends-on-add` to calls where `target_status` equals the task's
*current* status (i.e., it only ever rides the existing no-op-replay branch, by construction —
never also performs a real status transition in the same call). This is a new, explicit
restriction (not reuse of one of the three existing restrictions verbatim), but it is the same
*shape* of restriction the other three already use (a hard validation error naming the required
condition, never a silent fallback), so the "true exact sibling" framing holds at the level of
validation discipline even though the specific gating condition differs because the use case is
genuinely different (an edge-add has no phase to attach to; the other three do).

**(a) Direction rule — cannot be numeric, must be call-shape.** I tested the hypothesis that
direction could default mechanically (e.g. "higher project_number depends on lower") against this
very task's live dependency graph: tasks 274 and 312 (both *lower*, i.e. *older*, than 344) both
carry `dependencies: [...344]` — they depend on the *newer* task, because 344's work (the
edge-writing primitive itself) is their actual prerequisite, regardless of creation order. A
numeric default would get this backwards. The only sound rule is to fix it at the **call
convention**: the script's existing positional `task_number` argument is always the task that
*gains* the new dependency (the dependent); `--depends-on-add`'s JSON array lists the task numbers
it now depends on (the predecessors) — mirroring `dependencies[]`'s own existing field semantics
in `specs/state.json` exactly (an entry's `dependencies` array is what *it* depends on). This
removes ambiguity about how a chosen direction is *expressed*, while leaving the judgment of
*which* task is logically prior to the caller — exactly as Component 0's "Territory is a human
judgment, not a machine derivation" scope note already establishes for the adjacent file_scope
question, and as the dispatch's own "Motivating Instance" (20 edges added by hand, direction
chosen manually) confirms is the status quo this primitive mechanizes, not replaces.

**(b) Write-time cycle refusal — confirmed working via subprocess reuse, no edit to
`validate-state.sh` required.** `validate-state.sh`'s Kahn-algorithm cycle check lives inside its
`--deep` branch (lines ~905-957), reading `active_projects[].dependencies` directly from whatever
`STATE_FILE` argument it is given (it accepts an optional positional `STATE_FILE` path, defaulting
only when omitted). I verified this directly:

```
$ validate-state.sh --deep <scratch-state-with-1-depends-on-2-and-2-depends-on-1>
[FAIL] Dependency cycle detected among project_number(s): 2,1

$ validate-state.sh --deep <scratch-state-with-a-clean-chain>
[PASS] No dependency cycles detected among active_projects
```

This is the reuse path the dispatch requires: `--depends-on-add` builds a scratch copy of
`state.json` with the *candidate* edge already applied, shells out to
`validate-state.sh --deep <scratch-file>`, greps specifically for the
`"Dependency cycle detected among project_number(s):"` line (not the script's overall pass/fail,
since unrelated pre-existing WARN/FAIL findings elsewhere in a real `state.json` must not block an
otherwise-valid edge add), and refuses (nonzero exit, naming the cycle from that exact line) when
found; otherwise it proceeds to the real write via `state-write.sh`. This satisfies "consume
`validate-state.sh`'s existing Kahn implementation; do not transcribe a second copy" **without
editing `validate-state.sh`** — which matters concretely here because `validate-state.sh` is not
in this task's declared `file_scope`, so a design requiring its edit would be out of bounds. An
alternative (extract the Kahn loop into a new `scripts/lib/dependency-cycle-check.sh` and refactor
`validate-state.sh` to call it) would be architecturally cleaner in isolation but requires editing
`validate-state.sh`, which this task cannot do; the subprocess-reuse design above achieves the same
non-duplication guarantee while staying inside the declared scope, and should be preferred for
that reason.

**(c) Dry-run drain confirmation.** `orchestrate-cycle-plan.sh --dry-run --state-file F
<task_number> [<task_number> ...]` already exists and is self-contained (its own usage text
confirms `--session` is not required under `--dry-run`), and its documented stderr table exists
specifically "for a human running `/orchestrate --dry-run` at a terminal." This is the right tool
for confirming a newly-edge-backfilled batch actually drains, but it operates over an explicit
*batch* of task numbers, not over the single edge `--depends-on-add` just wrote — so I recommend
this be wired as a **documented verification step** (in `--depends-on-add`'s own usage comment and
in the new fixture test suite), not as something `--depends-on-add` invokes automatically on every
call: the two tasks it just linked may be a small part of a larger intended batch, and only the
caller (human or agent performing the backfill) knows the full candidate set to dry-run against.

**Test fixtures.** `scripts/tests/test-update-task-status.sh` already establishes the fixture
pattern to extend: a `mktemp -d` isolated workdir with a real deployed script dependency chain
copied in plus a private `specs/state.json`, `pass()`/`fail()`/`info()` counters, exit
0/1/2. The acceptance criterion's two required fixtures map directly onto this pattern: (i) a
fixture state.json where the candidate edge would close a cycle — assert nonzero exit and the
cycle named in stderr/stdout; (ii) a second fixture asserting a repeated `--depends-on-add` call
with the same arguments is a byte-for-byte no-op (mirrors `backfill-file-scope.sh`'s own documented
idempotence: "a second run ... is a byte-for-byte no-op"). `backfill-file-scope.sh` is the
shape to mirror (idempotent, `--dry-run` prints the diff and writes nothing, additive-only
union-merge via `state-write.sh`) but must not itself be modified — consulting its pattern only, as
the dispatch directs.

### Item 7 — Re-pointing the next-admissible-batch suggester's spec

Task 274 (`next_admissible_batch_suggestion`, status `not_started` in this repo's
`specs/state.json`) is the suggester; its own `file_scope`
(`scripts/orchestrate-suggest-next-batch.sh`, its test, `skills/skill-orchestrate/SKILL.md`,
`docs/architecture/batch-admit-schema.md`) does not overlap this task's `file_scope` at all, and
task 274's own dependency list already includes 344 (confirmed), so the dependency direction for
the eventual edge-add is already correct and in place. Task 274's description already states the
binding constraint correctly: the suggestion must be computed by *actually invoking*
`orchestrate-batch-admit.sh`, never by re-implementing its predicate, and the acceptance criterion
that a `file_scope`-colliding pair must never appear as a joint suggestion is sound and must not be
weakened (without an edge, the pair genuinely cannot share a wave, so the admission script's
refusal is correct).

**What this task needs to do**: via `/revise` on task 274, or a direct `state-write.sh` mutation to
its `description` field (never a hand-edit of `specs/state.json`), add language instructing the
suggester to **propose the serializing edge** (using the Item 6 primitive) for any pair it finds
file-scope-colliding and otherwise-suggestible, and then suggest the pair as a sequence — rather
than withholding the pair silently. This is a `specs/` state write belonging to the implementation
phase of this task, not a deliverable-file edit; no file in `agent-system/**` is touched by this
item.

### Scope-note conflict ruling

The guardrails doc's existing scope note reads:

> "`file_scope` declaration granularity, backfill, and absent-scope admission posture are owned by
> the file-scope-lifecycle topic and are out of scope here."

**Ruling**: "backfill" in that sentence refers specifically to *file_scope* backfill — the
population of the `file_scope` field's own values, which is exactly what
`scripts/backfill-file-scope.sh` (a one-shot backfill of missing `file_scope` from plan artifacts)
already does and is named for. It does not refer to, and was never written with, *dependency-edge*
backfill in mind — a categorically different operation (declaring a `dependencies[]` relationship
between two tasks whose `file_scope` already exists and already overlaps, vs. populating
`file_scope` itself). Item 6's `--depends-on-add` is dependency-edge backfill and is therefore
**not** disclaimed by this scope note.

Because this reading could be mistaken by a future reader (the bare word "backfill" is genuinely
ambiguous out of context), the scope note should be amended — not silently widened — to say so
explicitly: distinguish "file_scope backfill (population of the field itself; see
`backfill-file-scope.sh`)" from "dependency-edge backfill (adding a serializing edge between two
tasks already known to overlap; see Item 6 / `--depends-on-add`)," and state that only the former
is out of scope here.

## Recommendations

1. **Item 1**: add a short (2-3 sentence), visually separate, bolded-lead paragraph to
   `merge-sources/claudemd.md` stating the default posture and the overlap-to-edge move, modeled
   on the consumer repo's own `specs/ROADMAP.md` lines 13-18 (already a working, independently
   reinvented precedent), while keeping the existing pointer to the guardrails section's full
   dominance rule.
2. **Item 2**: add one explicit sentence in both the guardrails doc (next to the dominance rule)
   and `multi-task-operations.md` (next to §13's "File Footprint Overlap as a Serialization Edge")
   naming serialize-by-edge as the default move on an unordered overlap, cross-referencing the
   Item 6 primitive for *how*.
3. **Item 3**: add a narrowness test to Rule 1 (cross-referenced from, not duplicated out of,
   Component 0's existing qualifier) plus an explicit pointer from Rule 1 to the guardrails doc's
   own existing cap-aware fallback subsection — both, as the dispatch requires, with the two
   re-measured instances above cited as evidence.
4. **Item 4**: add an explicit owner-blocked carve-out as a numbered exception immediately
   following Rule 1, requiring the batch rendering to state the reason rather than emit a bare
   exclusion, citing the five-file certificate pair as the worked instance (by file-glob pattern,
   never by a foreign repo's task number).
5. **Item 5**: state the batch-plan rendering rule (pick an order + record the edge, or state the
   Item-4 reason; a bare "never with" is never acceptable and can itself be false) without touching
   `roadmap-format.md` or authoring the lint.
6. **Item 6**: implement `--depends-on-add=<json-array>` on `update-task-status.sh`, restricted to
   calls where `target_status` equals the task's current status (a pure no-op-replay carrier, by
   construction never also a phase transition); direction is fixed by call shape (positional
   `task_number` = dependent, array = new predecessors), never inferred numerically; write-time
   cycle refusal via a scratch-copy `validate-state.sh --deep` subprocess call grepped for the
   exact `"Dependency cycle detected among project_number(s):"` line (no edit to
   `validate-state.sh`, which is out of this task's `file_scope`); idempotent re-run is a no-op
   (mirroring `backfill-file-scope.sh`'s pattern, consumed not modified); document
   `orchestrate-cycle-plan.sh --dry-run` as the drain-confirmation step in the new flag's own usage
   comment and in the fixture suite, rather than auto-invoking it. Add the two required fixtures
   (cycle refusal; idempotent re-run) to `scripts/tests/test-update-task-status.sh`.
7. **Item 7**: via `/revise` or a `state-write.sh` mutation (never a hand-edit) on task 274's
   `description`, add the "propose the serializing edge, then suggest the pair as a sequence"
   instruction without weakening its existing disjointness acceptance criterion.
8. **Scope note**: amend the guardrails doc's scope note to explicitly distinguish file_scope
   backfill (out of scope here) from dependency-edge backfill (in scope, via Item 6) — do not leave
   the ambiguous wording standing and do not silently widen or narrow the note's claim.

## Decisions

- Treat `validate-state.sh`'s Kahn check as reused via **subprocess invocation against a scratch
  state file**, not via extracting a shared library function — because the latter requires editing
  `validate-state.sh`, which is outside this task's declared `file_scope`, while the former
  achieves the same "no second Kahn implementation" guarantee without touching that file. Verified
  working by direct execution against synthetic fixtures (see Findings, Item 6(b)).
- Reject a numeric (task-number-order) default for `--depends-on-add`'s direction rule, on the
  strength of this task's own live counter-example (274, 312 both depend on the newer task 344).
  Direction is fixed by call-argument shape instead.
- `--depends-on-add` rides the existing "no-op status replay" branch exclusively (never also
  performs a real status transition in the same call) — the cleanest fit given the host script's
  existing `operation:target_status` gating model and the precedent `--file-scope-add` already
  sets for a flag whose effect is independent of the status transition.
- The scope note's "backfill" is ruled to mean file_scope backfill only, and the note is to be
  amended (not silently reinterpreted) to say so explicitly, so a future reader cannot re-derive
  the ambiguity.
- Items 5 and 7 touch no files outside this task's declared edit targets and the `specs/` state
  write respectively — `roadmap-format.md`, the batch-proposal lint, and task 274's own
  `file_scope` files are confirmed untouched by this task's scope.

## Risks & Mitigations

- **Risk**: a narrowness test on Rule 1 could be read as weakening the dominance rule's
  correctness guarantee. **Mitigation**: the test only excludes *coarse* shared files
  (registration manifests, root gate scripts, shared READMEs/CHANGELOGs) from *triggering*
  mandatory grouping on their own; a genuinely narrow overlap is untouched and still mandatory.
  Cite `validate-state.sh` Check 8 (already WARN-only, already detects exactly this class of
  coarse `file_scope` entry) as the existing mechanical anchor for "coarse," so the test is not a
  new, impressionistic judgment call.
- **Risk**: `--depends-on-add`'s write-time cycle check (a scratch-file subprocess call to
  `validate-state.sh --deep`) could be slow or noisy if run against a large real `state.json`
  with many pre-existing unrelated WARN/FAIL findings. **Mitigation**: grep specifically for the
  cycle-detection line, never the overall pass/fail summary, so unrelated findings elsewhere in
  `state.json` cannot block an otherwise-valid edge add; `--deep` mode's other checks are the
  acceptable cost of reuse over a second implementation.
- **Risk**: Item 7's re-point could appear to weaken task 274's disjointness acceptance criterion
  if phrased loosely. **Mitigation**: the recommendation text above is explicit that the
  disjointness check (refusing to admit a colliding pair as a joint dispatch) stays exactly as
  written; only an *edge-proposing step* is added before the suggester gives up on a colliding
  pair.
- **Risk**: the dogfood batch (`{280, 311, this}`) assumption in the dispatch is already stale —
  both 280 and 311 are `completed` as of this research pass, not merely "verified acyclic" members
  of a pending batch. **Mitigation**: no action needed; this task's own dependency list
  (`[280, 311]`) is already satisfied, so the dogfood constraint is moot for scheduling purposes
  going forward — noted here only so the implementer does not waste time re-verifying a batch that
  has already drained.

## Context Extension Recommendations

- **Topic**: the direction-rule precedent for dependency-edge-adding primitives.
  **Gap**: nothing in `context/patterns/` currently documents "direction cannot be inferred from
  task numbering; it must be fixed by call-argument shape" as a general rule — this was derived
  ad hoc in this report from a live counter-example.
  **Recommendation**: once `--depends-on-add` ships, consider a short addition to
  `context/patterns/multi-task-operations.md` or a new pattern note cross-referenced from both it
  and the guardrails doc, naming this as the general rule for any future edge-adding primitive
  (not just this one), so the next person who builds a similar tool does not have to re-derive it.

## Appendix

**Search queries / commands used**:
- `grep -n "^#" .../batch-orchestration-guardrails.md` and targeted `sed -n` reads of the
  "Batching Is the Default", dominance-rule, cap, and scope-note sections.
- `grep -n "Multi-task syntax" -B5 -A8 .../merge-sources/claudemd.md` to confirm Item 1's exact
  placement defect.
- `grep -n "^#\|overlap\|never with\|serializ\|territory" .../multi-task-operations.md` and a
  full read of its §13.
- `sed -n '36,100p' / '264,322p' .../multi-task-creation-standard.md` for Component 0's
  narrowness qualifier and Component 4a's overlap-detection steps.
- `grep -n "file-scope-add\|research-questions\|hold-reason\|depends-on"
  .../scripts/update-task-status.sh` and a full read of its header-comment flag docs and no-op
  replay branch.
- `sed -n '905,960p' .../scripts/validate-state.sh` (the inline Kahn block) plus two live
  executions of `validate-state.sh --deep` against hand-built synthetic `state.json` fixtures (one
  cyclic, one acyclic) to confirm the exact FAIL/PASS message text.
- `python3 -I -c '...'` queries against this repo's own `specs/state.json` to re-measure the
  `manifest.json` open-task-overlap count (Item 3(i)) and confirm tasks 274/312/280/311's current
  status and dependency edges.
- Direct inspection of `~/Projects/Logos/Verification/specs/ROADMAP.md` (lines 13-18, 156) and
  `specs/state.json` (task 170's 135-entry `file_scope`) to corroborate Item 3(ii) and to find the
  Item-1 precedent text.
- `cat .../scripts/backfill-file-scope.sh` (full read) for the idempotent/`--dry-run` shape Item 6
  must mirror.
- `cat .../scripts/lib/file-scope-overlap.sh` (header + `scopes_overlap_first` def) to confirm the
  overlap predicate's single source of truth, relevant to Item 5's "check against the real
  predicate" framing.
- `sed -n '1,80p' .../scripts/tests/test-update-task-status.sh` for the existing fixture-suite
  pattern (mktemp workdir, pass/fail/info counters, exit 0/1/2) Item 6's new fixtures should
  extend.
