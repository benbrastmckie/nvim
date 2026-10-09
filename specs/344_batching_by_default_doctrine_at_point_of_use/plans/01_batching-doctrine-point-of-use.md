# Implementation Plan: Task #344

- **Task**: 344 - Carry the batching-by-default doctrine to the point of use, and make a territory
  overlap produce a serializing edge rather than a separation
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 280 (completed), 311 (completed) — both satisfied
- **Research Inputs**: `specs/344_batching_by_default_doctrine_at_point_of_use/reports/01_batching-doctrine-point-of-use.md`
- **Artifacts**: plans/01_batching-doctrine-point-of-use.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/context/standards/artifact-management.md`
  - `.claude/context/standards/shell-strict-mode.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/rules/no-task-references-in-deliverables.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/state-management.md`
  - `.claude/context/workflows/tasks.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

The batching-by-default doctrine (dominance rule: shared file territory > topic cohesion > graph
shape) already exists and is correctly stated in `batch-orchestration-guardrails.md`'s "Batching
Is the Default" section; the mechanism (wave dispatch serializing on any `dependencies[]` edge)
is sound too. This plan does **not** re-author the doctrine. It carries the doctrine to seven
specific points of use, closes two measured gaps in it (Rule 1 has no narrowness qualifier and no
cap-aware fallback pointer; no owner-blocked carve-out), states the batch-plan rendering rule,
and builds the one missing primitive — `update-task-status.sh --depends-on-add` — that turns "these
two tasks overlap" into an actual sequencing edge. Every deliverable edit lands in the source
store (`agent-system/extensions/core/`), never in `.claude/**`. Definition of done: all eight
acceptance criteria in the dispatch are satisfied, shellcheck is clean, and the full gate set
(`verify-deploy.sh`) is green after a redeploy.

### Research Integration

The research report is integrated as follows, and its three load-bearing *executed* findings are
carried into phase design rather than restated as opinion:

- **Item 6(b) reuse path is executable without touching `validate-state.sh`** (which is NOT in
  this task's `file_scope`): research ran `validate-state.sh --deep <scratch-state>` against a
  cyclic and an acyclic synthetic fixture and observed the exact lines
  `[FAIL] Dependency cycle detected among project_number(s): 2,1` and
  `[PASS] No dependency cycles detected among active_projects`. Phase 4 therefore shells out to
  the existing script against a scratch copy and greps that one line, instead of extracting the
  Kahn loop into a shared library (which would require editing an out-of-scope file). No second
  cycle detector is written anywhere.
- **Item 6(a) direction cannot be numeric**: research falsified "higher task number depends on
  lower" against this task's own live graph — two older, lower-numbered tasks each carry a
  dependency edge *onto* this newer one. Phase 3 therefore fixes direction by call-argument
  shape (positional `task_number` is always the dependent; the flag's array lists its new
  predecessors), mirroring `dependencies[]`'s own field semantics.
- **Item 1's precedent is already proven downstream**: a consumer repo's own always-read
  `specs/ROADMAP.md` independently reinvented a 3-line operative restatement of this exact
  posture, which is evidence that a short operative statement (not a pointer) is what reaches the
  point of use. Phase 6 models its wording on that precedent.

**One finding this plan adds that research did not surface**, discovered by measurement during
planning and the single hardest constraint on Item 1: the eager-context budget has **9 bytes of
headroom** (live `TOTAL: 65941 B` from `measure-eager-context.sh --check`, against
`orchestrator-context-budget.json`'s `eager_load.baseline_bytes` of `65950`), and
`verify-deploy.sh` Gate 20 sub-check B `fail()`s unconditionally on any regression above
baseline. `merge-sources/claudemd.md` is an eager-loaded file and
`orchestrator-context-budget.json` is **not** in this task's `file_scope`, so the baseline cannot
be moved. Item 1 must therefore be **byte-neutral or better**, achieved by an offsetting in-file
trim of duplicated detail — exactly the pattern the baseline note itself records four prior times
(2026-10-01, 2026-10-03, two in 2026-10-08). Phase 6 is built around this constraint and carries
the re-measurement as a hard verification criterion. Research justified Item 1's token cost in the
abstract; this is the mechanical ceiling that cost has to fit inside.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- State the batching posture (not merely point at it) at the always-loaded layer, byte-neutrally,
  with the token cost justified in writing.
- Name serialize-by-edge as the default move on an unordered territory overlap, in both the
  guardrails doc and `multi-task-operations.md`.
- Give Rule 1 a narrowness test **and** an explicit pointer to the existing cap-aware fallback,
  consistent with the existing truncation-precedence rule, with both measured instances
  re-measured and cited.
- State the owner-blocked carve-out (separation is correct when the would-be predecessor cannot
  progress) and require the batch plan to state the reason.
- State the batch-plan rendering rule, including that a bare "never with" note is not an
  acceptable rendering and can itself be false.
- Ship `--depends-on-add` on `update-task-status.sh` with `--dry-run`, a stated direction rule,
  and a mandatory write-time cycle refusal that reuses `validate-state.sh`'s existing Kahn check.
- Prove the refusal and the idempotent re-run with two fixtures.
- Re-point the next-admissible-batch suggester's spec via a `specs/` state write, without
  weakening its disjointness check.

**Non-Goals**:
- Re-authoring the doctrine. It exists and is correct; this task relocates and qualifies it.
- Any parallelism or throughput change. Serialization inside one invocation is an acceptable and
  often preferred outcome; the property defended is collision visibility and correct sequencing,
  never wall-clock.
- Weakening any admission gate. This task changes what an agent *chooses* to batch and what the
  system *teaches*, never what the runtime permits.
- Editing `scripts/validate-state.sh`, `scripts/orchestrate-batch-admit.sh`,
  `scripts/backfill-file-scope.sh`, `docs/reference/standards/multi-task-creation-standard.md`,
  `context/formats/roadmap-format.md`, `commands/orchestrate.md`,
  `docs/architecture/orchestrate-state-machine.md`, `manifest.json`, or
  `context/config/orchestrator-context-budget.json` — each is either owned elsewhere or
  deliberately excluded, and none is in this task's `file_scope`.
- Authoring the batch-proposal lint or the ROADMAP batch-block grammar.
- Touching the stale "Batching is not yet supported. Running with first N tasks only." string.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Item 1's addition pushes the eager-context TOTAL above `baseline_bytes` (9 B headroom), failing Gate 20 sub-check B | H | H | Phase 6 is byte-budgeted: trim first, verify the cut detail exists in its non-eager home, add second, then re-measure and require `TOTAL <= 65950`. The baseline is never moved (out of `file_scope`). |
| A narrowness test on Rule 1 reads as weakening the dominance rule | H | M | The test excludes only *coarse* shared files (registration manifest, repo-root gate script, shared README/CHANGELOG) from *triggering* mandatory grouping on their own; a genuinely narrow overlap stays mandatory and untouched. Anchor "coarse" to `validate-state.sh` Check 8's already-existing WARN-only coarse-`file_scope` detection so the test is mechanical, not impressionistic. |
| Doc text cites a flag spelling the implementation then changes | M | M | The flag's exact spelling (`--depends-on-add=<json-array>`) is fixed by this plan. Phase 8 greps the script for every flag name cited in the three doc files and fails on a mismatch. |
| Write-time cycle check is slow or noisy against a real `state.json` carrying unrelated WARN/FAIL findings | M | M | Grep for the single `Dependency cycle detected among project_number(s):` line, never the overall pass/fail summary, so unrelated findings cannot block a valid edge add. |
| `validate-state.sh --deep` resolves a sibling `archive/state.json` relative to `STATE_FILE`; a scratch copy in a bare temp dir has no such sibling | M | M | Only the cycle line is consulted, so a missing-archive finding is irrelevant by construction. Phase 4 asserts this explicitly by running the check against a scratch copy with no sibling archive and confirming the cycle verdict is still emitted. |
| Item 3's two measured instances are stale by implementation time | M | H | Both are declared hypotheses with a stated re-measurement command (Phase 1's **Scope Hypothesis**); the deliverable cites the re-measured figures with their own measurement date, never the plan's. |
| Task-number references leak into `agent-system/**` deliverables | M | M | Item 3(i), Item 4's certificate instance, and Item 7's re-point are all cited by durable anchor (filename, glob pattern, command, concept) — never by task number. Gate 4's task-reference lint runs in Phase 8. |
| Scope note's "backfill" disclaimer is silently widened to cover dependency-edge backfill | M | L | Phase 1 amends the note explicitly to distinguish file_scope backfill (out of scope there) from dependency-edge backfill (in scope, via the new primitive), rather than relying on a reader's inference. |
| New fixtures need `validate-state.sh` in the isolated fixture repo, which `REQUIRED_SCRIPTS` does not currently copy | M | H | Phase 5 adds it to `REQUIRED_SCRIPTS` (deploy-sourced, as it is not being edited); the existing source-store-first override already covers `update-task-status.sh`, so the fixtures exercise the pre-deploy edit. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4, 7 | 1 (for 2); 3 (for 4, 7) |
| 3 | 5, 6 | 4 (for 5); 1, 2, 3 (for 6) |
| 4 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Guardrails doctrine — Rule 1 qualifier, carve-out, rendering rule, scope note [COMPLETED]

**Goal**: Close Items 2 (guardrails half), 3, 4, 5 and the scope-note conflict inside
`batch-orchestration-guardrails.md`, without re-authoring the dominance rule it already states.

**Tasks**:
- [x] Re-measure Item 3(i): count tasks declaring `agent-system/extensions/core/manifest.json` in
  `file_scope` in this repo's `specs/state.json`, and how many are still open (non-terminal).
  Record the figure and the measurement date.
- [x] Re-measure Item 3(ii): confirm the broad-footprint rename task in
  `~/Projects/Logos/Verification/specs/state.json` still declares its large `file_scope`, and
  record the path count and measurement date.
- [x] Add a **narrowness test** to `### The dominance rule`'s rule 1: a shared *coarse* path — a
  repository-root gate script, a registration manifest, a shared README, a CHANGELOG, or any
  entry that would independently trip `validate-state.sh` Check 8's coarse-`file_scope` WARN —
  does not by itself make two tasks territory-mandatory. Cross-reference Component 0's existing
  narrowness qualifier in `docs/reference/standards/multi-task-creation-standard.md` rather than
  duplicating its prose (that file is NOT edited).
- [x] Add an explicit pointer from rule 1 to the doc's own existing `### The batch-size cap
  (MAX_TASKS)` fallback, so rule 1 no longer reads as absolute with the cap as an unrelated
  footnote. Do not invent a second fallback mechanism; preserve the existing truncation-precedence
  rule ("List territory-mandatory members first, so a trim to 8 can never split a
  territory-mandatory group off the end") verbatim in force.
- [x] Cite both re-measured instances as the evidence for the qualifier, by durable anchor only
  (`manifest.json`, "a broad-footprint directory-rename task declaring ~N paths") — never by task
  number, per `rules/no-task-references-in-deliverables.md`.
- [x] Add the **owner-blocked carve-out** as a numbered exception immediately following rule 1:
  rule 1's mandate is suspended when the would-be predecessor cannot progress (blocked on an
  owner action, `[PARTIAL]` behind something no task can unblock, or held) with no resolving task
  in this system; separation is then correct, and the batch proposal MUST state the reason.
  Worked instance: a pair overlapping on five `components/framed_channel/certificate/*.txt` files
  deliberately left unwired for exactly this reason — cited by glob pattern, not task number.
- [x] Add the **batch-plan rendering rule**: for an unordered territory overlap, a roadmap or
  batch plan picks an order and records the serializing edge, rendering the pair as a sequence. A
  bare "never with" note is never an acceptable terminal rendering — it under-renders a genuine
  overlap and, as measured against the real overlap predicate in
  `scripts/lib/file-scope-overlap.sh`, can itself be false (a "never with" note for a pair that is
  provably disjoint). Where the Item 4 carve-out applies, the render is a *reasoned* exclusion
  naming the blocker. State explicitly that the ROADMAP batch-block grammar and the
  batch-proposal lint are owned elsewhere and are not defined here.
- [x] Add the Item 2 sentence next to the dominance rule: on an unordered overlap between two
  candidates, the default move is to add a serializing `dependencies[]` edge (via
  `update-task-status.sh --depends-on-add`, direction per its stated rule) and run them as a
  sequence in the same invocation.
- [x] Amend `### Territory is a human judgment, not a machine derivation (scope note)` to
  distinguish **file_scope backfill** (population of the field itself, see
  `backfill-file-scope.sh` — still out of scope there) from **dependency-edge backfill** (adding
  a serializing edge between two tasks already known to overlap, see `--depends-on-add` — in
  scope). Do not silently widen or narrow the note's claim.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The two Item 3 figures asserted above (an open-task count for
`manifest.json` overlap in this repo; a ~135-path `file_scope` in the consumer repo) are
2026-10-06/2026-10-09 measurements and are hypotheses, not facts. Confirm at implementation time
with `jq -r '[.active_projects[] | select((.file_scope // []) | any(. == "agent-system/extensions/core/manifest.json"))] | map({n: .project_number, s: .status})' specs/state.json`
and the equivalent query against `~/Projects/Logos/Verification/specs/state.json`; cite the
re-measured values with their own date, and if a figure has moved, the *mechanism* claim (a
registration file can mechanically inflate a mandatory group past `MAX_TASKS`) is what the
deliverable asserts, supported by whatever the live count then is.

**Tier Justification**: Markdown-only guidance edit with no executable surface; the covering
checks are `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc lint and task-reference
lint) plus `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-gate-out-self-attribution.sh` (the
suites `suite_selection_select` resolves for this path), together with the `prose` row's diff
read-through confirming every hunk stays inside prose.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - rule 1
  narrowness test + cap-fallback pointer; owner-blocked carve-out; batch-plan rendering rule;
  overlap-to-edge default-move sentence; scope-note amendment

**Verification**:
- `--only-gate 3,4` green; the three mapped suites green.
- Rule 1's text contains both the narrowness test and the pointer to the cap subsection, and the
  truncation-precedence sentence is byte-identical to its pre-edit form.
- `grep -nE '\btask [0-9]+\b|\btasks [0-9]+' agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
  returns nothing new.
- The scope note names both backfill kinds explicitly.

---

### Phase 2: `multi-task-operations.md` — overlap-to-edge default move and the direction rule [COMPLETED]

**Goal**: Close Item 2's second half at §13 and record the general direction-rule insight the
research's Context Extension Recommendation identified.

**Tasks**:
- [x] In `### File Footprint Overlap as a Serialization Edge`, after the existing same-batch /
  cross-batch coverage bullets, add the prescriptive sentence for the uncovered case: two
  already-existing, separately-created tasks whose `file_scope` is found to overlap with no edge
  yet. The default move is to add the serializing `dependencies[]` edge via
  `update-task-status.sh --depends-on-add` and run them as a sequence in one invocation — never to
  record the overlap as a bare exclusion. Cross-reference the guardrails doc's dominance rule and
  its new carve-out and rendering rule (Phase 1's anchors) rather than restating them.
- [x] Add a short note naming the general rule for any edge-adding primitive: dependency
  direction cannot be inferred from task numbering (an older, lower-numbered task routinely
  depends on a newer one); it is fixed by the call's own argument shape. Keep it to two sentences;
  this is the durable home for the insight so a future tool author does not re-derive it.
- [x] Verify the Item 4 carve-out is reachable from here by pointer, so a reader arriving at §13
  does not apply the default move to a permanently-stalled predecessor.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
path — no suite covers it, and this justification claims none; the honest covering check is
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc lint and task-reference lint) plus
the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - §13 overlap-to-edge
  default-move sentence; the direction-rule general note

**Verification**:
- `--only-gate 3,4` green.
- Every cross-reference added points at a heading that actually exists in
  `batch-orchestration-guardrails.md` (confirm each anchor by `grep -n`).
- No task-number references introduced.

---

### Phase 3: `--depends-on-add` — flag parsing, validation, direction rule, state write [COMPLETED]

**Goal**: Add `--depends-on-add=<json-array>` to `update-task-status.sh` as a true exact sibling
of `--file-scope-add` / `--research-questions` / `--hold-reason`, writing the edge additively on
the existing no-op-replay branch.

**Tasks**:
- [x] Add `DEPENDS_ON_ADD=""` alongside the three existing flag variables and a
  `--depends-on-add=*) DEPENDS_ON_ADD="${arg#--depends-on-add=}" ;;` case in the argument loop.
- [x] Extend both usage strings (the header-comment synopsis at the top and the runtime `Usage:`
  line) with the new flag.
- [x] Validate eagerly, in the same shape the three siblings use: the value MUST parse as a JSON
  array of **numbers** (`jq -e 'type == "array" and (all(.[]; type == "number"))'`); a malformed
  value is a hard error (exit 1) naming the required shape, never a silent no-op.
- [x] Validate semantics before any write: every listed predecessor MUST exist in
  `active_projects` (refuse, naming the missing number); the dependent's own number MUST NOT
  appear in the list (self-edge refusal, exit nonzero); a predecessor already present in
  `dependencies[]` is not an error (idempotence, see below).
- [x] Restrict the flag to calls where `target_status` resolves to the task's **current** status —
  i.e. it only ever rides the existing no-op-replay branch and never also performs a real status
  transition in the same call. A violating call is a hard validation error naming the required
  condition, never a silent fallback. Document *why* in the header comment: an edge add between
  two already-existing tasks is phase-independent, so there is no natural
  `operation:target_status` pair that means "just add this edge".
- [x] Compute `DEPENDS_ON_ADD_LEN` the same way `FILE_SCOPE_ADD_LEN` is computed, so an absent
  flag or an empty array is a byte-for-byte no-op.
- [x] Add the write in `update_state_json()`'s **no-op branch** as a fourth `elif`, mirroring the
  `--file-scope-add` clause's union-merge shape exactly:
  `(.active_projects[] | select(.project_number == ($num | tonumber)) | .dependencies) |= ((. // []) + $dep | unique)`
  via a single `state-write.sh` invocation with `--regen-todo`. Union-merge (not overwrite) is
  what makes a repeated call a no-op.
- [x] Add the matching `[dry-run]` line in `update_state_json()`'s dry-run block, printing the
  per-task diff (current `dependencies[]` -> resulting `dependencies[]`) and writing nothing —
  mirroring `backfill-file-scope.sh`'s `--dry-run` shape. Consume that script's pattern only; do
  **not** modify it.
- [x] Write the **direction rule** into the flag's header comment as a rule, not a caller choice:
  the positional `task_number` is always the task that *gains* the dependency (the dependent); the
  JSON array lists the task numbers it now depends on (its predecessors) — mirroring
  `dependencies[]`'s own field semantics in `specs/state.json`. State explicitly that direction is
  never inferred from task numbering, with the live counter-example (an older, lower-numbered task
  depending on a newer one) stated as a mechanism, not by task number.
- [x] Document `orchestrate-cycle-plan.sh --dry-run --state-file F <task_number>...` in the flag's
  usage comment as the caller's drain-confirmation step, and state why it is not auto-invoked:
  only the caller knows the full intended batch, which is usually larger than the pair just
  linked.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: The edit is confined to one script and is additive — the base `jq` filter
and every existing branch are untouched when the flag is absent — so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-update-task-status.sh`
(the existing suite already regression-guards the shared no-op and real-write paths this clause
rides on) plus `shellcheck agent-system/extensions/core/scripts/update-task-status.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - new flag, eager + semantic
  validation, status-no-op restriction, union-merge write on the no-op branch, dry-run rendering,
  direction rule and drain-confirmation documentation

**Verification**:
- `shellcheck` clean per `context/standards/shell-strict-mode.md`.
- Existing suite still green: `run-all.sh --only test-update-task-status.sh`.
- Manual smoke against a scratch `--state-file` copy: a valid add unions the edge; a malformed
  value, a self-edge, a nonexistent predecessor, and a real status transition each exit nonzero
  with a message naming the condition; `--dry-run` prints the diff and leaves the file unchanged
  (`cmp` before/after).

---

### Phase 4: `--depends-on-add` — mandatory write-time cycle refusal [COMPLETED]

**Goal**: Refuse at write time any edge that would close a dependency cycle, by reusing
`validate-state.sh`'s existing Kahn check — with no second cycle detector anywhere in the new
code and no edit to `validate-state.sh`.

**Tasks**:
- [x] Before the write (and before the dry-run print returns), build a scratch copy of the state
  file with the **candidate** edge already applied: `mktemp -d`, `jq` the union-merge into
  `<scratchdir>/state.json`, with an `EXIT` trap removing the directory.
- [x] Invoke `"$SCRIPT_DIR/validate-state.sh" --deep <scratch-state>` and capture its combined
  output. Do **not** consult its overall exit status: a real `state.json` can carry unrelated
  pre-existing WARN/FAIL findings that must not block an otherwise-valid edge add.
- [x] Grep the captured output for exactly
  `Dependency cycle detected among project_number(s):`. On a match, refuse: print the matched line
  verbatim (so the cycle members are named), print the rejected edge, and `exit` nonzero without
  calling `state-write.sh`. On no match, proceed to the Phase 3 write.
- [x] Make the refusal fire on `--dry-run` too, so a dry run cannot report an edge as addable that
  a real run would refuse.
- [x] Guard the reuse: if `validate-state.sh` is not found or not executable, refuse the edge
  (fail-closed) rather than writing an unchecked edge. State in a comment that fail-closed is
  deliberate — the whole point of the flag is that the check is not optional.
- [x] Add a header-comment paragraph recording *why* this lives at the point of write: cycle
  detection already exists and is blocking, but only as a separate validator reachable by
  explicit invocation or at the next dispatch, so whether a hand-written edge is cycle-checked
  today depends on whether the writer remembered. For a primitive whose entire job is adding
  edges, the check belongs at the write. State explicitly that this is a reuse requirement, not a
  new algorithm.
- [x] Confirm by execution that the scratch copy needs no sibling `archive/state.json`: run the
  check against a scratch copy in a bare temp dir and verify the cycle verdict line is still
  emitted (only that line is consulted, so any missing-archive finding is irrelevant by
  construction).

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: Still one script, still additive and reachable only via the new flag, so
the covering check remains `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-update-task-status.sh` plus `shellcheck
agent-system/extensions/core/scripts/update-task-status.sh`; `validate-state.sh` itself is invoked
as an unmodified subprocess, so no other module's surface changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - scratch-copy construction,
  `validate-state.sh --deep` subprocess invocation, cycle-line grep, fail-closed refusal,
  rationale comment

**Verification**:
- `shellcheck` clean.
- `grep -niE 'kahn|in_?degree|topolog' agent-system/extensions/core/scripts/update-task-status.sh`
  returns no new algorithm — only the comment naming the reused check.
- Manual smoke: a cycle-closing edge against a scratch state exits nonzero and prints the cycle
  members; the same call with `--dry-run` also exits nonzero; an acyclic edge proceeds.
- The scratch directory is removed on every exit path (`ls` the temp root after each smoke run).

---

### Phase 5: Fixtures — cycle refusal and idempotent re-run [COMPLETED]

**Goal**: Prove, in the existing fixture suite, that a cycle-creating edge is refused at write
time and that an idempotent re-run adds nothing.

**Tasks**:
- [x] Add `validate-state.sh` to `REQUIRED_SCRIPTS` so the isolated fixture repo carries it
  (deploy-sourced; it is not being edited). Confirm the existing `cp
  "$DEPLOY_SCRIPTS_SRC"/lib/*.sh` line already supplies its `lib/common.sh`,
  `lib/status-vocabulary.sh` and `lib/file-scope-overlap.sh` dependencies.
- [x] Extend `build_fixture_repo`'s inline `specs/state.json` (or add a second builder) so the
  fixture carries at least three tasks with a pre-existing edge, enough to close a cycle with one
  more edge.
- [x] **Fixture A — write-time cycle refusal**: with an existing edge `A -> B`, call
  `--depends-on-add` to add `B -> A`. Assert (i) nonzero exit, (ii) the output names the cycle
  (match on `Dependency cycle detected among project_number(s)`), and (iii) `dependencies[]` in
  the fixture `state.json` is byte-identical to its pre-call value.
- [x] **Fixture B — idempotent re-run**: add a valid edge, capture the resulting `state.json`
  `dependencies[]`, re-run the identical call, and assert the array is unchanged and the exit is
  zero.
- [x] Add the supporting negative cases Phase 3 introduced: malformed value, self-edge,
  nonexistent predecessor, and a call that would also perform a real status transition — each
  asserting nonzero exit and no state change.
- [x] Add a `--dry-run` case: the printed diff appears on stdout and `state.json` is unchanged.
- [x] Follow the suite's existing idiom exactly: `pass()`/`fail()`/`info()` counters, per-case
  `>"$WORKDIR/cNN.out" 2>"$WORKDIR/cNN.err"` capture, a fresh `build_fixture_repo` root for the
  new case block.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Two fixtures are *required* by the acceptance criteria (cycle refusal;
idempotent re-run), and this phase asserts roughly eight cases in total including the negatives.
The count is a hypothesis: confirm at implementation time by running
`bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` and reading its
`Results: N passed, 0 failed` line, and confirm the two mandated fixtures specifically by their
`[PASS]` labels rather than by the total.

**Tier Justification**: The edit is confined to one test file; the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-update-task-status.sh`
(which is precisely the suite being extended, and the only suite
`suite_selection_select` resolves as narrow coverage for this path) plus `shellcheck` on it.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - `validate-state.sh`
  added to `REQUIRED_SCRIPTS`; multi-task fixture state; the cycle-refusal and idempotence
  fixtures plus the negative and dry-run cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` exits 0 with every
  pre-existing case still passing.
- The suite leaves the real `specs/` tree untouched (the suite's own
  `BASELINE_SPECS_STATUS` comparison).
- `shellcheck` clean.

---

### Phase 6: Item 1 — state the posture at the always-loaded layer, byte-neutrally [COMPLETED]

**Goal**: Make `merge-sources/claudemd.md` **state** the batching posture under its own heading
rather than trail it as a clause of the comma-grammar sentence — at net zero or negative eager
bytes, with the token cost justified in writing.

**Tasks**:
- [x] Re-measure the headroom first: `REPO_ROOT="$(pwd)" bash
  .claude/scripts/measure-eager-context.sh --check`, read the `TOTAL: <bytes> B` line, and compare
  against `jq -r '.eager_load.baseline_bytes'
  agent-system/extensions/core/context/config/orchestrator-context-budget.json`. Record both
  numbers before any edit.
- [x] **Trim before adding.** Recover bytes from duplicated detail inside this same file, and
  verify the cut detail already exists in its non-eager home *before* cutting:
  - The `**Multi-task syntax**:` paragraph's syntax clause (commas/ranges/example/wave-dispatch
    restatement) is fully covered by `multi-task-operations.md`'s `## 1. Argument Parsing` and its
    `### Examples`. Confirm by `grep -n`, then reduce the clause to its pointer.
  - The `/orchestrate` Command Reference row's trailing enumeration of
    forced-phase / terminal-task-admission / artifact-keyed-admission / cycle-budget semantics is
    covered by `docs/architecture/orchestrate-state-machine.md`'s own headings. Confirm by
    `grep -n`, then compress to a bare pointer.
- [x] **Then add**, under its own heading (`### Batching`) so it is visually separate from the
  syntax sentence and a reader scanning for "when do I batch" has something to stop at: one short
  operative paragraph stating (a) batching is the default, (b) shared file territory is a reason
  to batch, not to separate, (c) on an unordered overlap, add the serializing edge via
  `update-task-status.sh --depends-on-add` and run the pair as a sequence — never a "never with"
  exclusion, and (d) a batch that serializes to width 1 is a correct batch. Keep the existing
  pointers to `multi-task-operations.md` and the guardrails doc's "Batching Is the Default"
  section.
- [x] Model the wording on the consumer repo's own always-read `specs/ROADMAP.md` operative
  bullets, which independently reinvented this restatement — evidence that a 2-3 line operative
  statement is what reaches the point of use where a pointer did not.
- [x] **Re-measure and gate.** Run `measure-eager-context.sh --check` again. The new `TOTAL` MUST
  be less than or equal to `baseline_bytes`. If it is not, recover more bytes from the same two
  paragraphs (or compress the new paragraph) — never move `baseline_bytes`, which is out of this
  task's `file_scope`, and never leave the overage for the final gate to catch.
- [x] Record the written token-cost justification in the implementation summary: the fixed eager
  cost is one short paragraph; a posture must fire *before* any file read, and a posture
  discoverable only by reading a ~1,900-line pattern file never fires; a pointer-only design has
  already been tried (it is what exists today) and did not reach the point of use; and in this
  instance the cost is *zero or negative* because the addition is paid for by removing detail
  duplicated in two non-eager homes.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The headroom figure (live `TOTAL: 65941 B` against `baseline_bytes: 65950`,
i.e. 9 bytes) and the estimate that ~250 bytes are recoverable from the two named paragraphs are
both measurements taken at planning time, not facts about implementation time. Confirm both
before editing with the `measure-eager-context.sh --check` / `jq` pair above and with `wc -c` on
the two candidate paragraphs; if less is recoverable than estimated, compress the new paragraph
rather than exceeding the baseline.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
path — no suite covers it, and this justification claims none; the covering checks are
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4,20` (doc lint, task-reference lint, and the
orchestrator context budget lock that is the actual binding constraint on this phase) plus the
`prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - new `### Batching` operative
  paragraph; `**Multi-task syntax**:` clause reduced to its pointer; `/orchestrate` row's
  semantics enumeration compressed to a pointer

**Verification**:
- `measure-eager-context.sh --check` reports `TOTAL` <= `baseline_bytes`, and `Volatile-file
  hits: 0`.
- `verify-deploy.sh --only-gate 3,4,20` green (Gate 20 is the binding check here).
- Every clause cut from this file is confirmed present in its non-eager home by `grep -n`,
  recorded in the commit message.
- The posture paragraph sits under its own heading, not as a trailing clause of the syntax
  sentence.

---

### Phase 7: Item 7 — re-point the next-admissible-batch suggester's spec [NOT STARTED]

**Goal**: Add an edge-proposing step to the suggester's spec via a `specs/` state write, without
weakening its disjointness acceptance criterion.

**Tasks**:
- [ ] Read the suggester task's current `description` from `specs/state.json` and confirm its
  existing acceptance criterion (a `file_scope`-colliding pair must not appear as a *joint*
  suggestion) is intact, and that its dependency edge onto this task is already present.
- [ ] Compose the appended language: for any pair the suggester finds `file_scope`-colliding and
  otherwise suggestible, **propose the serializing edge** (naming
  `update-task-status.sh --depends-on-add` and its direction rule) and then suggest the pair as a
  **sequence** — rather than withholding the pair silently. State explicitly that the
  disjointness check is unchanged and must not be weakened: without an edge the pair would share
  a wave and write concurrently, so the admission refusal is correct; the defect being fixed is
  only the missing edge-proposing step before giving up.
- [ ] Apply it as a `specs/` state write via `/revise` or
  `bash .claude/scripts/state-write.sh '<jq-filter>' --session-id "$session_id" --arg ... --regen-todo`
  — **never** a hand edit of `specs/state.json`. Append to the existing `description`; do not
  replace unrelated text.
- [ ] Confirm no file under `agent-system/**` is touched by this phase, and that
  `scripts/orchestrate-batch-admit.sh` and the admission verdict schema are untouched.
- [ ] Run `bash .claude/scripts/validate-state.sh --deep` afterwards and confirm no new findings.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: The only mutation is a `specs/state.json` `description` field written
through `state-write.sh`, with no deliverable file and no executable surface touched; the covering
check is `bash .claude/scripts/validate-state.sh --deep` (the state schema and cycle validator
that owns this file) plus `git status --short agent-system/` confirming no source-store path
changed.

**Files to modify**:
- `specs/state.json` - the suggester task's `description`, appended via `state-write.sh` (not a
  deliverable file; `specs/**` is exempt from the no-task-references rule)

**Verification**:
- `validate-state.sh --deep` reports no new findings.
- The pre-existing disjointness criterion text is still present verbatim in the description.
- `git status --short agent-system/` shows no change attributable to this phase.
- `generate-todo.sh` regeneration leaves `TODO.md` consistent (`--regen-todo` on the write).

---

### Phase 8: Cross-item consistency, redeploy, and full gate set [NOT STARTED]

**Goal**: Prove the eight acceptance criteria hold together, the three doc files and the script
agree on names, and the full gate set is green against the redeployed tree.

**Tasks**:
- [ ] Name-consistency sweep: for every flag, script, and heading name cited in
  `batch-orchestration-guardrails.md`, `multi-task-operations.md`, and `merge-sources/claudemd.md`
  by this task's edits, `grep` the cited target and confirm it exists (the flag in
  `update-task-status.sh`; each cross-referenced heading in its own file).
- [ ] Confirm the no-second-detector requirement across the whole diff:
  `git diff -- agent-system/extensions/core/scripts/ | grep -niE 'kahn|in_?degree|topolog'`
  surfaces only comment text naming the reused check.
- [ ] Confirm every declared boundary held: `git status --short` shows changes **only** in the
  five declared `file_scope` paths plus `specs/**`; in particular `manifest.json`,
  `validate-state.sh`, `backfill-file-scope.sh`, `orchestrate-batch-admit.sh`,
  `multi-task-creation-standard.md`, `roadmap-format.md`, `commands/orchestrate.md`,
  `orchestrate-state-machine.md` and `orchestrator-context-budget.json` are untouched.
- [ ] Confirm the stale "Batching is not yet supported" string is unchanged anywhere.
- [ ] `shellcheck` every touched shell file per `context/standards/shell-strict-mode.md`.
- [ ] No task-number references in any file landing under `agent-system/**`:
  `bash .claude/scripts/check-task-references.sh` (or Gate 4 below).
- [ ] Redeploy the source store: `bash .claude/scripts/deploy-headless.sh`, so `.claude/` reflects
  the source-store edits and the generated `.claude/CLAUDE.md` carries the new `### Batching`
  section.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (all 21 gates, no
  `--only-gate`, no `--skip-slow`), which includes Gate 3 doc lint, Gate 4 task-reference lint,
  Gate 8's full shell-suite battery, Gate 10's `validate-state.sh --deep`, and Gate 20's
  orchestrator context budget lock. Green is required before the task completes.
- [ ] Walk the eight acceptance criteria one at a time against the diff and record the evidence
  for each in the implementation summary.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- none planned - verification, redeploy, and evidence recording only

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits green across the complete gate set it aggregates
  (Gates 1-21), with no `--only-gate` narrowing and no `--skip-slow`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green (reached via Gate 8).
- `bash .claude/scripts/validate-state.sh --deep` green (reached via Gate 10).
- `measure-eager-context.sh --check`'s `TOTAL` <= `baseline_bytes` (reached via Gate 20).
- All eight acceptance criteria individually evidenced in the summary.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` exits 0, with
  the cycle-refusal fixture and the idempotent-re-run fixture both passing by name.
- [ ] A cycle-creating `--depends-on-add` call exits nonzero, names the cycle members, and leaves
  `dependencies[]` byte-identical — including under `--dry-run`.
- [ ] A repeated identical `--depends-on-add` call is a byte-for-byte no-op.
- [ ] Malformed value, self-edge, nonexistent predecessor, and a real status transition in the
  same call each exit nonzero with a message naming the condition.
- [ ] No second cycle detector exists anywhere in the new code.
- [ ] `shellcheck` clean on both touched shell files. **Entry point note**: this repository has
  no shellcheck wrapper script and no shellcheck gate inside `verify-deploy.sh` — verified live
  during planning (`ls scripts/ | grep "^lint-"` is empty; no suite in `scripts/tests/` invokes
  it; the only in-tree occurrences are `# shellcheck disable=` directives). The sanctioned
  invocation is therefore `shellcheck <path>` directly, and what is checked is its **exit
  status**, not a stdout diff against a baseline. Do not spend time hunting for a wrapper that
  does not exist.
- [ ] `measure-eager-context.sh --check`: `TOTAL` <= `baseline_bytes`, 0 volatile-file hits.
- [ ] `check-task-references.sh` clean for `agent-system/**`.
- [ ] `validate-state.sh --deep` clean after the Item 7 state write.
- [ ] `bash .claude/scripts/verify-deploy.sh` green across the full gate set after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — Rule 1
  narrowness test + cap-fallback pointer, owner-blocked carve-out, batch-plan rendering rule,
  overlap-to-edge default move, amended scope note.
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` — §13 overlap-to-edge
  default move, direction-rule general note.
- `agent-system/extensions/core/merge-sources/claudemd.md` — `### Batching` operative posture
  paragraph, byte-neutral via two offsetting trims.
- `agent-system/extensions/core/scripts/update-task-status.sh` — `--depends-on-add=<json-array>`
  with eager + semantic validation, status-no-op restriction, direction rule, write-time cycle
  refusal reusing `validate-state.sh`, `--dry-run` diff.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — cycle-refusal and
  idempotence fixtures plus negative and dry-run cases.
- `specs/state.json` — the suggester task's re-pointed `description` (state write, not a
  deliverable).
- `specs/344_batching_by_default_doctrine_at_point_of_use/summaries/01_batching-doctrine-point-of-use-summary.md`
  — implementation summary carrying the written token-cost justification, the re-measured Item 3
  figures, and the per-criterion acceptance evidence.

## Rollback/Contingency

Every phase is a scoped, per-substep commit, so the ordinary contingency is a targeted revert of
the offending phase's commit — the doc phases (1, 2, 6), the script phases (3, 4), the fixture
phase (5), and the state write (7) are independently revertible and have no shared edit surface
except `update-task-status.sh` between phases 3 and 4.

Specific contingencies:
- **Gate 20 cannot be satisfied byte-neutrally** (Phase 6): revert Phase 6's commit only. The
  guardrails and `multi-task-operations.md` work (Phases 1-2) stands on its own, and Item 1 is
  re-filed as a follow-up paired with a deliberate, reviewed `baseline_bytes` change owned by
  whoever owns `orchestrator-context-budget.json`. Do not move the baseline from inside this task.
- **The `validate-state.sh` subprocess reuse proves unworkable at implementation time** (Phase 4):
  do **not** fall back to transcribing a second Kahn implementation — that is explicitly
  forbidden. Mark Phase 4 `[BLOCKED]`, leave `--depends-on-add` unshipped (Phase 3's commit
  reverted too, since the flag must not exist without the refusal), and record the blocker.
- **The Item 7 state write goes wrong**: re-write the `description` field through `state-write.sh`
  with the corrected value; `specs/state.json` is additionally recoverable from git history.

If a genuine whole-tree rollback of uncommitted work becomes necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape (including its out-of-scope override flag) rather than improvising a destructive git
command.
