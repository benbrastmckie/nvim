# Implementation Plan: Task #274

- **Task**: 274 - Next-admissible-batch suggestion and alternatives-on-conflict, both computed by
  invoking the real admission script
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: 165, 272, 273, 275, 344 (all completed; none dropped)
- **Research Inputs**: `specs/274_next_admissible_batch_suggestion/reports/01_next-admissible-batch-suggestion.md`
- **Artifacts**: plans/01_next-admissible-batch-suggester.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build one new standalone script, `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`,
with two CLI modes mirroring the task's two modes (`--next-batch` for conclusion-time suggestion,
`--alternatives` for refusal-time alternatives) sharing a single internal admission-probe
function that shells out to the real `scripts/orchestrate-batch-admit.sh` and reads its v6
per-candidate verdicts. No collision, self-modification, or session-contention logic is
reimplemented anywhere in the new code. A caller-side edge-proposing step handles a
`file_scope`-colliding pair by proposing the serializing `dependencies[]` edge
(`update-task-status.sh --depends-on-add`) and presenting the pair as an ordered sequence instead
of silently withholding it. The script is then wired into the two existing trigger points —
Move 5's conclusion stage (new Step 7) and `commands/orchestrate.md`'s blocking `queue-check`
failure branch — and registered/documented across the manifest, the test corpus, and the
admission-schema consumer list.

### Research Integration

Findings carried directly into the phase structure:

- **The edge-proposing step needs no new admission logic.** `orchestrate-batch-admit.sh`'s
  collision comparison set already excludes any task connected to the candidate by a
  `dependencies[]` edge in either direction (the A1 dependency-edge exemption asymmetry). Adding
  the edge and re-invoking the real script is therefore sufficient to flip a colliding pair from
  `file_scope_collision` to `admit`. Phase 3 is a closed loop over the real predicate.
- **Mode A's render slot already exists.** The `### Conclusion` block in
  `context/patterns/orchestrate-batch-results-template.md` ends with `**Roadmap**: regenerated.`
  immediately before `### Next Steps`. The suggestion is a new informational line there, driven by
  a new Step 7 in `context/contracts/conclusion-stage.md`'s executable body (after Step 5's
  roadmap regenerate, folded into Step 6's render). It is NOT a fourth gated channel: it carries
  no `AskUserQuestion` approval and derives from `state.json`, not `issues.jsonl`, so
  conclusion-stage.md's Exactly-One-Channel and Hint-Versus-Decision rules do not apply to it.
- **Mode B's hook point is in `commands/orchestrate.md`, not `skill-orchestrate/SKILL.md`.** The
  one `task-lock.sh queue-check ... || exit 1` call site lives in the command file's setup
  section, ahead of the session mint and the Four-Move Loop. This is outside the originally
  declared `file_scope`; Phase 1 resolves that (see "Declared-scope reconciliation" below).
- **Reuse, never fork**: source `scripts/lib/task-classification-lib.sh` for
  `is_terminal_status()`; shell out to `scripts/orchestrate-triage-classify.sh` for the
  status→phase-group mapping that feeds `--phase-map`; shell out to
  `orchestrate-batch-admit.sh` for every admissibility probe. Do NOT source
  `scripts/lib/file-scope-overlap.sh` — the new script never needs to compute overlap itself,
  because every overlap fact it consumes arrives as a structured verdict field (`defer_reason`,
  `collision_scope`, `colliding_task_number`, `overlapping_path`).
- **Selection doctrine is already written down**: `context/patterns/batch-orchestration-guardrails.md`'s
  "Batching Is the Default" ranking (territory > topic > graph width, `MAX_TASKS=8` with
  territory-mandatory members listed first so a trim never splits a mandatory group off the end).
  Phase 2 applies it; it is selection guidance, never a substitute for the real admission probe.
- **Boundary with the ROADMAP coverage-appendix lint**: `scripts/roadmap-integration.sh`'s
  `render_coverage_appendix()` already emits chunked `/orchestrate N, M, ...` blocks with no
  `file_scope` check at all. That pre-existing gap belongs to the advisory-lint task for
  hand-authored batch proposals, not to this one. This task is the machine-derived *proposer*;
  that task is the *validator*. `roadmap-integration.sh` is not edited here, and its private
  `status_token()` is not reused — the small readiness predicate is computed independently
  instead (readiness is not the predicate the binding constraint protects).
- **Self-modification disposition**: the new script fails the reachability half of the
  two-conjunctive-test rule (it runs strictly after, or independently of, the admission/wave/lock
  decisions of the invocation it reports on), so it is NOT added to
  `context/reference/orchestrator-critical-paths.json` — consistent with
  `orchestrate-conclusion-aggregate.sh`, which is likewise absent. Phase 1 records this verdict
  in the new script's own header; Phase 5 closes the same documentation gap for both Move 5
  scripts together in the guardrails exclusion table.

### Declared-scope reconciliation

The research flagged one genuine gap: Mode B's hook needs a one-line edit to
`agent-system/extensions/core/commands/orchestrate.md`, which the task's declared `file_scope`
does not cover. This plan resolves it mechanically rather than by a mid-phase scramble: every file
this plan touches is listed in a phase's `**Files to modify**:` block, and
`scripts/plan-file-scope-harvest.sh` harvests the deduplicated union of those blocks into
`active_projects[].file_scope` at plan-postflight time (the only moment
`update-task-status.sh --file-scope-add` is admissible — it is restricted to
`postflight` with `target_status` in `{research, plan}`). No separate widening call is needed, and
no implementation phase has to request one. The resulting `file_scope` widens from four entries to
the ten listed in "Artifacts & Outputs" below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so `specs/ROADMAP.md` was
not loaded as a planning input. The research report's own ROADMAP cross-reference (the open-work
entry for the advisory batch-proposal lint) is carried forward above as a boundary note only.

## Goals & Non-Goals

**Goals**:

- One new script with two CLI modes and one shared admission-probe function, establishing
  admissibility exclusively by invoking `orchestrate-batch-admit.sh` and reading its v6 verdicts.
- A caller-side edge-proposing step: on an in-batch `file_scope_collision` between two otherwise
  suggestible candidates, propose the serializing edge and present the pair as an ordered
  sequence, never silently drop it.
- A bounded Mode B alternatives search over the live orchestration queue (`task-lock.sh
  queue-list`), with an explicitly stated probe cap.
- A fixture fleet that mechanically demonstrates each acceptance criterion, including a
  grep-provable "no copy of the admission predicate" regression.
- Both trigger points wired, and the new consumer documented in the admission-schema consumer
  list without touching the schema itself.

**Non-Goals**:

- Any change to `orchestrate-batch-admit.sh`, its verdict schema, or its version — the script is
  consumed, never modified or extended. Alternatives are a caller-side loop, not a schema field.
- Any change to `scripts/roadmap-integration.sh` or `render_coverage_appendix()`.
- Adding the new script to `context/reference/orchestrator-critical-paths.json`.
- Any edit under `.claude/**` (a disposable deploy artifact). All edits land in the source store,
  `agent-system/extensions/core/`.
- Any approval-gate (`--record-approval` / `--check-approval`) machinery for the suggestion. It is
  informational, like the `**Roadmap**: regenerated.` line it sits beside.
- Removing the transitively redundant `dependencies[]` edge on task 272 from this task's own
  state entry.

## Decisions

These are design choices this plan makes and the implementation must follow, not open questions:

1. **Edge direction convention**: the lower `project_number` is written as the predecessor
   (`--depends-on-add` is called on the higher-numbered task, which is the task that *gains* the
   dependency). This is a deterministic rendering choice, chosen for consistency with
   `orchestrate-predispatch-review.sh`'s existing Class D display convention and the self-
   modification tie-breaker's ascending-first convention — it is explicitly NOT a claim that
   numbering reveals a pre-existing truth about which task logically precedes the other
   (`context/patterns/multi-task-operations.md` warns against exactly that inference). The new
   script's header must state the convention in those terms.
2. **Propose-by-default, write only on opt-in**: in its default form the edge-proposing step
   emits the exact `update-task-status.sh ... --depends-on-add=[...]` command alongside the
   ordered-sequence suggestion, and labels that pair's admissibility as conditional on the edge
   (citing the dependency-edge exemption as the mechanism). An explicit `--write-edges` flag
   performs the real write and then **re-probes the real admission script** to show both
   candidates flip to `admit`. Rationale: conclusion time is the wrong moment to mutate
   `specs/state.json` dependency edges unasked, while the stronger reading of the
   edge-proposing step (write, then re-probe) is exactly what discharges the acceptance criterion
   — so both are available and the acceptance demonstration uses `--write-edges` under a scratch
   tree. Neither form may ever silently drop a colliding pair.
3. **`--depends-on-add` is issued as a dedicated no-op status call**: the flag requires
   `operation:target_status` to resolve to the task's *current* status, so the edge write cannot
   ride along on an unrelated transition. The call is idempotent (union-merge), and
   `update-task-status.sh` already refuses a cycle-introducing edge via its own
   `validate-state.sh --deep` check — the new script does not re-check for cycles.
4. **Readiness is computed locally; admission never is.** Readiness ("is this task's own
   dependency graph clear") is a small independent jq predicate in the new script — non-terminal
   status via `task-classification-lib.sh`'s `is_terminal_status()`, plus every `dependencies[]`
   entry either absent from `active_projects` or itself `completed`. Admission ("does this
   candidate set collide") comes only ever from `orchestrate-batch-admit.sh`.
5. **Absent-`file_scope` posture is taken from the shipped v6 ruling, not assumed**: blocking
   in-batch, advisory cross-batch, converging via the lowest-numbered absent-scope candidate. The
   suggester reads the verdicts' `absent_scope_advisory` / `designated_absent_candidate` fields
   rather than deciding anything itself. (The dependency that owns that ruling is completed, so
   no edge was dropped and no fallback posture had to be assumed.)
6. **Suggestions are time-stamped claims, not guarantees**: the rendered text states plainly that
   the set was admissible when suggested and should be re-verified at dispatch. The real
   admission check at actual dispatch time remains the sole source of truth.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A later edit re-derives collision logic locally "for speed", drifting from the real predicate | H | M | Phase 4 ships a grep-provable regression: the new script's source contains no `file-scope-overlap` jq defs and no hand-rolled path-prefix comparison |
| The `commands/orchestrate.md` scope gap surfaces mid-phase as an unplanned widen | M | H (if unaddressed) | Resolved up front: the file is listed in Phase 5's `Files to modify`, so the plan-postflight harvest widens `file_scope` before any implementation dispatch runs |
| Mode B's alternatives search probes a combinatorially large number of subsets | M | M | Phase 3 bounds the search explicitly: candidates not covered by any live queue entry, filtered by the Mode A doctrine, with a hard cap on probe invocations stated in the script header and asserted by a fixture |
| A suggested batch is admissible at suggestion time but not when the user runs it | L | H | Accepted and stated in the rendered text (Decision 6); dispatch-time admission remains authoritative |
| The edge-proposing step autonomously mutates `specs/state.json` at conclusion time | M | L | Decision 2: propose-only by default; the write is opt-in via `--write-edges` |
| A new script is added to the source store but never deployed because the manifest was not updated | M | M | Phase 4 registers both the script and its suite in `manifest.json` and adds a `suite-cost-hints.txt` entry, verified by `test-manifest-scripts-sync.sh` |
| Mode A's suggestion is mistaken for a fourth approval channel in the conclusion stage | L | M | Phase 5's `conclusion-stage.md` Step 7 text states explicitly that it is informational, ungated, and not `issues.jsonl`-derived |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is deliberately serial: Phases 1-3
all build up one new file, Phase 4 tests the behavior Phase 3 completes, and Phase 5 wires the
finished script into its callers.

---

### Phase 1: Script skeleton, CLI contract, and header dispositions [NOT STARTED]

**Goal**: `orchestrate-suggest-next-batch.sh` exists in the source store with strict mode, a
validated two-mode CLI, a working `--help`, and a header comment that records every disposition
this plan decided — so no later phase has to re-litigate them.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` with the
      strict-mode preamble and script-dir/project-root resolution per
      `context/standards/shell-strict-mode.md`, modelled on the sibling
      `orchestrate-conclusion-aggregate.sh` (source-store/deployed dual-path tolerance included).
- [ ] Implement argument parsing and validation for the two modes: `--next-batch` (Mode A) and
      `--alternatives` (Mode B), mutually exclusive, exactly one required; plus `--session-id
      <id>`, `--max-tasks <N>` (default 8), `--write-edges` (default off, per Decision 2), and
      `--help`. An unrecognized flag or a missing/duplicate mode is a usage error (exit 2) with a
      loud stderr line, never a silent default.
- [ ] Write the header comment block recording, each as its own named paragraph: (a) the binding
      constraint — admissibility is established ONLY by invoking `orchestrate-batch-admit.sh`,
      with the reason (a second copy would drift, and a suggestion the real script then refuses is
      worse than none); (b) the self-modification-hazard disposition — excluded from
      `orchestrator-critical-paths.json`, failing the reachability test because this script runs
      after or independently of the admission/wave/lock decisions it reports on; (c) the
      edge-direction convention of Decision 1, stated as a deterministic rendering choice and
      explicitly not an inferred truth; (d) the propose-by-default / `--write-edges` split of
      Decision 2; (e) the "admissible when suggested, re-verify at dispatch" limitation.
- [ ] Add the exit-code contract to the header and implement its skeleton: 0 on a rendered
      suggestion, 0 with an explicit "no suggestible batch" line when the pool is empty (never a
      nonzero exit for "found nothing"), 2 for usage errors, and a documented nonzero for an
      unavailable `specs/state.json` or a missing admission script (fail loud, never silently
      suggest nothing).
- [ ] `chmod +x` the new script.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The only executable touched is the brand-new script, which no call site
yet invokes, so `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 22
agent-system/extensions/core` (the shellcheck gate) plus a `--help` and bad-flag smoke invocation
covers its whole blast radius.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - new file: strict-mode
  preamble, two-mode argument parsing and validation, `--help`, exit-code contract, full header
  disposition block

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 22 agent-system/extensions/core`
  passes (shellcheck clean).
- `bash agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh --help` exits 0 and
  prints both modes.
- Invoking with no mode, with both modes, and with an unrecognized flag each exits 2 with a stderr
  line naming the problem.
- `grep -c 'file-scope-overlap' <new script>` is 0 (the no-forked-predicate invariant, asserted
  from the first phase onward rather than only at the end).

---

### Phase 2: Candidate pool, phase map, and the shared admission probe (Mode A) [NOT STARTED]

**Goal**: `--next-batch` produces a real, admission-verified suggestion end to end: build the
ready-candidate pool, derive `--phase-map`, select a candidate set by the documented doctrine, and
prove the set admissible by invoking the real admission script.

**Tasks**:
- [ ] Implement the readiness predicate (Decision 4): source
      `scripts/lib/task-classification-lib.sh` and use `is_terminal_status()`; exclude
      `hold`/`implementing`/`blocked`/`partial`; require every `dependencies[]` entry to be either
      absent from `active_projects` or itself `completed`. Keep it to a small jq block and do not
      widen scope into `roadmap-integration.sh` or `orchestrate-cycle-plan.sh` to share theirs.
- [ ] Derive the `--phase-map` argument by invoking
      `scripts/orchestrate-triage-classify.sh mt <task_numbers...>` and mapping each verdict's
      `group` through the `research|plan|implement` filter, mirroring the existing composition in
      `scripts/orchestrate-cycle-plan.sh`'s admission block. Never re-derive the status→group
      mapping inline.
- [ ] Implement the one shared `probe_candidate_set()` function: invoke
      `scripts/orchestrate-batch-admit.sh --invocation-count <size of this candidate set>
      --session-id <forwarded id> --phase-map <derived map> <task_numbers...>`, and parse its v6
      verdicts for `verdict`, `defer_reason`, `collision_scope`, `colliding_task_number`,
      `overlapping_path`, `absent_scope_advisory`, and `designated_absent_candidate`. Both modes
      call this one function; no mode gets its own copy.
- [ ] Apply the selection doctrine from `batch-orchestration-guardrails.md`'s "Batching Is the
      Default": territory-mandatory members first, then same-`topic` dispatch-safe candidates,
      then prefer widening wave 1 over extending a chain while always including a dependent whose
      sole prerequisite is already in the set; truncate at `--max-tasks` (default 8) with
      territory-mandatory members ordered first so a trim never splits a mandatory group off the
      end.
- [ ] Render Mode A's output: the `/orchestrate N, M, ...` line, the per-member verdict evidence,
      and the "verified against the current queue/registry; re-run to re-verify before acting"
      caveat (Decision 6). Emit an explicit "no suggestible batch" line, exit 0, when the pool is
      empty.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: All edits stay inside the one new script, which still has no call site, so
`verify-deploy.sh --only-gate 22 agent-system/extensions/core` plus a live `--next-batch` run
against the real `specs/state.json` (read-only — the probe and the triage classifier are both
read-only) covers every path this phase adds.

**Scope Hypothesis**: This phase assumes `orchestrate-triage-classify.sh mt` and
`orchestrate-batch-admit.sh --phase-map` can be composed exactly as
`orchestrate-cycle-plan.sh`'s admission block already composes them, and that the v6 verdict
fields named above are all present. Confirm at implementation time by reading that block and the
admission script's verdict-schema header before writing the probe, and by asserting each parsed
field is non-null-or-absent-by-design on a real invocation — do not treat the field list as
given.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - readiness predicate,
  phase-map derivation, the shared `probe_candidate_set()` function, selection doctrine, Mode A
  rendering

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 22 agent-system/extensions/core`
  passes.
- `bash agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh --next-batch
  --session-id <a test id>` emits a suggestion (or the explicit empty-pool line) and exits 0, with
  every member's admission verdict shown.
- `specs/state.json` is byte-identical before and after that run (`git diff --stat` empty for it)
  — Mode A is read-only.
- The script's source still contains no `file-scope-overlap` reference and no hand-rolled
  path-prefix comparison.

---

### Phase 3: Edge-proposing step and Mode B alternatives search [NOT STARTED]

**Goal**: a `file_scope`-colliding pair is never silently withheld — it is proposed as an ordered
sequence with the serializing edge named (and, under `--write-edges`, written and re-probed); and
`--alternatives` performs a bounded search for a candidate set disjoint from every live queue
entry.

**Tasks**:
- [ ] Implement the edge-proposing step: when `probe_candidate_set()` returns an `in_batch`
      `file_scope_collision` between two members of an otherwise suggestible set, compute the
      ordered pair per Decision 1 (lower `project_number` as predecessor, so `--depends-on-add` is
      called on the higher-numbered task) and emit the exact dedicated no-op-status
      `update-task-status.sh postflight <higher> <its current status> <session_id>
      --depends-on-add=[<lower>]` command (Decision 3) together with the ordered-sequence
      suggestion and a line naming the dependency-edge exemption as the mechanism that makes the
      sequence admissible.
- [ ] Implement `--write-edges`: perform that write, then **re-invoke
      `probe_candidate_set()` over the same candidate set** and show both members' verdicts flip
      to `admit`. Do not re-check for cycles locally — `update-task-status.sh` already refuses a
      cycle-introducing edge. Surface a refused write loudly and fall back to propose-only for
      that pair rather than dropping it.
- [ ] Implement Mode B's input read: invoke `bash .claude/scripts/task-lock.sh queue-list` (with
      the source-store-aware path resolution from Phase 1) and parse its NDJSON entries for
      `task_numbers[]`, `file_scope[]`, `orchestration_id`, `command`, `state`, and the computed
      `live`/`liveness_reason`. Treat an empty queue as a normal case, not an error.
- [ ] Implement the bounded alternatives search: start from the Phase 2 ready pool minus every
      task covered by a live queue entry, apply the same selection doctrine, and probe candidate
      sets through the one shared probe function under a hard cap on probe invocations (a named
      constant, stated in the header, with the cap-reached condition rendered explicitly rather
      than silently truncating the search). Render each surviving alternative as its own
      `/orchestrate ...` line with its verdict evidence and the same re-verify caveat.
- [ ] Confirm in the header that the alternatives search is a caller-side loop and that no field
      was added to the admission verdict schema.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edit is still confined to the one new script with no call site wired,
and its sole write path delegates to `update-task-status.sh`, whose own cycle-refusal and
union-merge behavior are already covered by `bash
agent-system/extensions/core/scripts/tests/run-all.sh --only test-update-task-status.sh` — run
that suite plus `verify-deploy.sh --only-gate 22 agent-system/extensions/core`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - edge-proposing step,
  `--write-edges` write-then-reprobe path, `queue-list` read, bounded alternatives search, Mode B
  rendering

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 22 agent-system/extensions/core`
  passes.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-update-task-status.sh`
  passes (the delegated write path's own suite).
- `--alternatives --session-id <test id>` exits 0 against the live queue (empty or not) and leaves
  `specs/state.json` unchanged.
- A hand-constructed colliding pair is rendered as an ordered sequence with the
  `--depends-on-add` command shown — never omitted from the output. (The mechanical fixture proof
  of this, and of the post-write `admit` flip, lands in Phase 4.)

---

### Phase 4: Fixture fleet, manifest registration, and the no-forked-predicate regression [NOT STARTED]

**Goal**: every acceptance criterion is demonstrated mechanically by a registered suite, and the
new script and suite are wired into the manifest and cost hints so the deploy carries them.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`,
      modelled on `scripts/tests/test-orchestrate-conclusion-aggregate.sh`: the same dual-path
      script resolution (deployed `.claude/scripts/` first, then the source-store sibling), the
      same scratch-tree construction (copy the script under test plus
      `orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`, `update-task-status.sh`,
      `task-lock.sh`, `lib/file-scope-overlap.sh`, `lib/task-classification-lib.sh` and
      `context/reference/orchestrator-critical-paths.json` into a scratch root so
      `PROJECT_ROOT`-relative `specs/state.json` reads resolve to the fixture), and the same
      loud-abort-on-missing-script preamble.
- [ ] Fixture (a) — happy path: a clean multi-task ready set that the real admission script admits
      wholesale; assert every member appears in the Mode A suggestion with an `admit` verdict.
- [ ] Fixture (b) — the edge-proposing acceptance case: two ready candidates with colliding
      `file_scope` and no existing edge. Assert the pair does NOT appear as an unordered joint
      suggestion before the step runs, DOES appear as an ordered sequence with the
      `--depends-on-add` command rendered, and — under `--write-edges` — that a re-probe of the
      real admission script reports both as `admit`.
- [ ] Fixture (c) — Mode B: a live queue entry whose `file_scope` collides with every member of
      the obvious next batch, forcing the alternatives search to surface a different, disjoint
      set.
- [ ] Fixture (d) — an absent-`file_scope` candidate, asserting the shipped blocking-in-batch /
      advisory-cross-batch split is reflected in the suggestion rather than second-guessed.
- [ ] Fixture (e) — a ready pool larger than `--max-tasks`, asserting the truncation-precedence
      rule: territory-mandatory members are never split off the end.
- [ ] Fixture (f) — the no-forked-predicate regression: assert the new script's source contains no
      `file-scope-overlap` reference, no `scopes_overlap`/`norm`/`self_mod_match` jq def, and no
      hand-rolled path-prefix comparison; and assert the alternatives search added no field to the
      admission verdict schema (`docs/architecture/batch-admit-schema.md`'s schema section is
      unchanged).
- [ ] Fixture (g) — the probe-cap assertion from Phase 3: the alternatives search never exceeds
      its named cap, and the cap-reached condition is rendered rather than silent.
- [ ] Register both new files in `agent-system/extensions/core/manifest.json` —
      `orchestrate-suggest-next-batch.sh` in `provides.scripts` and
      `tests/test-orchestrate-suggest-next-batch.sh` in the tests list, each in the existing
      alphabetical position.
- [ ] Add a `test-orchestrate-suggest-next-batch.sh,<measured ms>` line to
      `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`, using a real measured
      runtime rather than an estimate.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: `manifest.json` is a registration surface with multiple independent
consumers (the deploy, the script inventory, the manifest-sync check), so the covering check is
the changed module plus its enumerated direct dependents: `bash
agent-system/extensions/core/scripts/tests/run-all.sh --only
test-orchestrate-suggest-next-batch.sh,test-manifest-scripts-sync.sh,test-script-inventory.sh`.

**Scope Hypothesis**: Seven fixtures (a)-(g) are asserted to cover the acceptance criteria, and
the scratch-tree copy list above is asserted to be sufficient for a
`PROJECT_ROOT`-relative admission probe. Confirm at implementation time by running each fixture
and observing it exercise the intended branch (a fixture that passes without reaching its branch
is not coverage), and by adding whatever further scratch-tree files a failing probe reveals it
needs — the copy list is a starting hypothesis, not a verified inventory.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` - new file:
  fixtures (a)-(g), scratch-tree harness, dual-path script resolution
- `agent-system/extensions/core/manifest.json` - register the new script and its test suite
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - add the new suite's measured
  cost hint

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-orchestrate-suggest-next-batch.sh,test-manifest-scripts-sync.sh,test-script-inventory.sh`
  passes, with the new suite's own case count matching the seven fixtures.
- Each fixture's assertion failure mode is checked by deliberately inverting its expectation once
  and observing a red result (so no fixture is vacuously green).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 22
  agent-system/extensions/core` passes for the new suite file.

---

### Phase 5: Wire both triggers, document the new consumer, close the self-mod doc gap [NOT STARTED]

**Goal**: Mode A fires from the conclusion stage and renders into the batch-results `###
Conclusion` block; Mode B fires at the `queue-check` refusal; the new consumer is recorded in the
admission-schema consumer list without touching the schema; and the Move 5 self-modification
disposition is written down for both Move 5 scripts.

**Tasks**:
- [ ] `context/contracts/conclusion-stage.md`: add **Step 7 — Suggest next batch** to "## The
      Executable Stage Body", placed after Step 5 (Roadmap update) with its render folded into
      Step 6 (Report). State explicitly that it is informational, carries no approval gate, is
      derived from `specs/state.json` rather than `issues.jsonl`, and is therefore NOT a fourth
      channel — the Exactly-One-Channel and Hint-Versus-Decision rules do not apply to it. Give
      the copy-pasteable `orchestrate-suggest-next-batch.sh --next-batch --session-id
      "$session_id"` invocation.
- [ ] `context/patterns/orchestrate-batch-results-template.md`: add a `**Suggested next batch**:
      /orchestrate {suggested_task_numbers}` line to the `### Conclusion` block immediately after
      `**Roadmap**: regenerated (`specs/ROADMAP.md`).`, with the re-verify caveat and the
      colliding-pair sequence rendering, and a note that the line is omitted-with-an-explicit-
      reason rather than left blank when no batch is suggestible.
- [ ] `commands/orchestrate.md`: replace the bare `|| exit 1` on the blocking `queue-check` call
      with a branch that invokes `orchestrate-suggest-next-batch.sh --alternatives --session-id
      "$batch_session_id"` and then exits 1. The refusal must still abort — the suggestion is
      additive output on the way out, never a reason to continue — and a failure of the suggester
      itself must not mask the refusal's own exit code.
- [ ] `skills/skill-orchestrate/SKILL.md`: add the Move 5 pointer to the new Step 7 so the skill's
      own conclusion-stage description and the contract do not diverge. Keep it a pointer, not a
      second copy of the step body.
- [ ] `docs/architecture/batch-admit-schema.md`: add exactly one row/line to the "Read by"
      consumer list naming `orchestrate-suggest-next-batch.sh` and what it does with the verdicts
      (re-presents them to suggest a batch; never re-derives the predicate; writes only a
      serializing `dependencies[]` edge, strictly outside the verdict schema). Make NO change to
      "## Complete JSON Schema", "## Field Definitions", any versioned field, or the Version
      History.
- [ ] `context/patterns/batch-orchestration-guardrails.md`: add one row to the
      `orchestrator-critical-paths.json` Exclusion Table covering both Move 5 scripts together
      (`orchestrate-conclusion-aggregate.sh` and `orchestrate-suggest-next-batch.sh`), recording
      the reachability/decision-relevance verdict and why — closing the documentation gap the
      research found for the existing script opportunistically alongside the new one.
- [ ] Re-read every edited markdown file for task-number references and remove any that would
      land outside `specs/**` (cite durable anchors — filenames, section headings, decision names
      — instead).

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - new Step 7 in the
  executable stage body
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - the
  `**Suggested next batch**` render line in the `### Conclusion` block
- `agent-system/extensions/core/commands/orchestrate.md` - Mode B hook at the blocking
  `queue-check` failure branch
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 5 pointer to Step 7
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - one new "Read by"
  consumer entry; schema itself untouched
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - one
  Exclusion Table row covering both Move 5 scripts

**Verification**:
- The complete gate set passes: `bash agent-system/extensions/core/scripts/verify-deploy.sh
  agent-system/extensions/core` (every gate, no `--skip-slow`, no `--only-gate` narrowing) —
  including Gate 3 (doc-lint), Gate 4 (task-reference lint), Gate 8 (the full shell-suite
  battery), Gate 22 (shellcheck), and every other gate it aggregates.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes with no new failures against
  `scripts/tests/known-failures.txt`.
- `git diff` on `docs/architecture/batch-admit-schema.md` touches only the consumer list — no
  schema, field-definition, or version-history line.
- `grep -n 'queue-check' commands/orchestrate.md` shows the refusal still exits 1 on the
  suggester's failure as well as its success.

---

## Testing & Validation

- [ ] A suggested batch is verified by running the real admission script over it and showing every
      member admitted (fixture a).
- [ ] A fixture where two candidates collide on `file_scope` demonstrably does NOT appear as a
      joint (unordered) suggestion (fixture b, pre-edge assertion).
- [ ] That same colliding pair DOES appear as an ordered sequence with the `--depends-on-add`
      command proposed, and flips to `admit` on a real re-probe under `--write-edges` (fixture b,
      post-edge assertion).
- [ ] No copy of the admission predicate exists anywhere in the new code — grep-provable (fixture
      f).
- [ ] The alternatives search added no field to the admission verdict schema (fixture f).
- [ ] shellcheck clean per `context/standards/shell-strict-mode.md` (Gate 22).
- [ ] No task-number references in any deliverable outside `specs/**` (Gate 4).
- [ ] Mode A and Mode B both leave `specs/state.json` unchanged in their default form.

## Artifacts & Outputs

New files:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`

Modified files:
- `agent-system/extensions/core/manifest.json`
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`

Deliberately untouched: `scripts/orchestrate-batch-admit.sh`, its verdict schema,
`scripts/roadmap-integration.sh`, and `context/reference/orchestrator-critical-paths.json`.

## Rollback/Contingency

Each phase commits on its own green sub-steps, so reverting is per-phase. The two new files can be
deleted outright with no consumer left dangling as long as Phase 5's wiring is reverted in the same
step — the ordering dependency runs one way only: Phases 1-4 are inert (nothing calls the new
script), and only Phase 5 makes it reachable. If Phase 5's `commands/orchestrate.md` hook proves
problematic, reverting that one line restores the bare `|| exit 1` refusal with no loss of existing
behavior; the conclusion-stage Step 7 can likewise be reverted independently, leaving the script
in place and unused. Before any intentional rollback that would discard uncommitted work, take a
checkpoint with `bash .claude/scripts/git-snapshot.sh 274 --no-revert` first.
