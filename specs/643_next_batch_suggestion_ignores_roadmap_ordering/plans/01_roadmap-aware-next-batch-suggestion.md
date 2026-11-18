# Implementation Plan: Task #643

- **Task**: 643 - Align /orchestrate's conclusion-stage next-batch suggestion with the authored roadmap ordering, or render both so the divergence is visible
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/643_next_batch_suggestion_ignores_roadmap_ordering/reports/01_roadmap_aware_suggester.md
- **Artifacts**: plans/01_roadmap-aware-next-batch-suggestion.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-suggest-next-batch.sh`'s Mode A selects its candidate sets from the ready pool
sorted ascending by `project_number` and truncated to `MAX_TASKS=8`, so the conclusion stage's
Step 7 suggestion is structurally blind to `specs/state.json`'s authored `roadmap_batches`
ordering — the one artifact carrying operator priority — and recommends the oldest ready task
numbers instead. This plan implements the research report's Direction (a): factor the existing
readiness predicate into a reusable set, add a roadmap-batch candidate source that walks
`roadmap_batches` in authored array order (readiness-filtering each batch, skipping an
empty-filtered batch at zero probe cost, probing the first non-empty one through the existing
unmodified `suggest_from_candidates()` engine), and fall back to today's three mechanical options
only with an explicit stated reason. Definition of done: a Step 7 suggestion either names an
authored roadmap batch (with its `description`) or states plainly why no authored batch was
admissible and what it fell back to; the existing suite covers the absent-key,
empty-array, and no-admissible-authored-batch paths; and the full gate set passes after redeploy.

The edit target is the source store `agent-system/extensions/core/**` (resolved
`.extensions.core.source_dir` = `/home/benjamin/.config/nvim/agent-system/extensions/core`),
never the deployed `.claude/**` tree, with a redeploy via `deploy-headless.sh` afterwards.

### Research Integration

Findings integrated from `reports/01_roadmap_aware_suggester.md`:

- **Direction (a) adopted, (b) and (c) rejected** — (c) can never satisfy the acceptance
  criterion's "names an authored roadmap batch" half; (b) as an always-on dual render restores
  exactly the two-disjoint-lists confusion the task exists to remove. (b)'s spirit is preserved
  as the mandatory fallback-explanation line.
- **Readiness filtering is local and pre-probe** — `orchestrate-batch-admit.sh` has no readiness
  notion at all (file-scope collision + self-modification hazard only), so the binding constraint
  governs the collision dimension exclusively. `build_ready_pool()` already runs before any probe;
  the roadmap walk preserves that split unchanged.
- **Two precedents reused instead of a third readiness check** — `build_ready_pool()`'s fuller bar
  (non-terminal, not hold/implementing/blocked/partial, every dependency completed) and
  `roadmap-integration.sh`'s `render_next()` "omit terminal members, render the still-live ones"
  convention for a mixed batch.
- **Live-corpus validation** — walking the 15 live `roadmap_batches` entries, the first four
  authored batches filter to empty (every member mid-lifecycle) and are skipped at zero probe
  cost; batch 5 is the first non-empty filtered candidate. The walk is cheap on real data; a
  filtered-to-one-member batch is a valid candidate (`suggest_from_candidates()` already accepts a
  length-1 list).
- **Probe budget and cap-reached rendering already exist** — `MAX_PROBE_INVOCATIONS=20` is a
  shared script-global counter; a cap hit during the roadmap walk routes through the existing
  `PROBE_CAP_HIT` / `run_candidate_round()` convention, never a second cap message.
- **One doc anchor** — `context/patterns/orchestrate-batch-results-template.md`'s
  `**Suggested next batch**:` section needs the new render case; Step 7's invocation line in
  `context/contracts/conclusion-stage.md` is unchanged because only the invoked script's internals
  change.

**Premise re-validation (Carried-Figure Discipline).** The four extracted description lines were
each checked against live state at plan time, not assumed:

- *Source store is the edit target* — CONFIRMED live: `.extensions.core.source_dir` resolves to
  `/home/benjamin/.config/nvim/agent-system/extensions/core`, and both the script and its suite
  exist there.
- *1,085 lines, zero `roadmap_batches`/`roadmap_notes`/`ROADMAP` occurrences* — CONFIRMED
  unchanged: `wc -l` = 1085; `grep -c` over the whole file = 0.
- *Nearest closed record not covering* — carried from the research report unchanged; the record is
  archived and not independently re-checkable at plan time, and nothing in the live script
  contradicts it (the ascending-truncation bias and the roadmap blindness are both still present).
- *Binding constraint (admissibility only from `orchestrate-batch-admit.sh`)* — CONFIRMED
  unchanged: the script's header section `(a) Binding constraint` states it verbatim, and
  `probe_candidate_set()` remains the only admission path. This plan adds no second predicate.

**Two mechanical findings made at plan time, not present in the research report:**

1. `usage()` prints the header by fixed line range (`sed -n '2,94p'`, at
   `orchestrate-suggest-next-batch.sh:99`), and the header currently ends at line 94. Any header
   lines added to document the roadmap walk silently fall outside `--help` output unless that
   range is widened in the same edit.
2. Editing `context/patterns/orchestrate-batch-results-template.md` moves its own `line_count`
   entry in `agent-system/extensions/core/index-entries.json` (currently 271). That check
   (`check-extension-docs.sh` Rule R) is not commit-blocking in this repository — no `pre-commit`
   hook is installed, verified at plan time — so the declaration is owed in the phase that moves
   the count while the regeneration itself is reconciled by `deploy-headless.sh` in the final
   phase.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed at plan time. (Note the irony and the scope boundary: this task changes how a
roadmap is *consumed* by the suggester; it does not author or reorder `roadmap_batches` itself.)

## Goals & Non-Goals

**Goals**:

- Make `specs/state.json`'s authored `roadmap_batches` ordering the primary candidate source for
  Mode A's next-batch suggestion, walked in array order.
- Readiness-filter each authored batch using the existing predicate, skipping an empty-filtered
  batch without spending a probe invocation.
- Establish admissibility exclusively through the existing `suggest_from_candidates()` ->
  `probe_candidate_set()` -> `orchestrate-batch-admit.sh` chain, unmodified.
- Render the chosen batch's `description` so the operator sees why it was authored.
- When no authored batch survives filtering and probing, print one explicit line naming how many
  batches were checked and why none was usable, then fall through to today's three mechanical
  options unchanged.
- Cover the new behavior in `scripts/tests/test-orchestrate-suggest-next-batch.sh`, including the
  absent-`roadmap_batches` and empty-array paths and the no-admissible-authored-batch path.

**Non-Goals**:

- No second copy of the collision/admissibility predicate anywhere (the script's binding
  constraint (a) stands).
- No change to Mode B (`--alternatives`) selection behavior, which keeps its single-pool
  `suggest_from_pool()` path.
- No change to Step 7's invocation line in `context/contracts/conclusion-stage.md`, nor to the
  script's CLI surface (no new flags).
- No authoring, reordering, or mutation of `roadmap_batches` itself, and no change to
  `roadmap-integration.sh` or `specs/ROADMAP.md` rendering.
- No always-on dual (roadmap + mechanical) render; the mechanical options remain a stated fallback.
- No speculative `MAX_ROADMAP_BATCHES_TRIED` cap unless Phase 3's testing shows the shared probe
  budget is actually insufficient.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A `state.json` whose leading authored batches are mostly non-empty-but-deferring consumes the shared `MAX_PROBE_INVOCATIONS` budget before the mechanical fallback is reached | M | L | Empty-filtered batches cost zero probes (live-corpus: 4 leading skips, 0 probes). Route any cap hit through the existing `PROBE_CAP_HIT` line. Only add a batches-tried cap if Phase 3 demonstrates a real exhaustion case |
| A `roadmap_batches` entry names a `task_id` no longer in `active_projects` (vault renumbering, stale authoring) | M | M | The readiness SET built in Phase 1 has no entry for an absent task, so absent is treated identically to not-ready; Phase 3 covers this with its own case |
| Refactoring `build_ready_pool()` silently changes the existing mechanical selection | H | L | Phase 1 is behavior-preserving by construction and verified by the existing suite passing unchanged before any roadmap logic is added (Phase 2) |
| Header additions fall out of `--help` because `usage()` uses a fixed `sed -n '2,94p'` range | L | H | Phase 2 explicitly widens that range in the same edit and verifies `--help` prints the new lines |
| Existing test cases break because their scratch `state.json` has no `roadmap_batches` key | M | M | The absent-key path is a silent zero-probe skip straight to the mechanical render, which is precisely what keeps cases (a)-(g) green; Phase 2's verification runs the suite unchanged before new cases are added |
| Source-store invocation refused by `deploy-root-guard.sh` | L | M | All live-tree attestation happens in Phase 5, after `deploy-headless.sh`; earlier phases verify through the suite's scratch deployed-tree fixture, which is how this suite already runs |

## Decisions

- **Roadmap walk runs before the three mechanical criteria and suppresses them on success.** The
  acceptance criterion is an either/or contract; rendering both every time reproduces the
  divergence confusion rather than resolving it.
- **Readiness stays a local, pre-probe predicate; admissibility stays exclusively
  `orchestrate-batch-admit.sh`'s.** This is the split the existing mechanical path already uses;
  the roadmap source changes which sets get probed, never what establishes admissibility.
- **The fallback line is mandatory, not optional.** It is the surface that makes a roadmap /
  suggester divergence visible, discharging candidate direction (b)'s goal without a dual render.
- **`index-entries.json`'s `line_count` drift is declared in Phase 4 and reconciled in Phase 5.**
  Permitted because Rule R is advisory here (no `pre-commit` hook installed, verified at plan
  time) and `deploy-headless.sh` auto-repairs it as a side effect of regeneration.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Factor the readiness predicate into a reusable ready set [COMPLETED]

**Goal**: One readiness computation, two consumers — the existing flat ascending ready-pool list
and (in Phase 2) per-batch filtering — with no observable change to today's output.

**Tasks**:
- [x] Read `build_ready_pool()` (`orchestrate-suggest-next-batch.sh`, around lines 303-336) and its
      header comment in full before editing. *(completed)*
- [x] Introduce a script-level associative set (e.g. `declare -A READY_SET=()`) populated once by a
      new `build_ready_set()` that carries the existing three-condition predicate verbatim
      (non-terminal via the sourced `is_terminal_status`; not hold/implementing/blocked/partial;
      every `dependencies[]` entry absent-or-completed). Do not restate or re-derive the predicate
      — move it. *(completed)*
- [x] Reduce `build_ready_pool()` to emitting the same ascending `task_number`-per-line stream from
      that set, preserving its exact current output contract (`sort -n -k1,1` ordering, one number
      per line, no trailing noise). *(completed)*
- [x] Add a `task_is_ready <num>` accessor (a set membership test) so an absent-from-`active_projects`
      task id is false rather than silently true. *(completed)*
- [x] Update `build_ready_pool()`'s header comment to say the predicate now lives in
      `build_ready_set()` and is shared, keeping the Decision-4 attribution intact. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's single path returns exactly
`test-orchestrate-suggest-next-batch.sh`, so `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
is the covering check for a refactor confined to one file with no CLI or output change.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - add `build_ready_set()` + `task_is_ready()`; `build_ready_pool()` becomes a consumer of the shared set

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
  passes with the same case count as before the edit (behavior-preserving refactor).
- `bash -n agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` clean, and
  `shellcheck` (if available) reports no new findings on the edited file.

---

### Phase 2: Add the roadmap-batch candidate source to Mode A [COMPLETED]

**Goal**: Mode A walks `roadmap_batches` in authored order, probes the first non-empty
readiness-filtered batch through the existing engine, renders it with its `description`, and
otherwise falls through to the mechanical options with an explicit stated reason.

**Tasks**:
- [x] Add a `read_roadmap_batches()` reader: `jq` over `STATE_FILE` emitting one line per batch
      (`task_ids` CSV plus `description`), tolerating an absent key and an empty array identically
      (both yield zero lines, zero probes). *(completed)*
- [x] Add `suggest_from_roadmap_batches()`: for each batch in array order, filter `task_ids` through
      `task_is_ready` (Phase 1); on an empty filtered set, record the skip and continue WITHOUT
      calling `probe_candidate_set()`; on a non-empty filtered set, print the batch's authored
      position and `description`, then call the existing, unmodified
      `suggest_from_candidates()` with the filtered members. *(completed)*
- [x] Return success as soon as one batch renders; on success `mode_next_batch()` must NOT also run
      the three mechanical criteria for that invocation. *(completed)*
- [x] Note in the rendered output when a batch's filtered set is a proper subset of its authored
      `task_ids`, naming the omitted members (mirroring `render_next()`'s omit-and-say convention),
      so a partial batch is never presented as the whole authored batch. *(completed)*
- [x] On exhausting every batch, print one explicit line naming how many authored batches were
      checked, how many were skipped as empty-filtered, and how many were probed but deferred, then
      fall through to the existing three-criterion mechanical render with its existing text
      unchanged. *(completed)*
- [x] Check `PROBE_CAP_HIT` after each probing batch and stop the walk through the existing
      cap-reached convention; add no second cap message. *(completed)*
- [x] Wire the call into `mode_next_batch()` immediately after the empty-ready-pool early exit and
      before the `criteria` loop; leave the empty-ready-pool message, the option labels, and the
      "every candidate deferred" message untouched. *(completed)*
- [x] Extend the script's header (sections describing Mode A's selection doctrine) with the roadmap
      walk, the fallback statement, and the readiness/admissibility split — then widen `usage()`'s
      `sed -n '2,94p'` range (`orchestrate-suggest-next-batch.sh:99`) to the new header end line so
      the added lines actually appear in `--help`. *(completed: widened to 2,114p)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase is hypothesized to be confined to
`orchestrate-suggest-next-batch.sh` alone — two new functions, an insertion in
`mode_next_batch()`, header text, and the `usage()` range — with NO change to
`suggest_from_candidates()`, `run_candidate_round()`, `probe_candidate_set()`,
`select_candidates_for_criterion()`, `propose_edge_for_pair()`, Mode B, or the CLI flag set. The
implementer confirms this by diffing the finished phase (`git diff --stat` shows exactly one file;
`git diff` shows no hunk inside those functions) and by re-running the existing suite's Mode B and
edge-proposing cases green; if any of those surfaces genuinely must change, that is a scope
excursion to record, not a silent widening.

**Tier Justification**: `suite_selection_select` over this phase's single path returns exactly
`test-orchestrate-suggest-next-batch.sh`, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
exercises the whole Mode A/Mode B surface of the one file this phase edits.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - `read_roadmap_batches()` + `suggest_from_roadmap_batches()`, the `mode_next_batch()` insertion, header documentation, and the widened `usage()` line range

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
  still passes unchanged (every pre-existing case stays green; their scratch `state.json` has no
  `roadmap_batches` key, which must take the silent zero-probe skip path).
- `bash agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh --help` prints the
  new roadmap-walk header lines (proving the `usage()` range was widened, not just the header).
- `grep -c 'orchestrate-batch-admit' ` on the diff confirms no new admission call site beyond
  `probe_candidate_set()`; `git diff` shows no directory-prefix or overlap comparison added.
- `bash -n` clean on the edited file.

---

### Phase 3: Extend the regression suite with the roadmap-walk cases [COMPLETED]

**Goal**: The suite proves each new behavior mechanically, including both acceptance-named
degenerate paths (absent key, empty array) and the no-admissible-authored-batch path.

**Tasks**:
- [x] Add a `set_roadmap_batches <scratch> <json>` helper beside the existing
      `add_task`/`add_task_topic`/`add_queue_entry` helpers, writing `.roadmap_batches` onto the
      scratch `state.json` via `jq` (same tmp-file-then-`mv` convention). *(completed)*
- [x] Case: a clean authored batch, all members ready and disjoint -> the batch renders, its
      `description` appears, and the `Option 1 -- shared territory` mechanical header does NOT. *(completed: case k)*
- [x] Case: `roadmap_batches` key absent -> mechanical render fires exactly as today (regression
      guard for the pre-existing cases' fixture shape). *(completed: case l)*
- [x] Case: `roadmap_batches: []` -> same fallback behavior, asserted separately from the absent
      case. *(completed: case m)*
- [x] Case: two authored batches, every member not ready -> the explicit "no authored batch"
      fallback line names the batches checked, and the mechanical options then render. *(completed: case n)*
- [x] Case: first batch empty-filtered, second batch admissible -> the second renders and the
      first's skip is visible in the output. *(completed: case o; required a Phase 2 bug fix, see deviations)*
- [x] Case: a batch whose filtered set is a non-empty proper subset (one member `implementing`) ->
      the suggestion omits that member and says so. *(completed: case p)*
- [x] Case: a batch containing a `task_id` absent from `active_projects` entirely -> treated as
      not-ready, never silently admitted. *(completed: case q)*
- [x] Case: a batch with an internal `file_scope` collision -> the existing ordered-sequence +
      `--depends-on-add` rendering fires, proving no new collision code path was introduced. *(completed: case r)*
- [x] Update the suite's header comment to enumerate the new cases alongside (a)-(g). *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: eight new cases plus one helper, hypothesized to fit entirely within
`test-orchestrate-suggest-next-batch.sh` with no change to `scripts/tests/lib/common.sh` or to
`build_scratch()`'s copy list. The implementer confirms by `git diff --stat` naming one file; if a
new scratch dependency is genuinely needed, record the `build_scratch()` change explicitly rather
than absorbing it silently.

**Tier Justification**: `suite_selection_select` over this phase's single path returns exactly
`test-orchestrate-suggest-next-batch.sh`, which is the suite being edited and is run in full by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` - `set_roadmap_batches()` helper, eight new cases, header comment update

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
  exits 0 with every new case reported PASS and the pre-existing cases still passing.
- Each new case is confirmed to actually fail against a deliberately reverted behavior (spot-check
  at least the absent-key and no-admissible-batch cases) so none is a vacuous assertion.

---

### Phase 4: Record the new render case and the shared-readiness relationship [NOT STARTED]

**Goal**: The conclusion report's documented output cases include the roadmap-batch case and its
fallback, and the shared readiness concept is recorded where this script's guardrail row already
lives.

**Tasks**:
- [ ] In `context/patterns/orchestrate-batch-results-template.md`'s `**Suggested next batch**:`
      section (the anchor at line 236, confirmed present at plan time), add the new case: a
      suggestion naming an authored roadmap batch with its `description` and any omitted-member
      note, and the fallback form stating how many authored batches were checked and that the
      mechanical options follow. Keep the existing colliding-pair, cap-reached, and
      nothing-suggestible paragraphs intact.
- [ ] In `context/patterns/batch-orchestration-guardrails.md`, add a short subsection recording
      that `build_ready_set()`'s predicate and `roadmap-integration.sh`'s `render_next()`
      terminal-member filtering are the same readiness concept applied at two different bars, so a
      future reader changing one knows to check the other (the research report's context-extension
      recommendation). Do not alter the existing Exclusion Table row.
- [ ] Confirm `context/contracts/conclusion-stage.md`'s Step 7 invocation line needs no edit (the
      call site is unchanged) and state that confirmation in the phase's commit message rather than
      editing the file.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: two markdown files plus the derived `index-entries.json` line-count drift
they cause; no change to `conclusion-stage.md`. The implementer confirms by re-reading Step 7's
invocation line against the finished Phase 2 behavior before closing the phase — if the call site
did change, the declaration here is wrong and must be widened rather than skipped.

**Tier Justification**: `suite_selection_select` over this phase's three touched paths returns the
`__FULL_SWEEP__` sentinel — no suite covers them — so per sub-case (b) the covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(the source-store repository's own root as `TARGET`, where both gates run rather than skip) plus
the `local` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - new roadmap-batch render case and its fallback form in the `**Suggested next batch**:` section
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - new subsection recording the shared readiness concept across the two bars
- `agent-system/extensions/core/index-entries.json` - coupled generated surface: both edits above move their files' `line_count` entries (template currently 271); declared here, reconciled by the Phase 5 regeneration because `check-extension-docs.sh` Rule R is advisory in this repository (no `pre-commit` hook installed, verified at plan time)

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes (doc-lint and task-reference lint both run, neither skips).
- Diff read-through confirms every changed hunk is prose inside the named sections, with no
  record-versioning language and no task-number reference (both files are deliverables outside
  `specs/**`).

---

### Phase 5: Redeploy, run the full gate set, and attest live behavior [NOT STARTED]

**Goal**: The change is live in the deployed tree, the complete gate set is green, and the
suggester's real behavior against this repository's own `specs/state.json` is observed, not
assumed.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repository's
      standard headless deploy entry point) to regenerate the deployed `.claude/**` tree from the
      source store, which also auto-repairs the `index-entries.json` `line_count` drift declared in
      Phase 4.
- [ ] Confirm `git diff` on `agent-system/extensions/core/index-entries.json` shows only the
      expected `line_count` updates for the two files Phase 4 edited — no unrelated churn.
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate`), and record the result.
- [ ] Invoke the deployed suggester live against this repository's real state:
      `bash .claude/scripts/orchestrate-suggest-next-batch.sh --next-batch --session-id "$session_id"`,
      and confirm the output either names an authored roadmap batch with its `description` or states
      how many authored batches were checked and that it fell back — i.e. the task's ACCEPTANCE
      sentence, observed rather than inferred. Capture the output in the phase's summary.
- [ ] Cross-check that output against `specs/ROADMAP.md`'s `## Next` block: the named batch must be
      one of the authored batches, or the fallback reason must be consistent with the live
      readiness of the leading batches.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration (`deploy-headless.sh`), an implicit scope claim over the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` reconciliation for the two files Phase 4 edited

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates, every gate, no
  `--skip-slow` and no `--only-gate` narrowing) exits 0.
- `bash .claude/scripts/tests/run-all.sh` passes in full, including
  `test-orchestrate-suggest-next-batch.sh`'s new cases as deployed.
- The live `--next-batch` invocation's stdout satisfies the ACCEPTANCE sentence verbatim (names an
  authored batch, or states the batches checked and the fallback), quoted in the summary.
- `bash .claude/scripts/validate-state.sh` clean (no state mutation was intended by any phase; the
  suggester ran in its default propose-only form, never `--write-edges`).

## Testing & Validation

- [ ] Existing cases (a)-(g) of `test-orchestrate-suggest-next-batch.sh` pass unchanged after every
      phase (no fixture in them declares `roadmap_batches`, so they exercise the absent-key path).
- [ ] New case: clean authored batch renders, names its `description`, and suppresses the mechanical
      options.
- [ ] New case: absent `roadmap_batches` key -> mechanical fallback, zero roadmap probes.
- [ ] New case: `roadmap_batches: []` -> mechanical fallback, asserted independently.
- [ ] New case: every authored batch unready -> explicit fallback line naming the batches checked.
- [ ] New case: first batch empty-filtered, second admissible -> second renders, first's skip visible.
- [ ] New case: proper-subset filtering -> omitted member named, not silently dropped.
- [ ] New case: a `task_id` absent from `active_projects` -> treated as not-ready.
- [ ] New case: internal `file_scope` collision -> existing ordered-sequence rendering, no new
      collision code path.
- [ ] `--help` output includes the new roadmap-walk header documentation.
- [ ] Full `verify-deploy.sh` gate set green after redeploy.
- [ ] Live `--next-batch` output satisfies the ACCEPTANCE sentence and is consistent with
      `specs/ROADMAP.md`'s `## Next`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — roadmap-aware Mode A
  candidate source, shared readiness set, extended header and widened `usage()` range.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` — eight new
  cases plus the `set_roadmap_batches()` helper.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — new
  render case for the conclusion report.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — the
  shared-readiness-concept record.
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` reconciliation.
- Regenerated deployed `.claude/**` tree (not committed; gitignored deploy artifact).
- `specs/643_next_batch_suggestion_ignores_roadmap_ordering/summaries/01_*-summary.md` at
  completion.

## Rollback/Contingency

Each phase commits separately, so reverting is per-phase via `git revert` of that phase's commit
followed by a redeploy (`deploy-headless.sh`) to bring the deployed tree back in line with the
source store. If an in-flight phase must discard uncommitted working-tree changes, take a snapshot
first using the rollback-rung invocation shape in `context/contracts/recovery.md` (including its
out-of-scope override flag where the deployed tree is involved), then perform the revert — never a
destructive git operation on a dirty tree without that snapshot. The fallback-only contingency, if
the roadmap walk proves unworkable at implementation time, is to land Phases 1, 3, and 4 and leave
`suggest_from_roadmap_batches()` unwired behind an explicit, documented no-op — but that outcome
fails the task's ACCEPTANCE criterion and must be recorded as `[PARTIAL]` with a stated reason, not
presented as completion.
